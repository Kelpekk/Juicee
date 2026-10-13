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

enum WiggleAxis { BOTH, HORIZONTAL, VERTICAL }

@export_group("Advanced")
## Which axis jitters: BOTH, HORIZONTAL only, or VERTICAL only.
@export var axis: WiggleAxis = WiggleAxis.BOTH
## Also jitter rotation by up to this many degrees, for a frantic rattle. 0 = position only.
@export_range(0.0, 45.0, 1.0) var rotation_jitter: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["axis", "rotation_jitter"]))

func get_category_name() -> String: return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not context is Node2D:
		_warn("JuiceeWiggleEffect: context must be a Node2D")
		return
	var target := context as Node2D
	var play := _gen
	var original_pos: Vector2 = _capture_offset(target, "position")
	var jitter_rot := rotation_jitter > 0.0
	var orig_rot: float = _capture_offset(target, "rotation") if jitter_rot else 0.0
	var elapsed := 0.0
	var step := 1.0 / frequency
	var tree := context.get_tree()
	var eff_amp := _px(amplitude) * intensity_mult

	while elapsed < duration and is_instance_valid(target) and _gen == play:
		var t := elapsed / duration
		var falloff := (1.0 - t) if decay else 1.0
		var current_amp := eff_amp * falloff
		var ox := 0.0 if axis == WiggleAxis.VERTICAL else randf_range(-current_amp, current_amp)
		var oy := 0.0 if axis == WiggleAxis.HORIZONTAL else randf_range(-current_amp, current_amp)
		_write_offset(target, "position", original_pos, Vector2(ox, oy), current_amp)
		if jitter_rot:
			_write_offset(target, "rotation", orig_rot,
					randf_range(-1.0, 1.0) * deg_to_rad(rotation_jitter) * falloff,
					deg_to_rad(rotation_jitter) * falloff)
		elapsed += await _wait_step(tree, step)

	# A newer play or stop() holds these now; releasing here would take them from it.
	if _gen != play:
		return
	_release_state(target, "position")
	if jitter_rot:
		_release_state(target, "rotation")
