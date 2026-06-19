## Base class for all Juicee effects.
##
## Subclasses override `_apply(context, intensity_mult)` to do work.
## All effects get for free: randomization (chance, intensity_min/max), pre-delay,
## cooldown, runtime params, stop() / is_playing() state queries, and tween tracking
## (so stop() actually kills tween-driven effects mid-flight).
@tool
class_name JuiceeEffect
extends Resource

signal started
signal finished
signal stopped
## Fires once the apply() call enters its pre-delay wait. The graph editor's
## debug walker uses it to draw a fill bar showing the countdown.
signal delay_started(seconds: float)

@export_group("Randomization")
## Probability (0–1) that this effect actually fires when triggered.
## 1.0 = always fires, 0.5 = fires half the time, 0.0 = never fires.
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
## Pre-delay in seconds before the effect starts. Useful for chaining timing within a sequence.
@export_range(0.0, 10.0, 0.01) var delay: float = 0.0
## Lower bound of a random multiplier applied to the effect's intensity each play.
## Set both intensity_min and intensity_max to 1.0 to disable randomization.
@export_range(0.1, 5.0, 0.01) var intensity_min: float = 1.0
## Upper bound of the random intensity multiplier.
@export_range(0.1, 5.0, 0.01) var intensity_max: float = 1.0

@export_group("Cooldown")
## Minimum seconds between successive apply() calls on this effect resource.
## 0 = no cooldown. Useful for spam-prevention without wrapping in a JuiceePlayer.
@export_range(0.0, 10.0, 0.01) var cooldown: float = 0.0

@export_group("Editor")
## Position of this effect's block in the visual graph editor. Used by JuiceeGraphEditor.
@export var graph_position: Vector2 = Vector2.ZERO

## Global accessibility settings — set by the Juicee autoload in _ready().
## Automatically consulted in apply() so subclasses need zero extra code.
static var accessibility: JuiceeAccessibility = JuiceeAccessibility.new()

## Runtime parameters passed by the caller (e.g., {"hit_direction": Vector2.LEFT}).
var _runtime_params: Dictionary = {}

## True between started/finished — query via is_playing(). Manual-loop effects also
## should check this and break early so stop() works.
var _active: bool = false
## True if stop() was called during the current play — manual loops bail out on this.
var _cancelled: bool = false
## Time of last apply() (in seconds, from Time.get_ticks_msec). Used by cooldown.
var _last_apply_time: float = -1e9
## Tweens created during the current play — killed by stop(). Subclasses MUST wrap
## their `create_tween()` calls with `_track()` for stop() to work on them.
var _active_tweens: Array[Tween] = []
## JuiceeStateStack captures for this play. Populated by _capture_state().
## stop() releases all entries so tween-killed effects still restore properties.
var _state_captures: Array = []
## True between the start of apply() and when the effect either starts playing or
## is blocked (cooldown, chance). _play_parallel uses this to avoid exiting the
## polling loop prematurely when all effects have a non-zero delay.
var _pending_start: bool = false
## Monotonic counter bumped by every apply() and every stop(). Each coroutine
## captures its own snapshot and bails out (without emitting finished or touching
## state) once the global counter has moved past it — that's how spam-clicking
## play during a delay yields ONE effect run instead of N queued ones.
var _gen: int = 0

## Entry point used by JuiceeSequence — handles cooldown/chance/delay/intensity,
## then calls _apply() and emits signals. Do NOT override; override `_apply()`.
func apply(context: Node, params: Dictionary = {}) -> void:
	# Bump generation FIRST so any in-flight coroutine (mid-delay or mid-_apply)
	# will see a stale snapshot and bail out without finishing.
	_gen += 1
	var my_gen: int = _gen

	# Cancel any tweens from a previous apply() so we don't get stacked plays.
	for t in _active_tweens:
		if is_instance_valid(t) and t.is_valid():
			t.kill()
	_active_tweens.clear()
	# Release any state captured by a previous (now-superseded) run before clearing.
	# Without this, rapid replay leaks StateStack ref counts and properties never restore.
	for entry in _state_captures:
		JuiceeStateStack.release(entry[0], entry[1])
	_state_captures.clear()
	_active = false
	_pending_start = true
	_cancelled = false

	# Cooldown gate — silently drop calls inside the cooldown window.
	if cooldown > 0.0:
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _last_apply_time < cooldown:
			_pending_start = false
			return
		_last_apply_time = now

	if chance < 1.0 and randf() > chance:
		_pending_start = false
		return
	if delay > 0.0:
		if not context or not context.is_inside_tree():
			_pending_start = false
			return
		delay_started.emit(delay)
		await context.get_tree().create_timer(delay, true, false, false).timeout
		if my_gen != _gen:
			_pending_start = false
			return  # superseded by a later apply() or stop()
	var mult: float = 1.0
	if intensity_min != 1.0 or intensity_max != 1.0:
		mult = randf_range(intensity_min, intensity_max)
	# Accessibility gate — scales or silences effects based on player preferences.
	mult *= accessibility.effective_multiplier(get_accessibility_tag())
	if mult <= 0.0:
		_pending_start = false
		return

	_pending_start = false
	_runtime_params = params
	_active = true
	started.emit()
	await _apply(context, mult)
	if my_gen != _gen:
		return  # superseded mid-_apply — the newer call owns state now
	_active = false
	_runtime_params = {}
	_active_tweens.clear()
	if _cancelled:
		_cancelled = false
		stopped.emit()
	else:
		finished.emit()

## Override this in subclasses. `intensity_mult` is 1.0 unless randomization is enabled.
func _apply(context: Node, intensity_mult: float) -> void:
	pass

## Override to declare which accessibility category this effect belongs to.
## The accessibility layer uses this to silence or scale the effect based on player prefs.
## Return one of JuiceeAccessibility.TAG_* (default TAG_NONE = always plays at full intensity).
func get_accessibility_tag() -> int:
	return JuiceeAccessibility.TAG_NONE

## Register a tween for cleanup-on-stop. Subclasses MUST use this for every Tween
## they create — otherwise stop() can't kill them. Usage:
## [codeblock]
## var tween := _track(target.create_tween())
## [/codeblock]
func _track(tween: Tween) -> Tween:
	if tween:
		_active_tweens.append(tween)
	return tween

## Capture a property for state-restore, registering it for cleanup-on-stop().
## Use instead of JuiceeStateStack.capture() in tween-based effects so stop()
## can restore the property even when the tween's finished signal never fires.
func _capture_state(target: Object, property: String) -> Variant:
	var original = JuiceeStateStack.capture(target, property)
	_state_captures.append([target, property])
	return original

## Release a previously captured property. Removes the entry from _state_captures
## so stop() doesn't double-release it — loop-based effects MUST use this instead
## of calling JuiceeStateStack.release() directly.
func _release_state(target: Object, property: String) -> void:
	for i in _state_captures.size():
		if _state_captures[i][0] == target and _state_captures[i][1] == property:
			_state_captures.remove_at(i)
			JuiceeStateStack.release(target, property)
			return
	# Entry not found — stop() already released it. No-op is correct.

## Curve-based property tween — animates `prop_name` on `target` from
## `from_value` to `to_value` over `duration`, sampling the curve to derive the
## per-frame ratio. Works on any lerp-able type (float, Vector2, Vector3, Color).
## If `curve` is null, falls back to a regular `tween_property` so the caller
## can chain `set_trans`/`set_ease` as usual.
##
## Curves give designers full control over the easing shape: punch, bounce,
## squash-stretch-overshoot, or any custom feel — without touching effect code.
## [codeblock]
## # In an effect:
## @export var amplitude_curve: Curve
## ...
## _tween_curved(tween, target, "scale", original, original * 1.5, 0.4, amplitude_curve)
## [/codeblock]
func _tween_curved(tween: Tween, target: Object, prop_name: String, from_value: Variant,
		to_value: Variant, duration: float, curve: Curve = null) -> Tweener:
	if curve and is_instance_valid(target):
		var setter := func(t: float) -> void:
			if not is_instance_valid(target):
				return
			target.set(prop_name, lerp(from_value, to_value, curve.sample(t)))
		# Force linear transition — curve drives the easing, set_trans on the
		# returned tweener would double-apply.
		return tween.tween_method(setter, 0.0, 1.0, duration).set_trans(Tween.TRANS_LINEAR)
	# Fall back to native tween_property so caller can set_trans/set_ease normally.
	return tween.tween_property(target, prop_name, to_value, duration)

## Builds a self-contained screen-overlay tree:
##   CanvasLayer (layer=z)
##   ├── BackBufferCopy (COPY_MODE_VIEWPORT)   ← captures viewport
##   └── ColorRect (sibling, full viewport)    ← samples back buffer
## Siblings (BackBufferCopy → ColorRect) is the classic Godot pattern — back
## buffer is captured when BackBufferCopy renders, then the next sibling can
## read it via SCREEN_TEXTURE in a shader. Gives the shader its own isolated
## snapshot so Juicee's effects don't fight with user post-process shaders or
## stack with each other. Returns [layer, rect].
func _spawn_screen_shader_overlay(context: Node, layer_name: StringName, z: int = 128) -> Array:
	if not context or not context.is_inside_tree():
		return []
	_sweep_overlay_layers(context, layer_name)

	var layer := CanvasLayer.new()
	layer.name = layer_name
	layer.layer = z
	context.add_child(layer)

	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(bb)

	var rect := ColorRect.new()
	rect.color = Color.TRANSPARENT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	_size_to_viewport(rect, context)
	_add_editor_preview_hint(layer, context)
	return [layer, rect]

## Solid-color overlay (no shader, no back buffer) — for tint/wipe effects that
## only need a colored ColorRect on top of the scene.
func _spawn_screen_solid_overlay(context: Node, layer_name: StringName, z: int = 128) -> Array:
	if not context or not context.is_inside_tree():
		return []
	_sweep_overlay_layers(context, layer_name)

	var layer := CanvasLayer.new()
	layer.name = layer_name
	layer.layer = z
	context.add_child(layer)

	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	_size_to_viewport(rect, context)
	_add_editor_preview_hint(layer, context)
	return [layer, rect]

## In editor preview (Inspector ▶ Preview, JuiceeGraph ▶ Test), the project
## viewport is smaller than the editor's 2D canvas — shader effects render
## inside that smaller rect, which looks like "broken" full-screen coverage.
## This helper draws a soft outline + label that explicitly marks the area
## the effect actually covers, so the user understands the boundary instead
## of thinking the addon shipped a bug. In runtime (F6, exported game) the
## viewport IS the window, so we skip the hint there.
func _add_editor_preview_hint(layer: CanvasLayer, context: Node) -> void:
	if not Engine.is_editor_hint():
		return
	if not context or not context.is_inside_tree():
		return
	# Skip inside the hover panel's mini SubViewport — the hint would fill most of the
	# 118 px preview area with instructional text that makes no sense at that scale.
	var n := context
	while n:
		if n.has_meta("_juicee_hover_preview"):
			return
		n = n.get_parent()

	var hint_panel := Panel.new()
	hint_panel.name = &"_juicee_preview_hint"
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(1.0, 0.78, 0.30, 0.85)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	hint_panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(hint_panel)
	_size_to_viewport(hint_panel, context)

	# Floating label — top-left corner, pill style.
	var label_wrap := PanelContainer.new()
	label_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label_sb := StyleBoxFlat.new()
	label_sb.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	label_sb.border_color = Color(1.0, 0.78, 0.30, 0.85)
	label_sb.border_width_left = 1
	label_sb.border_width_right = 1
	label_sb.border_width_top = 1
	label_sb.border_width_bottom = 1
	label_sb.corner_radius_top_left = 4
	label_sb.corner_radius_top_right = 4
	label_sb.corner_radius_bottom_left = 4
	label_sb.corner_radius_bottom_right = 4
	label_sb.content_margin_left = 8
	label_sb.content_margin_right = 8
	label_sb.content_margin_top = 4
	label_sb.content_margin_bottom = 4
	label_wrap.add_theme_stylebox_override("panel", label_sb)
	label_wrap.position = Vector2(8, 8)
	hint_panel.add_child(label_wrap)

	var label := Label.new()
	label.text = "Editor preview · effects render inside this rect.\nRun the project (F5 / F6) for full-window coverage."
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	label.add_theme_font_size_override("font_size", 10)
	label_wrap.add_child(label)

# Sets the rect to fill the viewport explicitly. Belt-and-suspenders — anchors
# alone (PRESET_FULL_RECT) don't always resolve when the Control's parent is a
# CanvasLayer (not a Control), especially in editor preview. Combines both for
# reliability, plus reacts to viewport resizes and auto-disconnects when the
# rect is freed (so spamming play doesn't leak signal handlers).
func _size_to_viewport(rect: Control, context: Node) -> void:
	# TOP_LEFT anchors (equal opposite, all 0) so the explicit size set below is
	# honored — FULL_RECT's non-equal anchors would override it and warn on every
	# screen effect. The resize listener keeps it filling the viewport.
	rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rect.position = Vector2.ZERO
	if not context:
		return
	var vp := context.get_viewport()
	if not vp:
		return
	var vp_size := vp.get_visible_rect().size
	if vp_size.x > 0.0 and vp_size.y > 0.0:
		rect.position = Vector2.ZERO
		rect.size = vp_size

	# Per-rect viewport resize listener. Stored as a Callable bound to this
	# specific rect+viewport so we can disconnect it cleanly when the rect dies.
	var resize_cb := func() -> void:
		if is_instance_valid(rect) and is_instance_valid(vp):
			rect.size = vp.get_visible_rect().size
	vp.size_changed.connect(resize_cb)
	rect.tree_exiting.connect(func() -> void:
		if is_instance_valid(vp) and vp.size_changed.is_connected(resize_cb):
			vp.size_changed.disconnect(resize_cb)
	)

## Removes ALL screen-overlay layers under `context` whose name starts with the
## given prefix — including auto-renamed siblings (e.g. "_juicee_blur_overlay2")
## that Godot creates when a queue_free'd node still occupies the canonical
## name. Without this sweep, spam-running an effect leaves stale layers stacked
## (each renamed to dodge the previous, none of them cleaned up because their
## owning apply() coroutine was superseded mid-await). Call this at the very
## start of every screen effect's _apply().
func _sweep_overlay_layers(context: Node, layer_name: StringName) -> void:
	if not context:
		return
	var prefix := String(layer_name)
	for child in context.get_children():
		var n := String(child.name)
		if n.begins_with(prefix):
			# Rename first so add_child(new) below can take the canonical name
			# immediately without a collision-rename.
			child.name = StringName("_juicee_dying_%d" % randi())
			child.queue_free()

## Cancel the currently-running effect.
## - Kills all tweens started via _track().
## - Manual-loop effects check `_cancelled` flag and exit on next iteration.
## - Bumps the generation counter so any coroutine waiting on a delay timer
##   also bails out (won't reach the actual _apply() step).
## After stop(), the next apply() can fire normally.
func stop() -> void:
	_gen += 1
	_cancelled = true
	_active = false
	_pending_start = false
	for t in _active_tweens:
		if is_instance_valid(t) and t.is_valid():
			t.kill()
	_active_tweens.clear()
	# Release any StateStack entries captured this play — tween-based effects can't
	# release from within their zombied coroutines (killed tweens never emit finished),
	# so stop() must do it to ensure properties are restored to their original values.
	for entry in _state_captures:
		JuiceeStateStack.release(entry[0], entry[1])
	_state_captures.clear()

## Returns true if this effect is currently mid-apply (between started/finished).
func is_playing() -> bool:
	return _active

## Time remaining (in seconds) before the cooldown expires, or 0.0 if ready to fire.
func cooldown_remaining() -> float:
	if cooldown <= 0.0:
		return 0.0
	var now: float = Time.get_ticks_msec() / 1000.0
	return maxf(0.0, cooldown - (now - _last_apply_time))

func get_display_name() -> String:
	var script_path: String = (get_script() as Script).resource_path
	var file_name: String = script_path.get_file().get_basename()
	return file_name.replace("_effect", "").replace("_", " ").capitalize()

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_icon_path() -> String:
	return ""

## Category for grouping in the JuiceeGraph popup. Override to set custom group
## (e.g., "Screen", "Camera", "Object", "Time", "Audio", "UI", "Flow", "Physics").
## If returns "" the graph editor falls back to its built-in category map.
func get_category_name() -> String:
	return ""

## Short description shown as a tooltip when hovering this effect in the popup.
## If returns "" the graph editor falls back to its built-in description map.
func get_description() -> String:
	return ""
