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

@export_group("Advanced")
## Fade the node out over this many seconds just before it is freed, so it dissolves
## instead of vanishing. 0 = it disappears instantly.
@export_range(0.0, 5.0, 0.05) var fade_out_time: float = 0.0
## Also shrink the node to nothing during that fade.
@export var shrink_out: bool = false
## Detach the node from its parent the moment the timer starts, so a dying object stops
## following its spawner while it plays out.
@export var detach_first: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["fade_out_time", "shrink_out", "detach_first"]))

func get_category_name() -> String: return "Flow"
func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_NONE

func _apply(context: Node, _intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return

	# Advanced detach_first: a dying object should stop following its spawner while
	# it plays out, so reparent it to the scene root before the timer runs.
	if detach_first and context.get_parent():
		var keep_pos: Variant = context.get("global_position") if "global_position" in context else null
		var scene_root: Node = context.get_tree().current_scene
		if scene_root and scene_root != context:
			context.get_parent().remove_child(context)
			scene_root.add_child(context)
			if keep_pos != null:
				context.set("global_position", keep_pos)

	if destruct_delay > 0.0:
		await context.get_tree().create_timer(destruct_delay, true, false, false).timeout
		if _gen != play:
			return

	var target: Node = context
	if not target_path.is_empty():
		target = context.get_node_or_null(target_path)

	if not is_instance_valid(target):
		return

	var to_free: Node = target.get_parent() if free_parent else target
	if not is_instance_valid(to_free):
		return
	# The tree's root is the game window and its other children are the autoloads, so freeing one
	# ends the game. A path or free_parent one level too high is the only way to get here.
	var tree := to_free.get_tree()
	if tree and (to_free == tree.root or (to_free.get_parent() == tree.root and to_free != tree.current_scene)):
		_warn("JuiceeAutoDestructEffect: '%s' is the game's window or an autoload, and freeing it would end the game, so it was left alone" % to_free.name)
		return

	# Advanced: dissolve out (fade, optionally shrinking) instead of blinking away.
	if fade_out_time > 0.0 and to_free is CanvasItem:
		var ci := to_free as CanvasItem
		var tw := ci.create_tween().set_parallel(true)
		tw.tween_property(ci, "modulate:a", 0.0, fade_out_time)
		if shrink_out and "scale" in ci:
			tw.tween_property(ci, "scale", Vector2.ZERO, fade_out_time)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		# Once the dissolve has begun, the node goes: stop() leaves this tween running, and a node
		# left faded out would be there for good with nothing on screen to show for it.
		await _tween_done(tw)
		if not is_instance_valid(to_free):
			return

	to_free.queue_free()
