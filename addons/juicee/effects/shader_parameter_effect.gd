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
@export_enum("Linear", "Sine", "Quint", "Quart", "Quad", "Expo", "Elastic", "Bounce", "Back", "Spring", "Cubic", "Circ") var transition: int = Tween.TRANS_QUAD
## Tween ease type.
@export_enum("EaseIn", "EaseOut", "EaseInOut", "EaseOutIn") var easing: int = Tween.EASE_OUT

func get_category_name() -> String: return "Object"

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if parameter_name.is_empty():
		push_warning("JuiceeShaderParameterEffect: parameter_name is empty")
		return

	var target: Node = context
	if not target_path.is_empty():
		target = context.get_node_or_null(target_path)
	if not is_instance_valid(target):
		push_warning("JuiceeShaderParameterEffect: target not found")
		return

	var mat: ShaderMaterial = null
	if target is MeshInstance3D:
		mat = target.get_active_material(surface_index) as ShaderMaterial
	elif target is CanvasItem:
		mat = target.material as ShaderMaterial
	if not mat:
		push_warning("JuiceeShaderParameterEffect: no ShaderMaterial on target")
		return

	var original: Variant = mat.get_shader_parameter(parameter_name)
	var start: Variant = from_value if from_value != null else original

	var tween := _track(context.create_tween())
	tween.tween_method(
		func(v: Variant) -> void:
			if is_instance_valid(mat): mat.set_shader_parameter(parameter_name, v),
		start, to_value, duration
	).set_trans(transition).set_ease(easing)
	await tween.finished

	if restore_on_end and is_instance_valid(mat):
		mat.set_shader_parameter(parameter_name, original)
