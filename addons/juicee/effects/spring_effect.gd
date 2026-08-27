## Harmonic-oscillator spring physics on any Vector2 property. Drives the
## property away from its rest value with an impulse, then naturally settles
## back via spring + damping forces. The classic UI "bouncy menu" feel.
##
## Universal animator for: button.position bouncing on hover, sprite.scale
## punching on hit, ui_panel.position oscillating into view. Works on any
## node that has a Vector2 property.
##
## Math:  F = -k*x - c*v ; a = F/m ; v += a*dt ; x += v*dt
@tool
class_name JuiceeSpringEffect
extends JuiceeEffect

## Node path to the target (e.g., "../Button" or "%MenuButton"). Resolved
## relative to the `context` node passed to apply().
@export var target_path: NodePath
## Name of the Vector2 property to oscillate (e.g., "scale", "position",
## "pivot_offset"). Type must be Vector2 for this v1.0 - float/Color in v1.1.
@export var property: String = "scale"
## Initial velocity kick. Bigger = stronger overshoot.
@export var impulse: Vector2 = Vector2(0.5, 0.5)
## Spring stiffness (k). Higher = snappier return, more oscillation cycles.
@export_range(10.0, 1000.0, 5.0) var stiffness: float = 200.0
## Damping coefficient (c). Higher = settles faster, less ringy.
@export_range(0.0, 50.0, 0.5) var damping: float = 10.0
## Mass - higher = more inertia, slower oscillation.
@export_range(0.1, 10.0, 0.1) var mass: float = 1.0
## Maximum simulation duration in seconds - bails out if still ringing after this.
@export_range(0.2, 10.0, 0.05) var max_duration: float = 2.0
## Settled threshold - both displacement and velocity must be below this length
## to consider the simulation done early.
@export_range(0.001, 0.5, 0.001) var settle_threshold: float = 0.01

func get_category_name() -> String:
	return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var target: Node = context.get_node_or_null(target_path) if not target_path.is_empty() else context
	if not target:
		push_warning("JuiceeSpringEffect: target_path '%s' not found" % str(target_path))
		return
	if not target.has_method("get") or not (property in target):
		push_warning("JuiceeSpringEffect: target has no property '%s'" % property)
		return

	# Capture the original (rest) value via JuiceeStateStack - concurrent springs
	# on the same property will restore the TRUE original.
	var rest_value = _capture_state(target, property)
	if not (rest_value is Vector2):
		push_warning("JuiceeSpringEffect: property '%s' is not Vector2" % property)
		_release_state(target, property)
		return

	var current: Vector2 = rest_value
	var velocity: Vector2 = impulse * intensity_mult
	var elapsed: float = 0.0
	var tree := target.get_tree()
	if not tree:
		_release_state(target, property)
		return

	var dt: float = 1.0 / 60.0  # target physics step
	while elapsed < max_duration and not _cancelled and is_instance_valid(target):
		var displacement: Vector2 = current - rest_value
		# F_spring = -k * x
		var spring_force: Vector2 = displacement * (-stiffness)
		# F_damping = -c * v
		var damping_force: Vector2 = velocity * (-damping)
		var force: Vector2 = spring_force + damping_force
		var acceleration: Vector2 = force / mass
		velocity += acceleration * dt
		current += velocity * dt
		target.set(property, current)
		# Early-out if settled (tiny displacement AND tiny velocity).
		if displacement.length() < settle_threshold and velocity.length() < settle_threshold:
			break
		await tree.process_frame
		elapsed += dt

	# Snap to rest position to clean up any sub-threshold drift.
	if is_instance_valid(target):
		target.set(property, rest_value)
	_release_state(target, property)
