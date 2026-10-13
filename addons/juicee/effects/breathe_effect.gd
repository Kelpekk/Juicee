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

enum BreatheAxis { BOTH, HORIZONTAL, VERTICAL }

@export_group("Advanced")
## Which axis expands on the in-breath: BOTH (uniform), HORIZONTAL, or VERTICAL only.
@export var axis: BreatheAxis = BreatheAxis.BOTH
## Also rise this many pixels on the in-breath, for a gentle float-with-breath. 0 = none.
@export_range(0.0, 60.0, 1.0) var bob_pixels: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["axis", "bob_pixels"]))

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "A slow gentle scale in-and-out idle loop.\nLiving characters, pickups, breathing menus. cycles = 0 loops forever."

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		_warn("JuiceeBreatheEffect: context is not a Node2D")
		return

	var play := _gen
	var original: Vector2 = _capture_offset(target, "scale")
	var bobbing := bob_pixels > 0.0
	var orig_pos: Vector2 = _capture_offset(target, "position") if bobbing else Vector2.ZERO
	var amt: float = amount * intensity_mult
	var elapsed := 0.0
	var step := 1.0 / 60.0
	var tree := target.get_tree()
	# A period of 0 divides by zero below.
	var per := maxf(period, 0.001)
	var total: float = (per * cycles) if cycles > 0 else INF
	while elapsed < total and is_instance_valid(target) and _gen == play:
		# sin starting at 0 so it eases out from the resting scale, no pop on start.
		var k: float = (1.0 - cos(elapsed / per * TAU)) * 0.5
		var grow := original * amt * k
		match axis:
			BreatheAxis.HORIZONTAL:
				grow.y = 0.0
			BreatheAxis.VERTICAL:
				grow.x = 0.0
		_write_offset(target, "scale", original, grow, original.length() * absf(amt))
		if bobbing:
			_write_offset(target, "position", orig_pos, Vector2(0.0, -_px(bob_pixels) * k),
					_px(bob_pixels))
		elapsed += await _wait_step(tree, step)
	# A newer play or stop() holds these now.
	if _gen != play:
		return
	_release_state(target, "scale")
	if bobbing:
		_release_state(target, "position")
