## 3D position punch — move Node3D by offset then return.
@tool
class_name JuiceePosition3DEffect
extends JuiceeEffect

## Offset to apply to the node's position at peak (in world units).
@export var offset: Vector3 = Vector3(0, 0.5, 0)
## Total punch duration in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## If true, returns to original position after the punch.
@export var return_to_original: bool = true
## Offset from where the node already is (true), or the exact value to land on (false).
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

	var original: Vector3 = _capture_state(target, "position")
	var target_pos: Vector3
	if relative:
		target_pos = original + offset * intensity_mult
	else:
		# An exact destination is exactly that: intensity scales how far we travel
		# toward it, never the destination itself.
		target_pos = original.lerp(offset, intensity_mult)

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
