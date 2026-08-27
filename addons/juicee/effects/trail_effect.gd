@tool
class_name JuiceeTrailEffect
extends JuiceeEffect

## How long to keep spawning ghost copies.
@export_range(0.05, 10.0, 0.05) var duration: float = 1.0
## Time between ghost spawns. Lower = denser trail.
@export_range(0.01, 0.5, 0.01) var interval: float = 0.05
## Cap on simultaneous ghosts on screen (oldest get queued for deletion).
@export_range(1, 50, 1) var max_ghosts: int = 10
## Color/alpha applied to each ghost (semi-transparent by default).
@export var ghost_modulate: Color = Color(1.0, 1.0, 1.0, 0.4)
## If true, older ghosts get progressively more transparent.
@export var fade_ghosts: bool = true

func _apply(context: Node, _intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target:
		push_warning("JuiceeTrailEffect: context is not a Node2D")
		return
	var source := _find_sprite(target)
	if not source:
		push_warning("JuiceeTrailEffect: target has no Sprite2D")
		return

	var tree := target.get_tree()
	var scene_root: Node = _spawn_parent(target)
	var ghosts: Array[Sprite2D] = []
	var elapsed: float = 0.0

	while elapsed < duration and is_instance_valid(target) and is_instance_valid(source) and not _cancelled:
		var ghost := Sprite2D.new()
		ghost.texture = source.texture
		ghost.hframes = source.hframes
		ghost.vframes = source.vframes
		ghost.frame = source.frame
		ghost.flip_h = source.flip_h
		ghost.flip_v = source.flip_v
		ghost.modulate = ghost_modulate
		ghost.z_index = target.z_index - 1
		scene_root.add_child(ghost)
		# Match the source's WORLD transform AFTER parenting: setting global_* before
		# add_child treats them as local (no parent yet), which doubles the offset when
		# scene_root isn't at the world origin (the fallback parents under the target).
		ghost.global_position = source.global_position
		ghost.global_rotation = source.global_rotation
		ghost.global_scale = source.global_scale
		ghosts.append(ghost)

		if ghosts.size() > max_ghosts:
			var old := ghosts.pop_front()
			if is_instance_valid(old):
				old.queue_free()

		if fade_ghosts:
			for i in ghosts.size():
				if is_instance_valid(ghosts[i]):
					ghosts[i].modulate.a = ghost_modulate.a * (float(i + 1) / float(ghosts.size()))

		await tree.create_timer(interval, true, false, false).timeout
		elapsed += interval

	for g in ghosts:
		if is_instance_valid(g):
			g.queue_free()

func _find_sprite(node: Node2D) -> Sprite2D:
	if node is Sprite2D:
		return node as Sprite2D
	for child in node.get_children():
		if child is Node2D:
			var r := _find_sprite(child as Node2D)
			if r:
				return r
	return null
