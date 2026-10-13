## Jelly wobble: a springy squash-and-stretch scale oscillation that decays, the gel
## bounce of a slime, a bouncy UI element, or a landing jiggle.
@tool
class_name JuiceeJellyWobbleEffect
extends JuiceeEffect

## Peak scale deviation at the start (0.25 = wobbles between ~75% and ~125%).
@export_range(0.05, 0.8, 0.01) var amount: float = 0.25
## Wobbles per second.
@export_range(0.2, 8.0, 0.1) var frequency: float = 4.0
## Total wobble time.
@export_range(0.1, 3.0, 0.05) var duration: float = 0.6
## How fast the wobble dies down. 0 = constant, higher = settles sooner.
@export_range(0.0, 8.0, 0.1) var decay: float = 3.0

@export_group("Advanced")
## Keep volume (squash one axis while the other stretches, the classic jelly). Off wobbles
## both axes together, so it pulses in and out instead.
@export var volume_preserve: bool = true
## Degrees of rotation wobble layered on the squash, for extra jiggle. 0 = scale only.
@export_range(0.0, 45.0, 1.0) var rotation_wobble: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["volume_preserve", "rotation_wobble"]))

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Springy squash-stretch scale wobble that decays.\nSlimes, jelly, bouncy UI, landing jiggle."

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		_warn("JuiceeJellyWobbleEffect: context is not a Node2D")
		return

	var play := _gen
	var original: Vector2 = _capture_offset(target, "scale")
	var wobble_rot := rotation_wobble > 0.0
	var orig_rot: float = _capture_offset(target, "rotation") if wobble_rot else 0.0
	var amt: float = amount * intensity_mult
	var elapsed := 0.0
	var step := 1.0 / 60.0
	var tree := target.get_tree()
	while elapsed < duration and is_instance_valid(target) and _gen == play:
		var envelope: float = exp(-maxf(decay, 0.0) * elapsed)
		var wave: float = sin(elapsed * frequency * TAU) * envelope
		var s: float = wave * amt
		if volume_preserve:
			# Squash one axis, stretch the other (reads as volume-preserving jelly).
			_write_offset(target, "scale", original, Vector2(original.x * s, -original.y * s),
					original.length() * absf(amt) * envelope)
		else:
			# Both axes together: pulses bigger/smaller instead of squashing.
			_write_offset(target, "scale", original, original * s,
					original.length() * absf(amt) * envelope)
		if wobble_rot:
			_write_offset(target, "rotation", orig_rot, deg_to_rad(rotation_wobble) * wave,
					deg_to_rad(rotation_wobble) * envelope)
		elapsed += await _wait_step(tree, step)
	# A newer play or stop() holds these now; releasing here would take them from it.
	if _gen != play:
		return
	_release_state(target, "scale")
	if wobble_rot:
		_release_state(target, "rotation")
