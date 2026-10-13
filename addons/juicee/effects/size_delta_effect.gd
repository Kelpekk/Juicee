## Tween a Control node's size or custom_minimum_size to a target value.
##
## Use for: health bar growing/shrinking, animated panel expand/collapse,
## tooltip appear animation, progress bar fill, menu item highlight resize.
@tool
class_name JuiceeSizeDeltaEffect
extends JuiceeEffect

enum SizeTarget {
	CUSTOM_MINIMUM_SIZE, ## Animate custom_minimum_size (recommended for anchored layouts).
	SIZE,                ## Animate size directly (use for freely-positioned Controls).
}

## Which size property to animate.
@export var size_target: SizeTarget = SizeTarget.CUSTOM_MINIMUM_SIZE
## Target size in pixels.
@export var target_size: Vector2 = Vector2(200.0, 50.0)
## Duration to reach target size.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## If true, tween back to original size after reaching target_size.
@export var restore_on_end: bool = false
## Hold time at target size before restoring (only when restore_on_end = true).
@export_range(0.0, 10.0, 0.05) var hold_duration: float = 0.0
## Duration of the return tween (only when restore_on_end = true).
@export_range(0.05, 5.0, 0.05) var restore_duration: float = 0.2
## Tween transition.
@export var transition: Tween.TransitionType = Tween.TRANS_QUAD
## Tween ease.
@export var easing: Tween.EaseType = Tween.EASE_OUT

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing Transition/Ease for the resize. FEEL-style.
@export var ease_curve: Curve
## Treat Target Size as a delta added to the current size, not an absolute size.
@export var relative: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "relative"]))

func get_category_name() -> String: return "Object"
func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_NONE

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	if not context is Control:
		_warn("JuiceeSizeDeltaEffect: context must be a Control node")
		return
	var ctrl := context as Control

	var prop: String = "custom_minimum_size" if size_target == SizeTarget.CUSTOM_MINIMUM_SIZE else "size"
	# Held on the state stack, so stop() mid-change undoes it. A size that stays is let go at the
	# end without restoring.
	_capture_state(ctrl, prop)
	var original_size: Vector2 = ctrl.get(prop)
	var effective_size: Vector2
	if relative:
		effective_size = original_size + target_size * intensity_mult
	else:
		effective_size = original_size.lerp(target_size, intensity_mult)

	var tween := _track(context.create_tween())
	if ease_curve:
		_tween_curved(tween, ctrl, prop, original_size, effective_size, duration, ease_curve)
	else:
		tween.set_trans(transition).set_ease(easing)
		tween.tween_property(ctrl, prop, effective_size, duration)
	await tween.finished

	if _gen != play:
		return

	if restore_on_end:
		if hold_duration > 0.0:
			await context.get_tree().create_timer(hold_duration, true, false, false).timeout
			if _gen != play:
				return

		var r_tween := _track(context.create_tween())
		r_tween.set_trans(transition).set_ease(easing)
		r_tween.tween_property(ctrl, prop, original_size, restore_duration)
		await r_tween.finished
		if _gen != play:
			return
	_release_state(ctrl, prop, restore_on_end)
