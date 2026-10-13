@tool
class_name JuiceeBounceEffect
extends JuiceeEffect

## Peak scale multiplier. 1.3 = 30% bigger at peak.
@export_range(1.05, 5.0, 0.05) var scale_factor: float = 1.3
## Total bounce duration (40% punch-out + 60% return-with-elastic).
@export_range(0.05, 2.0, 0.05) var duration: float = 0.3
## Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends.
@export var ease_type: Tween.EaseType = Tween.EASE_OUT
## Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest.
@export var trans_type: Tween.TransitionType = Tween.TRANS_ELASTIC

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing Transition/Ease for the return. FEEL-style.
@export var ease_curve: Curve
## Anticipation dip: squash to (1 - this) of size for a beat before punching up. 0 = none.
@export_range(0.0, 0.5, 0.05) var anticipation: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "anticipation"]))

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var target: Node2D = context as Node2D
	if not target:
		_warn("JuiceeBounceEffect: context is not a Node2D")
		return

	var effective_factor := 1.0 + (scale_factor - 1.0) * intensity_mult
	var original_scale: Vector2 = _capture_state(target, "scale")
	var peak_scale: Vector2 = original_scale * effective_factor
	var half: float = duration * 0.4
	var back: float = duration * 0.6

	var tween := _track(target.create_tween())
	# Advanced anticipation: a quick squash before the punch reads as winding up.
	if anticipation > 0.0:
		tween.tween_property(target, "scale", original_scale * (1.0 - anticipation), duration * 0.15)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(target, "scale", peak_scale, half)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# ease_curve (advanced) overrides the return easing when set.
	if ease_curve:
		_tween_curved(tween, target, "scale", peak_scale, original_scale, back, ease_curve)
	else:
		tween.tween_property(target, "scale", original_scale, back)\
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	if _gen != play:
		return
	_release_state(target, "scale")
