## Afterimage / ghost trail: fading sprite copies left behind as the node moves.
@tool
class_name JuiceeAfterimageEffect
extends JuiceeEffect

## Shared pool so a dense trail reuses ghost sprites instead of new + free each frame.
static var _pool := JuiceeNodePool.new()

static func _new_ghost() -> Node:
	var ghost := Sprite2D.new()
	ghost.name = StringName("_juicee_ghost_%d" % randi())
	return ghost

## How long to keep dropping ghosts (match it to your dash / dodge length).
@export_range(0.05, 3.0, 0.05) var duration: float = 0.3
## Seconds between ghosts. Smaller = a denser trail.
@export_range(0.01, 0.5, 0.01) var interval: float = 0.04
## How long each ghost takes to fade out.
@export_range(0.05, 2.0, 0.05) var ghost_lifetime: float = 0.35
## Ghost tint (multiplies the sprite). The alpha sets the starting opacity.
@export var color: Color = Color(0.6, 0.9, 1.0, 0.6)

@export_group("Advanced")
## Each ghost shrinks (or grows) to this fraction of the sprite over its life. 1 = it
## holds the original size.
@export_range(0.2, 2.0, 0.05) var ghost_end_scale: float = 1.0
## Degrees each ghost rotates as it fades, so a dash trail spirals slightly.
@export_range(-180.0, 180.0, 5.0) var ghost_spin: float = 0.0
## Colour each ghost fades toward before vanishing. Leave alpha 0 for a plain fade; set
## a hot tint for an energy trail that cools as it dissipates.
@export var fade_to: Color = Color(1.0, 1.0, 1.0, 0.0)

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ghost_end_scale", "ghost_spin", "fade_to"]))

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Fading sprite copies left behind as the node moves.\nDashes, dodges, speed power-ups. Needs a Sprite2D or AnimatedSprite2D."

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var node: Node2D = context as Node2D
	if not node or not node.is_inside_tree():
		_warn("JuiceeAfterimageEffect: context is not a Node2D")
		return
	# The context is usually the character rather than the sprite inside it, and the
	# sprite is an AnimatedSprite2D as often as not.
	var sprite: Node2D = _find_sprite_node(node)
	if not sprite:
		_warn("JuiceeAfterimageEffect: no Sprite2D or AnimatedSprite2D on %s"
				% _target_label(node))
		return

	var tree := sprite.get_tree()
	# Shared, so this also lands correctly when the target is inside a SubViewport rather
	# than under the running scene. Its own copy of the lookup did not.
	var spawn_parent: Node = _spawn_parent(sprite)
	if not spawn_parent:
		return

	var elapsed := 0.0
	var step: float = max(0.01, interval)
	while elapsed < duration and is_instance_valid(sprite) and _gen == play:
		_spawn_ghost(sprite, spawn_parent, intensity_mult)
		elapsed += await _wait_step(tree, step)

## Drops one ghost copying the sprite's current look + world transform, then fades it
## out on its own tween and parks it back in the pool. Each ghost is independent, so
## stopping the dash mid-flight still lets the trail already on screen fade naturally.
func _spawn_ghost(sprite: Node2D, parent: Node, strength: float = 1.0) -> void:
	var ghost: Sprite2D = _pool.acquire(_new_ghost)
	if not _copy_sprite_look(sprite, ghost):
		# Nothing to photograph this frame (an empty animation, a frame past the end).
		# Park the ghost rather than leaving it out of the pool for good.
		_pool.release(ghost)
		return
	ghost.modulate = Color(color.r, color.g, color.b, clampf(color.a * strength, 0.0, 1.0))
	_add_behind(ghost, parent, sprite)
	# World transform AFTER parenting: setting global_* before add_child treats them
	# as local, which doubles the offset when the parent isn't at the world origin.
	ghost.global_position = sprite.global_position
	ghost.global_rotation = sprite.global_rotation
	ghost.global_scale = sprite.global_scale

	# Ghost-owned (untracked) tween so each fades independently of the effect.
	var tw := ghost.create_tween().set_parallel(true)
	# fade_to (advanced) lets a ghost cool toward a tint instead of a plain alpha fade.
	if fade_to != Color(1.0, 1.0, 1.0, 0.0):
		tw.tween_property(ghost, "modulate", fade_to, ghost_lifetime)
	else:
		tw.tween_property(ghost, "modulate:a", 0.0, ghost_lifetime)
	if not is_equal_approx(ghost_end_scale, 1.0):
		tw.tween_property(ghost, "scale", ghost.scale * ghost_end_scale, ghost_lifetime)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if ghost_spin != 0.0:
		tw.tween_property(ghost, "rotation", ghost.rotation + deg_to_rad(ghost_spin), ghost_lifetime)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		if is_instance_valid(ghost):
			_pool.release(ghost), CONNECT_ONE_SHOT)
