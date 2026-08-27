## Afterimage / ghost trail: fading Sprite2D copies left behind as the node moves.
@tool
class_name JuiceeAfterimageEffect
extends JuiceeEffect

## Shared pool so a dense trail reuses ghost sprites instead of new + free each frame.
static var _pool := JuiceeNodePool.new()

static func _new_ghost() -> Node:
	return Sprite2D.new()

## How long to keep dropping ghosts (match it to your dash / dodge length).
@export_range(0.05, 3.0, 0.05) var duration: float = 0.3
## Seconds between ghosts. Smaller = a denser trail.
@export_range(0.01, 0.5, 0.01) var interval: float = 0.04
## How long each ghost takes to fade out.
@export_range(0.05, 2.0, 0.05) var ghost_lifetime: float = 0.35
## Ghost tint (multiplies the sprite). The alpha sets the starting opacity.
@export var color: Color = Color(0.6, 0.9, 1.0, 0.6)

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Fading sprite copies left behind as the node moves.\nDashes, dodges, speed power-ups. Needs a Sprite2D."

func _apply(context: Node, intensity_mult: float) -> void:
	var sprite: Sprite2D = context as Sprite2D
	if not sprite or not sprite.is_inside_tree():
		push_warning("JuiceeAfterimageEffect: context is not a Sprite2D")
		return

	var tree := sprite.get_tree()
	# current_scene is null in autoload / added-to-root contexts, fall back to the
	# sprite's own parent so the ghosts sit in the same space as the original.
	var spawn_parent: Node = tree.current_scene
	if not spawn_parent:
		spawn_parent = sprite.get_parent()
	if not spawn_parent:
		return

	var elapsed := 0.0
	var step: float = max(0.01, interval)
	while elapsed < duration and is_instance_valid(sprite) and not _cancelled:
		_spawn_ghost(sprite, spawn_parent)
		await tree.create_timer(step, true, false, false).timeout
		elapsed += step

## Drops one ghost copying the sprite's current look + world transform, then fades it
## out on its own tween and parks it back in the pool. Each ghost is independent, so
## stopping the dash mid-flight still lets the trail already on screen fade naturally.
func _spawn_ghost(sprite: Sprite2D, parent: Node) -> void:
	var ghost: Sprite2D = _pool.acquire(_new_ghost)
	ghost.texture = sprite.texture
	ghost.hframes = sprite.hframes
	ghost.vframes = sprite.vframes
	ghost.frame = sprite.frame
	ghost.region_enabled = sprite.region_enabled
	ghost.region_rect = sprite.region_rect
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v
	ghost.z_index = sprite.z_index - 1  # sit just behind the original
	ghost.modulate = color
	parent.add_child(ghost)
	# World transform AFTER parenting: setting global_* before add_child treats them
	# as local, which doubles the offset when the parent isn't at the world origin.
	ghost.global_position = sprite.global_position
	ghost.global_rotation = sprite.global_rotation
	ghost.global_scale = sprite.global_scale

	# Ghost-owned (untracked) tween so each fades independently of the effect.
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, ghost_lifetime)
	tw.finished.connect(func() -> void:
		if is_instance_valid(ghost):
			_pool.release(ghost), CONNECT_ONE_SHOT)
