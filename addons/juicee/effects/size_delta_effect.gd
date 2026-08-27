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

func get_category_name() -> String: return "Object"
func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_NONE

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not context is Control:
		push_warning("JuiceeSizeDeltaEffect: context must be a Control node")
		return
	var ctrl := context as Control

	var prop: String = "custom_minimum_size" if size_target == SizeTarget.CUSTOM_MINIMUM_SIZE else "size"
	var original_size: Vector2 = ctrl.get(prop)
	var effective_size := original_size.lerp(target_size, intensity_mult)

	var tween := _track(context.create_tween())
	tween.set_trans(transition).set_ease(easing)
	tween.tween_property(ctrl, prop, effective_size, duration)
	await tween.finished

	if _cancelled:
		return

	if restore_on_end:
		if hold_duration > 0.0:
			await context.get_tree().create_timer(hold_duration, true, false, false).timeout
			if _cancelled:
				return

		var r_tween := _track(context.create_tween())
		r_tween.set_trans(transition).set_ease(easing)
		r_tween.tween_property(ctrl, prop, original_size, restore_duration)
		await r_tween.finished
