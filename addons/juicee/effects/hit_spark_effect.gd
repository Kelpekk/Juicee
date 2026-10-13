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
## Half-width of the cone, in degrees either side of the hit direction. Small = a tight, focused spray.
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
@export_range(0.3, 8.0, 0.1) var spark_scale: float = 2.2

@export_group("Advanced")
## Shape of each spark: a STREAK facing the way it flies, a round DOT, a chunky SQUARE (debris),
## or a 4-point STAR (glinty).
@export var spark_shape: JuiceeBurstEffect.ParticleShape = JuiceeBurstEffect.ParticleShape.STREAK
## Colour each spark fades toward as it dies. Default transparent white (plain fade); set
## a warm tint (deep orange, alpha 0) for sparks that cool as they arc away.
@export var fade_to: Color = Color(1.0, 1.0, 1.0, 0.0)
## Air resistance. Sparks fly then slow instead of shooting straight. 0 = none.
@export_range(0.0, 200.0, 1.0) var air_drag: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["spark_shape", "fade_to", "air_drag"]))

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Directional spark spray off a hit point.\nClangs, parries, ricochets. Aim with hit_direction."

func _apply(context: Node, intensity_mult: float) -> void:
	var origin: Node2D = context as Node2D
	if not origin or not origin.is_inside_tree():
		_warn("JuiceeHitSparkEffect: context is not a Node2D")
		return

	var dir: Vector2 = _param("hit_direction", default_direction)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	var p: CPUParticles2D = _pool.acquire(_new_particles)
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = _capped(maxi(1, int(amount * intensity_mult * accessibility.density_scale())), 4096, "amount")
	# A particle node refuses a lifetime of 0 or less.
	p.lifetime = maxf(lifetime, 0.01)
	p.direction = dir
	p.spread = cone
	# A wide band, so ten sparks separate into a spray instead of travelling as one clump.
	p.initial_velocity_min = _px(speed) * intensity_mult * 0.45
	p.initial_velocity_max = _px(speed) * intensity_mult * 1.35
	p.gravity = gravity
	p.color = color
	# Fade each spark out over its life so the spray dissolves instead of popping off.
	# fade_to (advanced) lets the spark cool toward a tint instead of a plain fade.
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, fade_to)
	p.color_ramp = fade
	# Reuse the burst effect's shared crisp particle textures (dot / square / star).
	p.texture = JuiceeBurstEffect._shape_tex(spark_shape)
	p.particle_flag_align_y = spark_shape == JuiceeBurstEffect.ParticleShape.STREAK
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.scale_amount_min = spark_scale * 0.5
	p.scale_amount_max = spark_scale * 1.2
	if air_drag > 0.0:
		p.damping_min = air_drag * 0.7
		p.damping_max = air_drag * 1.3
	else:
		p.damping_min = 0.0
		p.damping_max = 0.0
	var spawn_parent: Node = _spawn_parent(origin)
	p.name = StringName("_juicee_hit_spark_%d" % randi())
	spawn_parent.add_child(p)
	# World position AFTER parenting: setting global_position before add_child treats
	# it as local, which doubles the offset when the parent isn't at the world origin.
	p.global_position = origin.global_position
	# restart() (not emitting = true) so a reused one-shot node emits again.
	p.restart()
	await origin.get_tree().create_timer(p.lifetime + 0.1, true, false, false).timeout
	# Park the node for the next hit to reuse.
	if is_instance_valid(p):
		p.emitting = false
		_pool.release(p)
