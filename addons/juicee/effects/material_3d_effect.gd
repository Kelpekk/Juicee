## Animate a material property on a MeshInstance3D (albedo, emission, roughness, etc.).
##
## Creates a unique material duplicate so only this instance is affected -
## other objects using the same material are not changed.
## Restores the original material at the end when Restore On End is on (the default).
##
## Use for: hit flash (albedo -> red), damage emission glow, dissolve,
## ghost effect (transparency ramp), powerup material change.
@tool
class_name JuiceeMaterial3DEffect
extends JuiceeEffect

## Path to the MeshInstance3D. Empty = context itself.
@export_node_path("MeshInstance3D") var mesh_path: NodePath = NodePath()
## Which surface (0 = first surface).
@export_range(0, 7, 1) var surface_index: int = 0
## Material property to tween: a BaseMaterial3D property, or a shader parameter on a ShaderMaterial.
## Examples: "albedo_color", "emission", "emission_energy_multiplier", "roughness", "metallic".
@export var property_name: String = "albedo_color"
## Start value (null = current material value at apply time).
@export var from_value: Variant = null
## Target value to tween to.
@export var to_value: Variant = Color(1.0, 0.2, 0.2, 1.0)
## Tween duration.
@export_range(0.05, 3.0, 0.05) var duration: float = 0.3
## Restore the original material at the end.
@export var restore_on_end: bool = true

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing the quad ease for the property tween.
@export var ease_curve: Curve
## Return to the starting value after reaching the target, instead of holding there.
## A hit flash wants this on; a permanent recolour wants it off.
@export var ping_pong: bool = false
## Seconds to hold at the target value before returning (only with Ping Pong).
@export_range(0.0, 10.0, 0.05) var hold_time: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "ping_pong", "hold_time"]))

func get_category_name() -> String: return "Object"

func _apply(context: Node, _intensity_mult: float) -> void:
	var mesh: MeshInstance3D = null
	if not mesh_path.is_empty():
		mesh = context.get_node_or_null(mesh_path) as MeshInstance3D
	if not mesh:
		mesh = context as MeshInstance3D
	if not mesh:
		_warn("JuiceeMaterial3DEffect: no MeshInstance3D found")
		return
	if property_name.is_empty():
		_warn("JuiceeMaterial3DEffect: property_name is empty")
		return

	var orig_mat: Material = mesh.get_active_material(surface_index)
	if not orig_mat:
		_warn("JuiceeMaterial3DEffect: no material on surface %d" % surface_index)
		return

	# Work on a duplicate so other mesh instances sharing this material are unaffected.
	var working_mat: Material = orig_mat.duplicate()
	# material_override beats surface overrides in Godot's material priority, so when the
	# mesh uses one we must animate THAT slot. Writing a surface override instead would be
	# masked by the still-active override and the effect would silently do nothing.
	var via_override: bool = mesh.material_override != null
	var slot := "material_override" if via_override else "surface_material_override/%d" % surface_index
	# The slot is held on the state stack: stop() and a new play put the mesh's own material back,
	# and a second Material 3D on the same mesh no longer takes the first one's copy for the
	# original and leaves it on.
	_capture_state(mesh, slot)
	mesh.set_indexed(slot, working_mat)
	var play := _gen

	# Where the value lives. A StandardMaterial3D keeps albedo_color and the rest as ordinary
	# properties; a ShaderMaterial keeps everything as shader parameters and returns null for
	# get("albedo_color"). That null used to go straight into tween_method, which cannot
	# interpolate from nothing, so the call returned null and the next line dereferenced it
	# and took the game down. A custom shader on a character is the ordinary case in 3D.
	var as_shader := working_mat as ShaderMaterial
	var on_shader := false
	var start: Variant = from_value
	if start == null:
		start = working_mat.get(property_name)
	if start == null and as_shader:
		start = as_shader.get_shader_parameter(property_name)
		# A uniform nobody has touched in the inspector reads back as null even when the
		# shader declares a default for it, so ask the shader itself. Same trap the shader
		# parameter effect already handles.
		if start == null and as_shader.shader:
			start = RenderingServer.shader_get_parameter_default(
					as_shader.shader.get_rid(), property_name)
		on_shader = start != null
	elif as_shader and working_mat.get(property_name) == null:
		on_shader = true

	if start == null:
		_warn("JuiceeMaterial3DEffect: %s has no property or shader parameter '%s'"
				% [working_mat.get_class(), property_name])
		_release_state(mesh, slot)
		return
	if typeof(start) != typeof(to_value):
		_warn("JuiceeMaterial3DEffect: '%s' is %s and To Value is %s, which cannot be blended"
				% [property_name, type_string(typeof(start)), type_string(typeof(to_value))])
		_release_state(mesh, slot)
		return

	var setter := func(v: Variant) -> void:
		if not is_instance_valid(working_mat):
			return
		if on_shader:
			(working_mat as ShaderMaterial).set_shader_parameter(property_name, v)
		else:
			working_mat.set(property_name, v)
	var tween := _track(context.create_tween())
	# ease_curve (advanced) overrides the quad ease on the way to the target.
	if ease_curve:
		tween.tween_method(func(t: float) -> void:
			setter.call(lerp(start, to_value, ease_curve.sample(t))), 0.0, 1.0, duration)
	else:
		tween.tween_method(setter, start, to_value, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Advanced ping_pong returns to the starting value, which is what a hit flash wants.
	if ping_pong:
		if hold_time > 0.0:
			tween.tween_interval(hold_time)
		tween.tween_method(setter, to_value, start, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if _gen != play:
		return
	if restore_on_end:
		_release_state(mesh, slot)
	else:
		# The changed copy stays on the mesh, and is what an effect still holding the slot
		# comes back to.
		_keep_state(mesh, slot, working_mat)
