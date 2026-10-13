## Glow pulse: pulses a CanvasItem brighter (and toward a tint) then back, a soft
## highlight without a Light2D. Selection glow, charge tells, heartbeat, pickups.
##
## A node already drawing at full white needs glow on the WorldEnvironment to read as
## brighter; a tint pulses either way.
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

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing the sine for the brighten phase. FEEL-style.
@export var ease_curve: Curve
## Seconds to hold at peak brightness on each pulse before easing back. 0 = no hold.
@export_range(0.0, 3.0, 0.05) var hold_time: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "hold_time"]))

func get_accessibility_tag() -> int:
	return JuiceeAccessibility.TAG_FLASH

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Pulse a CanvasItem brighter then back, no Light2D.\nSelection glow, charge tells, heartbeat, pickups."

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var target: CanvasItem = context as CanvasItem
	if not target or not target.is_inside_tree():
		_warn("JuiceeGlowPulseEffect: context is not a CanvasItem")
		return

	var original: Color = _capture_state(target, "modulate")
	var p: float = 1.0 + (peak - 1.0) * intensity_mult
	# Not clamped at 1: a node sitting at white has nowhere to go below it, and modulate takes
	# values above 1, which is also what glow picks up. The ceiling only stops a runaway.
	var peak_col := Color(
		clampf(original.r * tint.r * p, 0.0, 4.0),
		clampf(original.g * tint.g * p, 0.0, 4.0),
		clampf(original.b * tint.b * p, 0.0, 4.0),
		original.a)
	var half: float = duration * 0.5

	var tween := _track(target.create_tween())
	for i in _capped(maxi(1, count), 1000, "count"):
		if ease_curve:
			_tween_curved(tween, target, "modulate", original, peak_col, half, ease_curve)
		else:
			tween.tween_property(target, "modulate", peak_col, half)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if hold_time > 0.0:
			tween.tween_interval(hold_time)
		tween.tween_property(target, "modulate", original, half)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	if _gen != play:
		return
	_release_state(target, "modulate")
