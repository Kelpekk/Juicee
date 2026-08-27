## Continuous rotation on a Node2D for a fixed duration.
##
## Use for: death spin, coin collect, confused/dizzy state, powerup spin,
## tornado particle source, spinning saw blade activation.
@tool
class_name JuiceeSpinEffect
extends JuiceeEffect

## Degrees rotated per second. Negative = counter-clockwise. 360 = one full rotation/sec.
@export_range(-3600.0, 3600.0, 10.0) var degrees_per_second: float = 360.0
## Total spin duration in seconds.
@export_range(0.1, 30.0, 0.05) var duration: float = 1.0
## If true, tweens rotation back to the original angle after spinning ends.
@export var restore_on_end: bool = false
## Duration of the snap-back tween (only used when restore_on_end = true).
@export_range(0.05, 1.0, 0.05) var restore_duration: float = 0.15
## Start fast and decelerate into the stop, like a coin settling, instead of spinning
## at constant speed and stopping dead.
@export var ease_out: bool = false

func get_category_name() -> String: return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not context is Node2D:
		push_warning("JuiceeSpinEffect: context must be a Node2D")
		return
	var target := context as Node2D
	var start_rot := target.rotation
	var total_rot := deg_to_rad(degrees_per_second * intensity_mult * duration)
	var tree := context.get_tree()

	var tween := _track(target.create_tween())
	var step := tween.tween_property(target, "rotation", start_rot + total_rot, duration)
	if ease_out:
		step.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		step.set_trans(Tween.TRANS_LINEAR)
	await tween.finished

	if restore_on_end and not _cancelled:
		var snap := _track(target.create_tween())
		snap.tween_property(target, "rotation", start_rot, restore_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await snap.finished
