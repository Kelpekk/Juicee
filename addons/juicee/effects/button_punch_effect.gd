## UI scale-punch - the bouncy button feel of polished menus.
##
## Targets `Control` nodes (Button, Label, Panel, etc.) and gives them the same
## scale punch `JuiceeBounceEffect` gives a Node2D, with a few UI-friendly
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

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing the built-in easing on the punch. FEEL-style.
@export var ease_curve: Curve
## Degrees the button also tilts on the punch, which reads as a physical press rather
## than a pure scale pop. 0 = no tilt.
@export_range(0.0, 20.0, 0.5) var rotation_kick: float = 0.0

func _validate_property(property_info: Dictionary) -> void:
	_gate_advanced(property_info, PackedStringArray(["ease_curve", "rotation_kick"]))

func get_category_name() -> String:
	return "Text"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var target: Control = context as Control
	if not target or not target.is_inside_tree():
		_warn("JuiceeButtonPunchEffect: context is not a Control")
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
	# ease_curve (advanced) overrides the back-ease on the punch itself.
	if ease_curve:
		_tween_curved(tween, target, "scale", target.scale, original_scale * peak, duration * 0.30, ease_curve)
	else:
		tween.tween_property(target, "scale", original_scale * peak, duration * 0.30)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Advanced rotation_kick tilts the button as it presses, which reads as physical
	# rather than a pure scale pop. Runs on its own tween so it overlaps the punch.
	if rotation_kick != 0.0:
		var orig_rot: float = _capture_state(target, "rotation")
		if target.size != Vector2.ZERO:
			target.pivot_offset = target.size * 0.5
		var rtw := _track(target.create_tween())
		rtw.tween_property(target, "rotation", orig_rot + deg_to_rad(rotation_kick) * intensity_mult, duration * 0.30)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rtw.tween_property(target, "rotation", orig_rot, duration * 0.55)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		rtw.finished.connect(func() -> void:
			if is_instance_valid(target):
				target.rotation = orig_rot
			_release_state(target, "rotation"), CONNECT_ONE_SHOT)
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
	if _gen != play:
		return
	if is_instance_valid(target):
		target.pivot_offset = original_pivot
	# Release captured baselines (after restore so the next concurrent effect
	# sees the right original).
	_release_state(target, "scale")
	_release_state(target, "pivot_offset")
	if flash_color.a > 0.0:
		_release_state(target, "modulate")
