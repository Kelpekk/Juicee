## Animate depth-of-field blur on a Camera3D via its CameraAttributes resource.
##
## Supports both CameraAttributesPractical and CameraAttributesPhysical.
## Fades DOF in, holds, then fades out (or keeps it on when fade_out=false).
## Use for: sniper scope, cinematic focus pull, death blur, close-up dialogue.
@tool
class_name JuiceeDepthOfFieldEffect
extends JuiceeEffect

## Path to the Camera3D. Empty = search the viewport for the active camera.
@export_node_path("Camera3D") var camera_path: NodePath = NodePath()
## Enable far-distance DOF blur.
@export var blur_far: bool = true
## Distance at which far DOF begins (metres).
@export_range(0.1, 200.0, 0.1) var far_distance: float = 10.0
## Blur transition range past far_distance.
@export_range(0.1, 50.0, 0.1) var far_transition: float = 5.0
## Enable near-distance DOF blur.
@export var blur_near: bool = false
## Near DOF distance (metres).
@export_range(0.0, 20.0, 0.1) var near_distance: float = 1.0
## Near DOF transition range.
@export_range(0.01, 10.0, 0.1) var near_transition: float = 0.5
## Total duration. fade_in = 15%, hold = 70%, fade_out = 15%.
@export_range(0.1, 10.0, 0.1) var duration: float = 2.0
## Keep the DOF on after the effect ends (disable manually via restore).
@export var fade_out: bool = true

func get_category_color() -> Color: return Color(0.28, 0.72, 0.95)
func get_category_name() -> String: return "Screen"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var cam: Camera3D = null
	if not camera_path.is_empty():
		cam = context.get_node_or_null(camera_path) as Camera3D
	if not cam:
		var vp := context.get_viewport()
		cam = vp.get_camera_3d() if vp else null
	if not cam:
		push_warning("JuiceeDepthOfFieldEffect: no Camera3D found")
		return

	var attr := cam.attributes
	if not attr:
		push_warning("JuiceeDepthOfFieldEffect: Camera3D has no CameraAttributes resource")
		return

	# Store original DOF state.
	var orig_far_enabled: bool = false
	var orig_near_enabled: bool = false
	if attr is CameraAttributesPractical:
		orig_far_enabled = attr.dof_blur_far_enabled
		orig_near_enabled = attr.dof_blur_near_enabled

	# Apply DOF settings.
	if attr is CameraAttributesPractical:
		if blur_far:
			attr.dof_blur_far_enabled = true
			attr.dof_blur_far_distance = far_distance
			attr.dof_blur_far_transition = far_transition
		if blur_near:
			attr.dof_blur_near_enabled = true
			attr.dof_blur_near_distance = near_distance
			attr.dof_blur_near_transition = near_transition

	var fade_in_time := duration * 0.15
	var hold_time := duration * 0.70
	var fade_out_time := duration * 0.15
	var tree := context.get_tree()

	await tree.create_timer(fade_in_time, true, false, false).timeout
	if _cancelled: _restore_cam(attr, orig_far_enabled, orig_near_enabled); return

	await tree.create_timer(hold_time, true, false, false).timeout
	if _cancelled: _restore_cam(attr, orig_far_enabled, orig_near_enabled); return

	if fade_out:
		await tree.create_timer(fade_out_time, true, false, false).timeout
		_restore_cam(attr, orig_far_enabled, orig_near_enabled)

func _restore_cam(attr: CameraAttributes, orig_far: bool, orig_near: bool) -> void:
	if not is_instance_valid(attr):
		return
	if attr is CameraAttributesPractical:
		attr.dof_blur_far_enabled = orig_far
		attr.dof_blur_near_enabled = orig_near
