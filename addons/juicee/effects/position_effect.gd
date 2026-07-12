@tool
class_name JuiceePositionEffect
extends JuiceeEffect

## Offset to apply to the node's position at peak (in pixels).
@export var offset: Vector2 = Vector2(0, -20)
## Total punch duration in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## If true, returns to original position after the punch.
@export var return_to_original: bool = true
## If true, the CURRENT value is changing RELATIVELY, else TARGET value is the DESTINATION.
@export var relative: bool = true

# Back-compat: old .tres files used `return_to_origin`.
func _set(property: StringName, value) -> bool:
	if property == &"return_to_origin":
		return_to_original = value
		return true
	return false
@export var trans_type: Tween.TransitionType = Tween.TRANS_BACK
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_icon_path() -> String:
	return "res://addons/juicee/icons/bounce.svg"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target:
		push_warning("JuiceePositionEffect: context is not a Node2D")
		return

	var effective_offset: Vector2
	var original: Vector2
	var target_pos: Vector2
	effective_offset = offset * intensity_mult
	original = _capture_state(target, "position")
	if relative:
		target_pos = original + effective_offset
	else:
		target_pos = effective_offset

	var tween := _track(target.create_tween())
	if return_to_original:
		tween.tween_property(target, "position", target_pos, duration * 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(target, "position", original, duration * 0.6)\
			.set_trans(trans_type).set_ease(ease_type)
	else:
		tween.tween_property(target, "position", target_pos, duration)\
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	# return_to_original=false intentionally leaves the position changed — don't restore.
	_release_state(target, "position", return_to_original)
