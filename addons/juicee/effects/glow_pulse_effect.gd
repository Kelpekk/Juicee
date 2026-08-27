## Glow pulse: pulses a CanvasItem brighter (and toward a tint) then back, a soft
## highlight without a Light2D. Selection glow, charge tells, heartbeat, pickups.
@tool
class_name JuiceeGlowPulseEffect
extends JuiceeEffect

## Brightness multiplier at the peak of each pulse.
@export_range(1.0, 4.0, 0.05) var peak: float = 1.8
## Tint the modulate moves toward at the peak (white = just brighter).
@export var tint: Color = Color.WHITE
## Duration of a single pulse (up and back).
@export_range(0.05, 3.0, 0.05) var duration: float = 0.5
## How many pulses.
@export_range(1, 12, 1) var count: int = 1

func get_accessibility_tag() -> int:
	return JuiceeAccessibility.TAG_FLASH

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Pulse a CanvasItem brighter then back, no Light2D.\nSelection glow, charge tells, heartbeat, pickups."

func _apply(context: Node, intensity_mult: float) -> void:
	var target: CanvasItem = context as CanvasItem
	if not target or not target.is_inside_tree():
		push_warning("JuiceeGlowPulseEffect: context is not a CanvasItem")
		return

	var original: Color = _capture_state(target, "modulate")
	var p: float = 1.0 + (peak - 1.0) * intensity_mult
	var peak_col := Color(
		clampf(original.r * tint.r * p, 0.0, 1.0),
		clampf(original.g * tint.g * p, 0.0, 1.0),
		clampf(original.b * tint.b * p, 0.0, 1.0),
		original.a)
	var half: float = duration * 0.5

	var tween := _track(target.create_tween())
	for i in maxi(1, count):
		tween.tween_property(target, "modulate", peak_col, half)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(target, "modulate", original, half)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	_release_state(target, "modulate")
