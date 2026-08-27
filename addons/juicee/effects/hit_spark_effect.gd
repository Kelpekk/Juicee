## Directional spark spray off a hit point, aimed by the "hit_direction" param.
## A tight, fast cone (vs JuiceeBurstEffect's soft omni-directional puff).
@tool
class_name JuiceeHitSparkEffect
extends JuiceeEffect

## Shared pool so repeated hits reuse the particle node instead of new + free each.
static var _pool := JuiceeNodePool.new()

static func _new_particles() -> Node:
	return CPUParticles2D.new()

## How many sparks fly.
@export_range(1, 64, 1) var amount: int = 10
## Spark speed (actual is randomized around this).
@export_range(50.0, 1200.0, 10.0) var speed: float = 420.0
## Cone width in degrees around the hit direction. Small = a tight, focused spray.
@export_range(2.0, 90.0, 1.0) var cone: float = 24.0
## How long each spark lives.
@export_range(0.05, 1.0, 0.05) var lifetime: float = 0.25
## Spark color.
@export var color: Color = Color(1.0, 0.95, 0.6, 1.0)
## Aim used when the caller doesn't pass {"hit_direction": ...}. Sparks fly this way.
@export var default_direction: Vector2 = Vector2.RIGHT
## Gravity pulling the sparks down as they fly (0 = straight cone).
@export var gravity: Vector2 = Vector2(0, 600)
## Visual size of each spark.
@export_range(0.3, 8.0, 0.1) var spark_scale: float = 1.4

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Directional spark spray off a hit point.\nClangs, parries, ricochets. Aim with hit_direction."

func _apply(context: Node, intensity_mult: float) -> void:
	var origin: Node2D = context as Node2D
	if not origin or not origin.is_inside_tree():
		push_warning("JuiceeHitSparkEffect: context is not a Node2D")
		return

	var dir: Vector2 = _runtime_params.get("hit_direction", default_direction)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	var p: CPUParticles2D = _pool.acquire(_new_particles)
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = max(1, int(amount * intensity_mult * accessibility.density_scale()))
	p.lifetime = lifetime
	p.direction = dir
	p.spread = cone
	p.initial_velocity_min = speed * intensity_mult * 0.6
	p.initial_velocity_max = speed * intensity_mult * 1.2
	p.gravity = gravity
	p.color = color
	# Fade each spark out over its life so the spray dissolves instead of popping off.
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	# Reuse the burst effect's soft round dot so there's one shared particle texture.
	p.texture = JuiceeBurstEffect._soft_dot()
	p.scale_amount_min = spark_scale * 0.5
	p.scale_amount_max = spark_scale * 1.2
	# current_scene is null in autoload / added-to-root contexts, fall back to origin.
	var spawn_parent: Node = origin.get_tree().current_scene
	if not spawn_parent:
		spawn_parent = origin
	spawn_parent.add_child(p)
	# World position AFTER parenting: setting global_position before add_child treats
	# it as local, which doubles the offset when the parent isn't at the world origin.
	p.global_position = origin.global_position
	# restart() (not emitting = true) so a reused one-shot node emits again.
	p.restart()
	await origin.get_tree().create_timer(lifetime + 0.1, true, false, false).timeout
	# Park the node for the next hit to reuse.
	if is_instance_valid(p):
		p.emitting = false
		_pool.release(p)
