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

@export_group("Advanced")
## Offset (pixels) held from the target, so the camera frames it off-centre instead of
## dead centre. e.g. (0, -60) keeps the subject low in frame.
@export var follow_offset: Vector2 = Vector2.ZERO
## Lead the target by this many pixels per unit of its speed, so the camera looks ahead
## in the direction of travel. 0 = no look-ahead.
@export_range(0.0, 1.0, 0.01) var look_ahead: float = 0.0
## Stop correcting once the camera is within this many pixels of the target, so it
## settles instead of micro-drifting. 0 = always correct.
@export_range(0.0, 100.0, 1.0) var deadzone: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["follow_offset", "look_ahead", "deadzone"]))

func _apply(context: Node, _intensity_mult: float) -> void:
	var play := _gen
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		_warn("JuiceeCameraFollowEffect: context is not a Node2D")
		return
	var cam: Camera2D = target.get_viewport().get_camera_2d()
	if not cam:
		_warn("JuiceeCameraFollowEffect: no Camera2D in viewport")
		return

	var original_position: Vector2 = _capture_state(cam, "global_position")
	var elapsed: float = 0.0
	var tree: SceneTree = target.get_tree()
	var step: float = 1.0 / 60.0

	var last_target_pos: Vector2 = target.global_position
	while elapsed < duration and is_instance_valid(cam) and is_instance_valid(target) and _gen == play:
		# Advanced: frame the target off-centre, and lead it in its direction of travel.
		var goal: Vector2 = target.global_position + follow_offset
		if look_ahead > 0.0:
			var velocity: Vector2 = (target.global_position - last_target_pos) / step
			goal += velocity * look_ahead
		last_target_pos = target.global_position
		# Deadzone lets the camera settle instead of micro-correcting forever.
		if deadzone <= 0.0 or cam.global_position.distance_to(goal) > deadzone:
			cam.global_position = cam.global_position.lerp(goal, follow_speed * step)
		elapsed += await _wait_step(tree, step)

	# A newer play or stop() holds what this one held.
	if _gen != play:
		return
	if return_to_original and is_instance_valid(cam):
		var tween: Tween = _track(cam.create_tween())
		tween.tween_property(cam, "global_position", original_position, return_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
		if _gen != play:
			return
	# return_to_original=false intentionally leaves the camera where it ended up.
	_release_state(cam, "global_position", return_to_original)
