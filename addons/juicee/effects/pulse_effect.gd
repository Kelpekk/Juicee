## Periodic scale pulse on a Node2D or Control node.
##
## Each pulse quickly scales up then eases back to the original size.
## Use for: notification badge, heartbeat, low-health indicator,
## "press to continue" button, collect ready indicator, energy bar cap.
@tool
class_name JuiceePulseEffect
extends JuiceeEffect

## Scale overshoot per pulse as a fraction (0.15 = 15% larger at peak).
@export_range(0.01, 1.0, 0.01) var scale_amount: float = 0.15
## Number of pulses to fire. 0 = fire until `duration` runs out.
@export_range(0, 100, 1) var count: int = 3
## Seconds between the start of each pulse.
@export_range(0.05, 5.0, 0.05) var pulse_interval: float = 0.5
## Maximum run time in seconds, whatever Count says. 0 = no limit (with Count 0 it pulses until stop()).
@export_range(0.0, 60.0, 0.5) var duration: float = 0.0

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing the built-in easing for the grow phase.
@export var ease_curve: Curve
## Fraction of each pulse spent growing (rest is the ease back). 0.25 = a quick punch.
@export_range(0.05, 0.9, 0.05) var up_ratio: float = 0.25

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "up_ratio"]))

func get_category_name() -> String: return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not (context is Node2D or context is Control):
		_warn("JuiceePulseEffect: context must be Node2D or Control")
		return

	var tree := context.get_tree()
	var eff := scale_amount * intensity_mult
	var play := _gen
	# From the stack, so a stop() mid-pulse and a second pulse started on this one come back to
	# the node's own scale, not to wherever this pulse had got to.
	var original_scale: Vector2 = _capture_state(context, "scale")
	# A Control scales from its top-left corner; pivot at the centre so it pulses in
	# place instead of stretching sideways. Node2D scales around its origin (no pivot).
	var ctrl := context as Control
	if ctrl:
		_capture_state(ctrl, "pivot_offset")
		ctrl.pivot_offset = ctrl.size * 0.5
	var fired := 0
	var elapsed := 0.0
	# Outside 0..1 one phase would take a negative time and the other run on past the pulse.
	var up_share := clampf(up_ratio, 0.0, 1.0)
	var tween: Tween = null
	var max_dur: float = duration if duration > 0.0 else (pulse_interval * count if count > 0 else 1e9)

	while _gen == play and elapsed < max_dur and is_instance_valid(context):
		if count > 0 and fired >= count:
			break
		fired += 1
		var peak := original_scale * (1.0 + eff)
		var up_t := pulse_interval * up_share
		var down_t := pulse_interval * (1.0 - up_share)
		tween = _track(context.create_tween())
		# ease_curve (advanced) overrides the grow-phase easing when set.
		if ease_curve:
			_tween_curved(tween, context, "scale", original_scale, peak, up_t, ease_curve)
		else:
			tween.tween_property(context, "scale", peak, up_t)\
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(context, "scale", original_scale, down_t)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
		elapsed += await _wait_step(tree, pulse_interval)

	# A newer play or stop() holds these now. Otherwise the stack puts the exact scale back.
	if _gen != play:
		return
	# The last pulse can still be easing back; it must not write after the scale is put back.
	if tween and tween.is_valid():
		tween.kill()
	_release_state(context, "scale")
	if ctrl:
		_release_state(ctrl, "pivot_offset")
