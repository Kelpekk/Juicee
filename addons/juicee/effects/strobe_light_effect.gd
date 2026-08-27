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
## Leave alpha < 1 to skip color override entirely.
@export var strobe_color: Color = Color(1, 1, 1, 0)
## Fraction of each pulse spent in the ON state. 0.5 = even on/off,
## 0.2 = quick flashes with darkness between (more dramatic).
@export_range(0.05, 0.95, 0.05) var on_ratio: float = 0.4

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_FLASH

func get_category_name() -> String:
	return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var light: Light2D = context as Light2D
	if not light or not light.is_inside_tree():
		push_warning("JuiceeStrobeLightEffect: context is not a Light2D")
		return

	var orig_enabled: bool = _capture_state(light, "enabled")
	var orig_energy: float = _capture_state(light, "energy")
	var orig_color: Color = _capture_state(light, "color")

	var effective_peak: float = peak_energy * intensity_mult
	var pulse_duration: float = duration / float(pulse_count)
	var on_time: float = pulse_duration * on_ratio
	var off_time: float = pulse_duration - on_time
	var apply_color: bool = strobe_color.a > 0.01

	var tree := light.get_tree()
	if not tree:
		_restore(light, orig_enabled, orig_energy, orig_color)
		return

	for i in pulse_count:
		if _cancelled or not is_instance_valid(light):
			break
		# ON phase.
		light.enabled = true
		light.energy = effective_peak
		if apply_color:
			light.color = strobe_color
		await tree.create_timer(on_time, true, false, false).timeout
		if _cancelled or not is_instance_valid(light):
			break
		# OFF phase.
		light.enabled = false
		if apply_color:
			light.color = orig_color
		await tree.create_timer(off_time, true, false, false).timeout

	_restore(light, orig_enabled, orig_energy, orig_color)

func _restore(light: Light2D, enabled: bool, energy: float, color: Color) -> void:
	if is_instance_valid(light):
		light.enabled = enabled
		light.energy = energy
		light.color = color
	_release_state(light, "enabled")
	_release_state(light, "energy")
	_release_state(light, "color")
