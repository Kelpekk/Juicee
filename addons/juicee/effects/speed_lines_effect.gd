## Anime "speed lines" full-screen overlay - radial streaks converging on the
## centre of the screen. Sells bursts of speed, dashes, focus/shock moments and
## big impacts. Works in 2D and 3D viewports (CanvasLayer overlay).
@tool
class_name JuiceeSpeedLinesEffect
extends JuiceeEffect

const SHADER: Shader = preload("res://addons/juicee/shaders/speed_lines.gdshader")
const LAYER_NAME := &"_juicee_speed_lines_overlay"

## Angular streak count - higher = more, thinner lines.
@export_range(20.0, 400.0, 1.0) var density: float = 140.0
## Peak opacity of the streaks.
@export_range(0.0, 1.0, 0.01) var strength: float = 0.5
## Radius (0..1) of the clear zone in the middle (keeps the focal point readable).
@export_range(0.0, 0.9, 0.01) var center_clear: float = 0.35
## Streak colour - white = speed, black = shock/focus.
@export var line_color: Color = Color.WHITE
## Animation rate - subtle shimmer of the streaks. 0 = static.
@export_range(0.0, 20.0, 0.1) var anim_speed: float = 6.0
## Total effect duration in seconds.
@export_range(0.1, 30.0, 0.1) var duration: float = 0.4
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
	mat.set_shader_parameter("density", density)
	mat.set_shader_parameter("strength", 0.0)
	mat.set_shader_parameter("center_clear", center_clear)
	mat.set_shader_parameter("line_color", line_color)
	mat.set_shader_parameter("speed", anim_speed)
	rect.material = mat

	var tree := context.get_tree()
	var elapsed := 0.0
	var peak := strength * intensity_mult
	var fade_in_end := duration * 0.1
	var fade_out_start := duration * 0.9

	while elapsed < duration and not _cancelled and is_instance_valid(rect):
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
