## Apply a continuous force or impulse to a RigidBody2D or RigidBody3D.
##
## Use for: explosion push, wind gusts, magnetic pull, conveyor belts,
## gravity override for a short period, knock back with sustained force.
@tool
class_name JuiceeAddForceEffect
extends JuiceeEffect

enum Mode {
	IMPULSE,         ## Instant velocity change (apply_impulse / apply_central_impulse).
	CONSTANT_FORCE,  ## Apply over `duration` seconds (add_constant_force / set_constant_force).
	TORQUE_IMPULSE,  ## Instant angular velocity kick.
}

## Force/impulse direction and magnitude.
@export var force: Vector2 = Vector2(0, -300)
## 3D force (used when context is RigidBody3D).
@export var force_3d: Vector3 = Vector3(0, 5, 0)
## Application mode.
@export var mode: Mode = Mode.IMPULSE
## Duration for CONSTANT_FORCE mode (seconds).
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## If true, clear the constant force when duration ends (CONSTANT_FORCE mode only).
@export var clear_force_on_end: bool = true
## For IMPULSE/TORQUE: offset from center of mass (local position, Vector2).
@export var at_position: Vector2 = Vector2.ZERO

func get_category_name() -> String: return "Physics"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return

	var f2 := force * intensity_mult
	var f3 := force_3d * intensity_mult

	if context is RigidBody2D:
		var rb := context as RigidBody2D
		match mode:
			Mode.IMPULSE:
				rb.apply_impulse(f2, at_position)
			Mode.CONSTANT_FORCE:
				rb.constant_force += f2   # persists every physics step (apply_force lasts 1 frame)
				await context.get_tree().create_timer(duration, true, false, false).timeout
				if clear_force_on_end and is_instance_valid(rb):
					rb.constant_force -= f2
			Mode.TORQUE_IMPULSE:
				rb.apply_torque_impulse(f2.x)

	elif context is RigidBody3D:
		var rb := context as RigidBody3D
		match mode:
			Mode.IMPULSE:
				rb.apply_central_impulse(f3)
			Mode.CONSTANT_FORCE:
				rb.constant_force += f3   # persists every physics step (apply_central_force lasts 1 frame)
				await context.get_tree().create_timer(duration, true, false, false).timeout
				if clear_force_on_end and is_instance_valid(rb):
					rb.constant_force -= f3
			Mode.TORQUE_IMPULSE:
				rb.apply_torque_impulse(f3)
	else:
		push_warning("JuiceeAddForceEffect: context must be RigidBody2D or RigidBody3D")
