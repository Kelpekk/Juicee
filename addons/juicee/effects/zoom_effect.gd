@tool
class_name JuiceeZoomEffect
extends JuiceeEffect

## Camera2D zoom multiplier (>1 = zoom in, <1 = zoom out).
@export_range(0.1, 5.0, 0.05) var zoom_factor: float = 1.2
## Total duration of the zoom punch in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.4
## If true, camera zoom returns to original after the punch.
@export var return_to_original: bool = true
@export var trans_type: Tween.TransitionType = Tween.TRANS_BACK
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var cam: Camera2D = context.get_viewport().get_camera_2d()
	if not cam:
		push_warning("JuiceeZoomEffect: no Camera2D in viewport")
		return

	var effective_factor := 1.0 + (zoom_factor - 1.0) * intensity_mult
	var original: Vector2 = _capture_state(cam, "zoom")
	var target_zoom := original * effective_factor

	var tween := _track(cam.create_tween())
	if return_to_original:
		tween.tween_property(cam, "zoom", target_zoom, duration * 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(cam, "zoom", original, duration * 0.6)\
			.set_trans(trans_type).set_ease(ease_type)
	else:
		tween.tween_property(cam, "zoom", target_zoom, duration)\
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	# return_to_original=false intentionally leaves the zoom changed - don't restore.
	_release_state(cam, "zoom", return_to_original)
