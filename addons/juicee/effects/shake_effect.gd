@tool
class_name JuiceeShakeEffect
extends JuiceeEffect

## Maximum shake displacement in pixels.
@export_range(0.0, 100.0, 0.5) var intensity: float = 8.0
## Total shake duration in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## Shake oscillations per second.
@export_range(1.0, 60.0, 0.5) var frequency: float = 15.0
## How quickly the shake amplitude falls off. 0 = constant, higher = faster decay.
@export_range(0.0, 5.0, 0.01) var decay: float = 0.8
## If true, uses smooth Perlin noise. If false, uses random offsets (jittery).
@export var use_noise: bool = true
## Max camera roll in degrees layered on the positional shake. A touch of rotation
## makes the same shake read much more violent. Try 1.5. 0 = position only.
@export_range(0.0, 15.0, 0.1) var roll_degrees: float = 0.0

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_SCREENSHAKE

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var cam: Camera2D = context.get_viewport().get_camera_2d()
	if not cam:
		push_warning("JuiceeShakeEffect: no Camera2D in viewport")
		return

	# Directional juicee: if caller passed {"hit_direction": Vector2.LEFT}, bias the shake
	# in that direction so the camera "recoils" away from the hit.
	var hit_direction: Vector2 = _runtime_params.get("hit_direction", Vector2.ZERO)
	var has_direction: bool = hit_direction != Vector2.ZERO
	if has_direction:
		hit_direction = hit_direction.normalized()

	var noise: FastNoiseLite
	if use_noise:
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.seed = randi()

	var effective_intensity := intensity * intensity_mult
	var effective_roll := deg_to_rad(roll_degrees) * intensity_mult
	var rolling := effective_roll > 0.0
	# Ref-counted state - handles concurrent shakes correctly. Rotation is only
	# claimed when we actually roll: capturing it with roll_degrees = 0 would
	# restore the camera's rotation on release, clobbering whatever the game's
	# own camera controller did to it during the shake.
	var original_offset: Vector2 = _capture_state(cam, "offset")
	var original_rotation: float = _capture_state(cam, "rotation") if rolling else 0.0
	var elapsed: float = 0.0
	var step: float = 1.0 / frequency
	var noise_offset: float = 0.0
	var tree := context.get_tree()

	while elapsed < duration and is_instance_valid(cam) and not _cancelled:
		var progress: float = elapsed / duration
		var falloff: float = pow(1.0 - progress, decay * 2.0)
		var current_intensity: float = effective_intensity * falloff
		var offset: Vector2
		if use_noise:
			noise_offset += step * 10.0
			offset = Vector2(
				noise.get_noise_1d(noise_offset) * current_intensity,
				noise.get_noise_1d(noise_offset + 100.0) * current_intensity
			)
		else:
			offset = Vector2(
				randf_range(-current_intensity, current_intensity),
				randf_range(-current_intensity, current_intensity)
			)
		# Add directional bias on top of the random noise (recoil away from hit).
		if has_direction:
			var directional_pulse: float = current_intensity * 0.6 * sin(elapsed * frequency * TAU)
			offset += hit_direction * directional_pulse
		cam.offset = original_offset + offset
		if rolling:
			var r: float = noise.get_noise_1d(noise_offset + 200.0) if use_noise \
				else randf_range(-1.0, 1.0)
			cam.rotation = original_rotation + r * effective_roll * falloff
		await tree.create_timer(step, true, false, false).timeout
		elapsed += step

	_release_state(cam, "offset")
	if rolling:
		_release_state(cam, "rotation")
