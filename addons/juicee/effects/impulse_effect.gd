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

@export_group("Advanced")
## Random spin (degrees/sec, +/-) applied along with the impulse.
@export_range(0.0, 1080.0, 10.0) var spin: float = 0.0
## Zero the body's velocity first, so the impulse lands the same every time.
@export var reset_velocity: bool = false
## Randomize the impulse magnitude by this fraction (0.3 = 70%-130% each fire), so a
## stream of launches has natural variety.
@export_range(0.0, 0.9, 0.05) var force_variance: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["spin", "reset_velocity", "force_variance"]))

func _apply(context: Node, intensity_mult: float) -> void:
	var resolved: Node = context.get_node_or_null(target) if not target.is_empty() else context
	var body: RigidBody2D = resolved as RigidBody2D
	if not body:
		_warn("JuiceeImpulseEffect: target is not a RigidBody2D")
		return
	if not body.is_inside_tree():
		return

	# {"impulse": Vector2} overrides the exported vector for this one play.
	var effective_impulse: Vector2 = (_param("impulse", impulse) as Vector2) * intensity_mult
	if random_cone_degrees > 0.0:
		var spread := deg_to_rad(random_cone_degrees)
		var angle_offset := randf_range(-spread * 0.5, spread * 0.5)
		effective_impulse = effective_impulse.rotated(angle_offset)
	# Advanced: per-fire magnitude variety so a stream of launches isn't identical.
	if force_variance > 0.0:
		effective_impulse *= 1.0 + randf_range(-force_variance, force_variance)

	if reset_velocity:
		body.linear_velocity = Vector2.ZERO
	body.apply_central_impulse(effective_impulse)
	if spin > 0.0:
		body.angular_velocity += deg_to_rad(randf_range(-spin, spin)) * intensity_mult
