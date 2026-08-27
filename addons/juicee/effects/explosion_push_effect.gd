## Explosion Push: a radial impulse that shoves every RigidBody2D within `radius`
## away from the origin, falling off with distance. The whole-blast version of Impulse.
@tool
class_name JuiceeExplosionPushEffect
extends JuiceeEffect

## Path to the blast origin (a Node2D). Empty = the context itself is the origin.
@export var origin: NodePath
## Blast radius in pixels. Bodies outside get nothing.
@export_range(16.0, 2000.0, 1.0) var radius: float = 200.0
## Peak impulse at the centre (pixels/sec of velocity). Falls off to 0 at the edge.
@export_range(10.0, 4000.0, 10.0) var force: float = 600.0
## Falloff shape. 1 = linear, 2 = quadratic (softer edges, punchier centre).
@export_range(0.5, 4.0, 0.1) var falloff_exponent: float = 1.0
## Max bodies the query returns.
@export_range(1, 256, 1) var max_bodies: int = 64

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Physics"

func get_description() -> String:
	return "A radial impulse that shoves every RigidBody2D within radius away from the blast.\nExplosions, shockwaves, force pushes; the whole-scene version of Impulse."

func _apply(context: Node, intensity_mult: float) -> void:
	var src: Node = context.get_node_or_null(origin) if not origin.is_empty() else context
	var origin_node: Node2D = src as Node2D
	if not origin_node or not origin_node.is_inside_tree():
		push_warning("JuiceeExplosionPushEffect: origin is not a Node2D in the tree")
		return

	var center: Vector2 = origin_node.global_position
	var space := origin_node.get_world_2d().direct_space_state
	var circle := CircleShape2D.new()
	circle.radius = radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = Transform2D(0.0, center)
	params.collide_with_bodies = true
	params.collide_with_areas = false

	for hit in space.intersect_shape(params, max_bodies):
		var body := hit.get("collider") as RigidBody2D
		if body == null:
			continue
		var offset: Vector2 = body.global_position - center
		var dist: float = offset.length()
		var dir: Vector2 = offset.normalized() if dist > 1.0 else Vector2.from_angle(randf() * TAU)
		var t: float = clampf(1.0 - dist / radius, 0.0, 1.0)
		body.apply_central_impulse(dir * force * pow(t, falloff_exponent) * intensity_mult)
