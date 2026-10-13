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

@export_group("Advanced")
## Hinge offset (pixels) to swing around, like a pendulum. (0,0) rotates in place;
## (0, -40) hangs and swings from a point above the node, e.g. a sign on a hook.
@export var pivot: Vector2 = Vector2.ZERO

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["pivot"]))

func get_accessibility_tag() -> int:
	return JuiceeAccessibility.TAG_SCREENSHAKE

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "A springy rotational rock that decays.\nStruck bells, head-tilts, hit reactions."

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		_warn("JuiceeWobbleRotationEffect: context is not a Node2D")
		return

	var play := _gen
	var original: float = _capture_offset(target, "rotation")
	var use_pivot := pivot != Vector2.ZERO
	var orig_pos: Vector2 = _capture_offset(target, "position") if use_pivot else Vector2.ZERO
	var amp: float = deg_to_rad(amount_degrees) * intensity_mult
	var elapsed := 0.0
	var step := 1.0 / 60.0
	var tree := target.get_tree()
	while elapsed < duration and is_instance_valid(target) and _gen == play:
		var swing: float = amp * exp(-maxf(decay, 0.0) * elapsed)
		var angle: float = swing * sin(elapsed * frequency * TAU)
		_write_offset(target, "rotation", original, angle, swing)
		# Pivot (advanced): orbit the origin around the hinge so it swings, not just spins.
		if use_pivot:
			_write_offset(target, "position", orig_pos, pivot - pivot.rotated(angle),
					pivot.length() * absf(swing))
		elapsed += await _wait_step(tree, step)
	# A newer play or stop() holds these now; releasing here would take them from it.
	if _gen != play:
		return
	_release_state(target, "rotation")
	if use_pivot:
		_release_state(target, "position")
