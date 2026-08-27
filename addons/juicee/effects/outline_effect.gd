## Animate a colored outline around a CanvasItem (typically a Sprite2D).
##
## Use for: lock-on selection rings, "interactable" highlights, status
## effect indicators (poisoned = green, burning = red, frozen = cyan),
## focus emphasis in UI.
##
## Wraps the target's existing material temporarily - restores the original
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

func get_category_name() -> String:
	return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: CanvasItem = context as CanvasItem
	if not target or not target.is_inside_tree():
		push_warning("JuiceeOutlineEffect: context is not a CanvasItem")
		return

	# Save the original material so we can restore it.
	var original_material: Material = target.material
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("outline_width", 0.0)
	mat.set_shader_parameter("outline_color", outline_color)
	target.material = mat

	var peak_width: float = outline_width * intensity_mult
	var tween := _track(target.create_tween())
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("outline_width", v),
		0.0, peak_width, duration * 0.25
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if fade_out:
		tween.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("outline_width", v),
			peak_width, 0.0, duration * 0.75
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		tween.tween_interval(duration * 0.75)

	await tween.finished
	# Only restore the material when fading out. With fade_out=false the outline is
	# meant to persist (the caller cleans up later) - restoring here would erase it.
	if fade_out and is_instance_valid(target):
		target.material = original_material
