@tool
class_name JuiceeZoomEffect
extends JuiceeEffect

## Camera2D zoom multiplier (>1 = zoom in, <1 = zoom out).
@export_range(0.1, 5.0, 0.05) var zoom_factor: float = 1.2
## Total duration of the zoom punch in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.4
## If true, camera zoom returns to original after the punch.
@export var return_to_original: bool = true
## Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest.
@export var trans_type: Tween.TransitionType = Tween.TRANS_BACK
## Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends.
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing Transition/Ease for the zoom. FEEL-style.
@export var ease_curve: Curve
## Seconds to hold at the target zoom before returning. 0 = zoom straight back.
@export_range(0.0, 30.0, 0.05) var hold_time: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "hold_time"]))

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	var cam: Camera2D = context.get_viewport().get_camera_2d()
	if not cam:
		_warn("JuiceeZoomEffect: no Camera2D in viewport")
		return

	var effective_factor := 1.0 + (zoom_factor - 1.0) * intensity_mult
	var original: Vector2 = _capture_state(cam, "zoom")
	var target_zoom := _camera_zoom(original * effective_factor)

	var tween := _track(cam.create_tween())
	if return_to_original:
		if ease_curve:
			_tween_curved(tween, cam, "zoom", original, target_zoom, duration * 0.4, ease_curve)
		else:
			tween.tween_property(cam, "zoom", target_zoom, duration * 0.4)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if hold_time > 0.0:
			tween.tween_interval(hold_time)
		tween.tween_property(cam, "zoom", original, duration * 0.6)\
			.set_trans(trans_type).set_ease(ease_type)
	elif ease_curve:
		_tween_curved(tween, cam, "zoom", original, target_zoom, duration, ease_curve)
	else:
		tween.tween_property(cam, "zoom", target_zoom, duration)\
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	if _gen != play:
		return
	# return_to_original=false intentionally leaves the zoom changed - don't restore.
	_release_state(cam, "zoom", return_to_original)
