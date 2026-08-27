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

const SHADER: Shader = preload("res://addons/juicee/shaders/pixelate.gdshader")
const LAYER_NAME := &"_juicee_pixelate_overlay"

func _apply(context: Node, intensity_mult: float) -> void:
	var pair := _spawn_screen_shader_overlay(context, LAYER_NAME)
	if pair.is_empty():
		return
	var layer := pair[0] as CanvasLayer
	var rect := pair[1] as ColorRect

	var effective_pixel := max(1.0, pixel_size * intensity_mult)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("pixel_size", effective_pixel)
	rect.material = material

	var tween := _track(layer.create_tween())
	if fade_out:
		tween.tween_method(
			func(v: float) -> void: material.set_shader_parameter("pixel_size", v),
			effective_pixel, 1.0, duration
		).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_interval(duration)

	await tween.finished
	# fade_out=false means "holds" - keep the overlay alive instead of freeing it.
	if fade_out and is_instance_valid(layer):
		layer.queue_free()
