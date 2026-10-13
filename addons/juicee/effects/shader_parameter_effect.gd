## Tween any ShaderMaterial uniform on a CanvasItem or MeshInstance3D.
##
## This is the universal "animate any shader param" escape hatch - equivalent to
## FEEL's MMF_ShaderController. Point it at any node with a ShaderMaterial,
## name the uniform, and supply from/to values.
##
## Use for: animated shader dissolves, hit-flash uniforms, charge-up glow,
## forcefield intensity, custom post-process parameter drives.
@tool
class_name JuiceeShaderParameterEffect
extends JuiceeEffect

## Node with a ShaderMaterial. Empty = context node itself.
@export var target_path: NodePath = NodePath()
## For MeshInstance3D: which surface (0 = first surface).
@export_range(0, 8, 1) var surface_index: int = 0
## Name of the shader uniform to animate (as written in the shader).
@export var parameter_name: String = ""
## Starting value. Leave null to use the current value at apply() time.
@export var from_value: Variant = null
## Target value to animate to.
@export var to_value: Variant = 1.0
## Animation duration in seconds.
@export_range(0.05, 10.0, 0.05) var duration: float = 0.4
## Restore original uniform value at the end.
@export var restore_on_end: bool = true

## Tween transition type.
@export var transition: Tween.TransitionType = Tween.TRANS_QUAD
## Tween ease type.
@export var easing: Tween.EaseType = Tween.EASE_OUT

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing the built-in easing for the parameter sweep.
@export var ease_curve: Curve
## Sweep to the value and back again (the return takes another Duration), which is
## what a one-shot shader pulse (a dissolve blip, a hit rim-light) wants.
@export var ping_pong: bool = false
## Oscillate the parameter this many times across the duration instead of a single
## sweep, for a throbbing shader.
@export_range(1, 20, 1) var oscillations: int = 1

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "ping_pong", "oscillations"]))

func get_category_name() -> String: return "Object"

func _apply(context: Node, _intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	if parameter_name.is_empty():
		_warn("JuiceeShaderParameterEffect: parameter_name is empty")
		return

	var target: Node = context
	if not target_path.is_empty():
		target = context.get_node_or_null(target_path)
	if not is_instance_valid(target):
		_warn("JuiceeShaderParameterEffect: target not found")
		return

	var mat: ShaderMaterial = _shader_material_on(target)
	if not mat:
		var holder := _nearest_node(target, func(n: Node) -> bool: return _shader_material_on(n) != null)
		if holder:
			target = holder
			mat = _shader_material_on(target)
	if not mat:
		_warn("JuiceeShaderParameterEffect: nothing here draws with a ShaderMaterial")
		return

	var original: Variant = mat.get_shader_parameter(parameter_name)
	# A value that comes back is held on the state stack, so stop() puts it back too.
	var held := "shader_parameter/" + parameter_name
	if restore_on_end:
		_capture_state(mat, held)
	# A uniform nobody has touched in the inspector reads back as null, even when the
	# shader declares a default for it, so ask the shader itself before giving up.
	var start: Variant = from_value if from_value != null else original
	if start == null and mat.shader:
		start = RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), parameter_name)
	if start == null:
		start = _zero_like(to_value)
	if start == null:
		_warn("JuiceeShaderParameterEffect: cannot determine a start value for '%s'" % parameter_name)
		return

	var setter := func(v: Variant) -> void:
		if is_instance_valid(mat): mat.set_shader_parameter(parameter_name, v)
	var tween := _track(context.create_tween())
	if oscillations > 1:
		# Advanced: throb between the two values instead of one sweep, for a pulsing
		# dissolve / rim light that lives for the whole duration.
		tween.tween_method(func(t: float) -> void:
			var k: float = 0.5 - 0.5 * cos(t * TAU * oscillations)
			setter.call(lerp(start, to_value, k)), 0.0, 1.0, duration)
	elif ease_curve:
		tween.tween_method(func(t: float) -> void:
			setter.call(lerp(start, to_value, ease_curve.sample(t))), 0.0, 1.0, duration)
	else:
		tween.tween_method(setter, start, to_value, duration)\
			.set_trans(transition).set_ease(easing)
	# ping_pong sweeps back over a second duration, which is what a one-shot shader blip
	# wants (the value should not sit at the target afterwards).
	if ping_pong and oscillations <= 1:
		tween.tween_method(setter, to_value, start, duration)\
			.set_trans(transition).set_ease(easing)
	await tween.finished
	if _gen != play:
		return

	if restore_on_end:
		_release_state(mat, held)

## The ShaderMaterial a node draws with, if it has one.
func _shader_material_on(node: Node) -> ShaderMaterial:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).get_active_material(surface_index) as ShaderMaterial
	if node is CanvasItem:
		return (node as CanvasItem).material as ShaderMaterial
	return null

## A typed zero matching to_value, used as the starting point when neither the material
## nor the shader can tell us what the uniform currently is.
func _zero_like(v: Variant) -> Variant:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT: return 0.0
		TYPE_VECTOR2: return Vector2.ZERO
		TYPE_VECTOR3: return Vector3.ZERO
		TYPE_VECTOR4: return Vector4.ZERO
		TYPE_COLOR: return Color(0.0, 0.0, 0.0, 0.0)
	return null
