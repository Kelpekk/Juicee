## 3D rotation punch - rotate Node3D around an axis then return.
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
## Offset from where the node already is (true), or the exact value to land on (false).
@export var relative: bool = true
# Back-compat: old .tres files used `return_to_origin`.
func _set(property: StringName, value) -> bool:
	if property == &"return_to_origin":
		return_to_original = value
		return true
	return false
## Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest.
@export var trans_type: Tween.TransitionType = Tween.TRANS_ELASTIC
## Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends.
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing Transition/Ease for the turn. FEEL-style.
@export var ease_curve: Curve
## Seconds to hold at the rotated angle before returning. 0 = turn straight back.
@export_range(0.0, 10.0, 0.05) var hold_time: float = 0.0
## Rock back and forth this many times instead of a single turn, decaying each swing.
@export_range(1, 12, 1) var oscillations: int = 1

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "hold_time", "oscillations"]))

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var target: Node3D = context as Node3D
	if not target:
		_warn("JuiceeRotation3DEffect: context is not a Node3D")
		return

	var original: Quaternion = _capture_state(target, "quaternion")
	if axis.is_zero_approx():
		_warn("JuiceeRotation3DEffect: axis is (0, 0, 0), so there is nothing to turn around")
		return
	var goal := Quaternion(axis.normalized(), deg_to_rad(angle_degrees))
	var target_quat: Quaternion
	if relative:
		target_quat = original * Quaternion(axis.normalized(),
			deg_to_rad(angle_degrees) * intensity_mult)
	else:
		# An exact orientation is exactly that: intensity scales how far we turn
		# toward it, never the orientation itself.
		target_quat = original.slerp(goal, intensity_mult)

	var tween := _track(target.create_tween())
	if return_to_original:
		# Advanced oscillations rock the turn back and forth, each swing weaker.
		var swings: int = _capped(maxi(1, oscillations), 1000, "oscillations")
		# The turn as a delta from rest, so a swing is a partial slerp of it (negative
		# on alternate swings for the rock-back).
		var delta: Quaternion = original.inverse() * target_quat
		var step_dur: float = duration * 0.4 / float(swings)
		for i in swings:
			var amount: float = (1.0 - float(i) / float(swings) * 0.6) * (1.0 if i % 2 == 0 else -0.5)
			var swing_quat: Quaternion = original * Quaternion.IDENTITY.slerp(delta, amount)
			if ease_curve:
				_tween_curved(tween, target, "quaternion", target.quaternion, swing_quat, step_dur, ease_curve)
			else:
				tween.tween_property(target, "quaternion", swing_quat, step_dur)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if hold_time > 0.0:
			tween.tween_interval(hold_time)
		tween.tween_property(target, "quaternion", original, duration * 0.6)\
			.set_trans(trans_type).set_ease(ease_type)
	else:
		tween.tween_property(target, "quaternion", target_quat, duration)\
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	if _gen != play:
		return
	# return_to_original=false intentionally leaves the rotation changed - don't restore.
	_release_state(target, "quaternion", return_to_original)
