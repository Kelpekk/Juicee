## Instantly set any property on any node, then optionally restore after a delay.
##
## The direct-assignment version of PropertyTweenEffect - no animation, just set.
## Equivalent to FEEL's MMF_SetActive generalized to any property.
##
## Use for: toggle a bool flag mid-sequence, snap a node to a position,
## enable/disable a collision layer, change a label text, set a flag variable.
@tool
class_name JuiceeSetPropertyEffect
extends JuiceeEffect

## Node to modify. Empty = context node.
@export var target_path: NodePath = NodePath()
## Property name (supports sub-paths: "position:x", "material:albedo_color").
@export var property_name: String = ""
## Value to set.
@export var value: Variant = true
## Restore the original value after restore_delay seconds (0 = restore immediately after setting, -1 = never restore).
@export_range(-1.0, 30.0, 0.1) var restore_delay: float = -1.0

func get_category_name() -> String: return "Flow"

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if property_name.is_empty():
		push_warning("JuiceeSetPropertyEffect: property_name is empty")
		return

	var target: Node = context
	if not target_path.is_empty():
		target = context.get_node_or_null(target_path)
	if not is_instance_valid(target):
		push_warning("JuiceeSetPropertyEffect: target not found")
		return

	var original: Variant = null
	if restore_delay >= 0.0:
		original = target.get_indexed(property_name)

	target.set_indexed(property_name, value)

	if restore_delay < 0.0:
		return

	if restore_delay > 0.0:
		await context.get_tree().create_timer(restore_delay, true, false, false).timeout
		if _cancelled:
			return

	if is_instance_valid(target):
		target.set_indexed(property_name, original)
