@tool
class_name JuiceeFlashEffect
extends JuiceeEffect

## Color to flash to. White = bright flash, red = damage, etc.
@export var flash_color: Color = Color.WHITE
## Total duration spread across all flashes.
@export_range(0.05, 2.0, 0.05) var duration: float = 0.15
## Number of flashes to perform. 1 = single, 3 = blink three times.
@export_range(1, 10, 1) var flash_count: int = 1
## Over-brighten multiplier on flash_color (modulate can exceed 1.0), so a white
## flash actually brightens an untinted sprite. 1.0 = plain tint to flash_color.
@export_range(1.0, 4.0, 0.1) var boost: float = 2.0

@export_group("Advanced")
## Each successive flash is this fraction as strong as the one before, so a burst
## fades out instead of strobing evenly. 1 = every flash equal.
@export_range(0.2, 1.0, 0.05) var flash_decay: float = 1.0
## Seconds held at full brightness before each flash falls off. 0 = an instant blink.
@export_range(0.0, 1.0, 0.01) var hold_time: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["flash_decay", "hold_time"]))

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_FLASH

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var target: CanvasItem = context as CanvasItem
	if not target or not target.is_inside_tree():
		_warn("JuiceeFlashEffect: context is not a CanvasItem in the tree")
		return

	var original_modulate: Color = _capture_state(target, "modulate")
	var effective_color := flash_color
	if intensity_mult != 1.0:
		effective_color = original_modulate.lerp(flash_color, clamp(intensity_mult, 0.0, 1.0))
	effective_color = Color(effective_color.r * boost, effective_color.g * boost,
		effective_color.b * boost, effective_color.a)
	if flash_count < 1:
		return
	var flashes := _capped(flash_count, 1000, "flash_count")
	var single_duration: float = duration / float(flashes * 2)
	var tween := _track(target.create_tween())

	for i in flashes:
		# Advanced flash_decay makes a burst die out instead of strobing evenly.
		var strength: float = pow(flash_decay, float(i))
		var step_color: Color = original_modulate.lerp(effective_color, strength)
		tween.tween_property(target, "modulate", step_color, single_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if hold_time > 0.0:
			tween.tween_interval(hold_time)
		tween.tween_property(target, "modulate", original_modulate, single_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween.finished
	if _gen != play:
		return
	_release_state(target, "modulate")
