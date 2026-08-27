## Rhythmic sinusoidal Camera2D bob.
##
## Use for: walking footstep camera, ship rocking on waves, breathing idle animation,
## hypnotic pendulum, drunk/dizzy state camera.
##
## The bob amplitude fades in over the first 10% and out over the last 10%
## of `duration` so it never pops in/out abruptly.
@tool
class_name JuiceeCameraBobEffect
extends JuiceeEffect

## Per-axis bob amplitude in pixels. (0, 4) = vertical only, (3, 3) = circular.
@export var amplitude: Vector2 = Vector2(0.0, 4.0)
## Bob cycles per second (2.0 = leisurely walk, 3.5 = run, 0.5 = breathing).
@export_range(0.1, 15.0, 0.1) var frequency: float = 2.0
## Total duration in seconds.
@export_range(0.1, 30.0, 0.1) var duration: float = 2.0
## Phase offset in radians. PI/2 = start at peak instead of zero crossing.
@export_range(0.0, 6.283, 0.01) var phase_offset: float = 0.0

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_SCREENSHAKE
func get_category_name() -> String: return "Camera"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var cam: Camera2D = context.get_viewport().get_camera_2d()
	if not cam:
		push_warning("JuiceeCameraBobEffect: no Camera2D in viewport")
		return

	var original_pos: Vector2 = _capture_state(cam, "position")
	var elapsed := 0.0
	var tree := context.get_tree()
	var eff_amp := amplitude * intensity_mult

	while elapsed < duration and is_instance_valid(cam) and not _cancelled:
		var t := elapsed / duration
		# Smooth fade-in (first 10%) and fade-out (last 10%).
		var env := sin(t * PI)
		var bob := Vector2(
			sin(elapsed * frequency * TAU + phase_offset) * eff_amp.x,
			sin(elapsed * frequency * TAU + phase_offset + PI * 0.5) * eff_amp.y
		) * env
		cam.position = original_pos + bob
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()

	_release_state(cam, "position")
