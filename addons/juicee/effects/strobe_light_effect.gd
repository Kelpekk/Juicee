## Strobe a Light2D - rapid on/off pulses for lightning strikes, flashbangs,
## emergency siren rotators, glitch moments.
##
## Square-wave toggling of `enabled` + optional color shift per pulse.
## More chaotic and attention-grabbing than `JuiceeLightFlashEffect` which
## ramps smoothly.
@tool
class_name JuiceeStrobeLightEffect
extends JuiceeEffect

## Number of on/off pulses across the duration.
@export_range(1, 64, 1) var pulse_count: int = 6
## Total duration of the strobe.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.5
## Peak energy during the "on" phase.
@export_range(0.0, 16.0, 0.05) var peak_energy: float = 3.0
## If set, light color is overridden during the strobe (resets at end).
## Leave alpha at 0 to keep the light's own colour.
@export var strobe_color: Color = Color(1, 1, 1, 0)
## Fraction of each pulse spent in the ON state. 0.5 = even on/off,
## 0.2 = quick flashes with darkness between (more dramatic).
@export_range(0.05, 0.95, 0.05) var on_ratio: float = 0.4

@export_group("Advanced")
## Randomize each pulse length by this fraction, for a failing / broken strobe rather
## than a metronome. 0 = perfectly even pulses.
@export_range(0.0, 0.9, 0.05) var irregularity: float = 0.0
## Each pulse is this fraction as bright as the one before, so the strobe dies out.
## 1 = every pulse equal.
@export_range(0.3, 1.0, 0.05) var energy_decay: float = 1.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["irregularity", "energy_decay"]))

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_FLASH

func get_category_name() -> String:
	return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var light: Light2D = context as Light2D
	if not light or not light.is_inside_tree():
		_warn("JuiceeStrobeLightEffect: context is not a Light2D")
		return

	_capture_state(light, "enabled")
	_capture_state(light, "energy")
	var orig_color: Color = _capture_state(light, "color")

	var effective_peak: float = peak_energy * intensity_mult
	var pulse_duration: float = duration / float(pulse_count)
	var on_time: float = pulse_duration * on_ratio
	var off_time: float = pulse_duration - on_time
	var apply_color: bool = strobe_color.a > 0.01

	var tree := light.get_tree()
	var play := _gen
	for i in pulse_count:
		if not is_instance_valid(light):
			break
		# Advanced: each pulse can dim (energy_decay) and vary in length (irregularity),
		# turning a metronome strobe into a failing one.
		var on_t := on_time
		var off_t := off_time
		if irregularity > 0.0:
			on_t *= 1.0 + randf_range(-irregularity, irregularity)
			off_t *= 1.0 + randf_range(-irregularity, irregularity)
		# ON phase.
		light.enabled = true
		light.energy = effective_peak * pow(energy_decay, float(i))
		if apply_color:
			light.color = strobe_color
		await tree.create_timer(maxf(0.001, on_t), true, false, false).timeout
		if _gen != play:
			return
		if not is_instance_valid(light):
			break
		# OFF phase.
		light.enabled = false
		if apply_color:
			light.color = orig_color
		await tree.create_timer(maxf(0.001, off_t), true, false, false).timeout
		if _gen != play:
			return

	# The stack gives these back only once the last effect holding the light lets go, so a second
	# strobe is not cut short.
	_release_state(light, "enabled")
	_release_state(light, "energy")
	_release_state(light, "color")
