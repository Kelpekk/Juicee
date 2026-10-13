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

@export_group("Advanced")
## Seconds to hold the graded look before it fades back. 0 = fade straight back.
@export_range(0.0, 30.0, 0.05) var hold_time: float = 0.0
## Fraction of the duration spent grading in. 0.3 = a quick grade, slow release.
@export_range(0.05, 0.95, 0.05) var ramp_in_ratio: float = 0.3

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["hold_time", "ramp_in_ratio"]))

const SHADER: Shader = preload("res://addons/juicee/shaders/color_grade.gdshader")
const LAYER_NAME := &"_juicee_color_grade_overlay"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
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

	# Part strength grades only part of the way.
	var sat: float = maxf(0.0, lerpf(1.0, saturation, intensity_mult))
	var con: float = maxf(0.0, lerpf(1.0, contrast, intensity_mult))
	var bri: float = brightness * intensity_mult
	var tin: Vector3 = Vector3.ONE.lerp(Vector3(tint.r, tint.g, tint.b), intensity_mult)
	var in_t: float = duration * ramp_in_ratio
	var out_t: float = duration * (1.0 - ramp_in_ratio)
	var tween: Tween = _track(layer.create_tween()).set_parallel(true)
	tween.tween_method(_set_param.bind(material, "saturation"), 1.0, sat, in_t)
	tween.tween_method(_set_param.bind(material, "contrast"),   1.0, con, in_t)
	tween.tween_method(_set_param.bind(material, "brightness"), 0.0, bri, in_t)
	tween.tween_method(_set_tint.bind(material), Vector3(1.0, 1.0, 1.0), tin, in_t)

	if fade_out:
		var back: Tween = _track(layer.create_tween()).set_parallel(true)
		# Advanced hold_time keeps the graded look on screen before it releases.
		var out_at: float = in_t + hold_time
		back.tween_method(_set_param.bind(material, "saturation"), sat, 1.0, out_t).set_delay(out_at)
		back.tween_method(_set_param.bind(material, "contrast"),   con, 1.0, out_t).set_delay(out_at)
		back.tween_method(_set_param.bind(material, "brightness"), bri, 0.0, out_t).set_delay(out_at)
		back.tween_method(_set_tint.bind(material), tin, Vector3(1.0, 1.0, 1.0), out_t).set_delay(out_at)
		await back.finished
		if _gen != play:
			return
	else:
		await tween.finished
		if _gen != play:
			return
		await context.get_tree().create_timer(out_t + hold_time, true, false, false).timeout
		if _gen != play:
			return

	# fade_out=false means "holds at target values" - keep the overlay alive. stop() takes it down.
	if is_instance_valid(layer):
		if fade_out:
			layer.queue_free()
		else:
			_free_when_released(layer)

func _set_param(value: float, mat: ShaderMaterial, param: String) -> void:
	if is_instance_valid(mat):
		mat.set_shader_parameter(param, value)

func _set_tint(value: Vector3, mat: ShaderMaterial) -> void:
	if is_instance_valid(mat):
		mat.set_shader_parameter("tint", value)
