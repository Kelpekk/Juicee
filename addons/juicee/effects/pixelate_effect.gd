## Full-screen pixelation effect - great for damage hits, glitch moments, retro flashes.
@tool
class_name JuiceePixelateEffect
extends JuiceeEffect

## Starting pixel size in screen pixels - higher = chunkier.
@export_range(1.0, 64.0, 1.0) var pixel_size: float = 8.0
## How long the pixelation effect lasts.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.4
## If true, pixel size tweens from peak back to 1 (resolves to normal). If false, holds.
@export var fade_out: bool = true

@export_group("Advanced")
## Hand-drawn curve (0..1) shaping how the pixels resolve back to normal. FEEL-style.
@export var intensity_curve: Curve
## Seconds to hold at full chunkiness before resolving. 0 = resolve immediately.
@export_range(0.0, 10.0, 0.05) var hold_time: float = 0.0
## Resolve in this many hard steps instead of smoothly, for a retro "loading" feel.
## 0 = smooth (the default).
@export_range(0, 12, 1) var steps: int = 0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["intensity_curve", "hold_time", "steps"]))

const SHADER: Shader = preload("res://addons/juicee/shaders/pixelate.gdshader")
const LAYER_NAME := &"_juicee_pixelate_overlay"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var pair := _spawn_screen_shader_overlay(context, LAYER_NAME)
	if pair.is_empty():
		return
	var layer := pair[0] as CanvasLayer
	var rect := pair[1] as ColorRect

	var effective_pixel := maxf(1.0, pixel_size * intensity_mult)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("pixel_size", effective_pixel)
	rect.material = material

	var setter := func(v: float) -> void: material.set_shader_parameter("pixel_size", v)
	var tween := _track(layer.create_tween())
	if hold_time > 0.0:
		tween.tween_interval(hold_time)
	if fade_out:
		if steps > 0:
			# Hard steps: snap down through `steps` chunk sizes instead of a smooth ramp.
			var step_count := _capped(steps, 1000, "steps")
			var per: float = duration / float(step_count)
			for i in range(1, step_count + 1):
				var v: float = lerpf(effective_pixel, 1.0, float(i) / float(step_count))
				tween.tween_callback(setter.bind(v))
				tween.tween_interval(per)
		elif intensity_curve:
			tween.tween_method(func(t: float) -> void:
				setter.call(lerpf(effective_pixel, 1.0, intensity_curve.sample(t))), 0.0, 1.0, duration)
		else:
			tween.tween_method(setter, effective_pixel, 1.0, duration)\
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_interval(duration)

	await tween.finished
	if _gen != play:
		return
	# fade_out=false means "holds" - keep the overlay alive instead of freeing it. stop() takes it down.
	if is_instance_valid(layer):
		if fade_out:
			layer.queue_free()
		else:
			_free_when_released(layer)
