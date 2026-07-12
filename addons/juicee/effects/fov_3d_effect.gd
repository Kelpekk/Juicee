## Camera3D field-of-view punch — zoom in/out via FOV change.
@tool
class_name JuiceeFOV3DEffect
extends JuiceeEffect

## Amount to add to the camera's FOV in degrees (positive = zoom out, negative = zoom in).
@export_range(-50.0, 50.0, 0.5) var fov_delta: float = 10.0
## Total duration of the FOV punch in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.4
## If true, FOV returns to its original value after the punch.
@export var return_to_original: bool = true
@export var trans_type: Tween.TransitionType = Tween.TRANS_BACK
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

func get_category_color() -> Color:
	return Color(1.0, 0.333, 0.333)

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var cam: Camera3D = context.get_viewport().get_camera_3d()
	if not cam:
		push_warning("JuiceeFOV3DEffect: no Camera3D in viewport")
		return

	var original: float = _capture_state(cam, "fov")
	var target_fov := clamp(original + fov_delta * intensity_mult, 1.0, 179.0)

	var tween := _track(cam.create_tween())
	if return_to_original:
		tween.tween_property(cam, "fov", target_fov, duration * 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(cam, "fov", original, duration * 0.6) \
			.set_trans(trans_type).set_ease(ease_type)
	else:
		tween.tween_property(cam, "fov", target_fov, duration) \
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	# return_to_original=false intentionally leaves the FOV changed — don't restore.
	_release_state(cam, "fov", return_to_original)
