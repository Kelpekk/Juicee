## Generic floating text - like JuiceeDamageNumberEffect but for any string.
##
## Use for: "Level Up!" labels, pickup names, status messages ("Stunned!",
## "Combo x3"), notifications, item-found callouts.
##
## Caller passes the text via runtime params (preferred for dynamic content)
## or falls back to the `default_text` @export:
## [codeblock]
## juice.play({"text": "Level Up!"})
## juice.play({"text": "Sword of Doom!", "color": Color.GOLD})
## [/codeblock]
@tool
class_name JuiceeFloatingTextEffect
extends JuiceeEffect

enum RiseDirection { UP, DOWN, RANDOM_HORIZONTAL_DRIFT }

## Default text shown when caller doesn't pass `text` via runtime params.
@export var default_text: String = "Hello!"
## Text color (overridable via `color` runtime param).
@export var color: Color = Color.WHITE
## Direction the label travels during the animation.
@export var rise_direction: RiseDirection = RiseDirection.UP
## How far the label moves (pixels).
@export_range(0.0, 400.0, 1.0) var travel_distance: float = 100.0
## Random offset perpendicular to the travel direction, so two spawns at the
## same place don't perfectly overlap.
@export_range(0.0, 100.0, 1.0) var spread: float = 30.0
## Font size in pixels.
@export_range(8, 128, 1) var font_size: int = 24
## Optional custom font.
@export var font: Font
## Total animation duration.
@export_range(0.1, 8.0, 0.05) var duration: float = 1.2
## Black outline width - readability on busy backgrounds.
@export var outline_width: int = 2
## Pop-in scale punch at start (set 0 to disable).
@export_range(0.0, 1.0, 0.05) var pop_in_amount: float = 0.3

@export_group("Advanced")
## Hand-drawn easing curve (0..1) shaping the travel, replacing the quart ease-out.
@export var ease_curve: Curve
## Fraction of the duration the text stays fully opaque before fading. 0.5 = the default
## (fade over the second half); 0.9 = it hangs and then snaps out.
@export_range(0.1, 0.95, 0.05) var fade_start_ratio: float = 0.5
## Slowly rotate the label this many degrees over its life, for a lazy tumble. 0 = none.
@export_range(-180.0, 180.0, 5.0) var spin_degrees: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "fade_start_ratio", "spin_degrees"]))

func get_category_name() -> String:
	return "Text"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		_warn("JuiceeFloatingTextEffect: context is not a Node2D")
		return

	var text_value: String = str(_runtime_params.get("text", default_text))
	var effective_color: Color = _param("color", color)

	var label := Label.new()
	label.name = StringName("_juicee_float_%d" % randi())
	label.text = text_value
	label.add_theme_color_override("font_color", effective_color)
	if outline_width > 0:
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", outline_width)
	label.add_theme_font_size_override("font_size", clampi(font_size, 1, 1024))
	if font:
		label.add_theme_font_override("font", font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hidden until positioned - a Control spawns at (0,0) and we only know its size
	# (to centre it) after one frame; without this it flashes in the top-left corner.
	label.visible = false

	var spawn_parent: Node = _spawn_parent(target)
	spawn_parent.add_child(label)
	# The label lives in the scene, not under the target, so the target leaving does not stop the
	# play and take the text with it. An explicit stop() still does.
	_unwatch_context()
	# Freed by stop() - the rise/fade tween's `await` would otherwise skip the
	# queue_free below and leave the label floating forever. Not by a restart: firing
	# again stacks a second label next to this one (issue #4).
	_free_on_stop(label, true)

	# One frame to compute label.size from its content. The target may be freed in that frame, and
	# the text still rises from where it was.
	var anchor := target.global_position
	await target.get_tree().process_frame
	if not is_instance_valid(label):
		return
	if is_instance_valid(target):
		anchor = target.global_position

	# Determine travel vector based on direction enum.
	var travel := Vector2.ZERO
	var perpendicular_offset := 0.0
	var td := _px(travel_distance)
	var sp := _px(spread)
	match rise_direction:
		RiseDirection.UP:
			travel = Vector2(0, -td * intensity_mult)
			perpendicular_offset = randf_range(-sp, sp) * 0.5
		RiseDirection.DOWN:
			travel = Vector2(0, td * intensity_mult)
			perpendicular_offset = randf_range(-sp, sp) * 0.5
		RiseDirection.RANDOM_HORIZONTAL_DRIFT:
			var drift_dir := -1.0 if randf() < 0.5 else 1.0
			travel = Vector2(drift_dir * td * intensity_mult * 0.6, -td * intensity_mult * 0.8)
			perpendicular_offset = randf_range(-sp, sp) * 0.5

	var spawn_offset := Vector2(perpendicular_offset, 0)
	if rise_direction == RiseDirection.RANDOM_HORIZONTAL_DRIFT:
		spawn_offset = Vector2(0, perpendicular_offset)

	var start_pos := anchor + spawn_offset - label.size * 0.5
	label.global_position = start_pos
	label.visible = true

	# Label-owned (untracked) tweens: each spawned label animates independently, so
	# re-triggering the effect mid-flight spawns a SEPARATE label instead of killing
	# the previous one's tween (which would freeze it mid-air forever - issue #4).
	# Pop-in scale punch at start.
	if pop_in_amount > 0.0:
		label.pivot_offset = label.size * 0.5
		label.scale = Vector2(1.0 - pop_in_amount, 1.0 - pop_in_amount)
		var punch := label.create_tween()
		punch.tween_property(label, "scale", Vector2.ONE * (1.0 + pop_in_amount * 0.5), 0.12)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		punch.tween_property(label, "scale", Vector2.ONE, 0.15)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Parallel rise + fade.
	var end_pos := start_pos + travel
	var tween := label.create_tween().set_parallel(true)
	# ease_curve (advanced) overrides the quart ease on the travel.
	if ease_curve:
		var from_pos := start_pos
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(label):
				label.global_position = from_pos.lerp(end_pos, ease_curve.sample(t)),
			0.0, 1.0, duration)
	else:
		tween.tween_property(label, "global_position", end_pos, duration)\
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	var hold_t: float = duration * fade_start_ratio
	tween.tween_property(label, "modulate:a", 0.0, duration - hold_t).set_delay(hold_t)
	if spin_degrees != 0.0:
		label.pivot_offset = label.size * 0.5
		tween.tween_property(label, "rotation", deg_to_rad(spin_degrees), duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await _tween_done(tween)
	if is_instance_valid(label):
		label.queue_free()
