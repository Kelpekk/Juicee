## Full-screen digital glitch - horizontal tear + chromatic split.
## Perfect for damage hits, hacking moments, system-broken vibes.
@tool
class_name JuiceeGlitchEffect
extends JuiceeEffect

## Peak glitch intensity (0 = none, 1 = chaotic tear + chromatic split).
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.5
## How long the glitch effect lasts before fading out.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3

# Back-compat: old .tres files used `strength`. Route writes to `intensity`.
func _set(property: StringName, value) -> bool:
	if property == &"strength":
		intensity = value
		return true
	return false

const SHADER: Shader = preload("res://addons/juicee/shaders/glitch.gdshader")
const LAYER_NAME := &"_juicee_glitch_overlay"

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_CHROMATIC

func _apply(context: Node, intensity_mult: float) -> void:
	var pair := _spawn_screen_shader_overlay(context, LAYER_NAME)
	if pair.is_empty():
		return
	var layer := pair[0] as CanvasLayer
	var rect := pair[1] as ColorRect

	var effective_strength: float = clamp(intensity * intensity_mult, 0.0, 1.0)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("strength", effective_strength)
	material.set_shader_parameter("time_offset", randf() * 100.0)
	rect.material = material

	var tween: Tween = _track(layer.create_tween())
	tween.tween_method(_set_strength.bind(material), effective_strength, 0.0, duration)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	await tween.finished
	if is_instance_valid(layer):
		layer.queue_free()

func _set_strength(value: float, mat: ShaderMaterial) -> void:
	if is_instance_valid(mat):
		mat.set_shader_parameter("strength", value)
