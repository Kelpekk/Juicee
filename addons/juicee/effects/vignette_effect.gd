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

const SHADER: Shader = preload("res://addons/juicee/shaders/vignette.gdshader")
const LAYER_NAME := &"_juicee_vignette_overlay"

func _apply(context: Node, intensity_mult: float) -> void:
	var pair := _spawn_screen_shader_overlay(context, LAYER_NAME, 127)
	if pair.is_empty():
		return
	var layer := pair[0] as CanvasLayer
	var rect := pair[1] as ColorRect

	var effective_intensity := clamp(intensity * intensity_mult, 0.0, 1.0)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("intensity", 0.0)
	material.set_shader_parameter("softness", softness)
	material.set_shader_parameter("vignette_color", vignette_color)
	rect.material = material

	var tween := _track(layer.create_tween())
	tween.tween_method(
		func(v: float) -> void: material.set_shader_parameter("intensity", v),
		0.0, effective_intensity, duration * 0.3
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if fade_out:
		tween.tween_method(
			func(v: float) -> void: material.set_shader_parameter("intensity", v),
			effective_intensity, 0.0, duration * 0.7
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		tween.tween_interval(duration * 0.7)

	await tween.finished
	# fade_out=false means "stays at peak" - keep the overlay alive instead of freeing it.
	if fade_out and is_instance_valid(layer):
		layer.queue_free()
