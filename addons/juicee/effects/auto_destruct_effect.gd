## Queue-free the context node (or a target) after an optional delay.
##
## Essential for cleaning up temporary VFX objects at the end of a death or
## spawn sequence. Pairs naturally with InstantiateEffect.
##
## Use for: despawn a hit-spark scene after its animation, remove a floating
## text node after it fades out, clean up a temporary projectile, enemy corpse
## cleanup after a death sequence finishes.
@tool
class_name JuiceeAutoDestructEffect
extends JuiceeEffect

## Node to free. Empty = context node itself.
@export var target_path: NodePath = NodePath()
## Seconds to wait before freeing. 0 = queue_free immediately (next frame).
@export_range(0.0, 30.0, 0.1) var destruct_delay: float = 0.0
## Free the PARENT of the resolved target instead of the target itself.
## Useful when the context is a child (e.g., sprite) but you want to free the root.
@export var free_parent: bool = false

func get_category_name() -> String: return "Flow"
func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_NONE

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return

	if destruct_delay > 0.0:
		await context.get_tree().create_timer(destruct_delay, true, false, false).timeout
		if _cancelled:
			return

	var target: Node = context
	if not target_path.is_empty():
		target = context.get_node_or_null(target_path)

	if not is_instance_valid(target):
		return

	var to_free: Node = target.get_parent() if free_parent else target
	if is_instance_valid(to_free):
		to_free.queue_free()
