@tool
class_name JuiceeHitStopEffect
extends JuiceeEffect

## How long (in real seconds) the freeze lasts. ~0.05-0.15 is the sweet spot for impact.
@export_range(0.01, 1.0, 0.01) var freeze_duration: float = 0.08
## Engine.time_scale value during the freeze. 0 = full stop, 0.05 = bullet-time, 1 = no freeze.
@export_range(0.0, 1.0, 0.01) var time_scale_during: float = 0.0

func _apply(context: Node, intensity_mult: float) -> void:
	if Engine.is_editor_hint():
		return
	if not context or not context.is_inside_tree():
		return
	var effective_duration := freeze_duration * intensity_mult
	# Ref-counted via JuiceeStateStack so overlapping hit-stops don't restore each
	# other's frozen value. Capturing into a plain local would let a second hit
	# (fired within freeze_duration) record the already-frozen 0.0 as its "original"
	# and restore to that - leaving Engine.time_scale permanently stuck at 0.
	_capture_state(Engine, "time_scale")
	Engine.time_scale = time_scale_during
	await context.get_tree().create_timer(effective_duration, true, false, true).timeout
	_release_state(Engine, "time_scale")
