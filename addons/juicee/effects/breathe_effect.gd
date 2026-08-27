## Breathe: a slow, gentle scale in-and-out loop, the subtle "alive" idle of a
## character, a pickup, or a menu element. Set cycles = 0 to breathe forever (until stop()).
@tool
class_name JuiceeBreatheEffect
extends JuiceeEffect

## How much it grows on the in-breath (0.05 = 5% bigger at the peak).
@export_range(0.01, 0.4, 0.01) var amount: float = 0.05
## Seconds per breath.
@export_range(0.3, 8.0, 0.1) var period: float = 2.0
## Number of breaths. 0 = forever.
@export_range(0, 30, 1) var cycles: int = 3

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "A slow gentle scale in-and-out idle loop.\nLiving characters, pickups, breathing menus. cycles = 0 loops forever."

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		push_warning("JuiceeBreatheEffect: context is not a Node2D")
		return

	var original: Vector2 = _capture_state(target, "scale")
	var amt: float = amount * intensity_mult
	var elapsed := 0.0
	var step := 1.0 / 60.0
	var tree := target.get_tree()
	var total: float = (period * cycles) if cycles > 0 else INF
	while elapsed < total and is_instance_valid(target) and not _cancelled:
		# sin starting at 0 so it eases out from the resting scale, no pop on start.
		var k: float = (1.0 - cos(elapsed / period * TAU)) * 0.5
		target.scale = original * (1.0 + amt * k)
		await tree.create_timer(step, true, false, false).timeout
		elapsed += step
	_release_state(target, "scale")
