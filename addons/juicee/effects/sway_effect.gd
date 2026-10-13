## Gentle continuous rotation sway - a pendulum-like rock back and forth, driven by a
## smooth sine wave. Unlike [JuiceeWiggleEffect] (random position jitter) or
## [JuiceeSpinEffect] (a full revolution), this is a soft, looping tilt.
##
## Great for idle "alive" UI, hanging signs, floating pickups, swinging lanterns,
## or a title that subtly breathes. Set [member cycles] to 0 to sway forever
## (until [method JuiceeEffect.stop]).
@tool
class_name JuiceeSwayEffect
extends JuiceeEffect

## Peak sway angle to each side, in degrees.
@export_range(0.5, 90.0, 0.5) var angle: float = 6.0
## Seconds for one full swing, left to right and back again.
@export_range(0.1, 10.0, 0.05) var period: float = 1.2
## Number of full cycles to run. 0 = sway forever (until stop()).
@export_range(0.0, 100.0, 0.5) var cycles: float = 2.0
## For Control targets, rotate around the centre instead of the top-left corner.
@export var center_pivot: bool = true

@export_group("Advanced")
## Hinge offset (pixels) to swing around like a pendulum. (0,0) tilts in place; (0,-40)
## hangs and swings from a point above, e.g. a hanging sign or lantern.
@export var pivot: Vector2 = Vector2.ZERO
## A resting lean (degrees) that the sway rocks around, instead of straight up.
@export_range(-45.0, 45.0, 1.0) var lean_degrees: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["pivot", "lean_degrees"]))

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Smooth pendulum rotation sway (sine). cycles=0 loops forever - idle 'alive' UI, hanging signs, swinging lanterns, breathing titles."

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	if not (context is Node2D or context is Control):
		_warn("JuiceeSwayEffect: context must be a Node2D or Control")
		return

	# Control nodes rotate around their top-left by default; pivot to centre so the
	# sway reads as a tilt rather than a swing from the corner.
	# Held on the state stack, so the node's own pivot comes back when the sway ends.
	var pivoted := center_pivot and context is Control and (context as Control).size != Vector2.ZERO
	if pivoted:
		var c := context as Control
		_capture_state(c, "pivot_offset")
		c.pivot_offset = c.size * 0.5

	var base: float = _capture_offset(context, "rotation")
	var use_pivot := pivot != Vector2.ZERO
	var orig_pos: Vector2 = _capture_offset(context, "position") if use_pivot else Vector2.ZERO
	var lean: float = deg_to_rad(lean_degrees)
	var amp: float = deg_to_rad(angle) * intensity_mult
	var tree: SceneTree = context.get_tree()
	# A period of 0 divides by zero below.
	var per: float = maxf(period, 0.001)
	var total: float = cycles * per      # 0 -> infinite
	var elapsed: float = 0.0

	while is_instance_valid(context) and _gen == play:
		if total > 0.0 and elapsed >= total:
			break
		var swing: float = lean + sin(elapsed / per * TAU) * amp
		var reach: float = absf(lean) + absf(amp)
		_write_offset(context, "rotation", base, swing, reach)
		# Pivot (advanced): orbit the origin around the hinge so it swings from a point.
		if use_pivot:
			_write_offset(context, "position", orig_pos, pivot - pivot.rotated(swing),
					pivot.length() * reach)
		await tree.process_frame
		if _gen != play:
			return
		elapsed += tree.root.get_process_delta_time()

	# A newer play or stop() holds what this one held.
	if _gen != play:
		return
	_release_state(context, "rotation")
	if use_pivot:
		_release_state(context, "position")
	if pivoted:
		_release_state(context, "pivot_offset")
