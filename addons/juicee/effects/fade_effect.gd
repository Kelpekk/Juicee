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

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing Transition/Ease for the fade. FEEL-style.
@export var ease_curve: Curve
## Force the fade to START from this alpha (e.g. 0 for a guaranteed fade-in). -1 = start
## from the node's current alpha.
@export_range(-1.0, 1.0, 0.01) var from_alpha: float = -1.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "from_alpha"]))

func get_category_name() -> String: return "Object"
func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_NONE

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	if not context is CanvasItem:
		_warn("JuiceeFadeEffect: context must be a CanvasItem")
		return
	var target := context as CanvasItem

	# Held on the state stack, so stop() mid-fade undoes it. A fade that stays is kept at the end.
	var held: Color = _capture_state(target, "modulate")
	var original_alpha: float = target.modulate.a
	# from_alpha (advanced): jump to a start alpha first, e.g. 0 for a clean fade-in.
	if from_alpha >= 0.0:
		var m0 := target.modulate
		m0.a = from_alpha
		target.modulate = m0
	var start_alpha: float = target.modulate.a
	var effective_alpha: float = clamp(target_alpha * intensity_mult + (1.0 - intensity_mult) * original_alpha, 0.0, 1.0)

	var tween := _track(context.create_tween())
	if ease_curve:
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(target):
				var mm := target.modulate
				mm.a = lerpf(start_alpha, effective_alpha, ease_curve.sample(t))
				target.modulate = mm,
			0.0, 1.0, duration)
	else:
		tween.set_trans(transition).set_ease(easing)
		tween.tween_property(target, "modulate:a", effective_alpha, duration)
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
		r_tween.tween_property(target, "modulate:a", original_alpha, restore_duration)
		await r_tween.finished
		if _gen != play:
			return
	if restore_on_end:
		_release_state(target, "modulate")
	else:
		# Named rather than read back: a flash on the same node may be writing modulate right now.
		_keep_state(target, "modulate", Color(held.r, held.g, held.b, effective_alpha))
