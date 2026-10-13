## Full-screen blur - pause menus, dream sequences, knockout effects.
@tool
class_name JuiceeBlurEffect
extends JuiceeEffect

## Peak blur intensity in pixels (a 3x3 weighted kernel).
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

@export_group("Advanced")
## Hand-drawn curve (0..1) shaping how the blur ramps in. FEEL-style curve control.
@export var intensity_curve: Curve
## Seconds to hold at full blur before it fades. 0 = ramp straight back out.
@export_range(0.0, 10.0, 0.05) var hold_time: float = 0.0
## Fraction of the duration spent ramping in. 0.3 = a quick blur-in, long fade-out.
@export_range(0.05, 0.95, 0.05) var ramp_in_ratio: float = 0.3

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["intensity_curve", "hold_time", "ramp_in_ratio"]))

const SHADER: Shader = preload("res://addons/juicee/shaders/blur.gdshader")
const LAYER_NAME := &"_juicee_blur_overlay"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
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

	var setter := func(v: float) -> void: material.set_shader_parameter("blur_amount", v)
	var in_t: float = duration * ramp_in_ratio
	var out_t: float = duration * (1.0 - ramp_in_ratio)
	var tween := _track(layer.create_tween())
	# intensity_curve (advanced) shapes the ramp-in when set.
	if intensity_curve:
		tween.tween_method(func(t: float) -> void:
			setter.call(effective_blur * intensity_curve.sample(t)), 0.0, 1.0, in_t)
	else:
		tween.tween_method(setter, 0.0, effective_blur, in_t)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold_time > 0.0:
		tween.tween_interval(hold_time)

	if fade_out:
		tween.tween_method(setter, effective_blur, 0.0, out_t)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		tween.tween_interval(out_t)

	await tween.finished
	if _gen != play:
		return
	# fade_out=false means "stays at peak" - keep the overlay alive instead of freeing it. stop() takes it down.
	if is_instance_valid(layer):
		if fade_out:
			layer.queue_free()
		else:
			_free_when_released(layer)
