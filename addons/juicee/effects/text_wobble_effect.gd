## Text wobble / shake - the Label shakes for emphasis. Drama text like
## "GAME OVER", "BOSS APPROACHING", "WAVE COMPLETE", or damage-state callouts.
##
## Targets a `Control` (typically `Label` or `RichTextLabel`) and oscillates
## its position with a sine-wave wobble that decays over the duration.
## Uses `JuiceeStateStack` for the position baseline so concurrent wobbles
## (or wobble during a different effect) restore correctly.
@tool
class_name JuiceeTextWobbleEffect
extends JuiceeEffect

## Peak wobble offset in pixels.
@export_range(0.0, 50.0, 0.5) var amplitude: float = 4.0
## Oscillations per second. Higher = jittery, lower = smooth.
@export_range(1.0, 60.0, 0.5) var frequency: float = 12.0
## Total wobble duration.
@export_range(0.05, 10.0, 0.05) var duration: float = 0.5
## How quickly the wobble decays. 0 = constant wobble, 1 = full fadeout at end.
@export_range(0.0, 1.0, 0.05) var decay: float = 0.7
## Vertical-to-horizontal wobble ratio (1 = equal both axes, 0 = horizontal only).
@export_range(0.0, 1.0, 0.05) var y_axis_ratio: float = 0.6

func get_category_name() -> String:
	return "Text"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Control = context as Control
	if not target or not target.is_inside_tree():
		push_warning("JuiceeTextWobbleEffect: context is not a Control")
		return

	var original_pos: Vector2 = _capture_state(target, "position")
	var effective_amplitude: float = amplitude * intensity_mult
	# Independent phases on X and Y for organic wobble.
	var phase_x_offset: float = randf() * TAU
	var phase_y_offset: float = randf() * TAU
	var elapsed: float = 0.0
	var tree := target.get_tree()
	if not tree:
		_release_state(target, "position")
		return

	while elapsed < duration and not _cancelled and is_instance_valid(target):
		var t: float = elapsed / duration
		var decay_factor: float = 1.0 - (decay * t)
		var current_amp: float = effective_amplitude * decay_factor
		var dx: float = sin(elapsed * TAU * frequency + phase_x_offset) * current_amp
		var dy: float = cos(elapsed * TAU * frequency * 1.3 + phase_y_offset) * current_amp * y_axis_ratio
		target.position = original_pos + Vector2(dx, dy)
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()

	if is_instance_valid(target):
		target.position = original_pos
	_release_state(target, "position")
