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
## IMPULSE mode on a RigidBody2D only: offset from the centre of mass (local position).
@export var at_position: Vector2 = Vector2.ZERO

@export_group("Advanced")
## Rotational force applied alongside the linear one, so a push also spins the body.
@export_range(-100000.0, 100000.0, 100.0) var torque: float = 0.0
## Hand-drawn curve (0..1) shaping how the force ramps over the duration (Force mode
## only). Null = a constant push for the whole duration.
@export var force_curve: Curve

func _validate_property(property_info: Dictionary) -> void:
	_gate_advanced(property_info, PackedStringArray(["torque", "force_curve"]))

func get_category_name() -> String: return "Physics"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return

	var f2 := force * intensity_mult
	var f3 := force_3d * intensity_mult
	# Advanced torque spins the body along with the push, so a shove also tumbles it.
	var spin: float = torque * intensity_mult

	if context is RigidBody2D:
		var rb := context as RigidBody2D
		if spin != 0.0:
			rb.apply_torque_impulse(spin)
		match mode:
			Mode.IMPULSE:
				rb.apply_impulse(f2, at_position)
			Mode.CONSTANT_FORCE:
				if force_curve:
					await _ramp(rb, f2)
					if _gen != play:
						return
				else:
					rb.constant_force += f2   # persists every physics step (apply_force lasts 1 frame)
					_take_back_on_stop(rb, f2)
					await context.get_tree().create_timer(duration, true, false, false).timeout
					if _gen != play:
						return
					if clear_force_on_end and is_instance_valid(rb):
						rb.constant_force -= f2
			Mode.TORQUE_IMPULSE:
				rb.apply_torque_impulse(f2.x)

	elif context is RigidBody3D:
		var rb := context as RigidBody3D
		if spin != 0.0:
			rb.apply_torque_impulse(Vector3(0.0, spin, 0.0))
		match mode:
			Mode.IMPULSE:
				rb.apply_central_impulse(f3)
			Mode.CONSTANT_FORCE:
				if force_curve:
					await _ramp(rb, f3)
					if _gen != play:
						return
				else:
					rb.constant_force += f3   # persists every physics step (apply_central_force lasts 1 frame)
					_take_back_on_stop(rb, f3)
					await context.get_tree().create_timer(duration, true, false, false).timeout
					if _gen != play:
						return
					if clear_force_on_end and is_instance_valid(rb):
						rb.constant_force -= f3
			Mode.TORQUE_IMPULSE:
				rb.apply_torque_impulse(f3)
	else:
		_warn("JuiceeAddForceEffect: context must be RigidBody2D or RigidBody3D")

## A push this play would take back at its end, stop() or the next play takes back at once.
func _take_back_on_stop(body: Node, push: Variant) -> void:
	if clear_force_on_end:
		_on_stop(_take_back_by_id.bind(body.get_instance_id(), push))

static func _take_back_by_id(id: int, push: Variant) -> void:
	var body := instance_from_id(id) as Node
	if body:
		body.set("constant_force", body.get("constant_force") - push)

## Force mode with a curve: re-set the push every physics step at the curve's height, so a
## gust can swell and die instead of being a flat block of force. Works for both body types
## because constant_force is a Vector2 on one and a Vector3 on the other, and `full` is
## already whichever one this body wants.
##
## It takes back what it added last step before adding this step's amount, so a constant
## force some other system put on the body is still there when this ends.
func _ramp(body: Node, full: Variant) -> void:
	var play := _gen
	var tree := body.get_tree()
	var applied: Variant = full * 0.0
	var elapsed := 0.0
	while elapsed < duration and _gen == play and is_instance_valid(body):
		var amount: Variant = full * force_curve.sample(elapsed / duration)
		body.set("constant_force", body.get("constant_force") - applied + amount)
		applied = amount
		await tree.physics_frame
		elapsed += tree.root.get_physics_process_delta_time()
	if is_instance_valid(body) and clear_force_on_end:
		body.set("constant_force", body.get("constant_force") - applied)
