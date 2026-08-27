## Rotational wobble: a springy rock back and forth that decays, like a struck bell, a
## confused head-tilt, or a hit reaction. Unlike SwayEffect (a steady loop) this dies down.
@tool
class_name JuiceeWobbleRotationEffect
extends JuiceeEffect

## Peak tilt in degrees at the start.
@export_range(1.0, 90.0, 1.0) var amount_degrees: float = 18.0
## Wobbles per second.
@export_range(0.5, 12.0, 0.1) var frequency: float = 5.0
## Total time.
@export_range(0.1, 3.0, 0.05) var duration: float = 0.6
## How fast it settles. 0 = constant, higher = sooner.
@export_range(0.0, 10.0, 0.1) var decay: float = 4.0

func get_accessibility_tag() -> int:
	return JuiceeAccessibility.TAG_SCREENSHAKE

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "A springy rotational rock that decays.\nStruck bells, head-tilts, hit reactions."

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		push_warning("JuiceeWobbleRotationEffect: context is not a Node2D")
		return

	var original: float = _capture_state(target, "rotation")
	var amp: float = deg_to_rad(amount_degrees) * intensity_mult
	var elapsed := 0.0
	var step := 1.0 / 60.0
	var tree := target.get_tree()
	while elapsed < duration and is_instance_valid(target) and not _cancelled:
		var envelope: float = exp(-decay * elapsed)
		target.rotation = original + amp * envelope * sin(elapsed * frequency * TAU)
		await tree.create_timer(step, true, false, false).timeout
		elapsed += step
	_release_state(target, "rotation")
