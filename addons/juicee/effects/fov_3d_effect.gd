## Camera3D field-of-view punch - zoom in/out via FOV change.
@tool
class_name JuiceeFOV3DEffect
extends JuiceeEffect

## Amount to add to the camera's FOV in degrees (positive = zoom out, negative = zoom in).
@export_range(-50.0, 50.0, 0.5) var fov_delta: float = 10.0
## Total duration of the FOV punch in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.4
## If true, FOV returns to its original value after the punch.
@export var return_to_original: bool = true
## Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest.
@export var trans_type: Tween.TransitionType = Tween.TRANS_BACK
## Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends.
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing Transition/Ease for the FOV shift. FEEL-style.
@export var ease_curve: Curve
## Seconds to hold the changed FOV before it returns. 0 = return straight away.
@export_range(0.0, 30.0, 0.05) var hold_time: float = 0.0
## Pulse in and out this many times instead of one shift, for a breathing zoom.
@export_range(1, 12, 1) var pulse_count: int = 1

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "hold_time", "pulse_count"]))

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	var cam: Camera3D = context.get_viewport().get_camera_3d()
	if not cam:
		_warn("JuiceeFOV3DEffect: no Camera3D in viewport")
		return

	var original: float = _capture_state(cam, "fov")
	var target_fov := clampf(original + fov_delta * intensity_mult, 1.0, 179.0)

	var tween := _track(cam.create_tween())
	if return_to_original:
		# Advanced pulse_count shares the duration between that many in-and-out swings,
		# each with its own hold, so a breathing zoom still takes the time it says.
		var pulses := _capped(maxi(pulse_count, 1), 1000, "pulse_count")
		var swing := duration / float(pulses)
		for _i in pulses:
			# ease_curve (advanced) overrides the built-in easing on the way out.
			if ease_curve:
				_tween_curved(tween, cam, "fov", original, target_fov, swing * 0.4, ease_curve)
			else:
				tween.tween_property(cam, "fov", target_fov, swing * 0.4) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			if hold_time > 0.0:
				tween.tween_interval(hold_time)
			tween.tween_property(cam, "fov", original, swing * 0.6) \
				.set_trans(trans_type).set_ease(ease_type)
	else:
		tween.tween_property(cam, "fov", target_fov, duration) \
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	if _gen != play:
		return
	# return_to_original=false intentionally leaves the FOV changed - don't restore.
	_release_state(cam, "fov", return_to_original)
