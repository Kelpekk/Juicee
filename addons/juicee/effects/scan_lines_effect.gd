## CRT scanlines full-screen overlay.
##
## Use for: retro monitor, broken TV, damaged HUD, hacking vibes, old-film cutscene.
## Works in 2D and 3D viewports (CanvasLayer overlay).
@tool
class_name JuiceeScanLinesEffect
extends JuiceeEffect

const SHADER: Shader = preload("res://addons/juicee/shaders/scanlines.gdshader")
const LAYER_NAME := &"_juicee_scanlines_overlay"

## Number of horizontal bands across the screen height. 300 = classic CRT density.
@export_range(50.0, 1000.0, 5.0) var line_count: float = 300.0
## How dark each alternate band gets. 0 = invisible, 1 = fully black bands.
@export_range(0.0, 1.0, 0.01) var strength: float = 0.25
## Vertical scroll speed in cycles per second. 0 = static bands.
@export_range(0.0, 5.0, 0.05) var scroll_speed: float = 0.0
## Total effect duration in seconds.
@export_range(0.1, 30.0, 0.1) var duration: float = 2.0
## Fade strength out over the last 10% of duration.
@export var fade_out: bool = true

func get_category_name() -> String: return "Screen"

func _apply(context: Node, intensity_mult: float) -> void:
	var result := _spawn_screen_shader_overlay(context, LAYER_NAME, 200)
	if result.is_empty():
		return
	var layer: CanvasLayer = result[0]
	var rect: ColorRect = result[1]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("line_count", line_count)
	mat.set_shader_parameter("strength", 0.0)
	mat.set_shader_parameter("scroll_speed", scroll_speed)
	rect.material = mat

	var tree := context.get_tree()
	var elapsed := 0.0
	var peak := strength * intensity_mult
	var fade_in_end := duration * 0.1
	var fade_out_start := duration * 0.9

	while elapsed < duration and not _cancelled and is_instance_valid(rect):
		var t := elapsed / duration
		var s: float
		if elapsed < fade_in_end:
			s = peak * (elapsed / fade_in_end)
		elif fade_out and elapsed > fade_out_start:
			s = peak * ((duration - elapsed) / (duration - fade_out_start))
		else:
			s = peak
		mat.set_shader_parameter("strength", s)
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()

	if is_instance_valid(layer):
		layer.queue_free()
