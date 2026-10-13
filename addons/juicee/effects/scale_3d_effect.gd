## 3D scale punch - scale a Node3D to target_scale then ease back. The Node3D
## counterpart of JuiceeScaleEffect. Pickups, impacts, growing and shrinking props.
@tool
class_name JuiceeScale3DEffect
extends JuiceeEffect

## Scale multiplier when `relative` (1.5 = half again as big), or the exact scale
## to land on when not.
@export var target_scale: Vector3 = Vector3(1.5, 1.5, 1.5)
## Total punch duration in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## If true, eases back to the original scale after the punch.
@export var return_to_original: bool = true
## Duration of the return animation. Ignored when return_to_original = false.
@export_range(0.05, 3.0, 0.05) var return_duration: float = 0.25
## Multiply the node's current scale (true), or treat target_scale as the exact
## scale to reach (false).
@export var relative: bool = true
## Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest.
@export var trans_type: Tween.TransitionType = Tween.TRANS_BACK
## Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends.
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing Transition/Ease for the scale. FEEL-style.
@export var ease_curve: Curve
## Seconds to hold at the target scale before returning. 0 = return straight away.
@export_range(0.0, 10.0, 0.05) var hold_time: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "hold_time"]))

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var target: Node3D = context as Node3D
	if not target:
		_warn("JuiceeScale3DEffect: context is not a Node3D")
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
		# ease_curve (advanced) overrides the built-in easing on the way out.
		if ease_curve:
			_tween_curved(tween, target, "scale", original, goal, duration, ease_curve)
		else:
			tween.tween_property(target, "scale", goal, duration)\
				.set_trans(trans_type).set_ease(ease_type)
		if hold_time > 0.0:
			tween.tween_interval(hold_time)
		tween.tween_property(target, "scale", original, return_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(target, "scale", goal, duration)\
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	if _gen != play:
		return
	# return_to_original = false intentionally leaves the scale changed - don't restore.
	_release_state(target, "scale", return_to_original)
