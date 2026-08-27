## Full-screen colored overlay that fades in then out.
## Great for damage red flash, level-up gold flash, etc.
@tool
class_name JuiceeScreenTintEffect
extends JuiceeEffect

## Color of the full-screen overlay. Alpha controls peak opacity.
## Common presets: red for damage, gold for level-up, blue for water hit.
@export var tint_color: Color = Color(1.0, 0.2, 0.2, 0.5)
## Total duration including fade-in and fade-out.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.4
## If true, overlay fades back to transparent. If false, it holds at peak.
@export var fade_out: bool = true

const LAYER_NAME := &"_juicee_screen_tint_overlay"

func _apply(context: Node, intensity_mult: float) -> void:
	var pair := _spawn_screen_solid_overlay(context, LAYER_NAME, 126)
	if pair.is_empty():
		return
	var layer := pair[0] as CanvasLayer
	var rect := pair[1] as ColorRect

	var effective_alpha := clamp(tint_color.a * intensity_mult, 0.0, 1.0)
	var effective_color := Color(tint_color.r, tint_color.g, tint_color.b, effective_alpha)
	rect.color = Color(effective_color.r, effective_color.g, effective_color.b, 0.0)

	var tween := _track(layer.create_tween())
	tween.tween_property(rect, "color", effective_color, duration * 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if fade_out:
		var transparent := Color(effective_color.r, effective_color.g, effective_color.b, 0.0)
		tween.tween_property(rect, "color", transparent, duration * 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		tween.tween_interval(duration * 0.7)

	await tween.finished
	# fade_out=false means "hold at peak" - keep the overlay alive (a later effect or
	# the caller clears it). Freeing it here would erase the hold the moment it lands.
	if fade_out and is_instance_valid(layer):
		layer.queue_free()
