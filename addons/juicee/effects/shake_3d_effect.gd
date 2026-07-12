## Camera3D shake for 3D games.
## Finds the active Camera3D via context.get_viewport().get_camera_3d() and shakes its position.
@tool
class_name JuiceeShake3DEffect
extends JuiceeEffect

## Maximum shake displacement in world units. Bump higher for large-scale worlds.
@export_range(0.0, 5.0, 0.01) var intensity: float = 0.25
## Total shake duration in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## Shake oscillations per second.
@export_range(1.0, 60.0, 0.5) var frequency: float = 15.0
## How quickly the shake amplitude falls off. 0 = constant, higher = faster decay.
@export_range(0.0, 5.0, 0.01) var decay: float = 0.8
## If true, uses smooth Perlin noise. If false, uses random offsets (jittery).
@export var use_noise: bool = true
## Per-axis multiplier. Set Y to 0 for horizontal-only shake (no vertical bob).
@export var axis_scale: Vector3 = Vector3.ONE

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_SCREENSHAKE
func get_category_color() -> Color:
	return Color(1.0, 0.333, 0.333)

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var cam: Camera3D = context.get_viewport().get_camera_3d()
	if not cam:
		push_warning("JuiceeShake3DEffect: no Camera3D in viewport")
		return

	var noise: FastNoiseLite
	if use_noise:
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.seed = randi()

	var effective_intensity := intensity * intensity_mult
	var original_pos: Vector3 = _capture_state(cam, "position")
	var elapsed: float = 0.0
	var step: float = 1.0 / frequency
	var noise_offset: float = 0.0
	var tree := context.get_tree()

	while elapsed < duration and is_instance_valid(cam) and not _cancelled:
		var progress: float = elapsed / duration
		var current_intensity: float = effective_intensity * pow(1.0 - progress, decay * 2.0)
		var offset: Vector3
		if use_noise:
			noise_offset += step * 10.0
			offset = Vector3(
				noise.get_noise_1d(noise_offset) * current_intensity,
				noise.get_noise_1d(noise_offset + 100.0) * current_intensity,
				noise.get_noise_1d(noise_offset + 200.0) * current_intensity
			)
		else:
			offset = Vector3(
				randf_range(-current_intensity, current_intensity),
				randf_range(-current_intensity, current_intensity),
				randf_range(-current_intensity, current_intensity)
			)
		cam.position = original_pos + offset * axis_scale
		await tree.create_timer(step, true, false, false).timeout
		elapsed += step

	_release_state(cam, "position")
