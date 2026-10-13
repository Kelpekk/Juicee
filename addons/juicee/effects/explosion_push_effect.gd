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

@export_group("Advanced")
## Extra upward force added to every pushed body, so a blast throws debris up and out
## instead of skidding it along the floor.
@export_range(0.0, 2000.0, 10.0) var lift: float = 0.0
## Random spin (degrees/sec, +/-) imparted to each body, so debris tumbles.
@export_range(0.0, 1080.0, 10.0) var spin: float = 0.0
## Physics layers the blast affects (0 = every layer, the default).
@export_flags_2d_physics var collision_mask: int = 0
## Also push bodies whose centre is outside the radius but whose shape overlaps it, with
## the weak push from the blast's outer edge. Off = only bodies whose own position is
## inside the radius get pushed.
@export var include_partial_overlap: bool = true

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["lift", "spin", "collision_mask", "include_partial_overlap"]))

func get_category_name() -> String:
	return "Physics"

func get_description() -> String:
	return "A radial impulse that shoves every RigidBody2D within radius away from the blast.\nExplosions, shockwaves, force pushes; the whole-scene version of Impulse."

func _apply(context: Node, intensity_mult: float) -> void:
	var src: Node = context.get_node_or_null(origin) if not origin.is_empty() else context
	var origin_node: Node2D = src as Node2D
	if not origin_node or not origin_node.is_inside_tree():
		_warn("JuiceeExplosionPushEffect: origin is not a Node2D in the tree")
		return

	var center: Vector2 = origin_node.global_position
	var space := origin_node.get_world_2d().direct_space_state
	var circle := CircleShape2D.new()
	if radius <= 0.0:
		_warn("JuiceeExplosionPushEffect: radius is %s, so nothing is in reach" % radius)
		return
	circle.radius = radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = Transform2D(0.0, center)
	params.collide_with_bodies = true
	params.collide_with_areas = false
	# Advanced: restrict the blast to specific physics layers (0 = every layer).
	if collision_mask != 0:
		params.collision_mask = collision_mask

	for hit in space.intersect_shape(params, maxi(max_bodies, 0)):
		var body := hit.get("collider") as RigidBody2D
		if body == null:
			continue
		var offset: Vector2 = body.global_position - center
		var dist: float = offset.length()
		# A body whose shape clips the blast but whose centre is outside gets no push
		# unless partial overlap is allowed.
		if dist > radius and not include_partial_overlap:
			continue
		var dir: Vector2 = offset.normalized() if dist > 1.0 else Vector2.from_angle(randf() * TAU)
		# A body that only clips the radius gets the edge push, a tenth of the centre's.
		var t: float = clampf(1.0 - dist / radius, 0.0, 1.0) if dist <= radius else 0.1
		var scaled: float = pow(t, falloff_exponent) * intensity_mult
		var push: Vector2 = dir * force * scaled
		if lift > 0.0:
			push += Vector2.UP * lift * scaled
		body.apply_central_impulse(push)
		if spin > 0.0:
			body.angular_velocity += deg_to_rad(randf_range(-spin, spin)) * scaled
