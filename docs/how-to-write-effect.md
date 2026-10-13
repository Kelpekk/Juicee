# Writing your own effect

[Juicee](../README.md) / [Docs](../README.md#docs)

Every Juicee effect is **one `.gd` file** extending `JuiceeEffect`. No central registry to update, no enum to extend, no graph node to add.

## Where to keep it

**Not in `addons/juicee/effects/`.** That folder is the addon's: the Update button writes over it, and installing a new version by hand means deleting it first. Anything of yours in there can go with it.

Keep your effects wherever you keep your own code, and point Juicee at that folder:

**Project Settings > Juicee > effect_folders** takes a list of directories. They are searched recursively, and everything in them that extends `JuiceeEffect` shows up in the "+ Add Effect" picker in the Inspector and in the graph's add-node popup, next to the built-in ones. Scripts in those folders that are not effects are left alone.

Your effect can name its own category with `get_category_name()`, so it groups under whatever you call it rather than being filed under someone else's taxonomy.

## The 30-line template

```gdscript
@tool
class_name MyCoolEffect
extends JuiceeEffect

## How far it moves, in pixels. A ## comment above an @export is its tooltip.
@export var amplitude: float = 10.0
@export var duration: float = 0.5

func get_category_name() -> String: return "My Game"   # optional
func get_description() -> String: return "Nudges a Node2D sideways and back."   # optional, the popup tooltip

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _play_id()
	var target := context as Node2D
	if not target or not target.is_inside_tree():
		_warn("MyCoolEffect: context is not a Node2D")
		return

	var original: Vector2 = _capture_state(target, "position")

	var tween := _track(target.create_tween())
	tween.tween_property(target, "position", original + Vector2(amplitude * intensity_mult, 0), duration * 0.5)
	tween.tween_property(target, "position", original, duration * 0.5)
	await tween.finished
	# Stopped or replaced: stop() or the new play has the position now.
	if not _still_playing(play):
		return

	_release_state(target, "position")
```

Save it as `my_cool_effect.gd` in one of your effect folders, and reload the project if it does not show up straight away.

The effect will now:

- Show up as **My Cool**, taken from the file name, in the JuiceeGraph popup under "My Game"
- Be selectable in the JuiceePlayer Inspector's "+ Add Effect" dropdown
- Inherit `chance`, `delay`, `intensity_min/max`, `cooldown`, `enabled`, `stop()`, `is_playing()` for free
- Have its `@export` properties shown as sliders with `##` docstrings as tooltips
- Respect the concurrent-restore state stack

---

## Core rules

1. **`@tool`**, so the Inspector's Preview and the graph's Test can run it in the editor. A `class_name` is for your own code, so it can write `MyCoolEffect.new()`; the pickers find the effect by what it extends either way.
2. **Override `_apply()`, NOT `apply()`** - `apply()` is the framework entry point that handles `chance`, `delay`, intensity multipliers, signals, and cooldown.
3. **Wrap every `create_tween()` with `_track()`** - otherwise `stop()` can't kill it.
4. **Note the play and check it after every `await`** - `var play := _play_id()` at the top of `_apply()`, then `_still_playing(play)` in loop conditions and before anything that runs after an `await`. `_cancelled` only says `stop()` was called: a new `apply()` resets it, so a loop that checks only `_cancelled` carries on beside the play that replaced it, and what it releases at its end is the newer play's hold.
5. **Use `_capture_state()` / `_release_state()`** for any property you'll restore at the end. Both helpers (defined in `JuiceeEffect`) register with `stop()` so properties are always restored and never double-released, even when effects are stopped mid-play or run concurrently.
6. **`is_inside_tree()` guards** - the context may have been freed between await points.
7. **`intensity_mult` is already accessibility-scaled** - don't apply your own accessibility checks; multiply your effect intensity by `intensity_mult` directly.
8. **Hand `stop()` what you spawn** - `_free_on_stop(node)` for a node the play adds, `_on_stop(callable)` for anything else the state stack cannot give back. Bind ids or use `weakref()` rather than a lambda that captures a node: Godot reports an error when a lambda is called after a node it captured was freed, whatever its body checks.

---

## Common patterns

### Tween that returns to original

```gdscript
var play := _play_id()
var original: Vector2 = _capture_state(target, "scale")
var tween := _track(target.create_tween())
tween.tween_property(target, "scale", original * 1.3, 0.15)
tween.tween_property(target, "scale", original, 0.2)
await tween.finished
# stop() or a new apply() wakes this with the play over: what it held is given back already.
if not _still_playing(play):
	return
_release_state(target, "scale")
```

A change meant to stay is captured all the same, and let go of without restoring at the end: `_release_state(target, "scale", false)`, or `_keep_state(target, "scale", goal)` to name the value kept. The stack then knows the original if the play is stopped half way, and an effect still holding the property comes back to the kept value instead of undoing it.

### Manual per-frame loop

Use this when you need per-frame control (noise-based shake, physics simulation, etc.).

```gdscript
var play := _play_id()
var original: Vector2 = _capture_offset(target, "position")
var elapsed := 0.0
var step := 1.0 / frequency
var tree := context.get_tree()
while elapsed < duration and _still_playing(play) and is_instance_valid(target):
	_write_offset(target, "position", original, Vector2(randf_range(-amplitude, amplitude), 0), amplitude)
	elapsed += await _wait_step(tree, step)
# Replaced by a new apply(), or stopped: the newer play or stop() owns the property now.
if not _still_playing(play):
	return
_release_state(target, "position")
```

**Move the property with `_write_offset()`** when the loop shakes or bobs it around where it was. Every loop doing that to one property adds up, the built-in shakes and wobbles among them, where setting it yourself lets the last loop to run each frame hide the others. The last argument is how far the offset reaches right now, here the amplitude. A loop that sets the whole value, a colour cycle say, takes it with `_capture_state()` and assigns it.

**Count the time with `_wait_step()`**, not by adding `step` after a timer. A timer can only fire on a frame, so the wait is usually longer than the step, and a loop that adds the step to its clock runs long: at 30fps a step of 1/24 of a second waits two frames. `_wait_step()` waits on the same timer and returns the time the wait really took. It follows `Engine.time_scale`, so a hit-stop slows the loop along with everything else. A loop that has to keep running through a freeze, like `FreezeFrameEffect`, waits on `create_timer(step, true, false, true)` instead.

### Screen shader overlay

```gdscript
const LAYER_NAME := &"_juicee_my_overlay"

func _apply(context: Node, intensity_mult: float) -> void:
	var result := _spawn_screen_shader_overlay(context, LAYER_NAME, 128)
	if result.is_empty():
		return
	var layer: CanvasLayer = result[0]
	var rect: ColorRect = result[1]

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://fx/shaders/my_effect.gdshader")   # your own folder, not the addon's
	mat.set_shader_parameter("strength", strength * intensity_mult)
	rect.material = mat

	# Fade in / hold / fade out
	var tween := _track(rect.create_tween())
	tween.tween_property(rect, "modulate:a", 1.0, duration * 0.1)
	tween.tween_interval(duration * 0.8)
	tween.tween_property(rect, "modulate:a", 0.0, duration * 0.1)
	await tween.finished

	if is_instance_valid(layer):
		layer.queue_free()
```

**Key points:**
- Always call `_spawn_screen_shader_overlay` (not `new CanvasLayer` directly) - it handles the sweep of stale layers.
- Start `rect.modulate.a = 0.0` and tween it in, or start at 1.0 for an immediate-on effect.
- `queue_free()` the layer (not the rect) - freeing the parent cleans up children.
- Read the screen through a `hint_screen_texture` sampler and `SCREEN_UV` (not `UV`) for correct full-screen coverage. The addon's own shaders declare `uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;`, or `filter_nearest` in the pixel ones.

### Spawning a temporary child node

```gdscript
func _apply(context: Node, intensity_mult: float) -> void:
	var label := Label.new()
	label.text = "Hello!"
	# Anything named _juicee* is stepped over when an effect looks for a node to play on, so a
	# spawn of yours is never mistaken for someone's target.
	label.name = StringName("_juicee_my_label_%d" % randi())
	label.position = Vector2(0, -50)
	context.add_child(label)
	# stop() frees it if the play is cut short.
	_free_on_stop(label)

	# Parallel, so it fades while it rises. A negative set_delay does not do this: measured, the
	# rise waited for the whole fade before it started.
	var tween := _track(label.create_tween()).set_parallel()
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_property(label, "position:y", -100.0, 0.8)
	await tween.finished

	if is_instance_valid(label):
		label.queue_free()
```

A tween you leave out of `_track()` on purpose, so that firing again does not cut it short, is waited for with `await _tween_done(tween)` rather than `await tween.finished`: a tween whose node is freed never sends `finished`.

### Reading runtime params

```gdscript
func _apply(context: Node, intensity_mult: float) -> void:
	var direction: Vector2 = _param("hit_direction", Vector2.ZERO)
	var damage: int = _param("damage", 0)
	# ... use these values ...
```

Caller passes params via `effect.apply(context, {"hit_direction": Vector2.LEFT})` or `juicee_player.play({"damage": 42})`. `_param()` returns the fallback, with a warning, when the caller passed a value of another type, so `{"hit_direction": "left"}` does not stop the play with a script error the way assigning `_runtime_params.get()` to a typed variable would.

### Designer-controlled easing with Curve

```gdscript
@export var scale_curve: Curve   # designer paints the easing shape in Inspector

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _play_id()
	var target := context as Node2D
	var original: Vector2 = _capture_state(target, "scale")
	var tween := _track(target.create_tween())
	_tween_curved(tween, target, "scale", original, original * 1.5, 0.4, scale_curve)
	await tween.finished
	if not _still_playing(play):
		return
	_release_state(target, "scale")
```

If `scale_curve` is null, `_tween_curved` falls back to a normal `tween_property` - the caller can chain `set_trans`/`set_ease` on it. If a curve is set, it samples the curve per-frame - set_trans is ignored.

---

## Optional virtual methods

```gdscript
func get_display_name() -> String         # "My Cool" (default: parsed from script name)
func get_category_name() -> String        # "My Game" - group in graph popup
func get_category_color() -> Color        # colored stripe on graph block titlebar
func get_icon_path() -> String            # SVG icon path
func get_description() -> String          # tooltip in graph popup
func get_accessibility_tag() -> int       # JuiceeAccessibility.TAG_SCREENSHAKE, etc.
func get_required_nodes() -> PackedStringArray  # ["Node2D"], or "property:text"
```

`get_required_nodes()` is worth overriding as soon as your effect casts its context to something.
Return the class names it can work on and a play that lands on the wrong kind of node moves to the
nearest right one instead of warning, which is what the built-ins do. Leave it alone if your effect
takes any node.

---

## Registering in the graph editor

For community effects shipping in the core addon, also add entries to the three dicts in `addons/juicee/core/juicee_effect_catalog.gd`:

```gdscript
# EFFECT_CATEGORIES - which category section to show it under
"my_cool_effect": "Object",

# EFFECT_DESCRIPTIONS - tooltip in the popup and graph block
"my_cool_effect": "Does something cool.\nUse for: boss intros, combo finishers.",

# EFFECT_DIMENSIONS - 2D/3D tags on the graph block titlebar
"my_cool_effect": ["2d"],   # or ["3d"] or ["2d","3d"]

# EFFECT_TARGETS - the kind of node it needs, so a play on the wrong one moves to the right one
"my_cool_effect": "Node2D",   # or "Node2D,Control", or "property:text", or leave it out
```

These are fallback registries - an effect that overrides `get_category_name()` / `get_description()` in its own `.gd` file takes precedence.

---

## Anti-patterns to avoid

| Wrong | Right | Why |
|---|---|---|
| `target.position = Vector2.ZERO` | `_capture_state()` + `_release_state()` | Concurrent effects get the wrong "original"; and without `_capture_state`, `stop()` can't restore mid-tween |
| `target.create_tween()` | `_track(target.create_tween())` | `stop()` can't kill untracked tweens |
| `await tree.create_timer(step).timeout`, then `elapsed += step` | `elapsed += await _wait_step(tree, step)` | A timer fires on a frame, so the wait runs longer than the step and a loop that adds the step runs long |
| Check `_active` or `_cancelled` in loops | Check `_still_playing(play)` | `_active` is managed by the framework, and a new `apply()` resets `_cancelled`, so a loop checking it carries on beside the play that replaced it |
| `var dir: Vector2 = _runtime_params.get("hit_direction", Vector2.ZERO)` | `var dir: Vector2 = _param("hit_direction", Vector2.ZERO)` | A caller passing the wrong type stops the play with a script error; `_param()` warns and falls back |
| Override `apply()` | Override `_apply()` | `apply()` runs the cooldown/chance/delay pipeline; bypassing it breaks all that |
| `JuiceeFoo.new().apply(ctx)` when the caller may want to stop it | `var e := JuiceeFoo.new(); e.apply(ctx); return e` | A running effect keeps itself alive, so fire-and-forget is fine, but `stop()` needs the reference |

---

## Contribute upstream

If your effect is general-purpose, open a PR. The bar is:

- Single file in `addons/juicee/effects/`
- `## docstring` on every `@export`
- Follows the patterns above (`_track`, `_cancelled`, `JuiceeStateStack`)
- Sensible defaults - `Effect.new(); effect.apply(some_context)` should produce a visible result without tweaking
- Entries in `EFFECT_CATEGORIES`, `EFFECT_DESCRIPTIONS`, `EFFECT_DIMENSIONS`
