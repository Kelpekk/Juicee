## Camera3D shake for 3D games.
## Finds the active Camera3D via context.get_viewport().get_camera_3d().
##
## Mostly a turn of the head, not a slide of it. Squirrel Eiserloh's GDC 2016 talk on
## camera math puts it flatly: in 3D, translational shake is "super lame" and "VERY BAD",
## rotational is "nice". A camera that slides around in a 3D scene reads as the world
## sliding; a camera that shakes its aim reads as the hit. This shipped translation-first
## with rotation off by default, which is the wrong way round, so the defaults are swapped
## and yaw and pitch were added to the roll that was already here.
@tool
class_name JuiceeShake3DEffect
extends JuiceeEffect

## Shake displacement in world units. Small on purpose: in 3D a sliding camera is the part
## that reads badly, so most of the shake wants to come from Tilt and Roll below.
@export_range(0.0, 5.0, 0.01) var intensity: float = 0.06
## Total shake duration in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## Shake oscillations per second.
@export_range(1.0, 60.0, 0.5) var frequency: float = 15.0
## How quickly the shake amplitude falls off. 0 = constant, higher = faster decay.
@export_range(0.0, 5.0, 0.01) var decay: float = 0.8
## If true, uses smooth Perlin noise. If false, uses random offsets (jittery).
@export var use_noise: bool = true
## Per-axis multiplier on the positional part of the shake. Set Y to 0 for no vertical slide (Tilt and Roll still turn the view).
@export var axis_scale: Vector3 = Vector3.ONE
## Yaw and pitch shake in degrees: the camera looking around rather than moving. This is
## the part that carries a 3D shake.
@export_range(0.0, 20.0, 0.1) var tilt_degrees: float = 1.6
## Camera roll in degrees, the twist that comes with a hit. Combined with Tilt it is the
## full three-axis shake the reference recommends.
@export_range(0.0, 20.0, 0.1) var roll_degrees: float = 0.9

@export_group("Advanced")
## Bias the shake along this world direction, so it recoils away from an impact.
## Zero = an even shake in all directions.
@export var directional_bias: Vector3 = Vector3.ZERO

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["directional_bias"]))

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_SCREENSHAKE

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	var cam: Camera3D = context.get_viewport().get_camera_3d()
	if not cam:
		_warn("JuiceeShake3DEffect: no Camera3D in viewport")
		return

	var noise: FastNoiseLite
	var noise_start := randf() * 1000.0
	if use_noise:
		noise = _shake_noise()

	var effective_intensity := intensity * intensity_mult
	var original_pos: Vector3 = _capture_offset(cam, "position")
	# Advanced roll twists the view on impact; captured only when actually used.
	var rotating := roll_degrees > 0.0 or tilt_degrees > 0.0
	var original_rot: Vector3 = Vector3.ZERO
	if rotating:
		original_rot = _capture_offset(cam, "rotation")
	var elapsed: float = 0.0
	var step: float = minf(1.0 / frequency, SHAKE_NOISE_STEP) if use_noise else 1.0 / frequency
	var tree := context.get_tree()

	while elapsed < duration and is_instance_valid(cam) and _gen == play:
		var progress: float = elapsed / duration
		var current_intensity: float = effective_intensity * pow(1.0 - progress, maxf(decay, 0.0) * 2.0)
		var offset: Vector3
		var reach := current_intensity
		if use_noise:
			offset = Vector3(
				_shake_noise_at(noise, noise_start, 0, elapsed, frequency),
				_shake_noise_at(noise, noise_start, 1, elapsed, frequency),
				_shake_noise_at(noise, noise_start, 2, elapsed, frequency)
			) * current_intensity
		else:
			offset = Vector3(
				randf_range(-current_intensity, current_intensity),
				randf_range(-current_intensity, current_intensity),
				randf_range(-current_intensity, current_intensity)
			)
		# Advanced directional_bias pushes the shake away from an impact instead of jittering
		# evenly around the rest position. A push that dies away, not a sine of the shake's own
		# frequency: the loop sampled that once per cycle, so it read zero every time.
		if directional_bias != Vector3.ZERO:
			var push := effective_intensity * 0.6 * exp(-progress * 5.0)
			offset += directional_bias.normalized() * push
			reach += push
		var widest_axis := maxf(absf(axis_scale.x), maxf(absf(axis_scale.y), absf(axis_scale.z)))
		_write_offset(cam, "position", original_pos, offset * axis_scale, reach * widest_axis)
		if rotating:
			var falloff: float = pow(1.0 - progress, maxf(decay, 0.0) * 2.0)
			# Three separate noise streams, so yaw, pitch and roll are not the same wobble
			# repeated on three axes.
			var ry: float = _shake_noise_at(noise, noise_start, 3, elapsed, frequency) if use_noise else randf_range(-1.0, 1.0)
			var rx: float = _shake_noise_at(noise, noise_start, 4, elapsed, frequency) if use_noise else randf_range(-1.0, 1.0)
			var rz: float = _shake_noise_at(noise, noise_start, 5, elapsed, frequency) if use_noise else randf_range(-1.0, 1.0)
			_write_offset(cam, "rotation", original_rot, Vector3(
				rx * deg_to_rad(tilt_degrees) * falloff * intensity_mult,
				ry * deg_to_rad(tilt_degrees) * falloff * intensity_mult,
				rz * deg_to_rad(roll_degrees) * falloff * intensity_mult),
				deg_to_rad(maxf(tilt_degrees, roll_degrees)) * falloff * intensity_mult)
		elapsed += await _wait_step(tree, step)

	# A newer play or stop() holds what this one held.
	if _gen != play:
		return
	_release_state(cam, "position")
	if rotating:
		_release_state(cam, "rotation")
