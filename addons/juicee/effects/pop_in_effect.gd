## Scale from zero (or a small seed scale) to the node's current size with spring overshoot.
##
## Works on both Node2D and Control nodes.
## Use for: menu pop-in, item spawn appear, notification badge, collectible spawn,
## dialogue bubble, damage indicator, achievement unlock.
##
## Uses Godot's TRANS_SPRING easing which produces a natural overshoot + settle.
@tool
class_name JuiceePopInEffect
extends JuiceeEffect

## Scale the pop starts from (0 = invisible, 0.5 = half size). An absolute scale, not a fraction of the node's own.
@export_range(0.0, 0.99, 0.01) var from_scale: float = 0.0
## Total animation duration including spring settle.
@export_range(0.05, 2.0, 0.05) var duration: float = 0.35

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing the built-in spring for the scale-in.
@export var ease_curve: Curve
## Also fade the node in from transparent while it pops.
@export var fade_in: bool = false
## Slide in from this pixel offset while scaling (e.g. (0, -40) drops in from above).
@export var slide_from: Vector2 = Vector2.ZERO

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "fade_in", "slide_from"]))

func get_category_name() -> String: return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not (context is Node2D or context is Control):
		_warn("JuiceePopInEffect: context must be a Node2D or Control")
		return

	var play := _gen
	# The size to grow to comes from the stack, so a pop started while another is still growing
	# grows to the node's own size, not to the small one the first had reached, and a stop()
	# mid-way puts that size back.
	var original_scale: Vector2 = _capture_state(context, "scale")
	var seed_scale := Vector2(from_scale, from_scale) * intensity_mult

	# A Control scales from its top-left corner unless we pivot at its centre, so the
	# pop-in would stretch out of the corner instead of growing in place. Node2D scales
	# around its own origin and has no pivot_offset, so this is Control-only.
	var ctrl := context as Control
	if ctrl:
		_capture_state(ctrl, "pivot_offset")
		ctrl.pivot_offset = ctrl.size * 0.5

	var tween := _track(context.create_tween()).set_parallel(true)
	# ease_curve (advanced) overrides the built-in spring when set.
	if ease_curve:
		context.set("scale", seed_scale)
		_tween_curved(tween, context, "scale", seed_scale, original_scale, duration, ease_curve)
	else:
		tween.tween_property(context, "scale", original_scale, duration)\
			.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)\
			.from(seed_scale)
	# Advanced: fade in from transparent, and/or slide in from an offset, in parallel.
	if fade_in:
		var target_a: float = (_capture_state(context, "modulate") as Color).a
		context.set("modulate", Color(context.get("modulate"), 0.0))
		tween.tween_property(context, "modulate:a", target_a, duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if slide_from != Vector2.ZERO:
		var home: Vector2 = _capture_state(context, "position")
		context.set("position", home + slide_from * intensity_mult)
		tween.tween_property(context, "position", home, duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if _gen != play:
		return
	_release_state(context, "scale")
	if fade_in:
		_release_state(context, "modulate")
	if slide_from != Vector2.ZERO:
		_release_state(context, "position")
	if ctrl:
		_release_state(ctrl, "pivot_offset")
