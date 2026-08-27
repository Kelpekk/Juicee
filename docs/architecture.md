# Juicee - Architecture & Internals

Deep dive into how the framework works. Read this if you're extending Juicee, debugging unexpected behavior, or evaluating it for a custom engine integration.

---

## Layer overview

```
┌─────────────────────────────────────────────────────┐
│  Game code                                          │
│  Juicee.shake_camera(self)   <- singleton            │
│  $Player.play()              <- JuiceePlayer node    │
│  JuiceeGraphPlayer.play(res) <- graph runtime        │
└────────────────┬────────────────────────────────────┘
                 │ calls .apply(context, params)
┌────────────────▼────────────────────────────────────┐
│  JuiceeSequence / JuiceeEffect                      │
│  • Cooldown gate                                    │
│  • Chance roll                                      │
│  • Pre-delay (real-time timer)                      │
│  • Intensity multiplier                             │
│  • Accessibility gate                               │
│  • _apply(context, intensity_mult)  <- your code     │
│  • Signal emit (started / finished / stopped)       │
└────────────────┬────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────┐
│  Runtime helpers                                    │
│  JuiceeStateStack  - concurrent property restore    │
│  _track(tween)     - stop() cleanup                 │
│  _spawn_*_overlay  - screen effect scaffolding      │
│  JuiceeBeatClock   - BPM tick source                │
└─────────────────────────────────────────────────────┘
```

---

## The apply() pipeline

Every `apply()` call runs this sequence:

```
apply(context, params)
 │
 ├─ Bump _gen  <- invalidates any in-flight coroutine from a previous apply()
 ├─ Kill all _active_tweens from the previous run
 ├─ Cooldown gate  -> silent drop if inside window
 ├─ Chance gate    -> randf() > chance -> return
 ├─ Pre-delay wait -> await create_timer(delay, real_time=true)
 │       └─ if _gen changed during delay -> bail out (superseded)
 ├─ intensity_mult = randf_range(intensity_min, intensity_max)
 │       × accessibility.effective_multiplier(get_accessibility_tag())
 ├─ if intensity_mult ≤ 0 -> return (accessibility blocked)
 ├─ _runtime_params = params
 ├─ _active = true
 ├─ started.emit()
 ├─ await _apply(context, intensity_mult)
 ├─ if _gen changed inside _apply -> bail out (another apply() superseded this one)
 ├─ _active = false
 └─ if _cancelled -> stopped.emit()
    else          -> finished.emit()
```

### Generation token cancellation

Every `apply()` increments `_gen` before doing anything. Each coroutine captures `var my_gen := _gen` at the start. After every await point it checks `if my_gen != _gen: return` - if the value changed, a newer `apply()` or `stop()` has taken ownership, and this coroutine exits silently.

This is how spam-clicking a button produces ONE effect run instead of N queued ones - each new `apply()` atomically supersedes the previous.

`stop()` also bumps `_gen`, so a pending delay timer aborts without ever reaching `_apply()`.

---

## Tween tracking

Every tween created in `_apply()` must be wrapped with `_track()`:

```gdscript
var tween := _track(target.create_tween())
```

`_track()` appends the tween to `_active_tweens`. `stop()` iterates this array and calls `tween.kill()` on each valid entry, then clears the array. Without tracking, `stop()` cannot kill tween-driven effects mid-flight.

**Rule:** one `_track()` call per `create_tween()` call, no exceptions.

---

## JuiceeStateStack - concurrent restore

Problem: two effects both modify `camera.offset`. The second one captures a mid-shake value as its "original." When the first finishes and restores `offset`, the second has the wrong baseline. When the second finishes, the camera is stuck at a shake frame.

Solution: ref-counted single-original store.

```
Key format:  "{instance_id}:{property_name}"

capture("cam", "offset"):
  -> if key exists: refs++, return existing original
  -> if key new:    original = cam.offset, refs=1, store

release("cam", "offset"):
  -> refs--
  -> if refs == 0: cam.offset = original, erase key
```

The true original is captured exactly once (by the first effect to touch the property). All subsequent effects get the same original. The property is only restored when the last effect releases it. No "stuck at a mid-shake frame" bug possible.

**Sub-property paths** work too: `JuiceeStateStack.capture(cam, "offset:x")` via `Object.get_indexed()` / `set_indexed()`.

**Dead target safety:** `release(freed_target, ...)` detects `is_instance_valid(target) == false` and prunes all stale entries for that instance. No leaks even if the node dies mid-effect.

---

## Screen overlay pattern

Full-screen shader effects (Blur, Chromatic, Shockwave, etc.) need to read the screen. Godot's standard approach is a `BackBufferCopy` that captures the viewport, followed by a `ColorRect` sibling that reads it via `SCREEN_TEXTURE` in a shader.

### `_spawn_screen_shader_overlay(context, layer_name, z)`

```
CanvasLayer (layer=z, name=layer_name)
├── BackBufferCopy (COPY_MODE_VIEWPORT)
│       └── captures viewport contents when it renders
└── ColorRect (size=viewport, shader=your_effect.gdshader)
        └── reads SCREEN_TEXTURE (= the back buffer captured above)
```

Returns `[CanvasLayer, ColorRect]`.

**Why siblings, not parent/child?** Godot's rendering order: `BackBufferCopy` renders first (captures screen), then sibling `ColorRect` renders (reads capture). If `ColorRect` were a child of `BackBufferCopy`, it would render inside the copy region before the capture finalizes - wrong result.

**Why a CanvasLayer?** To render on top of the entire scene regardless of the context node's position in the tree. `z` controls layering - Juicee effects use 128 by default. `FreezeFrame` flash uses 250 to sit above everything else.

### `_spawn_screen_solid_overlay(context, layer_name, z)`

Same structure but without the `BackBufferCopy`. Used for effects that only need a colored `ColorRect` (ScreenTint, CinematicBars, FreezeFrameFlash) - no shader, no screen read, zero extra GPU cost.

### `_sweep_overlay_layers(context, layer_name)`

Removes all children of `context` whose name starts with `layer_name`. Called at the top of every screen effect.

**Why necessary?** If effect A is running (has a layer named `_juicee_blur_overlay`) and effect A is called again before finishing, the new `apply()` bumps `_gen` - the old coroutine will bail out after its next await. But the old layer may still exist under a renamed name (Godot renames `_juicee_blur_overlay` to `_juicee_blur_overlay2` when a second child with the same name is added). The sweep removes ALL children whose name begins with the prefix, catching both the canonical name and any rename variants.

Without the sweep, rapid-firing a blur or shockwave would stack 5 shader overlays, each reading from each other, causing visual artifacts and mounting GPU cost.

---

## Shader uniforms pattern

All screen shaders use `hint_screen_texture` for the source image:

```glsl
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;          // <- always SCREEN_UV, not UV
    COLOR = texture(SCREEN_TEXT, uv);
}
```

**Critical:** `UV` on a `ColorRect` is the rect's own local UV (always 0->1 top-left to bottom-right regardless of window size). `SCREEN_UV` is the normalized viewport UV - the coordinates that correctly address the screen texture. Using `UV` with `SCREEN_TEXTURE` causes the shader to sample a fixed 0-1 region that doesn't match the viewport geometry, especially when the game runs at non-1:1 scaling.

**Aspect ratio** in screen-space effects (e.g. Shockwave's distance calculation):
```glsl
// CORRECT:
vec2 aspect = vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0);
vec2 d = (SCREEN_UV - origin_uv) * aspect;

// WRONG:
vec2 aspect = vec2(1.0 / SCREEN_PIXEL_SIZE.y * SCREEN_PIXEL_SIZE.x, 1.0);
// (this had a division order bug - produces 1/(y * x) not x/y)
```

`SCREEN_PIXEL_SIZE` = `vec2(1.0/viewport_width, 1.0/viewport_height)` - so `SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y` = `viewport_height / viewport_width` = the correct aspect ratio for UV-space distance normalization.

---

## Graph execution model

`JuiceeGraphPlayer` is a `Node` that adds itself as a temporary child of `context`, walks the graph recursively, then `queue_free()`s itself.

```gdscript
static func play(resource, context):
    var runner := JuiceeGraphPlayer.new()
    context.add_child(runner)
    await runner._chain(trigger, resource, context)
    if is_instance_valid(runner):
        runner.queue_free()
```

`_chain(node, resource, context)`:
1. Calls `_execute(node, context)` - if it's an effect node, awaits `effect.apply(context)`.
2. Gets `nexts = resource.get_next(node.id)`.
3. Dispatches based on `node.type`:
   - `split` -> calls `_chain()` on all nexts WITHOUT await (true parallel)
   - `loop` -> `for i in count: await _chain(nexts[0], ...)` (sequential repetition)
   - `random` -> picks one index via weighted random, awaits that branch
   - `condition` -> evaluates `Expression`, picks port 0 or 1
   - everything else -> `await _chain(nexts[0], ...)`

### Condition node evaluation

```gdscript
var expr := Expression.new()
if expr.parse(expr_str, ["context"]) == OK:
    var val := expr.execute([context], context)
    if not expr.has_execute_failed():
        result = bool(val)
```

The expression has `context` as a named variable. The `base_instance` is also `context`, so you can call methods directly: `context.is_in_group("player")` or just `is_in_group("player")` (both resolve). The expression is sandboxed to what `Expression` exposes - no `OS`, `FileAccess`, etc. for safety.

---

## JuiceeBeatClock internals

Uses a float accumulator + while loop in `_process()`:

```gdscript
func _process(delta: float) -> void:
    if not _running: return
    _accumulator += delta
    var beat_interval := 60.0 / bpm
    while _accumulator >= beat_interval:
        _accumulator -= beat_interval
        _beat_number += 1
        beat.emit(_beat_number)
```

The `while` (not `if`) handles the edge case where a long frame delta spans two beat intervals - both beats are emitted in order without being lost. This is important for fast BPM values (>240 BPM at 30FPS).

`get_beat_phase()` returns `_accumulator / beat_interval` - the interpolated 0->1 position within the current beat. Use this to drive visual effects that pulse continuously rather than just on the tick.

---

## FreezeFrame vs HitStop

Both set `Engine.time_scale` but with different intent and implementation:

|  | HitStop | FreezeFrame |
|---|---|---|
| Purpose | Tactile micro-pause (weapon impact, block) | Visual beat (finishing blow, super move) |
| Duration | 50-100ms typical | 60-120ms typical |
| Flash | None | Full-screen flash overlay |
| `time_scale` target | `0.0` or `0.05` | `0.0` |
| Timer | `create_timer(dur, true, false, false)` | `create_timer(dur, true, false, **true**)` |
| Timer ignores time_scale? | No (fine because 0.05 still runs) | **Yes** - required because `time_scale=0` stops all non-real-time timers |

The 4th argument to `SceneTree.create_timer()` is `ignore_time_scale`. FreezeFrame must pass `true` or the timer never fires while `time_scale=0`.

---

## Accessibility multiplier chain

```
apply(context, params)
  │
  └─ intensity_mult = randf_range(intensity_min, intensity_max)
                    × accessibility.effective_multiplier(tag)

effective_multiplier(tag):
  -> if not is_allowed(tag): return 0.0    <- hard block (no_screenshake etc.)
  -> base = intensity_scale                 <- 0.0-1.0 master slider
  -> if reduced_motion: base *= 0.25        <- soft 4× reduction
  -> return base
```

Setting `intensity_scale = 0.0` is equivalent to globally silencing all effects without setting individual flags. Setting `reduced_motion = true` multiplies by 0.25 - effects are still present but very subtle.

Effects that have no accessibility concern (audio, time, flow) return `TAG_NONE` from `get_accessibility_tag()`. `effective_multiplier(TAG_NONE)` returns `intensity_scale × (reduced_motion ? 0.25 : 1.0)` - reduced motion still applies, but individual flags like `no_screenshake` don't.

---

## Editor preview hint

When any screen effect spawns an overlay in the editor (not in a running game), `_add_editor_preview_hint()` adds:

1. A `Panel` with an amber 2px border sized to the editor preview viewport.
2. A floating `PanelContainer` label in the top-left corner saying "Editor preview · effects render inside this rect."

This marker is skipped in runtime (`Engine.is_editor_hint() == false`). It exists because the editor preview viewport is much smaller than the game window, making shader effects appear cropped or "broken" - the hint prevents bug reports for expected behavior.

---

## JuiceePlayer signal trigger system

`JuiceePlayer` can auto-fire without any code via `trigger_source` + `trigger_signal`:

```gdscript
func _connect_trigger_signal() -> void:
    var source := get_node_or_null(trigger_source)
    source.connect(trigger_signal, _on_trigger_signal)

func _on_trigger_signal(_a=null, _b=null, _c=null, _d=null) -> void:
    play()
```

The handler signature accepts up to 4 ignored arguments. This lets it connect to signals of any arity - `body_entered(body)`, `pressed()`, `area_shape_entered(area_rid, area, idx, shape)` - all work without knowing the signal's actual signature. Godot's `connect()` uses argument binding under the hood.

---

## Inspector plugin

`JuiceeInspectorPlugin` (`addons/juicee/editor/juicee_inspector_plugin.gd`) renders the custom card UI for `JuiceePlayer` and `JuiceeSequence` in the Inspector. It:

1. Detects when a `JuiceePlayer` is selected.
2. Renders a horizontal card per effect with the effect name, category tag, and **▶ Preview** button.
3. Provides a **+ Add Effect** dropdown that shows all discovered effects (same scan as the graph popup).
4. Provides drag-to-reorder handles.

The plugin does NOT replace the standard Inspector - it prepends its UI above the standard property list using `_parse_begin`.

---

## Extending Juicee

### Adding an effect (1 file)

See [how-to-write-effect.md](how-to-write-effect.md). The graph editor, Inspector dropdown, and `EFFECT_CATEGORIES`/`EFFECT_DESCRIPTIONS`/`EFFECT_DIMENSIONS` dicts in `juicee_graph_editor.gd` all auto-update from the file scan. For community effects, also add entries to those three dicts so the graph popup shows the correct category, description, and dimension tags.

### Adding a custom graph node type

1. Add a new key to `JuiceeGraphBlock.BUILTIN_META` with `title`, `sub`, `color`, `icon`, `tip`.
2. Add the port/body-building case to `JuiceeGraphBlock.create()`.
3. Add the execution case to `JuiceeGraphPlayer._chain()`.
4. Add the popup entry to `JuiceeGraphEditor._build_graph_popup()`.
5. Add the props editor case to `JuiceeGraphEditor._build_props_for_builtin()`.
6. Add the debug test case to `JuiceeGraphEditor._debug_walk()`.

### Replacing the screen overlay pattern

If you need a post-process pipeline that doesn't use `BackBufferCopy` (e.g., Godot 4 Compositor in 3D scenes), override `_spawn_screen_shader_overlay()` in a subclass of the effect, return your own `[CanvasLayer, YourNode]` array, and follow the same cleanup contract (`_sweep_overlay_layers` at the top, `layer.queue_free()` at the bottom).
