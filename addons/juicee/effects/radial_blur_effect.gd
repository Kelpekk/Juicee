## Radial (zoom) blur emanating from a center point.
##
## Use for: teleport arrival, speed-force dash, near-death tunnel vision,
## grenade concussion, dimension-shift warp.
##
## The center defaults to the context node's screen position (if Node2D)
## so the warp radiates outward from the impact point.
@tool
class_name JuiceeRadialBlurEffect
extends JuiceeEffect

const SHADER: Shader = preload("res://addons/juicee/shaders/radial_blur.gdshader")
const LAYER_NAME := &"_juicee_radial_blur_overlay"

## Max displacement per sample step. 0.02 = subtle, 0.06 = dramatic warp.
@export_range(0.0, 0.15, 0.005) var strength: float = 0.03
## Number of blur samples accumulated per pixel. More = smoother + heavier GPU cost.
@export_range(4, 16, 1) var samples: int = 8
## Total duration in seconds.
@export_range(0.1, 5.0, 0.05) var duration: float = 0.4
## Fixed screen-UV center (used when context is not a Node2D).
@export var center_uv: Vector2 = Vector2(0.5, 0.5)
## If true and context is Node2D, derives center_uv from the node's screen position.
@export var use_node_position: bool = true

func get_category_name() -> String: return "Screen"

func _apply(context: Node, intensity_mult: float) -> void:
	var result := _spawn_screen_shader_overlay(context, LAYER_NAME, 200)
	if result.is_empty():
		return
	var layer: CanvasLayer = result[0]
	var rect: ColorRect = result[1]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("strength", 0.0)
	mat.set_shader_parameter("samples", samples)
	rect.material = mat

	# Compute center_uv from node screen position.
	var origin := center_uv
	if use_node_position and context is Node2D:
		var vp := context.get_viewport()
		if vp:
			var screen_pos: Vector2 = (context as Node2D).get_global_transform_with_canvas().origin
			var vp_size := vp.get_visible_rect().size
			if vp_size.x > 0 and vp_size.y > 0:
				origin = (screen_pos / vp_size).clamp(Vector2.ZERO, Vector2.ONE)
	mat.set_shader_parameter("center_uv", origin)

	var tree := context.get_tree()
	var elapsed := 0.0
	var peak := strength * intensity_mult

	while elapsed < duration and not _cancelled and is_instance_valid(rect):
		var t := elapsed / duration
		# Ramp in over 15%, then ease out over remaining 85%.
		var s: float
		if t < 0.15:
			s = peak * (t / 0.15)
		else:
			s = peak * (1.0 - (t - 0.15) / 0.85)
		mat.set_shader_parameter("strength", s)
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()

	if is_instance_valid(layer):
		layer.queue_free()
