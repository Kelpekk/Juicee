## General-purpose scale tween to a target and optionally back.
##
## More flexible than BounceEffect (which does squash+stretch and always returns).
## Use for: grow an enemy on buff, shrink on nerf, scale-in UI from 0,
## persistent size change, one-way scale-to-0 death.
##
## Works on both Node2D and Control.
@tool
class_name JuiceeScaleEffect
extends JuiceeEffect

## Target scale multiplier. Applied relative to the node's current scale.
@export var target_scale: Vector2 = Vector2(1.5, 1.5)
## Duration of the scale-to animation.
@export_range(0.05, 3.0, 0.05) var duration: float = 0.3
## If true, tween back to the original scale after reaching target.
@export var return_to_original: bool = true
## Duration of the return animation. Ignored when return_to_original=false.
@export_range(0.05, 3.0, 0.05) var return_duration: float = 0.25
## If true, the CURRENT value is changing RELATIVELY, else TARGET value is the DESTINATION.
@export var relative: bool = true
## Transition type for the scale-to phase.
@export_enum("Linear", "Sine", "Quint", "Quart", "Quad", "Expo", "Elastic", "Bounce", "Back", "Spring", "Cubic", "Circ") var transition: int = Tween.TRANS_BACK
## Ease type for scale-to.
@export_enum("EaseIn", "EaseOut", "EaseInOut", "EaseOutIn") var easing: int = Tween.EASE_OUT

func get_category_color() -> Color: return Color(0.22, 0.58, 1.00)
func get_category_name() -> String: return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return

	var is_2d := context is Node2D
	var is_ctrl := context is Control
	if not is_2d and not is_ctrl:
		push_warning("JuiceeScaleEffect: context must be Node2D or Control")
		return

	var prop := "scale"
	var goal: Vector2
	# Scale from the node's CURRENT value, not the state-stack original, so two
	# scale effects on the same node compound instead of the second one targeting
	# where the first already is (and appearing not to move).
	if relative:
		var start: Vector2 = context.get_indexed(prop)
		goal = start * target_scale * intensity_mult
	else:
		goal = target_scale * intensity_mult

	var tween := _track(context.create_tween())
	tween.tween_property(context, prop, goal, duration)\
		.set_trans(transition).set_ease(easing)

	if return_to_original:
		# Capture the TRUE original via the state stack (so stacked effects all
		# unwind to it) and tween back; the stack restores it on release.
		var original: Vector2 = _capture_state(context, prop)
		tween.tween_property(context, prop, original, return_duration)\
			.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		await tween.finished
		_release_state(context, prop)
	else:
		# Permanent change — leave it at the goal. No state-stack restore, which
		# previously snapped the scale back even with return_to_original = false.
		await tween.finished
