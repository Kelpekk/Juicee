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
## Maximum run time when count = 0 (infinite pulses with a time limit).
@export_range(0.0, 60.0, 0.5) var duration: float = 0.0

func get_category_name() -> String: return "Text"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not (context is Node2D or context is Control):
		push_warning("JuiceePulseEffect: context must be Node2D or Control")
		return

	var tree := context.get_tree()
	var eff := scale_amount * intensity_mult
	var original_scale: Vector2 = context.get("scale")
	# A Control scales from its top-left corner; pivot at the centre so it pulses in
	# place instead of stretching sideways. Node2D scales around its origin (no pivot).
	var ctrl := context as Control
	var original_pivot := Vector2.ZERO
	if ctrl:
		original_pivot = ctrl.pivot_offset
		ctrl.pivot_offset = ctrl.size * 0.5
	var fired := 0
	var elapsed := 0.0
	var max_dur: float = duration if duration > 0.0 else (pulse_interval * count if count > 0 else 1e9)

	while not _cancelled and elapsed < max_dur and is_instance_valid(context):
		if count > 0 and fired >= count:
			break
		fired += 1
		var tween := _track(context.create_tween())
		tween.tween_property(context, "scale", original_scale * (1.0 + eff), pulse_interval * 0.25)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(context, "scale", original_scale, pulse_interval * 0.75)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)\
			.set_delay(pulse_interval * 0.25)
		await tree.create_timer(pulse_interval, true, false, false).timeout
		elapsed += pulse_interval

	# Ensure final scale is exactly the original in case of floating-point drift.
	if is_instance_valid(context) and not _cancelled:
		context.set("scale", original_scale)
	if ctrl and is_instance_valid(ctrl):
		ctrl.pivot_offset = original_pivot
