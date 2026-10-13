@tool
class_name JuiceeVignetteEffect
extends JuiceeEffect

## Darkness at the screen edges (0 = invisible, 1 = solid).
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.6
## How feathered the vignette edge is. 0 = hard edge, 1 = very soft falloff.
@export_range(0.0, 1.0, 0.01) var softness: float = 0.45
## Color tint of the vignette. Default is black, but try red for damage / gold for power-up.
@export var vignette_color: Color = Color(0.0, 0.0, 0.0, 1.0)
## Total duration including fade-in and fade-out.
@export_range(0.1, 5.0, 0.05) var duration: float = 0.8
## If true, vignette fades back to 0 at the end. If false, it stays at peak.
@export var fade_out: bool = true

@export_group("Advanced")
## Hand-drawn curve (0..1) shaping the fade-in. FEEL-style curve control.
@export var intensity_curve: Curve
## Seconds to hold at full darkness before fading. 0 = fade straight back.
@export_range(0.0, 30.0, 0.05) var hold_time: float = 0.0
## Throb in and out this many times across the duration instead of one fade in / out.
## 3+ with a red colour is the classic low-health pulse.
@export_range(1, 20, 1) var pulse_count: int = 1

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["intensity_curve", "hold_time", "pulse_count"]))

const SHADER: Shader = preload("res://addons/juicee/shaders/vignette.gdshader")
const LAYER_NAME := &"_juicee_vignette_overlay"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var pair := _spawn_screen_shader_overlay(context, LAYER_NAME, 127)
	if pair.is_empty():
		return
	var layer := pair[0] as CanvasLayer
	var rect := pair[1] as ColorRect

	var effective_intensity := clampf(intensity * intensity_mult, 0.0, 1.0)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("intensity", 0.0)
	material.set_shader_parameter("softness", softness)
	material.set_shader_parameter("vignette_color", vignette_color)
	rect.material = material

	var setter := func(v: float) -> void: material.set_shader_parameter("intensity", v)
	var tween := _track(layer.create_tween())
	var pulses: int = _capped(maxi(1, pulse_count), 1000, "pulse_count")
	var span: float = duration / float(pulses)
	# Each pulse fades in and back out; the last one honours hold_time / fade_out, so a
	# single pulse (the default) behaves exactly as before.
	for i in pulses:
		var is_last: bool = (i == pulses - 1)
		if intensity_curve:
			tween.tween_method(func(t: float) -> void:
				setter.call(effective_intensity * intensity_curve.sample(t)), 0.0, 1.0, span * 0.3)
		else:
			tween.tween_method(setter, 0.0, effective_intensity, span * 0.3)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if is_last and hold_time > 0.0:
			tween.tween_interval(hold_time)
		if fade_out or not is_last:
			tween.tween_method(setter, effective_intensity, 0.0, span * 0.7)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		else:
			tween.tween_interval(span * 0.7)

	await tween.finished
	if _gen != play:
		return
	# fade_out=false means "stays at peak" - keep the overlay alive instead of freeing it. stop() takes it down.
	if is_instance_valid(layer):
		if fade_out:
			layer.queue_free()
		else:
			_free_when_released(layer)
