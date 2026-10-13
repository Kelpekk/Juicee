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

@export_group("Advanced")
## Hand-drawn curve (0..1) shaping how the glitch decays. FEEL-style curve control.
@export var intensity_curve: Curve
## Seconds to hold at full glitch before it decays. 0 = decay immediately.
@export_range(0.0, 10.0, 0.05) var hold_time: float = 0.0
## Break the glitch into this many stuttering bursts with clean gaps between them,
## instead of one smooth decay. 1 = the classic single hit; 4+ = a broken-signal state.
@export_range(1, 12, 1) var bursts: int = 1

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["intensity_curve", "hold_time", "bursts"]))

const SHADER: Shader = preload("res://addons/juicee/shaders/glitch.gdshader")
const LAYER_NAME := &"_juicee_glitch_overlay"

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_CHROMATIC

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
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
	if hold_time > 0.0:
		tween.tween_interval(hold_time)
	var n: int = _capped(maxi(1, bursts), 1000, "bursts")
	if n > 1:
		# Stuttering bursts: each fires briefly then cuts to clean, with a new tear
		# pattern per burst, for a broken-signal state instead of one smooth decay.
		var span: float = duration / float(n)
		for i in n:
			var level: float = effective_strength * (1.0 - float(i) / float(n) * 0.5)
			tween.tween_callback(func() -> void:
				if is_instance_valid(material):
					material.set_shader_parameter("time_offset", randf() * 100.0)
					material.set_shader_parameter("strength", level))
			tween.tween_interval(span * 0.55)
			tween.tween_callback(func() -> void: _set_strength(0.0, material))
			tween.tween_interval(span * 0.45)
	elif intensity_curve:
		tween.tween_method(func(t: float) -> void:
			_set_strength(effective_strength * intensity_curve.sample(1.0 - t), material),
			0.0, 1.0, duration)
	else:
		tween.tween_method(_set_strength.bind(material), effective_strength, 0.0, duration)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	await tween.finished
	if _gen != play:
		return
	if is_instance_valid(layer):
		layer.queue_free()

func _set_strength(value: float, mat: ShaderMaterial) -> void:
	if is_instance_valid(mat):
		mat.set_shader_parameter("strength", value)
