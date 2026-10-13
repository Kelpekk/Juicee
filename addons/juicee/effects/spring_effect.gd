## Harmonic-oscillator spring physics on any Vector2 or float property. Drives the
## property away from its rest value with an impulse, then naturally settles
## back via spring + damping forces. The classic UI "bouncy menu" feel.
##
## Universal animator for: button.position bouncing on hover, sprite.scale
## punching on hit, ui_panel.position oscillating into view. Works on any
## node that has a Vector2 or float property.
##
## Math:  F = -k*x - c*v ; a = F/m ; v += a*dt ; x += v*dt
@tool
class_name JuiceeSpringEffect
extends JuiceeEffect

## Node path to the target (e.g., "../Button" or "%MenuButton"). Resolved
## relative to the `context` node passed to apply().
@export var target_path: NodePath
## Name of the property to spring. A Vector2 ("scale", "position", "pivot_offset") uses
## both impulse axes; a float ("rotation", "skew") springs on impulse.x.
@export var property: String = "scale"
## Initial velocity kick. Bigger = stronger overshoot. Tuned for a visible scale
## punch by default; lower it for subtle springs or raise it for position kicks.
@export var impulse: Vector2 = Vector2(4.0, 4.0)
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

@export_group("Advanced")
## Start the spring already displaced by this much and release it, instead of kicking it
## with velocity. A pulled-back catapult rather than a flick.
@export var initial_offset: Vector2 = Vector2.ZERO
## Clamp how far the spring may travel from rest, so a hard hit cannot fling a UI element
## off screen. 0 = no limit.
@export_range(0.0, 50.0, 0.5) var max_displacement: float = 0.0

func _validate_property(property_info: Dictionary) -> void:
	# Param named property_info: this effect has its own `property` export to animate.
	_gate_advanced(property_info, PackedStringArray(["initial_offset", "max_displacement"]))

func get_category_name() -> String:
	return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var target: Node = context.get_node_or_null(target_path) if not target_path.is_empty() else context
	if not target:
		_warn("JuiceeSpringEffect: target_path '%s' not found" % str(target_path))
		return
	# A Node3D has a "scale" as well, a Vector3 no spring can drive, so the search asks for the
	# type as much as the name.
	var springable := func(n: Node) -> bool:
		if not (property in n):
			return false
		var v: Variant = n.get(property)
		return v is Vector2 or v is float or v is int
	if not springable.call(target):
		var holder := _nearest_node(target, springable)
		if holder:
			target = holder
	if not (property in target):
		_warn("JuiceeSpringEffect: nothing here has a property '%s'" % property)
		return

	# Capture the original (rest) value via JuiceeStateStack - concurrent springs
	# on the same property will restore the TRUE original.
	var play := _gen
	var rest_value = _capture_offset(target, property)
	var tree := target.get_tree()
	if not tree:
		_release_state(target, property)
		return
	# One step per 1/60 s of real time, like the other spring effects, not one per frame.
	var dt: float = 1.0 / 60.0

	if rest_value is Vector2:
		var rest_v: Vector2 = rest_value
		# Advanced initial_offset releases the spring from a displaced start (a pulled-back
		# catapult) instead of kicking it with velocity.
		var current := rest_v + initial_offset * intensity_mult
		var velocity: Vector2 = impulse * intensity_mult
		var elapsed: float = 0.0
		while elapsed < max_duration and _gen == play and is_instance_valid(target):
			var displacement: Vector2 = current - rest_v
			# F = -k*x - c*v ; a = F/m
			var s := _spring_step(displacement, velocity, stiffness, damping, mass, dt)
			velocity = s[1]
			current = rest_v + s[0]
			# max_displacement keeps a hard hit from flinging a UI element off screen.
			if max_displacement > 0.0:
				var d: Vector2 = current - rest_v
				if d.length() > max_displacement:
					current = rest_v + d.limit_length(max_displacement)
			_write_offset(target, property, rest_v, current - rest_v, (current - rest_v).length())
			if displacement.length() < settle_threshold and velocity.length() < settle_threshold:
				break
			elapsed += await _wait_step(tree, dt)
		if _gen != play:
			return
		if is_instance_valid(target):
			_write_offset(target, property, rest_v, Vector2.ZERO, 0.0)
	elif rest_value is float or rest_value is int:
		# Scalar spring for float properties (rotation, skew...), kicked by impulse.x.
		var rest_f: float = rest_value
		var cur_f := rest_f
		var vel_f: float = impulse.x * intensity_mult
		var elapsed: float = 0.0
		while elapsed < max_duration and _gen == play and is_instance_valid(target):
			var disp := cur_f - rest_f
			var s := _spring_step(disp, vel_f, stiffness, damping, mass, dt)
			vel_f = s[1]
			cur_f = rest_f + float(s[0])
			_write_offset(target, property, rest_f, cur_f - rest_f, absf(cur_f - rest_f))
			if absf(disp) < settle_threshold and absf(vel_f) < settle_threshold:
				break
			elapsed += await _wait_step(tree, dt)
		if _gen != play:
			return
		if is_instance_valid(target):
			_write_offset(target, property, rest_f, 0.0, 0.0)
	else:
		_warn("JuiceeSpringEffect: property '%s' is not a Vector2 or float" % property)

	_release_state(target, property)
