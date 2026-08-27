## Jelly wobble: a springy squash-and-stretch scale oscillation that decays, the gel
## bounce of a slime, a bouncy UI element, or a landing jiggle.
@tool
class_name JuiceeJellyWobbleEffect
extends JuiceeEffect

## Peak scale deviation at the start (0.25 = wobbles between ~75% and ~125%).
@export_range(0.05, 0.8, 0.01) var amount: float = 0.25
## Wobbles per second.
@export_range(0.2, 8.0, 0.1) var frequency: float = 4.0
## Total wobble time.
@export_range(0.1, 3.0, 0.05) var duration: float = 0.6
## How fast the wobble dies down. 0 = constant, higher = settles sooner.
@export_range(0.0, 8.0, 0.1) var decay: float = 3.0

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Springy squash-stretch scale wobble that decays.\nSlimes, jelly, bouncy UI, landing jiggle."

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		push_warning("JuiceeJellyWobbleEffect: context is not a Node2D")
		return

	var original: Vector2 = _capture_state(target, "scale")
	var amt: float = amount * intensity_mult
	var elapsed := 0.0
	var step := 1.0 / 60.0
	var tree := target.get_tree()
	while elapsed < duration and is_instance_valid(target) and not _cancelled:
		var envelope: float = exp(-decay * elapsed) * amt
		var s: float = sin(elapsed * frequency * TAU) * envelope
		# Squash one axis, stretch the other (reads as volume-preserving jelly).
		target.scale = Vector2(original.x * (1.0 + s), original.y * (1.0 - s))
		await tree.create_timer(step, true, false, false).timeout
		elapsed += step
	_release_state(target, "scale")
