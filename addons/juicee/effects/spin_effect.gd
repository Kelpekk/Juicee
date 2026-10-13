## Continuous rotation on a Node2D for a fixed duration.
##
## Use for: death spin, coin collect, confused/dizzy state, powerup spin,
## tornado particle source, spinning saw blade activation.
@tool
class_name JuiceeSpinEffect
extends JuiceeEffect

## Degrees rotated per second. Negative = counter-clockwise. 360 = one full rotation/sec.
@export_range(-3600.0, 3600.0, 10.0) var degrees_per_second: float = 360.0
## Total spin duration in seconds. It turns degrees_per_second * duration degrees in all.
@export_range(0.1, 30.0, 0.05) var duration: float = 1.0
## If true, tweens rotation back to the original angle after spinning ends.
@export var restore_on_end: bool = false
## Duration of the snap-back tween (only used when restore_on_end = true).
@export_range(0.05, 1.0, 0.05) var restore_duration: float = 0.15
## Start fast and decelerate into the stop, like a coin settling, instead of spinning
## at constant speed and stopping dead.
@export var ease_out: bool = false

@export_group("Advanced")
## Hand-drawn speed curve (0..1) over the spin. Replaces Ease Out / constant speed with
## your own accel/decel shape. FEEL-style curve control.
@export var ease_curve: Curve
## Anticipation: wind back this many degrees (opposite the spin) before launching.
@export_range(0.0, 180.0, 5.0) var windup: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "windup"]))

func get_category_name() -> String: return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	if not context is Node2D:
		_warn("JuiceeSpinEffect: context must be a Node2D")
		return
	var target := context as Node2D
	# Held on the state stack, so stop() mid-spin undoes it. A spin that stays is let go at the
	# end without restoring.
	_capture_state(target, "rotation")
	var start_rot := target.rotation
	var total_rot := deg_to_rad(degrees_per_second * intensity_mult * duration)

	var spin_sign := 1.0 if degrees_per_second >= 0.0 else -1.0
	var main_from := start_rot
	var tween := _track(target.create_tween())
	# Advanced windup: brief anticipation back-swing before the spin launches.
	if windup > 0.0:
		main_from = start_rot - deg_to_rad(windup) * spin_sign
		tween.tween_property(target, "rotation", main_from, 0.12)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var end_rot := start_rot + total_rot
	# ease_curve (advanced) overrides the built-in easing/constant speed when set.
	if ease_curve:
		_tween_curved(tween, target, "rotation", main_from, end_rot, duration, ease_curve)
	else:
		var step := tween.tween_property(target, "rotation", end_rot, duration)
		if ease_out:
			step.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			step.set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	if _gen != play:
		return

	if restore_on_end:
		var snap := _track(target.create_tween())
		snap.tween_property(target, "rotation", start_rot, restore_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await snap.finished
		if _gen != play:
			return
	_release_state(target, "rotation", restore_on_end)
