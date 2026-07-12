## 3D Scale punch — scale Node3D by target_scale then return.
@tool
class_name JuiceeScale3DEffect
extends JuiceeEffect

## Target scale multiplier. Applied relative to the node's current scale.
@export var target_scale: Vector3 = Vector3(1.5, 1.5, 1.5)
## Total punch duration in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## If true, returns to original position after the punch.
@export var return_to_original: bool = true
## Duration of the return animation. Ignored when return_to_original=false.
@export_range(0.05, 3.0, 0.05) var return_duration: float = 0.25
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
	return Color(1.0, 0.333, 0.333)

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node3D = context as Node3D
	if not target:
		push_warning("JuiceePosition3DEffect: context is not a Node3D")
		return

	var effective_scale := target_scale * intensity_mult
	var original: Vector3 = _capture_state(target, "scale")
	var goal: Vector3
	if relative:
		goal = original + effective_scale
	else:
		goal = effective_scale

	var tween := _track(target.create_tween())
	if return_to_original:
		tween.tween_property(target, "scale", goal, duration * 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(target, "scale", original, duration * 0.6) \
			.set_trans(trans_type).set_ease(ease_type)
	else:
		tween.tween_property(target, "scale", goal, duration) \
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	# return_to_original=false intentionally leaves the position changed — don't restore.
	_release_state(target, "scale", return_to_original)
