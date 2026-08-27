## Full-screen color grading - temporarily shift saturation, contrast, brightness, tint.
## Great for damage (desaturate), level-up (boost saturation), boss intro (warm tint).
@tool
class_name JuiceeColorGradeEffect
extends JuiceeEffect

## Color saturation. 0 = grayscale, 1 = normal, >1 = oversaturated.
@export_range(0.0, 3.0, 0.05) var saturation: float = 0.5
## Contrast around midpoint. 1 = normal, <1 = muddy, >1 = punchy.
@export_range(0.0, 3.0, 0.05) var contrast: float = 1.0
## Additive brightness offset (-1 = black, 0 = normal, +1 = white).
@export_range(-1.0, 1.0, 0.01) var brightness: float = 0.0
## Color tint multiplier (e.g., red for damage, warm orange for sunset).
@export var tint: Color = Color.WHITE
## Total duration including ramp-in and ramp-out.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.8
## If true, color grading lerps back to neutral. If false, holds at target values.
@export var fade_out: bool = true

const SHADER: Shader = preload("res://addons/juicee/shaders/color_grade.gdshader")
const LAYER_NAME := &"_juicee_color_grade_overlay"

func _apply(context: Node, _intensity_mult: float) -> void:
	var pair := _spawn_screen_shader_overlay(context, LAYER_NAME)
	if pair.is_empty():
		return
	var layer := pair[0] as CanvasLayer
	var rect := pair[1] as ColorRect

	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("saturation", 1.0)
	material.set_shader_parameter("contrast", 1.0)
	material.set_shader_parameter("brightness", 0.0)
	material.set_shader_parameter("tint", Vector3(1.0, 1.0, 1.0))
	rect.material = material

	var tween: Tween = _track(layer.create_tween()).set_parallel(true)
	tween.tween_method(_set_param.bind(material, "saturation"), 1.0, saturation, duration * 0.3)
	tween.tween_method(_set_param.bind(material, "contrast"),   1.0, contrast,   duration * 0.3)
	tween.tween_method(_set_param.bind(material, "brightness"), 0.0, brightness, duration * 0.3)
	tween.tween_method(_set_tint.bind(material), Vector3(1.0, 1.0, 1.0), Vector3(tint.r, tint.g, tint.b), duration * 0.3)

	if fade_out:
		var back: Tween = _track(layer.create_tween()).set_parallel(true)
		var delay: float = duration * 0.3
		back.tween_method(_set_param.bind(material, "saturation"), saturation, 1.0, duration * 0.7).set_delay(delay)
		back.tween_method(_set_param.bind(material, "contrast"),   contrast,   1.0, duration * 0.7).set_delay(delay)
		back.tween_method(_set_param.bind(material, "brightness"), brightness, 0.0, duration * 0.7).set_delay(delay)
		back.tween_method(_set_tint.bind(material), Vector3(tint.r, tint.g, tint.b), Vector3(1.0, 1.0, 1.0), duration * 0.7).set_delay(delay)
		await back.finished
	else:
		await tween.finished
		await context.get_tree().create_timer(duration * 0.7, true, false, false).timeout

	# fade_out=false means "holds at target values" - keep the overlay alive.
	if fade_out and is_instance_valid(layer):
		layer.queue_free()

func _set_param(value: float, mat: ShaderMaterial, param: String) -> void:
	if is_instance_valid(mat):
		mat.set_shader_parameter(param, value)

func _set_tint(value: Vector3, mat: ShaderMaterial) -> void:
	if is_instance_valid(mat):
		mat.set_shader_parameter("tint", value)
