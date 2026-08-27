## Repeating modulate flash on a CanvasItem - for sustained danger states.
##
## Use for: low-health vignette pulsing, police-siren alarms, "boss enrage"
## visual warning, lock-on indicators, tutorial highlights. Sustains across
## multiple cycles, then fades out (or holds, if hold_at_end is true).
@tool
class_name JuiceeAmbientFlashEffect
extends JuiceeEffect

## Peak flash color (full alpha = solid color overlay; partial = tint).
@export var flash_color: Color = Color(1.0, 0.2, 0.2, 0.5)
## Total duration across all cycles.
@export_range(0.1, 30.0, 0.1) var duration: float = 3.0
## Cycles per second (higher = more frantic).
@export_range(0.2, 10.0, 0.1) var frequency: float = 1.5
## If true, holds at flash_color at the end. If false, fades back to original.
@export var hold_at_end: bool = false
## Easing curve for each pulse (null = linear sine wave).
@export var pulse_curve: Curve

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_FLASH

func get_category_name() -> String:
	return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: CanvasItem = context as CanvasItem
	if not target or not target.is_inside_tree():
		push_warning("JuiceeAmbientFlashEffect: context is not a CanvasItem")
		return

	var original_modulate: Color = _capture_state(target, "modulate")
	var target_color: Color = flash_color
	# Scale alpha by intensity_mult so quieter states still pulse.
	target_color.a = clamp(target_color.a * intensity_mult, 0.0, 1.0)

	var tree := target.get_tree()
	if not tree:
		_release_state(target, "modulate")
		return

	var elapsed := 0.0
	while elapsed < duration and not _cancelled and is_instance_valid(target):
		var t_pulse: float = fposmod(elapsed * frequency, 1.0)
		# Triangle wave: 0 -> 1 -> 0 across one cycle.
		var raw: float = 1.0 - abs(t_pulse * 2.0 - 1.0)
		var ratio: float = pulse_curve.sample(raw) if pulse_curve else sin(raw * PI * 0.5)
		target.modulate = original_modulate.lerp(target_color, ratio)
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()

	# When holding, set the flash colour and release WITHOUT restoring (otherwise
	# release would hard-restore the original on top of the hold). Otherwise release
	# normally, which restores the original modulate for us.
	var keep := hold_at_end and not _cancelled
	if is_instance_valid(target) and keep:
		target.modulate = target_color
	_release_state(target, "modulate", not keep)
