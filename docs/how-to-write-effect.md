# How to write a new Juicee effect

Every Juicee effect is **one `.gd` file** extending `JuiceeEffect`. No central registry to update, no enum to extend, no graph node to add - the editor scans `addons/juicee/effects/` automatically.

## The 30-line template

```gdscript
@tool
class_name MyCoolEffect
extends JuiceeEffect

## A short description used as a tooltip in the JuiceeGraph popup.
@export var amplitude: float = 10.0
@export var duration: float = 0.5

func get_category_name() -> String: return "My Game"   # optional

func _apply(context: Node, intensity_mult: float) -> void:
	var target := context as Node2D
	if not target or not target.is_inside_tree():
		push_warning("MyCoolEffect: context is not a Node2D")
		return

	var original: Vector2 = _capture_state(target, "position")

	var tween := _track(target.create_tween())
	tween.tween_property(target, "position", original + Vector2(amplitude * intensity_mult, 0), duration * 0.5)
	tween.tween_property(target, "position", original, duration * 0.5)
	await tween.finished

	_release_state(target, "position")
```

Drop this file into `addons/juicee/effects/`. Reload the project. Done.

The effect will now:

- Show up as **My Cool** in the JuiceeGraph popup under "My Game"
- Be selectable in the JuiceePlayer Inspector's "+ Add Effect" dropdown
- Inherit `chance`, `delay`, `intensity_min/max`, `cooldown`, `stop()`, `is_playing()` for free
- Have its `@export` properties shown as sliders with `##` docstrings as tooltips
- Respect the concurrent-restore state stack

---

## Core rules

1. **`@tool` + `class_name`** - required so the editor can list and instantiate it.
2. **Override `_apply()`, NOT `apply()`** - `apply()` is the framework entry point that handles `chance`, `delay`, intensity multipliers, signals, and cooldown.
3. **Wrap every `create_tween()` with `_track()`** - otherwise `stop()` can't kill it.
4. **Check `_cancelled` in manual loops** - `while elapsed < duration and not _cancelled:`
5. **Use `_capture_state()` / `_release_state()`** for any property you'll restore at the end. Both helpers (defined in `JuiceeEffect`) register with `stop()` so properties are always restored and never double-released, even when effects are stopped mid-play or run concurrently.
6. **`is_inside_tree()` guards** - the context may have been freed between await points.
7. **`intensity_mult` is already accessibility-scaled** - don't apply your own accessibility checks; multiply your effect intensity by `intensity_mult` directly.

---

## Common patterns

### Tween that returns to original

```gdscript
var original: Vector2 = _capture_state(target, "scale")
var tween := _track(target.create_tween())
tween.tween_property(target, "scale", original * 1.3, 0.15)
tween.tween_property(target, "scale", original, 0.2)
await tween.finished
_release_state(target, "scale")
```

### Manual per-frame loop

Use this when you need per-frame control (noise-based shake, physics simulation, etc.).

```gdscript
var elapsed := 0.0
var tree := context.get_tree()
while elapsed < duration and not _cancelled and is_instance_valid(target):
	target.position = original + Vector2(randf_range(-amplitude, amplitude), 0)
	var step := 1.0 / frequency
	await tree.create_timer(step, true, false, false).timeout
	elapsed += step
_release_state(target, "position")
```

**Timer arguments:** `create_timer(time, process_always, process_in_physics, ignore_time_scale)`. Pass `ignore_time_scale=true` if your effect needs to run during a `time_scale=0` freeze (like `FreezeFrameEffect`).

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
	mat.shader = preload("res://addons/juicee/shaders/my_effect.gdshader")
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
- Your shader MUST use `uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap` and `SCREEN_UV` (not `UV`) for correct full-screen coverage.

### Spawning a temporary child node

```gdscript
func _apply(context: Node, intensity_mult: float) -> void:
	var label := Label.new()
	label.text = "Hello!"
	label.position = Vector2(0, -50)
	context.add_child(label)

	var tween := _track(label.create_tween())
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_property(label, "position:y", -100.0, 0.8).set_delay(-0.8)
	await tween.finished

	if is_instance_valid(label):
		label.queue_free()
```

### Reading runtime params

```gdscript
func _apply(context: Node, intensity_mult: float) -> void:
	var direction: Vector2 = _runtime_params.get("hit_direction", Vector2.ZERO)
	var damage: int = _runtime_params.get("damage", 0)
	# ... use these values ...
```

Caller passes params via `effect.apply(context, {"hit_direction": Vector2.LEFT})` or `juicee_player.play({"damage": 42})`.

### Designer-controlled easing with Curve

```gdscript
@export var scale_curve: Curve   # designer paints the easing shape in Inspector

func _apply(context: Node, intensity_mult: float) -> void:
	var original: Vector2 = _capture_state(target, "scale")
	var tween := _track(target.create_tween())
	_tween_curved(tween, target, "scale", original, original * 1.5, 0.4, scale_curve)
	await tween.finished
	_release_state(target, "scale")
```

If `scale_curve` is null, `_tween_curved` falls back to a normal `tween_property` - the caller can chain `set_trans`/`set_ease` on it. If a curve is set, it samples the curve per-frame - set_trans is ignored.

---

## Optional virtual methods

```gdscript
func get_display_name() -> String:        # "My Cool" (default: parsed from script name)
func get_category_name() -> String:       # "My Game" - group in graph popup
func get_category_color() -> Color:       # colored stripe on graph block titlebar
func get_icon_path() -> String:           # SVG icon path
func get_description() -> String:         # tooltip in graph popup
func get_accessibility_tag() -> int:      # JuiceeAccessibility.TAG_SCREENSHAKE, etc.
```

---

## Registering in the graph editor

For community effects shipping in the core addon, also add entries to the three dicts in `addons/juicee/editor/juicee_graph_editor.gd`:

```gdscript
# EFFECT_CATEGORIES - which category section to show it under
"my_cool_effect": "Object",

# EFFECT_DESCRIPTIONS - tooltip in the popup and graph block
"my_cool_effect": "Does something cool.\nUse for: boss intros, combo finishers.",

# EFFECT_DIMENSIONS - 2D/3D tags on the graph block titlebar
"my_cool_effect": ["2d"],   # or ["3d"] or ["2d","3d"]
```

These are fallback registries - an effect that overrides `get_category_name()` / `get_description()` in its own `.gd` file takes precedence.

---

## Anti-patterns to avoid

| Wrong | Right | Why |
|---|---|---|
| `target.position = Vector2.ZERO` | `_capture_state()` + `_release_state()` | Concurrent effects get the wrong "original"; and without `_capture_state`, `stop()` can't restore mid-tween |
| `target.create_tween()` | `_track(target.create_tween())` | `stop()` can't kill untracked tweens |
| `await get_tree().create_timer(t).timeout` | `await tree.create_timer(t, true, false, false).timeout` | Default timer stops during scene changes; pass `process_always=true` |
| Check `_active` in loops | Check `_cancelled` | `_active` is managed by the framework; `_cancelled` is the stop flag for subclasses |
| Override `apply()` | Override `_apply()` | `apply()` runs the cooldown/chance/delay pipeline; bypassing it breaks all that |
| `new JuiceeFoo().apply(ctx)` (hold ref) | `var e := new JuiceeFoo(); e.apply(ctx); return e` | Temporary effects are GC'd mid-run if you don't hold a reference when the caller needs to call `stop()` |

---

## Contribute upstream

If your effect is general-purpose, open a PR. The bar is:

- Single file in `addons/juicee/effects/`
- `## docstring` on every `@export`
- Follows the patterns above (`_track`, `_cancelled`, `JuiceeStateStack`)
- Sensible defaults - `Effect.new(); effect.apply(some_context)` should produce a visible result without tweaking
- Entries in `EFFECT_CATEGORIES`, `EFFECT_DESCRIPTIONS`, `EFFECT_DIMENSIONS`
