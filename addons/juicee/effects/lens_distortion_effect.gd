## Full-screen barrel or pincushion lens distortion.
##
## Positive strength = barrel (fisheye, wide-angle look).
## Negative strength = pincushion (telephoto look).
## Use for: screen impacts, portal effects, scope zoom-in, psychedelic moments.
@tool
class_name JuiceeLensDistortionEffect
extends JuiceeEffect

## Distortion amount. Positive = barrel, negative = pincushion.
@export_range(-1.0, 1.0, 0.01) var strength: float = 0.25
## Duration in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.4
## Fade the effect out over the last 20% of duration.
@export var fade_out: bool = true

const LAYER_NAME := &"_juicee_lens_distortion_overlay"

func get_category_name() -> String: return "Screen"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var result := _spawn_screen_shader_overlay(context, LAYER_NAME, 130)
	if result.is_empty():
		return
	var layer: CanvasLayer = result[0]
	var rect: ColorRect = result[1]

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://addons/juicee/shaders/lens_distortion.gdshader")
	mat.set_shader_parameter("strength", strength * intensity_mult)
	mat.set_shader_parameter("intensity", 0.0)
	rect.material = mat

	var hold := duration * (0.8 if fade_out else 1.0)
	var fade := duration * 0.2

	var tween := _track(rect.create_tween())
	tween.tween_method(func(v: float) -> void:
		if is_instance_valid(mat): mat.set_shader_parameter("intensity", v),
		0.0, 1.0, duration * 0.1)
	tween.tween_interval(hold - duration * 0.1)
	if fade_out:
		tween.tween_method(func(v: float) -> void:
			if is_instance_valid(mat): mat.set_shader_parameter("intensity", v),
			1.0, 0.0, fade)
	await tween.finished

	# fade_out=false means the distortion holds - keep the overlay alive instead of freeing it.
	if fade_out and is_instance_valid(layer):
		layer.queue_free()
