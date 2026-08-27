## Stutter: a rapid burst of micro-freezes, the machine-gun hit-stop that sells a
## flurry of hits, a glitch, or a heavy multi-impact. Unlike HitStop (a single freeze).
@tool
class_name JuiceeStutterEffect
extends JuiceeEffect

## How many freeze stutters.
@export_range(2, 20, 1) var count: int = 5
## Real seconds each freeze lasts.
@export_range(0.005, 0.15, 0.005) var freeze_time: float = 0.03
## Real seconds of normal speed between freezes.
@export_range(0.005, 0.15, 0.005) var gap_time: float = 0.03
## Engine.time_scale during each freeze (0 = full stop).
@export_range(0.0, 1.0, 0.01) var time_scale_during: float = 0.0

func get_category_name() -> String:
	return "Time"

func get_description() -> String:
	return "A rapid burst of micro-freezes (machine-gun hit-stop).\nHit flurries, glitches, heavy multi-impacts."

func _apply(context: Node, intensity_mult: float) -> void:
	if Engine.is_editor_hint():
		return
	if not context or not context.is_inside_tree():
		return
	var tree := context.get_tree()
	for i in count:
		if _cancelled:
			break
		# Ref-counted so overlapping freezes don't restore each other's frozen value.
		_capture_state(Engine, "time_scale")
		Engine.time_scale = time_scale_during
		await tree.create_timer(freeze_time, true, false, true).timeout
		_release_state(Engine, "time_scale")
		if i < count - 1 and not _cancelled:
			await tree.create_timer(gap_time, true, false, true).timeout
