## 3D position punch - move Node3D by offset then return.
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
## Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest.
@export var trans_type: Tween.TransitionType = Tween.TRANS_BACK
## Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends.
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing Transition/Ease for the move. FEEL-style.
@export var ease_curve: Curve
## Seconds to hold at the offset before returning. 0 = move straight back.
@export_range(0.0, 10.0, 0.05) var hold_time: float = 0.0
## Read Offset along the node's own forward/up/right instead of the parent's axes, so a
## recoil pushes backwards whichever way the node is facing. Relative moves only: an
## exact destination is already a point, not a direction.
@export var use_local_space: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "hold_time", "use_local_space"]))

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var target: Node3D = context as Node3D
	if not target:
		_warn("JuiceePosition3DEffect: context is not a Node3D")
		return

	var original: Vector3 = _capture_state(target, "position")
	var target_pos: Vector3
	if relative:
		var move := offset * intensity_mult
		if use_local_space:
			# Its own axes, without its scale: a node scaled to 2 should not travel twice
			# as far for the same offset.
			move = target.transform.basis.orthonormalized() * move
		target_pos = original + move
	else:
		# An exact destination is exactly that: intensity scales how far we travel
		# toward it, never the destination itself.
		target_pos = original.lerp(offset, intensity_mult)

	var tween := _track(target.create_tween())
	if return_to_original:
		# ease_curve (advanced) overrides the built-in easing on the way out.
		if ease_curve:
			_tween_curved(tween, target, "position", original, target_pos, duration * 0.4, ease_curve)
		else:
			tween.tween_property(target, "position", target_pos, duration * 0.4)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if hold_time > 0.0:
			tween.tween_interval(hold_time)
		tween.tween_property(target, "position", original, duration * 0.6)\
			.set_trans(trans_type).set_ease(ease_type)
	else:
		tween.tween_property(target, "position", target_pos, duration)\
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	if _gen != play:
		return
	# return_to_original=false intentionally leaves the position changed - don't restore.
	_release_state(target, "position", return_to_original)
