@tool
class_name JuiceeChromaticEffect
extends JuiceeEffect

## Pixel offset between R / G / B channels - higher = more obvious distortion.
@export_range(0.0, 20.0, 0.1) var intensity: float = 5.0
## Duration of the effect with fade-out to zero.
@export_range(0.05, 2.0, 0.05) var duration: float = 0.2

@export_group("Advanced")
## Hand-drawn curve (0..1) shaping how the split decays. FEEL-style curve control.
@export var intensity_curve: Curve
## Seconds to hold the split at full strength before it decays. 0 = decay immediately.
@export_range(0.0, 10.0, 0.05) var hold_time: float = 0.0
## Wobble the split this many times while it decays, for an unstable-signal look.
## 0 = a clean single decay.
@export_range(0.0, 20.0, 0.5) var oscillations: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["intensity_curve", "hold_time", "oscillations"]))

const SHADER: Shader = preload("res://addons/juicee/shaders/chromatic.gdshader")
const LAYER_NAME := &"_juicee_chromatic_overlay"

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_CHROMATIC

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
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

	var setter := func(v: float) -> void: material.set_shader_parameter("intensity", v)
	var tween := _track(layer.create_tween())
	if hold_time > 0.0:
		tween.tween_interval(hold_time)
	if oscillations > 0.0:
		# Wobble on the way down: an unstable signal rather than one clean decay.
		tween.tween_method(func(t: float) -> void:
			var env: float = intensity_curve.sample(1.0 - t) if intensity_curve else (1.0 - t)
			var wob: float = 0.5 + 0.5 * cos(t * TAU * oscillations)
			setter.call(effective_intensity * env * wob), 0.0, 1.0, duration)
	elif intensity_curve:
		tween.tween_method(func(t: float) -> void:
			setter.call(effective_intensity * intensity_curve.sample(1.0 - t)), 0.0, 1.0, duration)
	else:
		tween.tween_method(setter, effective_intensity, 0.0, duration)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	await tween.finished
	if _gen != play:
		return
	if is_instance_valid(layer):
		layer.queue_free()
