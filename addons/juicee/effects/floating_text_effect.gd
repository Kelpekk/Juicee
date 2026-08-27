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

func get_category_name() -> String:
	return "Text"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		push_warning("JuiceeFloatingTextEffect: context is not a Node2D")
		return

	var text_value: String = str(_runtime_params.get("text", default_text))
	var effective_color: Color = _runtime_params.get("color", color)

	var label := Label.new()
	label.name = StringName("_juicee_float_%d" % randi())
	label.text = text_value
	label.add_theme_color_override("font_color", effective_color)
	if outline_width > 0:
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", outline_width)
	label.add_theme_font_size_override("font_size", font_size)
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
	# Freed by stop() - the rise/fade tween's `await` would otherwise skip the
	# queue_free below and leave the label floating forever.
	_on_stop(func() -> void:
		if is_instance_valid(label):
			label.queue_free())

	# One frame to compute label.size from its content.
	await target.get_tree().process_frame
	if not is_instance_valid(label):
		return

	# Determine travel vector based on direction enum.
	var travel := Vector2.ZERO
	var perpendicular_offset := 0.0
	match rise_direction:
		RiseDirection.UP:
			travel = Vector2(0, -travel_distance * intensity_mult)
			perpendicular_offset = randf_range(-spread, spread) * 0.5
		RiseDirection.DOWN:
			travel = Vector2(0, travel_distance * intensity_mult)
			perpendicular_offset = randf_range(-spread, spread) * 0.5
		RiseDirection.RANDOM_HORIZONTAL_DRIFT:
			var drift_dir := -1.0 if randf() < 0.5 else 1.0
			travel = Vector2(drift_dir * travel_distance * intensity_mult * 0.6, -travel_distance * intensity_mult * 0.8)
			perpendicular_offset = randf_range(-spread, spread) * 0.5

	var spawn_offset := Vector2(perpendicular_offset, 0)
	if rise_direction == RiseDirection.RANDOM_HORIZONTAL_DRIFT:
		spawn_offset = Vector2(0, perpendicular_offset)

	var start_pos := target.global_position + spawn_offset - label.size * 0.5
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
	tween.tween_property(label, "global_position", end_pos, duration)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)

	await tween.finished
	if is_instance_valid(label):
		label.queue_free()
