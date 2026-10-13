## Repeating modulate flash on a CanvasItem - for sustained danger states.
##
## Use for: low-health vignette pulsing, police-siren alarms, "boss enrage"
## visual warning, lock-on indicators, tutorial highlights. Sustains across
## multiple cycles, then returns to the original colour (or holds, if hold_at_end is true).
@tool
class_name JuiceeAmbientFlashEffect
extends JuiceeEffect

## Peak flash color the modulate pulses toward. Full alpha keeps the node opaque as
## it tints (a red danger pulse); a low alpha would read as fading out, not flashing.
@export var flash_color: Color = Color(1.0, 0.3, 0.3, 1.0)
## Total duration across all cycles.
@export_range(0.1, 30.0, 0.1) var duration: float = 3.0
## Cycles per second (higher = more frantic).
@export_range(0.2, 10.0, 0.1) var frequency: float = 1.5
## If true, holds at flash_color at the end. If false, the original colour comes straight back.
@export var hold_at_end: bool = false
## Easing curve for each pulse (null = a sine ease).
@export var pulse_curve: Curve

enum Waveform { TRIANGLE, SQUARE, SAWTOOTH }

@export_group("Advanced")
## Pulse shape: TRIANGLE fades in and out (an alarm throb), SQUARE snaps between the two
## colours (a police light), SAWTOOTH ramps up then cuts (a strobe sweep).
@export var waveform: Waveform = Waveform.TRIANGLE

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["waveform"]))

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_FLASH

func get_category_name() -> String:
	return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: CanvasItem = context as CanvasItem
	if not target or not target.is_inside_tree():
		_warn("JuiceeAmbientFlashEffect: context is not a CanvasItem")
		return

	var play := _gen
	var original_modulate: Color = _capture_state(target, "modulate")
	var target_color: Color = flash_color
	# Scale alpha by intensity_mult so quieter states still pulse.
	target_color.a = clamp(target_color.a * intensity_mult, 0.0, 1.0)

	var tree := target.get_tree()
	if not tree:
		_release_state(target, "modulate")
		return

	var elapsed := 0.0
	while elapsed < duration and _gen == play and is_instance_valid(target):
		var t_pulse: float = fposmod(elapsed * frequency, 1.0)
		# Pulse shape across one cycle (advanced Waveform; TRIANGLE is the default).
		var raw: float
		match waveform:
			Waveform.SQUARE:
				raw = 1.0 if t_pulse < 0.5 else 0.0
			Waveform.SAWTOOTH:
				raw = t_pulse
			_:
				raw = 1.0 - abs(t_pulse * 2.0 - 1.0)
		var ratio: float = pulse_curve.sample(raw) if pulse_curve else sin(raw * PI * 0.5)
		target.modulate = original_modulate.lerp(target_color, ratio)
		await tree.process_frame
		if _gen != play:
			return
		elapsed += tree.root.get_process_delta_time()
	# A newer play or stop() holds these now; releasing here would take them from it.
	if _gen != play:
		return

	# When holding, set the flash colour and keep the modulate held, so stop() can put the
	# original back later. Otherwise release, which restores the original modulate for us.
	if hold_at_end:
		if is_instance_valid(target):
			target.modulate = target_color
	else:
		_release_state(target, "modulate")
