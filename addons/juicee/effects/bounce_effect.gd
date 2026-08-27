@tool
class_name JuiceeBounceEffect
extends JuiceeEffect

## Peak scale multiplier. 1.3 = 30% bigger at peak.
@export_range(1.05, 5.0, 0.05) var scale_factor: float = 1.3
## Total bounce duration (40% punch-out + 60% return-with-elastic).
@export_range(0.05, 2.0, 0.05) var duration: float = 0.3
@export var ease_type: Tween.EaseType = Tween.EASE_OUT
@export var trans_type: Tween.TransitionType = Tween.TRANS_ELASTIC

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target:
		push_warning("JuiceeBounceEffect: context is not a Node2D")
		return

	var effective_factor := 1.0 + (scale_factor - 1.0) * intensity_mult
	var original_scale: Vector2 = _capture_state(target, "scale")
	var peak_scale: Vector2 = original_scale * effective_factor
	var half: float = duration * 0.4
	var back: float = duration * 0.6

	var tween := _track(target.create_tween())
	tween.tween_property(target, "scale", peak_scale, half)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", original_scale, back)\
		.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	_release_state(target, "scale")
