## Stretch / smear: briefly stretches the node along the "hit_direction" axis (thinning
## the other) then snaps back, the motion-smear of a fast dash, jump, or thrown object.
@tool
class_name JuiceeStretchEffect
extends JuiceeEffect

## How much it stretches (0.5 = 150% along the motion axis, ~70% across it).
@export_range(0.05, 1.5, 0.05) var amount: float = 0.5
## Time spent stretching out.
@export_range(0.02, 1.0, 0.01) var stretch_time: float = 0.08
## Time spent snapping back.
@export_range(0.02, 1.0, 0.01) var return_time: float = 0.2
## Axis used when no {"hit_direction": ...} is passed.
@export var default_direction: Vector2 = Vector2.RIGHT

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Stretch the node along its motion then snap back.\nDashes, jumps, thrown objects. Aim with hit_direction."

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		push_warning("JuiceeStretchEffect: context is not a Node2D")
		return

	var dir: Vector2 = _runtime_params.get("hit_direction", default_direction)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var amt: float = amount * intensity_mult
	var original: Vector2 = _capture_state(target, "scale")
	# Stretch the dominant axis of the direction, thin the other (volume-ish).
	var stretched: Vector2
	if absf(dir.x) >= absf(dir.y):
		stretched = Vector2(original.x * (1.0 + amt), original.y / (1.0 + amt * 0.6))
	else:
		stretched = Vector2(original.x / (1.0 + amt * 0.6), original.y * (1.0 + amt))

	var tween := _track(target.create_tween())
	tween.tween_property(target, "scale", stretched, stretch_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", original, return_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	_release_state(target, "scale")
