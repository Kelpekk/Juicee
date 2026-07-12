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

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Physics"

func get_description() -> String:
	return "Shove a RigidBody2D along hit_direction (a hit reaction).\nAimed knockback, vs ImpulseEffect's fixed vector."

func _apply(context: Node, intensity_mult: float) -> void:
	var resolved: Node = context.get_node_or_null(target) if not target.is_empty() else context
	var body: RigidBody2D = resolved as RigidBody2D
	if not body:
		push_warning("JuiceeKnockbackEffect: target is not a RigidBody2D")
		return
	if not body.is_inside_tree():
		return

	var dir: Vector2 = _runtime_params.get("hit_direction", default_direction)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	body.apply_central_impulse(dir.normalized() * force * intensity_mult)
