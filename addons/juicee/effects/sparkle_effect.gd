## Sparkle / twinkle: a scatter of little star pops around the node.
@tool
class_name JuiceeSparkleEffect
extends JuiceeEffect

## Shared pool so a stream of pickups reuses the sparkle sprites instead of new + free.
static var _pool := JuiceeNodePool.new()

static func _new_sparkle() -> Node:
	return Sprite2D.new()

## How many sparkles scatter around the node.
@export_range(1, 24, 1) var count: int = 6
## Radius of the area the sparkles scatter over.
@export_range(4.0, 200.0, 1.0) var spread: float = 36.0
## Visual size of each sparkle.
@export_range(0.2, 8.0, 0.1) var sparkle_scale: float = 2.0
## Sparkle color.
@export var color: Color = Color(1.0, 1.0, 0.7, 1.0)
## Total time over which the sparkles appear and fade.
@export_range(0.1, 3.0, 0.05) var duration: float = 0.6

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "A scatter of little star pops around the node.\nPickups, collectibles, level-ups, UI shine."

func _apply(context: Node, intensity_mult: float) -> void:
	var origin: Node2D = context as Node2D
	if not origin or not origin.is_inside_tree():
		push_warning("JuiceeSparkleEffect: context is not a Node2D")
		return

	var n: int = max(1, int(count * accessibility.density_scale()))
	var base_pos := origin.global_position
	# current_scene is null in autoload / added-to-root contexts, fall back to origin.
	var spawn_parent: Node = origin.get_tree().current_scene
	if not spawn_parent:
		spawn_parent = origin
	for i in n:
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).limit_length(1.0) * spread * intensity_mult
		var delay := randf() * duration * 0.6
		_spawn_sparkle(origin, spawn_parent, base_pos + off, delay)

	# Hold until the sparkles have run; each one releases itself to the pool.
	await origin.get_tree().create_timer(duration, true, false, false).timeout

## Pops one sparkle in at `pos` (after `delay`), fades it, and parks it. Independent of
## the effect so re-triggering layers new sparkles instead of cancelling old ones.
func _spawn_sparkle(origin: Node2D, parent: Node, pos: Vector2, delay: float) -> void:
	var s: Sprite2D = _pool.acquire(_new_sparkle)
	# Reuse the burst effect's soft round dot so there's one shared particle texture.
	s.texture = JuiceeBurstEffect._soft_dot()
	s.modulate = color
	s.rotation = randf() * TAU
	s.scale = Vector2.ZERO
	s.z_index = origin.z_index + 1
	parent.add_child(s)
	# World position AFTER parenting, so a non-origin scene root doesn't double the offset.
	s.global_position = pos

	var life := 0.4
	var tw := s.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(s, "scale", Vector2.ONE * sparkle_scale, life * 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "scale", Vector2.ONE * sparkle_scale * 0.2, life * 0.65)\
		.set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(s, "modulate:a", 0.0, life * 0.65)
	tw.finished.connect(func() -> void:
		if is_instance_valid(s):
			_pool.release(s), CONNECT_ONE_SHOT)
