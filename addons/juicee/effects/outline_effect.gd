## Animate a colored outline around a CanvasItem (typically a Sprite2D).
##
## Use for: lock-on selection rings, "interactable" highlights, status
## effect indicators (poisoned = green, burning = red, frozen = cyan),
## focus emphasis in UI.
##
## Swaps in its own material for the play - restores the original
## material when done. Pairs nicely with TextWobble or FloatingText for
## "ENEMY SPOTTED" callouts.
@tool
class_name JuiceeOutlineEffect
extends JuiceeEffect

const SHADER: Shader = preload("res://addons/juicee/shaders/outline.gdshader")

## Peak outline width in pixels.
@export_range(0.0, 16.0, 0.1) var outline_width: float = 2.0
## Outline color.
@export var outline_color: Color = Color(1.0, 0.85, 0.20, 1.0)
## Duration: ramp-in + hold + ramp-out.
@export_range(0.05, 10.0, 0.05) var duration: float = 0.8
## If true, outline fades back to 0 at end. If false, holds (caller cleans up
## with a follow-up effect or `target.material = null`).
@export var fade_out: bool = true

@export_group("Advanced")
## Pulse the outline in and out this many times across the duration, instead of one
## ramp-in / ramp-out. 1 = a single ramp; 3+ = a throbbing lock-on ring.
@export_range(1, 12, 1) var pulse_count: int = 1
## Seconds to hold the outline at full width before it fades.
@export_range(0.0, 5.0, 0.05) var hold_time: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["pulse_count", "hold_time"]))

func get_category_name() -> String:
	return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: CanvasItem = context as CanvasItem
	if not target or not target.is_inside_tree():
		_warn("JuiceeOutlineEffect: context is not a CanvasItem")
		return
	# The outline is drawn around a texture's opaque pixels, by a material on the node that draws
	# it. On a Node2D above the sprite it drew nothing, and on a Label or a Button it turned the
	# glyphs into yellow blocks.
	var want := get_required_nodes()
	if not want.is_empty() and not _matches_any(target, want):
		_warn("JuiceeOutlineEffect: %s draws no texture to outline. It needs a Sprite2D, " % target.name
				+ "AnimatedSprite2D, TextureRect, TextureButton or NinePatchRect, on it or near it.")
		return

	var play := _gen
	# The node's own material, from the stack: stop() mid-play and a second outline started on
	# this one both come back to it, rather than to the first outline's material.
	_capture_state(target, "material")
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("outline_width", 0.0)
	mat.set_shader_parameter("outline_color", outline_color)
	target.material = mat

	var peak_width: float = outline_width * intensity_mult
	var setter := func(v: float) -> void: mat.set_shader_parameter("outline_width", v)
	var tween := _track(target.create_tween())
	var pulses: int = _capped(maxi(1, pulse_count), 1000, "pulse_count")
	# Each pulse ramps in and back out; the last one honours hold_time / fade_out so a
	# single pulse (the default) behaves exactly as before.
	var span: float = duration / float(pulses)
	for i in pulses:
		var is_last: bool = (i == pulses - 1)
		tween.tween_method(setter, 0.0, peak_width, span * 0.25)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if is_last and hold_time > 0.0:
			tween.tween_interval(hold_time)
		if fade_out or not is_last:
			tween.tween_method(setter, peak_width, 0.0, span * 0.75)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		else:
			tween.tween_interval(span * 0.75)

	await tween.finished
	if _gen != play:
		return
	# Only restore the material when fading out. With fade_out=false the outline is meant to
	# persist: the material stays held, and stop() gives it back.
	if fade_out:
		_release_state(target, "material")
