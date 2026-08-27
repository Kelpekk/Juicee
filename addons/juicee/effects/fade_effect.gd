## Fade a CanvasItem's alpha to a target value over time.
##
## The most fundamental UI and game effect - fade out on death, fade in on spawn,
## cross-fade panels, ghost transparency, cutscene transitions.
## restore_on_end = true -> fade to target alpha, hold, then fade back.
##
## Use for: death sequence, UI panel appear/disappear, stealth/invisible state,
## cinematic fade to black, object materialising / dematerialising.
@tool
class_name JuiceeFadeEffect
extends JuiceeEffect

## Target alpha. 0.0 = fully transparent, 1.0 = fully opaque.
@export_range(0.0, 1.0, 0.01) var target_alpha: float = 0.0
## Duration to reach target_alpha.
@export_range(0.05, 10.0, 0.05) var duration: float = 0.5
## If true, tween back to original alpha after reaching target_alpha.
@export var restore_on_end: bool = false
## Hold time at target_alpha before restoring (only when restore_on_end = true).
@export_range(0.0, 10.0, 0.05) var hold_duration: float = 0.0
## Duration of the return tween (only when restore_on_end = true).
@export_range(0.05, 5.0, 0.05) var restore_duration: float = 0.4
## Tween transition.
@export var transition: Tween.TransitionType = Tween.TRANS_SINE
## Tween ease.
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT

func get_category_name() -> String: return "Object"
func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_NONE

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not context is CanvasItem:
		push_warning("JuiceeFadeEffect: context must be a CanvasItem")
		return
	var target := context as CanvasItem

	var original_alpha: float = target.modulate.a
	var effective_alpha: float = clamp(target_alpha * intensity_mult + (1.0 - intensity_mult) * original_alpha, 0.0, 1.0)

	var tween := _track(context.create_tween())
	tween.set_trans(transition).set_ease(easing)
	tween.tween_property(target, "modulate:a", effective_alpha, duration)
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
		r_tween.tween_property(target, "modulate:a", original_alpha, restore_duration)
		await r_tween.finished
