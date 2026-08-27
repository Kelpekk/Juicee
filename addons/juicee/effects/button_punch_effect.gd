## UI scale-punch - the bouncy button feel of polished menus.
##
## Targets `Control` nodes (Button, Label, Panel, etc.) and gives them the same
## squash-stretch energy `JuiceeBounceEffect` gives Node2D, with a few UI-friendly
## tweaks: pivots from the Control's actual center, restores the original
## scale via JuiceeStateStack so two presses don't double-punch, and works with
## both `pressed` and `hover` flows.
@tool
class_name JuiceeButtonPunchEffect
extends JuiceeEffect

## Peak scale factor on punch (1.2 = 20% bigger).
@export_range(1.0, 2.5, 0.01) var scale_factor: float = 1.15
## Total animation duration (punch out + ease back).
@export_range(0.05, 2.0, 0.01) var duration: float = 0.25
## Pre-punch dip - squash slightly before the punch so the bounce reads stronger.
## Set to 1.0 to disable.
@export_range(0.5, 1.0, 0.01) var pre_dip: float = 0.95
## Optional color flash during the punch (set alpha 0 to disable).
@export var flash_color: Color = Color(1.0, 1.0, 1.0, 0.0)

func get_category_name() -> String:
	return "Text"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Control = context as Control
	if not target or not target.is_inside_tree():
		push_warning("JuiceeButtonPunchEffect: context is not a Control")
		return

	# Capture pivot + scale so concurrent punches restore the TRUE original.
	var original_scale: Vector2 = _capture_state(target, "scale")
	var original_pivot: Vector2 = _capture_state(target, "pivot_offset")
	# Pivot from the Control's center so scale grows symmetrically.
	target.pivot_offset = target.size * 0.5

	var peak: float = 1.0 + (scale_factor - 1.0) * intensity_mult
	var tween := _track(target.create_tween())

	# Pre-dip -> punch -> settle.
	if pre_dip < 1.0:
		tween.tween_property(target, "scale", original_scale * pre_dip, duration * 0.15)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", original_scale * peak, duration * 0.30)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", original_scale, duration * 0.55)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Optional color flash in parallel with the punch.
	if flash_color.a > 0.0:
		var original_modulate: Color = _capture_state(target, "modulate")
		var flash_tween := _track(target.create_tween())
		flash_tween.tween_property(target, "modulate", flash_color, duration * 0.15)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash_tween.tween_property(target, "modulate", original_modulate, duration * 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween.finished
	if is_instance_valid(target):
		target.pivot_offset = original_pivot
	# Release captured baselines (after restore so the next concurrent effect
	# sees the right original).
	_release_state(target, "scale")
	_release_state(target, "pivot_offset")
	if flash_color.a > 0.0:
		_release_state(target, "modulate")
