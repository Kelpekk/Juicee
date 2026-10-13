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

@export_group("Advanced")
## Seconds to hold at full tint before fading. 0 = fade straight back.
@export_range(0.0, 30.0, 0.05) var hold_time: float = 0.0
## Flash in and out this many times across the duration instead of once. 3+ reads as an
## alarm strobe.
@export_range(1, 20, 1) var pulse_count: int = 1

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["hold_time", "pulse_count"]))

const LAYER_NAME := &"_juicee_screen_tint_overlay"

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_FLASH

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var pair := _spawn_screen_solid_overlay(context, LAYER_NAME, 126)
	if pair.is_empty():
		return
	var layer := pair[0] as CanvasLayer
	var rect := pair[1] as ColorRect

	var effective_alpha := clampf(tint_color.a * intensity_mult, 0.0, 1.0)
	var effective_color := Color(tint_color.r, tint_color.g, tint_color.b, effective_alpha)
	rect.color = Color(effective_color.r, effective_color.g, effective_color.b, 0.0)

	var transparent := Color(effective_color.r, effective_color.g, effective_color.b, 0.0)
	var tween := _track(layer.create_tween())
	var pulses: int = _capped(maxi(1, pulse_count), 1000, "pulse_count")
	var span: float = duration / float(pulses)
	# Each pulse flashes in and back out; the last one honours hold_time / fade_out, so a
	# single pulse (the default) behaves exactly as before.
	for i in pulses:
		var is_last: bool = (i == pulses - 1)
		tween.tween_property(rect, "color", effective_color, span * 0.3)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if is_last and hold_time > 0.0:
			tween.tween_interval(hold_time)
		if fade_out or not is_last:
			tween.tween_property(rect, "color", transparent, span * 0.7)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		else:
			tween.tween_interval(span * 0.7)

	await tween.finished
	if _gen != play:
		return
	# fade_out=false means "hold at peak" - keep the overlay alive until stop() or the next
	# play takes it down. Freeing it here would erase the hold the moment it lands.
	if is_instance_valid(layer):
		if fade_out:
			layer.queue_free()
		else:
			_free_when_released(layer)
