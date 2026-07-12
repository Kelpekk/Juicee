## Applies an instant impulse to a RigidBody2D (push/knockback).
@tool
class_name JuiceeImpulseEffect
extends JuiceeEffect

## Path to the RigidBody2D to push. If empty, the context itself must be a RigidBody2D.
@export_node_path("RigidBody2D") var target: NodePath
## Impulse vector applied at the body's center (pixels/sec for velocity).
@export var impulse: Vector2 = Vector2(200, -100)
## If > 0, impulse direction is randomized within this cone (in degrees) for variety.
@export_range(0.0, 180.0, 1.0) var random_cone_degrees: float = 0.0

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func _apply(context: Node, intensity_mult: float) -> void:
	var resolved: Node = context.get_node_or_null(target) if not target.is_empty() else context
	var body: RigidBody2D = resolved as RigidBody2D
	if not body:
		push_warning("JuiceeImpulseEffect: target is not a RigidBody2D")
		return
	if not body.is_inside_tree():
		return

	var effective_impulse := impulse * intensity_mult
	if random_cone_degrees > 0.0:
		var spread := deg_to_rad(random_cone_degrees)
		var angle_offset := randf_range(-spread * 0.5, spread * 0.5)
		effective_impulse = effective_impulse.rotated(angle_offset)

	body.apply_central_impulse(effective_impulse)
