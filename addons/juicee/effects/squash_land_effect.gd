## Landing squash: flatten the node on impact, then spring it back with overshoot.
@tool
class_name JuiceeSquashLandEffect
extends JuiceeEffect

enum FlattenAxis { VERTICAL, HORIZONTAL }

## Squash strength at the moment of impact. 0.4 = about 140% wide / 60% tall at the peak.
@export_range(0.05, 0.9, 0.05) var squash_amount: float = 0.4
## Total time for the squash plus the recovery.
@export_range(0.05, 2.0, 0.05) var duration: float = 0.35
## Spring overshoot on the way back: the node stretches tall past its size before it
## settles. 0 = ease straight back with no rebound.
@export_range(0.0, 1.0, 0.05) var bounce: float = 0.5

@export_group("Advanced")
## Which way it flattens: VERTICAL (a floor landing, wide + short) or HORIZONTAL (a wall
## slam, tall + thin).
@export var flatten_axis: FlattenAxis = FlattenAxis.VERTICAL

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["flatten_axis"]))

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Landing squash: flatten on impact, spring back.\nPlatformer landings, stomps, jelly hops."

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		_warn("JuiceeSquashLandEffect: context is not a Node2D")
		return

	var original: Vector2 = _capture_state(target, "scale")
	var amt: float = clampf(squash_amount * intensity_mult, 0.0, 0.95)
	# Flatten along the chosen axis: VERTICAL widens x / shortens y (weight hitting the
	# ground); HORIZONTAL does the reverse (a body slamming into a wall).
	var squashed: Vector2
	var rebound: Vector2
	if flatten_axis == FlattenAxis.HORIZONTAL:
		squashed = Vector2(original.x * (1.0 - amt), original.y * (1.0 + amt))
		rebound = Vector2(original.x * (1.0 + amt * 0.5 * bounce), original.y * (1.0 - amt * 0.3 * bounce))
	else:
		squashed = Vector2(original.x * (1.0 + amt), original.y * (1.0 - amt))
		rebound = Vector2(original.x * (1.0 - amt * 0.3 * bounce), original.y * (1.0 + amt * 0.5 * bounce))

	var tween := _track(target.create_tween())
	tween.tween_property(target, "scale", squashed, duration * 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Hold the flattened pose for a couple of frames. The squash is the whole point of the
	# effect and it was over before the eye could catch it.
	tween.tween_interval(duration * 0.12)
	if bounce > 0.0:
		tween.tween_property(target, "scale", rebound, duration * 0.4)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(target, "scale", original, duration * 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	else:
		tween.tween_property(target, "scale", original, duration * 0.75)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if _gen != play:
		return
	_release_state(target, "scale")
