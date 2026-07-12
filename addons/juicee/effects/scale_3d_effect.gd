## 3D scale punch — scale a Node3D to target_scale then spring back. The Node3D
## counterpart of JuiceeScaleEffect. Pickups, impacts, growing and shrinking props.
@tool
class_name JuiceeScale3DEffect
extends JuiceeEffect

## Scale multiplier when `relative` (1.5 = half again as big), or the exact scale
## to land on when not.
@export var target_scale: Vector3 = Vector3(1.5, 1.5, 1.5)
## Total punch duration in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## If true, springs back to the original scale after the punch.
@export var return_to_original: bool = true
## Duration of the return animation. Ignored when return_to_original = false.
@export_range(0.05, 3.0, 0.05) var return_duration: float = 0.25
## Multiply the node's current scale (true), or treat target_scale as the exact
## scale to reach (false).
@export var relative: bool = true
@export var trans_type: Tween.TransitionType = Tween.TRANS_BACK
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

func get_category_color() -> Color:
	return Color(1.0, 0.333, 0.333)

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node3D = context as Node3D
	if not target:
		push_warning("JuiceeScale3DEffect: context is not a Node3D")
		return

	var original: Vector3 = _capture_state(target, "scale")
	var goal: Vector3
	if relative:
		# Scale from the node's CURRENT value, matching JuiceeScaleEffect, so two
		# scale punches compound instead of the second one targeting where the
		# first already is. Intensity scales how far the punch goes, so at 0 the
		# node stays put rather than collapsing to nothing.
		var start: Vector3 = target.scale
		goal = start * (Vector3.ONE + (target_scale - Vector3.ONE) * intensity_mult)
	else:
		# An exact destination is exactly that: intensity must not move it.
		goal = target_scale

	var tween := _track(target.create_tween())
	if return_to_original:
		tween.tween_property(target, "scale", goal, duration)\
			.set_trans(trans_type).set_ease(ease_type)
		tween.tween_property(target, "scale", original, return_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(target, "scale", goal, duration)\
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	# return_to_original = false intentionally leaves the scale changed — don't restore.
	_release_state(target, "scale", return_to_original)
