## Animate a material property on a MeshInstance3D (albedo, emission, roughness, etc.).
##
## Creates a unique material duplicate so only this instance is affected —
## other objects using the same material are not changed.
## Restores the original material reference at the end (no permanent override).
##
## Use for: hit flash (albedo → red), damage emission glow, dissolve,
## ghost effect (transparency ramp), powerup material change.
@tool
class_name JuiceeMaterial3DEffect
extends JuiceeEffect

## Path to the MeshInstance3D. Empty = context itself.
@export_node_path("MeshInstance3D") var mesh_path: NodePath = NodePath()
## Which surface (0 = first surface).
@export_range(0, 7, 1) var surface_index: int = 0
## Material property to tween (standard BaseMaterial3D property names).
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

func get_category_color() -> Color: return Color(1.0, 0.333, 0.333)
func get_category_name() -> String: return "Object"

func _apply(context: Node, _intensity_mult: float) -> void:
	var mesh: MeshInstance3D = null
	if not mesh_path.is_empty():
		mesh = context.get_node_or_null(mesh_path) as MeshInstance3D
	if not mesh:
		mesh = context as MeshInstance3D
	if not mesh:
		push_warning("JuiceeMaterial3DEffect: no MeshInstance3D found")
		return
	if property_name.is_empty():
		push_warning("JuiceeMaterial3DEffect: property_name is empty")
		return

	var orig_mat: Material = mesh.get_active_material(surface_index)
	if not orig_mat:
		push_warning("JuiceeMaterial3DEffect: no material on surface %d" % surface_index)
		return

	# Work on a duplicate so other mesh instances sharing this material are unaffected.
	var working_mat: Material = orig_mat.duplicate()
	mesh.set_surface_override_material(surface_index, working_mat)

	var start: Variant = from_value if from_value != null else working_mat.get(property_name)
	var tween := _track(context.create_tween())
	tween.tween_method(
		func(v: Variant) -> void:
			if is_instance_valid(working_mat): working_mat.set(property_name, v),
		start, to_value, duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	if restore_on_end and is_instance_valid(mesh):
		mesh.set_surface_override_material(surface_index, orig_mat)
