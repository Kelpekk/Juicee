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

@export_group("Advanced")
## Each successive stutter gets shorter by this factor, so the judder accelerates into
## normal time instead of chugging evenly. 1 = every stutter identical.
@export_range(0.3, 1.0, 0.05) var decay: float = 1.0
## Randomize each freeze/gap length by this fraction, for an irregular broken judder.
@export_range(0.0, 0.9, 0.05) var jitter: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["decay", "jitter"]))

func get_category_name() -> String:
	return "Time"

func get_description() -> String:
	return "A rapid burst of micro-freezes (machine-gun hit-stop).\nHit flurries, glitches, heavy multi-impacts."

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if Engine.is_editor_hint():
		return
	if not context or not context.is_inside_tree():
		return
	var tree := context.get_tree()
	for i in count:
		if _gen != play:
			break
		# Advanced decay shortens each successive stutter so the judder accelerates back
		# into normal time; jitter randomizes the lengths for an irregular break-up.
		var scale_i: float = pow(decay, float(i))
		# Intensity shortens the freezes, not the gaps.
		var f_time: float = freeze_time * scale_i * intensity_mult
		var g_time: float = gap_time * scale_i
		if jitter > 0.0:
			f_time *= 1.0 + randf_range(-jitter, jitter)
			g_time *= 1.0 + randf_range(-jitter, jitter)
		# Ref-counted so overlapping freezes don't restore each other's frozen value.
		_capture_state(Engine, "time_scale")
		Engine.time_scale = time_scale_during
		await tree.create_timer(maxf(0.001, f_time), true, false, true).timeout
		if _gen != play:
			return
		_release_state(Engine, "time_scale")
		if i < count - 1:
			await tree.create_timer(maxf(0.001, g_time), true, false, true).timeout
