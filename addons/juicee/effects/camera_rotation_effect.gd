## Dutch tilt — rotate Camera2D by angle_degrees then return.
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
## Seconds to hold at peak angle. 0 = snap straight back.
@export_range(0.0, 5.0, 0.05) var hold_duration: float = 0.0
## Seconds to return to original rotation.
@export_range(0.05, 2.0, 0.05) var return_duration: float = 0.4

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_SCREENSHAKE
func get_category_color() -> Color: return Color(0.72, 0.28, 0.95)
func get_category_name() -> String: return "Camera"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var cam: Camera2D = context.get_viewport().get_camera_2d()
	if not cam:
		push_warning("JuiceeCameraRotationEffect: no Camera2D in viewport")
		return

	# A Camera2D ignores its own rotation by default (ignore_rotation = true), so
	# tweening cam.rotation would change the number and leave the screen level. Turn
	# it off for the tilt and put it back, even if the effect is stopped partway.
	var had_ignore := cam.ignore_rotation
	if had_ignore:
		cam.ignore_rotation = false
		_on_stop(func() -> void:
			if is_instance_valid(cam):
				cam.ignore_rotation = true)

	var original: float = _capture_state(cam, "rotation")
	var target_rad := deg_to_rad(angle_degrees * intensity_mult)

	var tween := _track(cam.create_tween())
	tween.tween_property(cam, "rotation", original + target_rad, tilt_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if hold_duration > 0.0:
		tween.tween_interval(hold_duration)
	tween.tween_property(cam, "rotation", original, return_duration)\
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	await tween.finished

	_release_state(cam, "rotation")
	if is_instance_valid(cam) and had_ignore:
		cam.ignore_rotation = true
