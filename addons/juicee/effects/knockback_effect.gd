## Knockback: shove a RigidBody2D in a direction, a hit reaction. Like ImpulseEffect
## but aimed by the "hit_direction" runtime param and scaled by `force`.
@tool
class_name JuiceeKnockbackEffect
extends JuiceeEffect

## Path to the RigidBody2D. Empty = the context itself must be a RigidBody2D.
@export_node_path("RigidBody2D") var target: NodePath
## Impulse strength (pixels/sec of velocity added).
@export_range(10.0, 2000.0, 10.0) var force: float = 400.0
## Direction used when no {"hit_direction": ...} is passed.
@export var default_direction: Vector2 = Vector2.RIGHT

@export_group("Advanced")
## Extra upward force added to the shove, so hits pop the body off the ground instead of
## sliding it along. 0 = a flat push.
@export_range(0.0, 2000.0, 10.0) var lift: float = 0.0
## Random spin (degrees/sec, +/-) imparted by the hit, so bodies tumble.
@export_range(0.0, 720.0, 10.0) var spin: float = 0.0
## Zero the body's current velocity before the shove, so knockback distance is consistent
## no matter how fast it was already moving.
@export var reset_velocity: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["lift", "spin", "reset_velocity"]))

func get_category_name() -> String:
	return "Physics"

func get_description() -> String:
	return "Shove a RigidBody2D along hit_direction (a hit reaction).\nAimed knockback, vs ImpulseEffect's fixed vector."

func _apply(context: Node, intensity_mult: float) -> void:
	var resolved: Node = context.get_node_or_null(target) if not target.is_empty() else context
	var body: RigidBody2D = resolved as RigidBody2D
	if not body:
		_warn("JuiceeKnockbackEffect: target is not a RigidBody2D")
		return
	if not body.is_inside_tree():
		return

	var dir: Vector2 = _param("hit_direction", default_direction)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	# Advanced: a clean slate makes knockback distance repeatable regardless of prior speed.
	if reset_velocity:
		body.linear_velocity = Vector2.ZERO
	var push: Vector2 = dir.normalized() * force * intensity_mult
	if lift > 0.0:
		push += Vector2.UP * lift * intensity_mult
	body.apply_central_impulse(push)
	if spin > 0.0:
		body.angular_velocity += deg_to_rad(randf_range(-spin, spin)) * intensity_mult
