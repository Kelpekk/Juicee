## General-purpose scale tween to a target and optionally back.
##
## More flexible than BounceEffect (a uniform punch that always returns).
## Use for: grow an enemy on buff, shrink on nerf, scale-in UI from 0,
## persistent size change, one-way scale-to-0 death.
##
## Works on both Node2D and Control.
@tool
class_name JuiceeScaleEffect
extends JuiceeEffect

## Target scale: a multiplier on the node's current scale when Relative is on, the exact scale when it is off.
@export var target_scale: Vector2 = Vector2(1.5, 1.5)
## Duration of the scale-to animation.
@export_range(0.05, 3.0, 0.05) var duration: float = 0.3
## If true, tween back to the original scale after reaching target.
@export var return_to_original: bool = true
## Duration of the return animation. Ignored when return_to_original=false.
@export_range(0.05, 3.0, 0.05) var return_duration: float = 0.25
## Multiply the node's current scale (true), or treat target_scale as the exact
## scale to reach (false).
@export var relative: bool = true
## Transition type for the scale-to phase.
@export var transition: Tween.TransitionType = Tween.TRANS_BACK
## Ease type for scale-to.
@export var easing: Tween.EaseType = Tween.EASE_OUT

@export_group("Advanced")
## Hand-drawn easing curve (0..1) that replaces the Transition/Ease above for the
## scale-to phase. Leave null for the built-in easing. This is FEEL-style curve control.
@export var ease_curve: Curve
## Seconds to hold at the target scale before returning. 0 = return straight away.
@export_range(0.0, 5.0, 0.05) var hold_time: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "hold_time"]))

func get_category_name() -> String: return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return

	var is_2d := context is Node2D
	var is_ctrl := context is Control
	if not is_2d and not is_ctrl:
		_warn("JuiceeScaleEffect: context must be Node2D or Control")
		return

	# A Control scales from its top-left corner; pivot at the centre so it grows in
	# place instead of stretching. Node2D scales around its origin and has no pivot.
	# Held on the state stack, so stop() puts the pivot back as well.
	var ctrl := context as Control
	if ctrl:
		_capture_state(ctrl, "pivot_offset")
		ctrl.pivot_offset = ctrl.size * 0.5

	var prop := "scale"
	var start: Vector2 = context.get_indexed(prop)
	var goal: Vector2
	if relative:
		# Scale from the node's CURRENT value, not the state-stack original, so two
		# scale effects on the same node compound instead of the second one targeting
		# where the first already is (and appearing not to move). Intensity scales how
		# far the punch goes, so at 0 the node holds still rather than collapsing.
		goal = start * (Vector2.ONE + (target_scale - Vector2.ONE) * intensity_mult)
	else:
		# An exact scale is exactly that: intensity scales how far we grow toward it,
		# never the scale itself.
		goal = start.lerp(target_scale, intensity_mult)

	# Held on the state stack either way, so other effects on the scale see its true original and
	# stop() mid-play undoes it. A scale that stays is kept at its goal when the play ends.
	var original: Vector2 = _capture_state(context, prop)
	var tween := _track(context.create_tween())
	# ease_curve (advanced) overrides the built-in transition/ease when set.
	if ease_curve:
		_tween_curved(tween, context, prop, start, goal, duration, ease_curve)
	else:
		tween.tween_property(context, prop, goal, duration)\
			.set_trans(transition).set_ease(easing)
	if hold_time > 0.0:
		tween.tween_interval(hold_time)
	if return_to_original:
		tween.tween_property(context, prop, original, return_duration)\
			.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	await tween.finished
	if _gen != play:
		return

	if return_to_original:
		_release_state(context, prop)
		if ctrl:
			_release_state(ctrl, "pivot_offset")
	else:
		_keep_state(context, prop, goal)
		# The pivot it grew around stays too: put back, it would move a scaled Control.
		if ctrl:
			_keep_state(ctrl, "pivot_offset", ctrl.pivot_offset)
