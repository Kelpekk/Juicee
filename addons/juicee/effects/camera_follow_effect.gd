## Smoothly lerps the active Camera2D to follow the context Node2D for a duration.
## Different from a permanent camera follow - this is a temporary "attention shift"
## (e.g., zoom-focus on a boss, then back).
@tool
class_name JuiceeCameraFollowEffect
extends JuiceeEffect

## How long (seconds) the camera follows the context node.
@export_range(0.05, 10.0, 0.05) var duration: float = 1.5
## Lerp speed - higher = snappier follow, lower = smoother lag.
@export_range(0.5, 20.0, 0.1) var follow_speed: float = 5.0
## If true, camera lerps back to its original position when duration ends.
@export var return_to_original: bool = true
## Duration of the return-to-original lerp.
@export_range(0.1, 5.0, 0.05) var return_duration: float = 0.6

func _apply(context: Node, _intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		push_warning("JuiceeCameraFollowEffect: context is not a Node2D")
		return
	var cam: Camera2D = target.get_viewport().get_camera_2d()
	if not cam:
		push_warning("JuiceeCameraFollowEffect: no Camera2D in viewport")
		return

	var original_position: Vector2 = _capture_state(cam, "global_position")
	var elapsed: float = 0.0
	var tree: SceneTree = target.get_tree()
	var step: float = 1.0 / 60.0

	while elapsed < duration and is_instance_valid(cam) and is_instance_valid(target) and not _cancelled:
		cam.global_position = cam.global_position.lerp(target.global_position, follow_speed * step)
		await tree.create_timer(step, true, false, false).timeout
		elapsed += step

	if return_to_original and is_instance_valid(cam):
		var tween: Tween = _track(cam.create_tween())
		tween.tween_property(cam, "global_position", original_position, return_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
	# return_to_original=false intentionally leaves the camera where it ended up.
	_release_state(cam, "global_position", return_to_original)
