# Architecture and internals

[Juicee](../README.md) / [Docs](../README.md#docs)

Deep dive into how the framework works. Read this if you're extending Juicee, debugging unexpected behavior, or evaluating it for a custom engine integration.

Contents: [Layer overview](#layer-overview), [The apply() pipeline](#the-apply-pipeline), [Tween tracking](#tween-tracking), [JuiceeStateStack: concurrent restore](#juiceestatestack-concurrent-restore), [Screen overlay pattern](#screen-overlay-pattern), [Shader uniforms pattern](#shader-uniforms-pattern), [Graph execution model](#graph-execution-model), [JuiceeBeatClock internals](#juiceebeatclock-internals), [FreezeFrame vs HitStop](#freezeframe-vs-hitstop), [Accessibility multiplier chain](#accessibility-multiplier-chain), [Editor preview hint](#editor-preview-hint), [JuiceePlayer signal trigger system](#juiceeplayer-signal-trigger-system), [Inspector plugin](#inspector-plugin), [Extending Juicee](#extending-juicee).

---

## Layer overview

```text
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
│  • Pre-delay (game-time timer)                      │
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

```text
apply(context, params)
 │
 ├─ enabled == false -> return, before anything else (a muted effect)
 ├─ Cooldown gate  -> silent drop if inside window
 ├─ Chance gate    -> randf() > chance -> return
 │       (a call dropped here leaves a play already running alone)
 ├─ Bump _gen  <- invalidates any in-flight coroutine from a previous apply()
 ├─ Put the previous run away as stop() would: kill its _active_tweens, release the state it
 │       captured, run its cleanup (overlays, bus effects), without the stopped signal
 ├─ Keep the effect alive until this play ends, so a fire-and-forget call is not freed
 ├─ Context in the tree? -> warn and return if it is null or not added yet
 ├─ Settings checked -> NaN, infinity or an enum value outside its list: warn and return
 ├─ params -> a NaN or infinity in them is left out of this play
 ├─ Pre-delay      -> delay_started.emit(delay), then await create_timer(delay, true, false, false)
 │       └─ if _gen changed during delay -> bail out (superseded)
 ├─ intensity_mult = randf_range(intensity_min, intensity_max)   (1.0 when both are 1)
 │       × params["intensity"]   (when the caller passed one)
 │       × accessibility.effective_multiplier(get_accessibility_tag())
 ├─ if intensity_mult ≤ 0 -> return (skipped by the caller, or blocked by accessibility)
 ├─ _retarget(context) -> the nearest node of the kind this effect needs, when the one it
 │       was handed is the wrong kind and it does not name a target of its own
 ├─ _runtime_params = params
 ├─ _active = true
 ├─ started.emit()
 ├─ Watch the context: if it leaves the tree mid-play, stop and restore right away
 ├─ await _apply(context, intensity_mult)
 ├─ if _gen changed inside _apply -> bail out (another apply() superseded this one, or
 │       stop() ended it and sent stopped itself)
 ├─ _active = false
 └─ finished.emit()
```

### Generation token cancellation

Every `apply()` increments `_gen` before doing anything, keeps `var my_gen := _gen`, and after each of its awaits checks `if my_gen != _gen: return`. If the value changed, a newer `apply()` or `stop()` has taken ownership, and this run exits silently. The pre-delay waits on game time, so `Engine.time_scale` slows it down.

This is how spam-clicking a button produces ONE effect run instead of N queued ones - each new `apply()` atomically supersedes the previous.

`stop()` also bumps `_gen`, so a pending delay timer aborts without ever reaching `_apply()`.

### Retargeting

Effects need a particular kind of node, and a `JuiceePlayer` hands over whatever it is parented
to, which is often a plain `Node` with the sprite beside it. `_retarget()` looks the right one up:
the context itself, then breadth first below it, at most the 256 nearest nodes, then up the parents, stopping before the scene
root so an effect never grabs the whole game, and stepping over anything named `_juicee*`, which
is everything Juicee spawns for itself. What each effect needs is `EFFECT_TARGETS` in the catalog,
a class name or `property:name` for the ones that drive a named property; effects that take any
node are absent from it and never move. An effect that names its own target (`target`,
`light_path`, `camera_path` and the rest) is left alone, because a NodePath is measured from the
context. `_nearest_node(context, ok)` is the same search with a predicate, for the effects whose
target cannot be known from a class.

---

## Tween tracking

Every tween created in `_apply()` must be wrapped with `_track()`:

```gdscript
var tween := _track(target.create_tween())
```

`_track()` appends the tween to `_active_tweens`. `stop()` iterates this array and calls `tween.kill()` on each valid entry, then clears the array. Without tracking, `stop()` cannot kill tween-driven effects mid-flight.

**Rule:** one `_track()` call per `create_tween()` call, no exceptions.

---

## JuiceeStateStack: concurrent restore

Problem: two effects both modify `camera.offset`. The second one captures a mid-shake value as its "original." When the first finishes and restores `offset`, the second has the wrong baseline. When the second finishes, the camera is stuck at a shake frame.

Solution: ref-counted single-original store.

```text
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

### What actually happens when two effects share a property

The stack solves restoring, and adds up the loops that move a property by an offset. The
four ways two writers can meet behave differently. Measured by sampling the property every
frame through an overlap (`temp/test_stacking.gd`):

**Tween over tween is continuous.** A second Scale effect starting on top of a running
one picks the property up from wherever it is and carries on. The largest single-frame
movement through the overlap was 0.055, against 0.079 for one effect's own return, so
there is no snap at the handover: the later tween simply wins each frame and it wins
from the current value. Afterwards the property returns to the true original, which is
the stack's whole job, and it does.

**Loops that move a property by an offset add up.** Shake, Wiggle, Sway, Breathe and the
other loops that move a property around its original (every loop-driven effect but Flicker,
Color Cycle, Ambient Flash and Text Scramble, which set the whole value) take it with
`_capture_offset()` and write with `_write_offset()`: each puts its offset into one sum on
the stack, and the property gets the original plus the sum. Each used to write its own
original plus offset, and the last to wake in a frame won. At 60 fps a camera shake of
intensity 20 peaked at 1.4 px under one of intensity 2 that landed after it
(`temp/probe_shake_overlap.gd`); now it peaks at 13.1 px. Many at once are scaled back so
together they reach about one and a half times as far as the widest, a number picked so
two hits shake more than one and a crowd of them does not throw the screen around: six
shakes of intensity 20 at once peak at 11.9 px, against 9.8 for one. A shake stopped
halfway takes its part out of the sum. An idle Breathe that bobs and a hit Wiggle on one node both show, 7.6 to
7.8 of 8 px up and 5.9 of 6 px sideways.

**A tween beats a manual loop, completely.** A loop-driven effect writes its value each
iteration, and a tween on the same property writes later in the frame and overwrites it.
Measured: a Wiggle with a 6 px amplitude running under a Position tween moved the node
**0.000 px**. Not reduced, not fighting - invisible. If you need both, put them on
different nodes. The same goes for two loops that set the whole value, a Flicker and a
Color Cycle on one `modulate`: the later to wake wins.

Because that failure looks exactly like an effect that is not firing, it warns. When a
property is held by more than one effect, at least one of them writes from a loop, and
they do not all add offsets, the second one to arrive emits `warning` and pushes the same
message, naming the property and the node. Two tweens sharing a property stay quiet,
because nothing is lost there, and so do loops that add up. The loop-driven effects are
listed in `JuiceeEffectCatalog.LOOP_WRITERS`, and a test re-derives that list from the
sources so it cannot drift away from them.

**Your own code beats everything.** A script assigning the property every frame wins,
because it runs after. So a car whose script leans and pitches its `Visual` node gives
the effects an empty `Juicy` node under it to work on: the effects animate `Juicy` and
never contend with the lean and pitch code. It is worth copying whenever code and
effects want the same object.

Tweens do not add up: a tween sets the whole value, so a tween and a loop on one
property still lose the loop, and that is what the warning is left for.

**Dead target safety:** `release(freed_target, ...)` detects `is_instance_valid(target) == false` and prunes all stale entries for that instance. No leaks even if the node dies mid-effect.

---

## Screen overlay pattern

Full-screen shader effects (Blur, Chromatic, Shockwave, etc.) need to read the screen. Godot's standard approach is a `BackBufferCopy` that captures the viewport, followed by a `ColorRect` sibling that reads it via `SCREEN_TEXTURE` in a shader.

### `_spawn_screen_shader_overlay(context, layer_name, z)`

```text
CanvasLayer (layer=z, name=layer_name)
├── BackBufferCopy (COPY_MODE_VIEWPORT)
│       └── captures viewport contents when it renders
└── ColorRect (size=viewport, shader=your_effect.gdshader)
        └── reads SCREEN_TEXTURE (= the back buffer captured above)
```

Returns `[CanvasLayer, ColorRect]`.

**Why siblings, not parent/child?** Godot's rendering order: `BackBufferCopy` renders first (captures screen), then sibling `ColorRect` renders (reads capture). If `ColorRect` were a child of `BackBufferCopy`, it would render inside the copy region before the capture finalizes - wrong result.

**Why a CanvasLayer?** To render on top of the entire scene regardless of the context node's position in the tree. `z` controls layering - Juicee effects use 128 by default. `FreezeFrame` flash uses 250 to sit above everything else.

The full spread is 126 to 250, not just 128: Screen Tint sits at 126, Vignette at 127, Blur, Chromatic, Color Grade, Glitch and Pixelate at the default 128, Lens Distortion at 130, the effects that draw over the frame (Film Grain, Radial Blur, Scan Lines, Shockwave, Speed Lines and Cinematic Bars) at 200, and the Freeze Frame flash at 250. That range is what a game's own HUD has to be placed against, since anything below it is part of the picture the shaders distort. See [Keeping your HUD readable](effects-reference.md#keeping-your-hud-readable).

### `_spawn_screen_solid_overlay(context, layer_name, z)`

Same structure but without the `BackBufferCopy`. Used for effects that only need a colored `ColorRect` (Screen Tint, and Freeze Frame's flash) - no shader, no screen read, zero extra GPU cost.

### `_sweep_overlay_layers(context, layer_name)`

Frees every child of `context` whose name starts with `layer_name`, renaming each one first so the new layer can take the exact name straight away. Both spawn helpers call it before adding their layer, so an effect never calls it itself.

**Why necessary?** If an effect is called again before its last run finished, the new `apply()` bumps `_gen` and the old run bails out at its next await, but its layer is still in the tree. Without the sweep that layer would stay, and the new one would be added beside it.

Without the sweep, rapid-firing a blur or shockwave would stack 5 shader overlays, each reading from each other, causing visual artifacts and mounting GPU cost.

---

## Shader uniforms pattern

All screen shaders read the source image through a `hint_screen_texture` sampler, `filter_linear_mipmap` in most and `filter_nearest` in the pixel ones:

```glsl
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;          // <- always SCREEN_UV, not UV
    COLOR = texture(SCREEN_TEXTURE, uv);
}
```

**Critical:** `UV` on a `ColorRect` is the rect's own local UV (always 0->1 top-left to bottom-right regardless of window size). `SCREEN_UV` is the normalized viewport UV - the coordinates that correctly address the screen texture. Using `UV` with `SCREEN_TEXTURE` causes the shader to sample a fixed 0-1 region that doesn't match the viewport geometry, especially when the game runs at non-1:1 scaling.

**Aspect ratio** in screen-space effects (e.g. Shockwave's distance calculation):
```glsl
vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
vec2 d = (SCREEN_UV - origin_uv) * aspect;
```

`SCREEN_PIXEL_SIZE` is `vec2(1.0 / viewport_width, 1.0 / viewport_height)`, so `SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x` is width over height. Multiplying the horizontal UV offset by it puts both axes in units of screen height, and a circle stays a circle. Shockwave used to multiply by `SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y`, height over width, which shrinks sideways distances twice over: measured on a 16:9 window its ring came out 3.2 times wider than tall. Note that `1.0 / SCREEN_PIXEL_SIZE.y * SCREEN_PIXEL_SIZE.x` is not a different formula, since GLSL evaluates it left to right as `x / y`.

---

## Graph execution model

`JuiceeGraphPlayer` is a `Node` that adds itself as a temporary child of `context`, walks the graph recursively, then `queue_free()`s itself.

```gdscript
static func play(resource, context):
    var trigger := resource.find_trigger()
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
| Timer | `create_timer(dur, true, false, true)` | `create_timer(dur, true, false, true)` |
| Timer ignores time_scale? | Yes | Yes |

The 4th argument to `SceneTree.create_timer()` is `ignore_time_scale`. Both pass `true`, because a timer that follows the time scale never fires while `time_scale` is 0.

---

## Accessibility multiplier chain

```text
apply(context, params)
  │
  └─ intensity_mult = randf_range(intensity_min, intensity_max)
                    × params["intensity"]   (when passed)
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
    var args := 0
    for s in source.get_signal_list():
        if StringName(s["name"]) == trigger_signal:
            args = (s["args"] as Array).size()
    source.connect(trigger_signal, _on_trigger_signal.unbind(args) if args > 0 else _on_trigger_signal)

func _on_trigger_signal() -> void:
    play()
```

The player reads how many arguments the signal sends and drops them all with `unbind()`, so `pressed()`, `body_entered(body)`, `area_shape_entered(area_rid, area, area_shape_index, local_shape_index)` and signals with more arguments still connect without the player knowing their signatures. In 1.x the handler took up to four arguments with defaults, and a signal with five reported an error every time it fired.

---

## Inspector plugin

`JuiceeInspectorPlugin` (`addons/juicee/editor/juicee_inspector_plugin.gd`) handles `JuiceePlayer` and `JuiceeSequence` in the Inspector. It:

1. Adds a toolbar under a `JuiceePlayer`'s heading (`_parse_category`), with **Preview Effect** and **Edit in Graph**. On a player with several sequences both ask which one.
2. Replaces the `effects` array of a `JuiceeSequence` with a row per effect (`_parse_property`): its name, category stripe and length, a preview button, and an inline editor that opens under it. Rows are dragged to reorder, and right-clicked for preview, mute, duplicate, move, reset to defaults, open in the Inspector and remove. The header plays the whole sequence and opens or closes every row at once.
3. Provides a **+ Add Effect** picker with collapsible categories, fuzzy search and the same 2D / 3D tags, over the same scan as the graph popup.

Every other property keeps Godot's standard editor.

---

## Extending Juicee

### Adding an effect (1 file)

See [how-to-write-effect.md](how-to-write-effect.md). The graph editor and the Inspector picker both list what `JuiceeEditorUtil.effect_scripts()` finds, which is the addon's own folder plus every directory in `juicee/effect_folders`.

`EFFECT_CATEGORIES` / `EFFECT_DESCRIPTIONS` / `EFFECT_DIMENSIONS` in `juicee_effect_catalog.gd` carry that metadata for the built-in effects. Do **not** add your own effects to them: they live inside the addon, and updating the addon means deleting its folder. Override `get_category_name()` and `get_description()` on your effect instead, which take precedence over those dicts and travel with your file.

### Adding a custom graph node type

1. Add a new key to `JuiceeGraphBlock.BUILTIN_META` with `title`, `sub`, `color`, `icon`, `tip`.
2. Add the port/body-building case to `JuiceeGraphBlock.create()`.
3. Add the execution case to `JuiceeGraphPlayer._chain()`. The editor's Test walks the graph through `JuiceeGraphPlayer.run()` as well, so it needs no case of its own. A block with outputs that mean different things reads them by port with `JuiceeGraphResource.get_next_by_port()`, as Condition and Random do: a port keeps its meaning whether or not the outputs before it are wired.
4. Add the popup entry with `_add_popup_item()` in `JuiceeGraphEditor._build_popup()`.
5. Add the props editor case to `JuiceePropertyPanel._build_props_for_builtin()`.

### Replacing the screen overlay pattern

If you need a post-process pipeline that doesn't use `BackBufferCopy` (e.g., Godot 4 Compositor in 3D scenes), override `_spawn_screen_shader_overlay()` in a subclass of the effect, return your own `[CanvasLayer, YourNode]` array, and follow the same cleanup contract (`_sweep_overlay_layers` at the top, `layer.queue_free()` at the bottom).
