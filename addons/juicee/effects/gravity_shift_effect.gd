## Gravity Shift: temporarily scale a RigidBody2D's gravity then ease it back. Float and
## levitate moments, low-gravity zones, heavy slam-downs. 0 = weightless, <0 = pulls upward.
@tool
class_name JuiceeGravityShiftEffect
extends JuiceeEffect

## Path to the RigidBody2D. Empty = the context itself must be a RigidBody2D.
@export var target: NodePath
## Gravity multiplier during the effect. 0 = weightless, <1 = light, >1 = heavy, <0 = upward.
@export_range(-4.0, 8.0, 0.1) var gravity_scale: float = 0.0
## How long the shifted gravity holds at full strength.
@export_range(0.05, 10.0, 0.05) var duration: float = 1.0
## Seconds to ease into and out of the shifted gravity.
@export_range(0.0, 2.0, 0.05) var blend_time: float = 0.15

@export_group("Advanced")
## Hand-drawn curve (0..1) shaping the ease into the shifted gravity. FEEL-style.
@export var ease_curve: Curve
## Also damp the body's velocity while gravity is shifted (0 = untouched, 1 = heavily
## damped), so a float feels weightless rather than coasting.
@export_range(0.0, 1.0, 0.05) var velocity_damp: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "velocity_damp"]))

func get_category_name() -> String:
	return "Physics"

func get_description() -> String:
	return "Temporarily scale a RigidBody2D's gravity, then restore it.\nFloat / levitate moments, low-grav zones, heavy slam-downs."

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var resolved: Node = context.get_node_or_null(target) if not target.is_empty() else context
	var body: RigidBody2D = resolved as RigidBody2D
	if not body or not body.is_inside_tree():
		_warn("JuiceeGravityShiftEffect: target is not a RigidBody2D")
		return

	var original: float = _capture_state(body, "gravity_scale")
	var shifted: float = lerpf(original, gravity_scale, intensity_mult)
	var tween := _track(body.create_tween())
	# ease_curve (advanced) shapes the blend into the shifted gravity.
	if ease_curve:
		_tween_curved(tween, body, "gravity_scale", original, shifted, blend_time, ease_curve)
	else:
		tween.tween_property(body, "gravity_scale", shifted, blend_time)
	# Advanced: bleed off existing velocity so a float reads as weightless, not coasting.
	if velocity_damp > 0.0:
		var orig_damp: float = _capture_state(body, "linear_damp")
		tween.parallel().tween_property(body, "linear_damp", orig_damp + velocity_damp * 12.0, blend_time)
		tween.tween_interval(duration)
		tween.tween_property(body, "linear_damp", orig_damp, blend_time)
		tween.parallel().tween_property(body, "gravity_scale", original, blend_time)
		await tween.finished
		if _gen != play:
			return
		_release_state(body, "linear_damp")
		_release_state(body, "gravity_scale")
		return
	tween.tween_interval(duration)
	tween.tween_property(body, "gravity_scale", original, blend_time)
	await tween.finished
	if _gen != play:
		return
	_release_state(body, "gravity_scale")
