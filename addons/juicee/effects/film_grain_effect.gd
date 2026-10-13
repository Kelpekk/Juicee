## Animated film grain noise full-screen overlay.
##
## Use for: cinematic cutscenes, horror, gritty war games, found-footage,
## old photograph feel, night-vision scope, VHS recordings.
@tool
class_name JuiceeFilmGrainEffect
extends JuiceeEffect

const SHADER: Shader = preload("res://addons/juicee/shaders/film_grain.gdshader")
const LAYER_NAME := &"_juicee_film_grain_overlay"

## Grain intensity. 0.15 = cinematic, 0.35 = heavy VHS noise, 0.5 = broken signal.
@export_range(0.0, 1.0, 0.01) var strength: float = 0.15
## Grain animation rate in frames per second (15 = classic film, 24 = digital).
@export_range(1.0, 60.0, 1.0) var speed: float = 15.0
## Total effect duration in seconds.
@export_range(0.1, 30.0, 0.1) var duration: float = 2.0
## Fade strength out at end of duration.
@export var fade_out: bool = true

@export_group("Advanced")
## Hand-drawn curve (0..1) shaping the grain strength over the whole duration, so it can
## surge and settle instead of holding flat. FEEL-style curve control.
@export var intensity_curve: Curve
## Run until stop() is called, ignoring Duration. For a permanent film / VHS look.
@export var loop: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["intensity_curve", "loop"]))

func get_category_name() -> String: return "Screen"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var result := _spawn_screen_shader_overlay(context, LAYER_NAME, 200)
	if result.is_empty():
		return
	var layer: CanvasLayer = result[0]
	var rect: ColorRect = result[1]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("strength", 0.0)
	mat.set_shader_parameter("speed", speed)
	rect.material = mat

	var tree := context.get_tree()
	var elapsed := 0.0
	var peak := strength * intensity_mult
	var fade_in_end := duration * 0.1
	var fade_out_start := duration * 0.9

	while (loop or elapsed < duration) and _gen == play and is_instance_valid(rect):
		var s: float
		if loop:
			# A permanent grain look: hold at peak (or follow the curve) with no fades.
			s = peak * (intensity_curve.sample(fposmod(elapsed / duration, 1.0)) if intensity_curve else 1.0)
		elif intensity_curve:
			s = peak * intensity_curve.sample(elapsed / duration)
		elif elapsed < fade_in_end:
			s = peak * (elapsed / fade_in_end)
		elif fade_out and elapsed > fade_out_start:
			s = peak * ((duration - elapsed) / (duration - fade_out_start))
		else:
			s = peak
		mat.set_shader_parameter("strength", s)
		await tree.process_frame
		if _gen != play:
			return
		elapsed += tree.root.get_process_delta_time()

	# A newer play or stop() holds what this one held.
	if _gen != play:
		return
	if is_instance_valid(layer):
		layer.queue_free()
