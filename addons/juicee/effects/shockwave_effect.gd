## Expanding radial distortion ring from the context node's position on screen.
##
## Use for: explosions, teleport arrivals, magic spell impacts, landing
## slams, sub-bass pulse beats. FEEL's `MMFShockwave` parity.
##
## Animates the ring radius from 0 -> max_radius over `duration`, with the
## distortion strength fading out as the ring expands. The origin is the
## context node's screen position when it is a Node2D, the screen centre otherwise.
@tool
class_name JuiceeShockwaveEffect
extends JuiceeEffect

const SHADER: Shader = preload("res://addons/juicee/shaders/shockwave.gdshader")
const LAYER_NAME := &"_juicee_shockwave_overlay"

## Maximum ring radius, in screen heights. From the centre of a 16:9 screen, 0.5 reaches the top and bottom, about 0.9 the sides.
@export_range(0.1, 2.0, 0.05) var max_radius: float = 0.6
## Width of the distortion band (fraction of screen height). 0.04 is a tight sharp ring.
@export_range(0.005, 0.3, 0.005) var ring_width: float = 0.04
## Peak UV displacement at the ring centre. Higher = more dramatic warp.
@export_range(0.002, 0.15, 0.002) var strength: float = 0.025
## Total animation duration in seconds.
@export_range(0.1, 3.0, 0.05) var duration: float = 0.5
## Optional easing curve for the radius expansion (null = ease-out quad).
@export var radius_curve: Curve

@export_group("Advanced")
## How sharply the distortion falls off across the ring band. Low (1-3) = a soft wide
## swell; high (12+) = a thin hard-edged shock front.
@export_range(1.0, 32.0, 0.5) var falloff: float = 6.0
## Send this many rings out one after another, each weaker than the last, for a
## rolling aftershock. 1 = a single wave.
@export_range(1, 6, 1) var ripples: int = 1
## Delay between successive ripples, as a fraction of the duration.
@export_range(0.05, 0.9, 0.05) var ripple_spacing: float = 0.25

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["falloff", "ripples", "ripple_spacing"]))

func get_category_name() -> String:
	return "Screen"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var result := _spawn_screen_shader_overlay(context, LAYER_NAME, 200)
	if result.is_empty():
		return
	var layer: CanvasLayer = result[0]
	var rect: ColorRect   = result[1]

	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("radius", 0.0)
	mat.set_shader_parameter("width", ring_width)
	mat.set_shader_parameter("strength", strength * intensity_mult)
	mat.set_shader_parameter("falloff", falloff)
	rect.material = mat

	# Compute the origin in screen-UV from the context node's global position.
	var origin_uv := Vector2(0.5, 0.5)
	if context is Node2D:
		var vp := context.get_viewport()
		if vp:
			var screen_pos: Vector2 = (context as Node2D).get_global_transform_with_canvas().origin
			var vp_size := vp.get_visible_rect().size
			if vp_size.x > 0 and vp_size.y > 0:
				origin_uv = screen_pos / vp_size
				origin_uv = origin_uv.clamp(Vector2.ZERO, Vector2.ONE)
	mat.set_shader_parameter("origin_uv", origin_uv)

	var tree := context.get_tree()
	# One sweep per ripple; each aftershock is weaker, with a gap between them. The
	# default (ripples = 1) is a single wave, exactly as before.
	var wave_count: int = _capped(maxi(1, ripples), 64, "ripples")
	for w in wave_count:
		if not is_instance_valid(rect):
			break
		var wave_strength: float = strength * intensity_mult * pow(0.6, w)
		var elapsed := 0.0
		while elapsed < duration and _gen == play and is_instance_valid(rect):
			var t := elapsed / duration
			var r: float
			if radius_curve:
				r = radius_curve.sample(t) * max_radius
			else:
				r = (1.0 - pow(1.0 - t, 2.0)) * max_radius
			# Strength also fades out as the ring expands.
			var fade := 1.0 - t
			mat.set_shader_parameter("radius", r)
			mat.set_shader_parameter("strength", wave_strength * fade)
			await tree.process_frame
			if _gen != play:
				return
			elapsed += tree.root.get_process_delta_time()
		if w < wave_count - 1:
			mat.set_shader_parameter("strength", 0.0)
			await tree.create_timer(duration * ripple_spacing, true, false, false).timeout
			if _gen != play:
				return

	if is_instance_valid(layer):
		layer.queue_free()
