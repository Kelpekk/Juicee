@tool
class_name JuiceeDelayEffect
extends JuiceeEffect

## Seconds to wait. Used inside sequences to space effects apart.
@export_range(0.01, 10.0, 0.05) var duration: float = 0.5

@export_group("Advanced")
## Randomize the wait by this fraction (0.5 = 50%-150% of Duration), so repeated
## sequences do not land on exactly the same beat.
@export_range(0.0, 0.9, 0.05) var variance: float = 0.0
## Wait in real seconds, ignoring Engine.time_scale, so a delay still runs during a
## hit-stop or slow-motion moment.
@export var ignore_time_scale: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["variance", "ignore_time_scale"]))

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	# Advanced variance keeps repeated sequences off the identical beat; ignore_time_scale
	# keeps the delay running during hit-stop / slow motion.
	# A wait is timing, not strength, so intensity leaves it alone.
	var wait: float = duration
	if variance > 0.0:
		wait *= 1.0 + randf_range(-variance, variance)
	await context.get_tree().create_timer(maxf(0.001, wait), true, false, ignore_time_scale).timeout
