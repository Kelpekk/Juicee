@tool
class_name JuiceeRotationEffect
extends JuiceeEffect

## Peak rotation in degrees (positive = clockwise in Godot 2D).
@export_range(-360.0, 360.0, 1.0) var angle_degrees: float = 15.0
## Total rotation punch duration in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## If true, rotates back to original after the punch.
@export var return_to_original: bool = true
## Offset from where the node already is (true), or the exact value to land on (false).
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
	return Color(0.22, 0.58, 1.00)

func get_icon_path() -> String:
	return "res://addons/juicee/icons/bounce.svg"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target:
		push_warning("JuiceeRotationEffect: context is not a Node2D")
		return

	var original: float = _capture_state(target, "rotation")
	var goal := deg_to_rad(angle_degrees)
	var target_rot: float
	if relative:
		target_rot = original + goal * intensity_mult
	else:
		# An exact angle is exactly that: intensity scales how far we swing toward
		# it, never the angle itself.
		target_rot = lerpf(original, goal, intensity_mult)

	var tween := _track(target.create_tween())
	if return_to_original:
		tween.tween_property(target, "rotation", target_rot, duration * 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(target, "rotation", original, duration * 0.6)\
			.set_trans(trans_type).set_ease(ease_type)
	else:
		tween.tween_property(target, "rotation", target_rot, duration)\
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	# return_to_original=false intentionally leaves the rotation changed — don't restore.
	_release_state(target, "rotation", return_to_original)
