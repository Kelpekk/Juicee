## Smooth color shift on a CanvasItem.
## Unlike JuiceeFlashEffect (which blinks), this tweens smoothly from current -> target -> back.
@tool
class_name JuiceeModulateEffect
extends JuiceeEffect

## Target color to lerp the modulate to. Values >1 brighten beyond white.
@export var target_color: Color = Color(1.5, 0.5, 0.5, 1.0)
## Total duration (split half tween-in, half tween-out if return_to_original).
@export_range(0.05, 5.0, 0.05) var duration: float = 0.5
## If true, lerps back to the original modulate after reaching target.
@export var return_to_original: bool = true
## Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest.
@export var trans_type: Tween.TransitionType = Tween.TRANS_SINE
## Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends.
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing Transition/Ease for the colour shift. FEEL-style.
@export var ease_curve: Curve
## Seconds to hold at the target colour before returning. 0 = shift straight back.
@export_range(0.0, 5.0, 0.05) var hold_time: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "hold_time"]))

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var target: CanvasItem = context as CanvasItem
	if not target or not target.is_inside_tree():
		_warn("JuiceeModulateEffect: context is not a CanvasItem in the tree")
		return

	var original: Color = _capture_state(target, "modulate")
	var effective_color := original.lerp(target_color, clamp(intensity_mult, 0.0, 1.0))

	var tween := _track(target.create_tween())
	if return_to_original:
		if ease_curve:
			_tween_curved(tween, target, "modulate", original, effective_color, duration * 0.5, ease_curve)
		else:
			tween.tween_property(target, "modulate", effective_color, duration * 0.5)\
				.set_trans(trans_type).set_ease(ease_type)
		if hold_time > 0.0:
			tween.tween_interval(hold_time)
		tween.tween_property(target, "modulate", original, duration * 0.5)\
			.set_trans(trans_type).set_ease(ease_type)
	elif ease_curve:
		_tween_curved(tween, target, "modulate", original, effective_color, duration, ease_curve)
	else:
		tween.tween_property(target, "modulate", effective_color, duration)\
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	if _gen != play:
		return
	# return_to_original=false intentionally leaves the modulate changed - don't restore.
	_release_state(target, "modulate", return_to_original)
