## Dutch tilt - rotate Camera2D by angle_degrees then return.
##
## Use for: suspense moments, horror reveals, disorientation hits,
## gravity shifts, off-kilter dream sequences.
@tool
class_name JuiceeCameraRotationEffect
extends JuiceeEffect

## Peak rotation angle in degrees. Positive = clockwise.
@export_range(-45.0, 45.0, 0.5) var angle_degrees: float = 5.0
## Seconds to tilt to the peak angle.
@export_range(0.05, 2.0, 0.05) var tilt_duration: float = 0.3
## Seconds to hold at peak angle. 0 = return straight away.
@export_range(0.0, 5.0, 0.05) var hold_duration: float = 0.0
## Seconds to return to original rotation.
@export_range(0.05, 2.0, 0.05) var return_duration: float = 0.4

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing the built-in easing on the tilt in. FEEL-style.
@export var ease_curve: Curve
## Rock back and forth this many times instead of a single tilt-and-return. 3+ reads as
## a disoriented / drunk camera.
@export_range(1, 12, 1) var oscillations: int = 1

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "oscillations"]))

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_SCREENSHAKE
func get_category_name() -> String: return "Camera"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	var cam: Camera2D = context.get_viewport().get_camera_2d()
	if not cam:
		_warn("JuiceeCameraRotationEffect: no Camera2D in viewport")
		return

	# A Camera2D ignores its own rotation by default (ignore_rotation = true), so
	# tweening cam.rotation would change the number and leave the screen level. Turn
	# it off for the tilt and put it back, even if the effect is stopped partway.
	var had_ignore := cam.ignore_rotation
	if had_ignore:
		cam.ignore_rotation = false
		_on_stop(_set_by_id.bind(cam.get_instance_id(), &"ignore_rotation", true))

	var original: float = _capture_state(cam, "rotation")
	var target_rad := deg_to_rad(angle_degrees * intensity_mult)

	var tween := _track(cam.create_tween())
	# Advanced oscillations: rock the tilt side to side, decaying, before settling.
	var swings: int = _capped(maxi(1, oscillations), 1000, "oscillations")
	for i in swings:
		var dir: float = 1.0 if i % 2 == 0 else -1.0
		var decay: float = 1.0 - float(i) / float(swings) * 0.6
		var goal: float = original + target_rad * dir * decay
		if ease_curve:
			_tween_curved(tween, cam, "rotation", cam.rotation, goal, tilt_duration, ease_curve)
		else:
			tween.tween_property(cam, "rotation", goal, tilt_duration)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if i == 0 and hold_duration > 0.0 and swings == 1:
			tween.tween_interval(hold_duration)
	if swings > 1 and hold_duration > 0.0:
		tween.tween_interval(hold_duration)
	tween.tween_property(cam, "rotation", original, return_duration)\
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	await tween.finished
	if _gen != play:
		return

	_release_state(cam, "rotation")
	if is_instance_valid(cam) and had_ignore:
		cam.ignore_rotation = true
