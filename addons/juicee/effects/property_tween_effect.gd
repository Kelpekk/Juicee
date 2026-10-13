## Generic property animation - tween any property on the context (or a child).
## Killer feature: lets users add custom juicee without writing new effect classes.
##
## Example: tween `light_energy` on a Light2D from 0.0 -> 3.0 -> 0.0
@tool
class_name JuiceePropertyTweenEffect
extends JuiceeEffect

## Path to the node holding the property. "." means the context itself.
@export var property_path: NodePath = ^"."
## Property name to animate. Supports sub-paths like "modulate:a", "position:y", "scale".
@export var property: String = ""
# Needs an initial value: Godot 4.3 and 4.4 reject a bare `@export var x: Variant`
# because they can't infer a type from it, and the whole effect fails to parse.
## Target value to tween toward (any type the property accepts: float, Vector2, Color, ...).
@export var to_value: Variant = null
## How long the animation takes.
@export_range(0.05, 10.0, 0.05) var duration: float = 0.5
## If true, tweens back to the original value after reaching target.
@export var return_to_original: bool = true
## Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest.
@export var trans_type: Tween.TransitionType = Tween.TRANS_SINE
## Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends.
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing Transition/Ease for the tween. FEEL-style.
@export var ease_curve: Curve
## Seconds to hold at the target value before returning. 0 = come straight back.
@export_range(0.0, 30.0, 0.05) var hold_time: float = 0.0
## Bounce between the original and target this many times across the duration, instead
## of a single there-and-back. A quick way to build a throb out of any property.
@export_range(1, 20, 1) var oscillations: int = 1

func _validate_property(property_info: Dictionary) -> void:
	_gate_advanced(property_info, PackedStringArray(["ease_curve", "hold_time", "oscillations"]))

func _apply(context: Node, _intensity_mult: float) -> void:
	if property.is_empty():
		_warn("JuiceePropertyTweenEffect: property name is empty")
		return
	var target: Object = context
	if not property_path.is_empty() and property_path != NodePath("."):
		target = context.get_node_or_null(property_path)
	if not target:
		_warn("JuiceePropertyTweenEffect: target not found at '%s'" % property_path)
		return

	var wanted := property.split(":")[0]
	if target is Node and not (wanted in target):
		var holder := _nearest_node(target as Node, func(n: Node) -> bool: return wanted in n)
		if holder:
			target = holder

	var current: Variant = target.get_indexed(property)
	if current == null:
		_warn("JuiceePropertyTweenEffect: property '%s' not found" % property)
		return
	# A tween refuses to blend a Vector2 into a float, with an error every frame; whole numbers
	# and fractions blend fine.
	var numbers := [TYPE_INT, TYPE_FLOAT]
	if typeof(current) != typeof(to_value) and not (typeof(current) in numbers and typeof(to_value) in numbers):
		_warn("JuiceePropertyTweenEffect: '%s' is %s and To Value is %s, which cannot be blended"
				% [property, type_string(typeof(current)), type_string(typeof(to_value))])
		return
	var play := _gen
	# The value to come back to, from the stack: stop() mid-tween and a second play started on
	# this one both come back to it, not to wherever this play had got to.
	var original: Variant = _capture_state(target, property)

	var tween: Tween = _track((context as Node).create_tween()) if context is Node else null
	if not tween:
		return

	if return_to_original:
		# Advanced oscillations turn one there-and-back into a throb of N cycles.
		var cycles: int = _capped(maxi(1, oscillations), 1000, "oscillations")
		var half: float = duration * 0.5 / float(cycles)
		for i in cycles:
			if ease_curve:
				_tween_curved(tween, target, property, original, to_value, half, ease_curve)
			else:
				tween.tween_property(target, property, to_value, half).set_trans(trans_type).set_ease(ease_type)
			if i == cycles - 1 and hold_time > 0.0:
				tween.tween_interval(hold_time)
			tween.tween_property(target, property, original, half).set_trans(trans_type).set_ease(ease_type)
	else:
		tween.tween_property(target, property, to_value, duration)\
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	if _gen != play:
		return
	# Back to the original, or left where the tween took it, which the stack then forgets.
	_release_state(target, property, return_to_original)
