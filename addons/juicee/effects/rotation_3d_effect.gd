## 3D rotation punch — rotate Node3D around an axis then return.
@tool
class_name JuiceeRotation3DEffect
extends JuiceeEffect

## Axis to rotate around (will be auto-normalized).
@export var axis: Vector3 = Vector3.UP
## Peak rotation around the axis in degrees.
@export_range(-360.0, 360.0, 1.0) var angle_degrees: float = 15.0
## Total rotation punch duration in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## If true, rotates back to original orientation after the punch.
@export var return_to_original: bool = true
## If true, the CURRENT value is changing RELATIVELY, else TARGET value is the DESTINATION.
@export var relative: bool = true
# Back-compat: old .tres files used `return_to_origin`.
func _set(property: StringName, value) -> bool:
	if property == &"return_to_origin":
		return_to_original = value
		return true
	return false
@export var trans_type: Tween.TransitionType = Tween.TRANS_ELASTIC
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

func get_category_color() -> Color:
	return Color(1.0, 0.333, 0.333)

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node3D = context as Node3D
	if not target:
		push_warning("JuiceeRotation3DEffect: context is not a Node3D")
		return

	var effective_angle := deg_to_rad(angle_degrees) * intensity_mult
	var original: Quaternion = _capture_state(target, "quaternion")
	var rotation_delta := Quaternion(axis.normalized(), effective_angle)
	var target_quat: Quaternion
	if relative:
		target_quat = original * rotation_delta
	else:
		target_quat = rotation_delta

	var tween := _track(target.create_tween())
	if return_to_original:
		tween.tween_property(target, "quaternion", target_quat, duration * 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(target, "quaternion", original, duration * 0.6)\
			.set_trans(trans_type).set_ease(ease_type)
	else:
		tween.tween_property(target, "quaternion", target_quat, duration)\
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	# return_to_original=false intentionally leaves the rotation changed — don't restore.
	_release_state(target, "quaternion", return_to_original)
