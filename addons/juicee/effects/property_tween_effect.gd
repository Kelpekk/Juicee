## Generic property animation — tween any property on the context (or a child).
## Killer feature: lets users add custom juicee without writing new effect classes.
##
## Example: tween `light_energy` on a Light2D from 0.0 → 3.0 → 0.0
@tool
class_name JuiceePropertyTweenEffect
extends JuiceeEffect

## Path to the node holding the property. "." means the context itself.
@export var property_path: NodePath = ^"."
## Property name to animate. Supports sub-paths like "modulate:a", "position:y", "scale".
@export var property: String = ""
## Target value to tween toward (any type the property accepts: float, Vector2, Color, ...).
## Needs an initial value: Godot 4.3 and 4.4 reject a bare `@export var x: Variant`
## because they can't infer a type from it, and the whole effect fails to parse.
@export var to_value: Variant = null
## How long the animation takes.
@export_range(0.05, 10.0, 0.05) var duration: float = 0.5
## If true, tweens back to the original value after reaching target.
@export var return_to_original: bool = true
@export var trans_type: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

func get_category_color() -> Color:
	return Color(0.95, 0.85, 0.20)

func _apply(context: Node, _intensity_mult: float) -> void:
	if property.is_empty():
		push_warning("JuiceePropertyTweenEffect: property name is empty")
		return
	var target: Object = context
	if not property_path.is_empty() and property_path != NodePath("."):
		target = context.get_node_or_null(property_path)
	if not target:
		push_warning("JuiceePropertyTweenEffect: target not found at '%s'" % property_path)
		return

	var original: Variant = target.get_indexed(property)
	if original == null:
		push_warning("JuiceePropertyTweenEffect: property '%s' not found" % property)
		return

	var tween: Tween = _track((context as Node).create_tween()) if context is Node else null
	if not tween:
		return

	if return_to_original:
		tween.tween_property(target, property, to_value, duration * 0.5)\
			.set_trans(trans_type).set_ease(ease_type)
		tween.tween_property(target, property, original, duration * 0.5)\
			.set_trans(trans_type).set_ease(ease_type)
	else:
		tween.tween_property(target, property, to_value, duration)\
			.set_trans(trans_type).set_ease(ease_type)

	await tween.finished
	if is_instance_valid(target) and return_to_original:
		target.set_indexed(property, original)
