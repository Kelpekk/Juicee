## Full-screen blur - pause menus, dream sequences, knockout effects.
@tool
class_name JuiceeBlurEffect
extends JuiceeEffect

## Peak blur intensity in pixels (9-tap gaussian kernel).
@export_range(0.0, 8.0, 0.1) var intensity: float = 4.0

# Back-compat: old .tres files used `blur_amount`. Route writes to `intensity`.
func _set(property: StringName, value) -> bool:
	if property == &"blur_amount":
		intensity = value
		return true
	return false
## Total duration including ramp-in and ramp-out.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.6
## If true, blur fades back to 0 at the end. If false, it stays at peak.
@export var fade_out: bool = true

const SHADER: Shader = preload("res://addons/juicee/shaders/blur.gdshader")
const LAYER_NAME := &"_juicee_blur_overlay"

func _apply(context: Node, intensity_mult: float) -> void:
	var pair := _spawn_screen_shader_overlay(context, LAYER_NAME)
	if pair.is_empty():
		return
	var layer := pair[0] as CanvasLayer
	var rect := pair[1] as ColorRect

	var effective_blur := intensity * intensity_mult
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("blur_amount", 0.0)
	rect.material = material

	var tween := _track(layer.create_tween())
	tween.tween_method(
		func(v: float) -> void: material.set_shader_parameter("blur_amount", v),
		0.0, effective_blur, duration * 0.3
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if fade_out:
		tween.tween_method(
			func(v: float) -> void: material.set_shader_parameter("blur_amount", v),
			effective_blur, 0.0, duration * 0.7
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		tween.tween_interval(duration * 0.7)

	await tween.finished
	# fade_out=false means "stays at peak" - keep the overlay alive instead of freeing it.
	if fade_out and is_instance_valid(layer):
		layer.queue_free()
