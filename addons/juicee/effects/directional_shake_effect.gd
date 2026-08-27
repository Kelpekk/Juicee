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

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_SCREENSHAKE
func get_category_name() -> String: return "Camera"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var cam: Camera2D = context.get_viewport().get_camera_2d()
	if not cam:
		push_warning("JuiceeDirectionalShakeEffect: no Camera2D in viewport")
		return

	var dir := (_runtime_params.get("direction", direction) as Vector2).normalized()
	if dir.length_squared() < 0.001:
		dir = Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()

	var original_pos: Vector2 = _capture_state(cam, "position")
	var elapsed := 0.0
	var step := 1.0 / frequency
	var noise_t := 0.0
	var eff_kick := kick_distance * intensity_mult
	var eff_side := side_intensity * intensity_mult
	var tree := context.get_tree()

	while elapsed < duration and is_instance_valid(cam) and not _cancelled:
		var t := elapsed / duration
		# Directional kick: exponential decay so it snaps back quickly.
		var kick := eff_kick * exp(-t * 5.0)
		# Side noise: linear decay.
		var decay := 1.0 - t
		noise_t += step * 12.0
		var side_noise := noise.get_noise_1d(noise_t) * eff_side * decay
		# Kick is opposite to direction (impact feel).
		cam.position = original_pos + (-dir) * kick + perp * side_noise
		await tree.create_timer(step, true, false, false).timeout
		elapsed += step

	_release_state(cam, "position")
