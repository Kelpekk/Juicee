@tool
class_name JuiceePositionEffect
extends JuiceeEffect

## Offset to apply to the node's position at peak (in pixels).
@export var offset: Vector2 = Vector2(0, -20)
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
## Hand-drawn easing curve (0..1) replacing Transition/Ease for the move-to-peak.
## FEEL-style curve control.
@export var ease_curve: Curve

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve"]))

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var target: Node2D = context as Node2D
	if not target:
		_warn("JuiceePositionEffect: context is not a Node2D")
		return

	var original: Vector2 = _capture_state(target, "position")
	var target_pos: Vector2
	if relative:
		target_pos = original + offset * intensity_mult
	else:
		# An exact destination is exactly that: intensity scales how far we travel
		# toward it, never the destination itself.
		target_pos = original.lerp(offset, intensity_mult)

	var tween := _track(target.create_tween())
	if return_to_original:
		if ease_curve:
			_tween_curved(tween, target, "position", original, target_pos, duration * 0.4, ease_curve)
		else:
			tween.tween_property(target, "position", target_pos, duration * 0.4)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(target, "position", original, duration * 0.6)\
			.set_trans(trans_type).set_ease(ease_type)
	elif ease_curve:
		_tween_curved(tween, target, "position", original, target_pos, duration, ease_curve)
	else:
		tween.tween_property(target, "position", target_pos, duration)\
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	if _gen != play:
		return
	# return_to_original=false intentionally leaves the position changed - don't restore.
	_release_state(target, "position", return_to_original)
