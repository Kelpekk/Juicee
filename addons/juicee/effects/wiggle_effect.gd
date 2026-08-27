## Random continuous position jitter on a Node2D.
##
## Unlike Shake (which targets the camera), Wiggle moves the TARGET NODE itself.
## Use for: nervousness / fear animation, earthquake shaking an object,
## being hit repeatedly, TV static antenna wobble, rattling lock.
@tool
class_name JuiceeWiggleEffect
extends JuiceeEffect

## Max position displacement in pixels.
@export_range(0.0, 200.0, 0.5) var amplitude: float = 6.0
## Position update rate per second (higher = jitterier, lower = sluggish wobble).
@export_range(1.0, 60.0, 0.5) var frequency: float = 12.0
## Total wiggle duration in seconds.
@export_range(0.1, 30.0, 0.05) var duration: float = 1.0
## Amplitude decays to 0 by end of duration.
@export var decay: bool = true

func get_category_name() -> String: return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not context is Node2D:
		push_warning("JuiceeWiggleEffect: context must be a Node2D")
		return
	var target := context as Node2D
	var original_pos: Vector2 = _capture_state(target, "position")
	var elapsed := 0.0
	var step := 1.0 / frequency
	var tree := context.get_tree()
	var eff_amp := amplitude * intensity_mult

	while elapsed < duration and is_instance_valid(target) and not _cancelled:
		var t := elapsed / duration
		var current_amp := eff_amp * (1.0 - t if decay else 1.0)
		var offset := Vector2(
			randf_range(-current_amp, current_amp),
			randf_range(-current_amp, current_amp)
		)
		target.position = original_pos + offset
		await tree.create_timer(step, true, false, false).timeout
		elapsed += step

	_release_state(target, "position")
