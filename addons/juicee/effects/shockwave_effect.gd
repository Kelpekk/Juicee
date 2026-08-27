## Expanding radial distortion ring from a world-space origin point.
##
## Use for: explosions, teleport arrivals, magic spell impacts, landing
## slams, sub-bass pulse beats. FEEL's `MMFShockwave` parity.
##
## Animates the ring radius from 0 -> max_radius over `duration`, with the
## distortion strength fading out as the ring expands. The origin can be
## the context node's screen-space position (default) or a fixed screen-UV.
@tool
class_name JuiceeShockwaveEffect
extends JuiceeEffect

const SHADER: Shader = preload("res://addons/juicee/shaders/shockwave.gdshader")
const LAYER_NAME := &"_juicee_shockwave_overlay"

## Maximum ring radius (in normalized 0-1 screen space). 1.0 = reaches the screen edge.
@export_range(0.1, 2.0, 0.05) var max_radius: float = 0.6
## Width of the distortion band (fraction of screen height). 0.04 is a tight sharp ring.
@export_range(0.005, 0.3, 0.005) var ring_width: float = 0.04
## Peak UV displacement at the ring centre. Higher = more dramatic warp.
@export_range(0.002, 0.15, 0.002) var strength: float = 0.025
## Total animation duration in seconds.
@export_range(0.1, 3.0, 0.05) var duration: float = 0.5
## Optional easing curve for the radius expansion (null = ease-out quad).
@export var radius_curve: Curve

func get_category_name() -> String:
	return "Screen"

func _apply(context: Node, intensity_mult: float) -> void:
	var result := _spawn_screen_shader_overlay(context, LAYER_NAME, 200)
	if result.is_empty():
		return
	var layer: CanvasLayer = result[0]
	var rect: ColorRect   = result[1]

	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("radius", 0.0)
	mat.set_shader_parameter("width", ring_width)
	mat.set_shader_parameter("strength", strength * intensity_mult)
	mat.set_shader_parameter("falloff", 6.0)
	rect.material = mat

	# Compute the origin in screen-UV from the context node's global position.
	var origin_uv := Vector2(0.5, 0.5)
	if context is Node2D:
		var vp := context.get_viewport()
		if vp:
			var screen_pos: Vector2 = (context as Node2D).get_global_transform_with_canvas().origin
			var vp_size := vp.get_visible_rect().size
			if vp_size.x > 0 and vp_size.y > 0:
				origin_uv = screen_pos / vp_size
				origin_uv = origin_uv.clamp(Vector2.ZERO, Vector2.ONE)
	mat.set_shader_parameter("origin_uv", origin_uv)

	var tree := context.get_tree()
	var elapsed := 0.0
	while elapsed < duration and not _cancelled and is_instance_valid(rect):
		var t := elapsed / duration
		var r: float
		if radius_curve:
			r = radius_curve.sample(t) * max_radius
		else:
			r = (1.0 - pow(1.0 - t, 2.0)) * max_radius
		# Strength also fades out as the ring expands.
		var fade := 1.0 - t
		mat.set_shader_parameter("radius", r)
		mat.set_shader_parameter("strength", strength * intensity_mult * fade)
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()

	if is_instance_valid(layer):
		layer.queue_free()
