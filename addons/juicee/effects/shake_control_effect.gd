## Horizontal shake on a Control node - the classic "wrong answer" UI response.
##
## Use for: wrong password / PIN entry, invalid form input, locked button,
## "you can't go there" door, tutorial "not yet" block.
@tool
class_name JuiceeShakeControlEffect
extends JuiceeEffect

## Peak horizontal displacement in pixels. Vertical Ratio sets how much of it goes vertical.
@export_range(0.0, 100.0, 0.5) var intensity: float = 10.0
## Total shake duration in seconds.
@export_range(0.05, 2.0, 0.05) var duration: float = 0.3
## Updates per second (higher = more jittery).
@export_range(5.0, 60.0, 1.0) var frequency: float = 20.0

@export_group("Advanced")
## Vertical shake as a fraction of the horizontal. 0 = pure left/right (the classic
## "wrong answer" wobble), 1 = shakes equally in both axes.
@export_range(0.0, 2.0, 0.05) var vertical_ratio: float = 0.3
## Rotation jitter in degrees layered on the shake, for a more violent rattle. 0 = none.
@export_range(0.0, 30.0, 0.5) var rotation_jitter: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["vertical_ratio", "rotation_jitter"]))

func get_category_name() -> String: return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not context is Control:
		_warn("JuiceeShakeControlEffect: context must be a Control node")
		return
	var target := context as Control
	var play := _gen
	var original_pos: Vector2 = _capture_offset(target, "position")
	var elapsed := 0.0
	var step := 1.0 / frequency
	var tree := context.get_tree()
	var eff := intensity * intensity_mult

	var jitter_rot := rotation_jitter > 0.0
	var orig_rot: float = _capture_offset(target, "rotation") if jitter_rot else 0.0
	while elapsed < duration and is_instance_valid(target) and _gen == play:
		var decay := 1.0 - elapsed / duration
		var offset := Vector2(
			randf_range(-eff, eff) * decay,
			randf_range(-eff * vertical_ratio, eff * vertical_ratio) * decay
		)
		_write_offset(target, "position", original_pos, offset,
				absf(eff) * decay * maxf(1.0, absf(vertical_ratio)))
		if jitter_rot:
			_write_offset(target, "rotation", orig_rot,
					randf_range(-1.0, 1.0) * deg_to_rad(rotation_jitter) * decay,
					deg_to_rad(rotation_jitter) * decay)
		elapsed += await _wait_step(tree, step)

	# A newer play or stop() holds these now; releasing here would take them from it.
	if _gen != play:
		return
	_release_state(target, "position")
	if jitter_rot:
		_release_state(target, "rotation")
