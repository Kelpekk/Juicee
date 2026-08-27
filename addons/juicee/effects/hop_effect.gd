## Hop: a quick upward jump arc and back down, a happy little bounce for pickups,
## button presses, a coin, or an idle "notice me".
@tool
class_name JuiceeHopEffect
extends JuiceeEffect

## How high it hops, in pixels.
@export_range(2.0, 200.0, 1.0) var height: float = 24.0
## Total up + down time.
@export_range(0.1, 2.0, 0.05) var duration: float = 0.4

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "A quick upward jump arc and back down.\nPickups, coins, button presses, idle notice."

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		push_warning("JuiceeHopEffect: context is not a Node2D")
		return

	var original: Vector2 = _capture_state(target, "position")
	var top := original - Vector2(0, height * intensity_mult)

	var tween := _track(target.create_tween())
	# Up fast (decelerate), down a touch slower (accelerate) for a natural arc.
	tween.tween_property(target, "position", top, duration * 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "position", original, duration * 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	_release_state(target, "position")
