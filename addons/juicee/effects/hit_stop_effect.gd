@tool
class_name JuiceeHitStopEffect
extends JuiceeEffect

## How long (in real seconds) the freeze lasts. ~0.05-0.15 is the sweet spot for impact.
@export_range(0.01, 1.0, 0.01) var freeze_duration: float = 0.08
## Engine.time_scale value during the freeze. 0 = full stop, 0.05 = bullet-time, 1 = no freeze.
@export_range(0.0, 1.0, 0.01) var time_scale_during: float = 0.0

@export_group("Advanced")
## Ease time back up to normal over this many real seconds instead of snapping, which
## reads as a heavy blow recovering rather than a hard cut. 0 = an instant restore.
@export_range(0.0, 2.0, 0.01) var recover_time: float = 0.0
## Delay (real seconds) before the freeze bites, so the hit lands first and THEN time
## stops - a trick fighting games use to sell the connect.
@export_range(0.0, 0.5, 0.005) var pre_delay: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["recover_time", "pre_delay"]))

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if Engine.is_editor_hint():
		return
	if not context or not context.is_inside_tree():
		return
	# Advanced: let the hit read for a beat before time stops.
	if pre_delay > 0.0:
		await context.get_tree().create_timer(pre_delay, true, false, true).timeout
		if _gen != play or not is_instance_valid(context):
			return
	var effective_duration := freeze_duration * intensity_mult
	# Ref-counted via JuiceeStateStack so overlapping hit-stops don't restore each
	# other's frozen value. Capturing into a plain local would let a second hit
	# (fired within freeze_duration) record the already-frozen 0.0 as its "original"
	# and restore to that - leaving Engine.time_scale permanently stuck at 0.
	var normal_scale: float = _capture_state(Engine, "time_scale")
	Engine.time_scale = time_scale_during
	await context.get_tree().create_timer(effective_duration, true, false, true).timeout
	if _gen != play:
		return

	# Advanced: ramp time back up instead of snapping, so the blow recovers with weight.
	# Stepped on real time (ignore_time_scale) because time itself is what we're moving.
	if recover_time > 0.0 and is_instance_valid(context):
		var tree := context.get_tree()
		var step := 1.0 / 60.0
		var t := 0.0
		while t < recover_time and _gen == play and is_instance_valid(context):
			Engine.time_scale = lerpf(time_scale_during, normal_scale, t / recover_time)
			await tree.create_timer(step, true, false, true).timeout
			if _gen != play:
				return
			t += step

	_release_state(Engine, "time_scale")
