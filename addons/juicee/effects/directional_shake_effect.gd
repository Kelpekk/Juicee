## Direction-biased Camera2D shake.
##
## The camera is kicked OPPOSITE to `direction` (if hit from the right, camera
## goes left) with exponential decay, plus a perpendicular noise shake on top.
## Use for: got-hit-from-left, landing slam, explosion push direction.
##
## Runtime override: pass {"direction": Vector2.LEFT} to apply() to set the
## direction per-hit without changing the exported property.
@tool
class_name JuiceeDirectionalShakeEffect
extends JuiceeEffect

## Impact direction. Camera kicks opposite to this (hit from right = camera moves left).
@export var direction: Vector2 = Vector2.RIGHT
## How far the camera is initially kicked along the direction axis (pixels).
@export_range(0.0, 200.0, 0.5) var kick_distance: float = 20.0
## Amplitude of the perpendicular noise shake layered on top of the kick.
@export_range(0.0, 50.0, 0.5) var side_intensity: float = 4.0
## Total shake duration.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## Shake oscillations per second.
@export_range(1.0, 60.0, 0.5) var frequency: float = 16.0

@export_group("Advanced")
## Camera roll in degrees layered on the kick, so a big hit also twists the view.
@export_range(0.0, 15.0, 0.1) var roll_degrees: float = 0.0
## How fast the sideways shake and roll die away. 1 = linear falloff, 2+ = they die quickly.
@export_range(0.5, 5.0, 0.1) var decay_power: float = 1.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["roll_degrees", "decay_power"]))

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_SCREENSHAKE
func get_category_name() -> String: return "Camera"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var cam: Camera2D = context.get_viewport().get_camera_2d()
	if not cam:
		_warn("JuiceeDirectionalShakeEffect: no Camera2D in viewport")
		return

	var dir := (_param("direction", direction) as Vector2).normalized()
	if dir.length_squared() < 0.001:
		dir = Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)

	var noise := _shake_noise()
	var noise_start := randf() * 1000.0

	# `offset` and not `position`. Camera2D adds offset on top of wherever the camera
	# actually is, so a shake composes with a camera that is following something.
	# Writing position instead pins the camera to where it stood when the effect
	# started: measured on a camera moving the way a follow script moves one, this
	# dragged the view back by 228px mid-effect. JuiceeShakeEffect already used offset.
	var play := _gen
	var original_pos: Vector2 = _capture_offset(cam, "offset")
	# Camera2D ignores its own rotation by default, so a roll needs that turned off.
	var rolling := roll_degrees > 0.0
	var original_rot: float = 0.0
	var had_ignore := false
	if rolling:
		original_rot = _capture_offset(cam, "rotation")
		had_ignore = cam.ignore_rotation
		if had_ignore:
			cam.ignore_rotation = false
			_on_stop(_set_by_id.bind(cam.get_instance_id(), &"ignore_rotation", true))
	var elapsed := 0.0
	var step := minf(1.0 / frequency, SHAKE_NOISE_STEP)
	var eff_kick := kick_distance * intensity_mult
	var eff_side := side_intensity * intensity_mult
	var tree := context.get_tree()

	while elapsed < duration and is_instance_valid(cam) and _gen == play:
		var t := elapsed / duration
		# Directional kick: exponential decay so it snaps back quickly.
		var kick := eff_kick * exp(-t * 5.0)
		# Side noise: decay_power shapes the falloff (1 = linear, higher = snappier).
		var decay := pow(1.0 - t, maxf(decay_power, 0.0))
		var side_noise := _shake_noise_at(noise, noise_start, 0, elapsed, frequency) * eff_side * decay
		# Kick is opposite to direction (impact feel).
		_write_offset(cam, "offset", original_pos, (-dir) * kick + perp * side_noise,
				absf(kick) + absf(eff_side) * decay)
		if rolling:
			var roll := deg_to_rad(roll_degrees) * decay
			_write_offset(cam, "rotation", original_rot,
					_shake_noise_at(noise, noise_start, 1, elapsed, frequency) * roll, roll)
		elapsed += await _wait_step(tree, step)

	# A newer play or stop() holds these now; releasing here would take them from it.
	if _gen != play:
		return
	_release_state(cam, "offset")
	if rolling:
		_release_state(cam, "rotation")
		if is_instance_valid(cam) and had_ignore:
			cam.ignore_rotation = true
