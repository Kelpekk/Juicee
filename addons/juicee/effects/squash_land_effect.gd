## Landing squash: flatten the node on impact, then spring it back with overshoot.
@tool
class_name JuiceeSquashLandEffect
extends JuiceeEffect

## Squash strength at the moment of impact. 0.4 = about 140% wide / 60% tall at the peak.
@export_range(0.05, 0.9, 0.05) var squash_amount: float = 0.4
## Total time for the squash plus the recovery.
@export_range(0.05, 2.0, 0.05) var duration: float = 0.35
## Spring overshoot on the way back: the node stretches tall past its size before it
## settles. 0 = ease straight back with no rebound.
@export_range(0.0, 1.0, 0.05) var bounce: float = 0.5

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Landing squash: flatten on impact, spring back.\nPlatformer landings, stomps, jelly hops."

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		push_warning("JuiceeSquashLandEffect: context is not a Node2D")
		return

	var original: Vector2 = _capture_state(target, "scale")
	var amt: float = clampf(squash_amount * intensity_mult, 0.0, 0.95)
	# Flatten: wider on x, shorter on y (reads as weight hitting the ground).
	var squashed := Vector2(original.x * (1.0 + amt), original.y * (1.0 - amt))
	# Rebound the other way (tall + thin) before settling, scaled by `bounce`.
	var rebound := Vector2(original.x * (1.0 - amt * 0.3 * bounce), original.y * (1.0 + amt * 0.5 * bounce))

	var tween := _track(target.create_tween())
	tween.tween_property(target, "scale", squashed, duration * 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if bounce > 0.0:
		tween.tween_property(target, "scale", rebound, duration * 0.4)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(target, "scale", original, duration * 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	else:
		tween.tween_property(target, "scale", original, duration * 0.75)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	_release_state(target, "scale")
