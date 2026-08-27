## Gentle sine-wave vertical (or custom-axis) bob on a Node2D.
##
## Unlike CameraBob (which moves the camera), this moves the TARGET NODE.
## Use for: floating pickup item, idle NPC hover, UI element breathe,
## torch flame sway, buoy on water, space station drift.
##
## The amplitude fades in at the start and out at the end (sin(t*PI) envelope)
## so it never pops on or off.
@tool
class_name JuiceeSpriteBobEffect
extends JuiceeEffect

## Peak displacement in pixels.
@export_range(0.0, 100.0, 0.5) var amplitude: float = 4.0
## Bob cycles per second. 1.5 = gentle float, 3.0 = nervous flutter.
@export_range(0.1, 15.0, 0.1) var frequency: float = 1.5
## Total duration in seconds.
@export_range(0.1, 30.0, 0.1) var duration: float = 2.0
## Phase offset in radians (PI/2 = start at peak).
@export_range(0.0, 6.283, 0.01) var phase_offset: float = 0.0
## Direction of the bob. (0, 1) = vertical, (1, 0) = horizontal.
@export var bob_axis: Vector2 = Vector2(0.0, 1.0)

func get_category_name() -> String: return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not context is Node2D:
		push_warning("JuiceeSpriteBobEffect: context must be a Node2D")
		return
	var target := context as Node2D
	var original_pos: Vector2 = _capture_state(target, "position")
	var elapsed := 0.0
	var tree := context.get_tree()
	var eff_amp := amplitude * intensity_mult
	var axis_norm := bob_axis.normalized() if bob_axis.length_squared() > 0.0001 else Vector2.DOWN

	while elapsed < duration and is_instance_valid(target) and not _cancelled:
		var t := elapsed / duration
		var env := sin(t * PI)
		var bob := sin(elapsed * frequency * TAU + phase_offset) * eff_amp * env
		target.position = original_pos + axis_norm * bob
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()

	_release_state(target, "position")
