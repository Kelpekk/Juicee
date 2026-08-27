@tool
class_name JuiceeChromaticEffect
extends JuiceeEffect

## Pixel offset between R / G / B channels - higher = more obvious distortion.
@export_range(0.0, 20.0, 0.1) var intensity: float = 5.0
## Duration of the effect with fade-out to zero.
@export_range(0.05, 2.0, 0.05) var duration: float = 0.2

const SHADER: Shader = preload("res://addons/juicee/shaders/chromatic.gdshader")
const LAYER_NAME := &"_juicee_chromatic_overlay"

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_CHROMATIC

func _apply(context: Node, intensity_mult: float) -> void:
	var pair := _spawn_screen_shader_overlay(context, LAYER_NAME)
	if pair.is_empty():
		return
	var layer := pair[0] as CanvasLayer
	var rect := pair[1] as ColorRect

	var effective_intensity := intensity * intensity_mult
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("intensity", effective_intensity)
	rect.material = material

	var tween := _track(layer.create_tween())
	tween.tween_method(
		func(v: float) -> void: material.set_shader_parameter("intensity", v),
		effective_intensity, 0.0, duration
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	await tween.finished
	if is_instance_valid(layer):
		layer.queue_free()
