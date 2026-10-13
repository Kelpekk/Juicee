## Animate depth-of-field blur on a Camera3D via its CameraAttributes resource.
##
## A camera with no CameraAttributes gets a Practical one; a Physical camera only gets a warning.
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
## Peak blur strength: the camera's DOF Blur Amount at the height of the effect.
@export_range(0.0, 1.0, 0.01) var blur_amount: float = 0.1
## Total duration: the blur fades in, holds, then fades out (Fade In Ratio sets the in and out share).
@export_range(0.1, 10.0, 0.1) var duration: float = 2.0
## If true, the blur fades out at the end and the camera's DOF settings go back to how they were. If false, it stays on.
@export var fade_out: bool = true

@export_group("Advanced")
## Animate the far focus distance from this value to Far Distance over the fade-in, for a
## cinematic focus pull. -1 = snap straight to Far Distance (the default).
@export_range(-1.0, 200.0, 0.5) var focus_pull_from: float = -1.0
## Fraction of the duration spent fading the blur in, and again fading it out. 0.15 = a quick rack focus.
@export_range(0.05, 0.9, 0.05) var fade_in_ratio: float = 0.15

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["focus_pull_from", "fade_in_ratio"]))

func get_category_name() -> String: return "Screen"

const PROPERTIES: Array[String] = ["dof_blur_amount", "dof_blur_far_enabled", "dof_blur_far_distance",
	"dof_blur_far_transition", "dof_blur_near_enabled", "dof_blur_near_distance", "dof_blur_near_transition"]

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
		_warn("JuiceeDepthOfFieldEffect: no Camera3D found")
		return

	var attr := cam.attributes
	if attr is CameraAttributesPhysical:
		_warn("JuiceeDepthOfFieldEffect: the camera uses CameraAttributesPhysical; depth of field needs CameraAttributesPractical")
		return
	var practical := attr as CameraAttributesPractical
	# A camera is usually left with no attributes at all, and there is nothing to blur without
	# them. A fresh one has auto exposure and both DOF flags off, so it changes nothing by itself.
	var play := _gen
	var made_attributes := false
	if not practical:
		practical = CameraAttributesPractical.new()
		cam.attributes = practical
		made_attributes = true
	# The camera through a weak reference: a lambda that captured it would report an error when
	# called after the camera was freed, whatever its body checks.
	var cam_ref: WeakRef = weakref(cam)
	var drop_made := func() -> void:
		var c := cam_ref.get_ref() as Camera3D
		if c and c.attributes == practical:
			c.attributes = null
	if made_attributes:
		_on_stop(drop_made)

	# Captured so stop() or the end of the play puts the camera back as it was.
	for p in PROPERTIES:
		_capture_state(practical, p)

	practical.dof_blur_amount = 0.0
	if blur_far:
		practical.dof_blur_far_enabled = true
		practical.dof_blur_far_distance = far_distance if focus_pull_from < 0.0 else focus_pull_from
		practical.dof_blur_far_transition = far_transition
	if blur_near:
		practical.dof_blur_near_enabled = true
		practical.dof_blur_near_distance = near_distance
		practical.dof_blur_near_transition = near_transition

	var peak: float = clampf(blur_amount * intensity_mult, 0.0, 1.0)
	var fade_time: float = duration * fade_in_ratio
	var hold_time: float = maxf(0.0, duration - fade_time * 2.0)
	var tree := context.get_tree()

	var fade_in := _track(tree.create_tween()).set_parallel(true)
	fade_in.tween_property(practical, "dof_blur_amount", peak, fade_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Advanced focus pull: rack the far focus distance in over the same fade.
	if blur_far and focus_pull_from >= 0.0:
		fade_in.tween_property(practical, "dof_blur_far_distance", far_distance, fade_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_in.finished
	# A newer play or stop() owns the camera now.
	if _gen != play:
		return

	await tree.create_timer(hold_time, true, false, false).timeout
	if _gen != play:
		return

	if fade_out:
		var fade_away := _track(tree.create_tween())
		fade_away.tween_property(practical, "dof_blur_amount", 0.0, fade_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await fade_away.finished
		if _gen != play:
			return
		for p in PROPERTIES:
			_release_state(practical, p)
		if made_attributes:
			drop_made.call()
	elif made_attributes:
		# fade_out = false leaves the blur on: the settings stay held, and the attributes this
		# play gave the camera go when stop() gives the settings back.
		_hold_until_stop(drop_made)
