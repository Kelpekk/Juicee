## Tremolo: rhythmically wobbles an audio bus's volume up and down, a pulsing amplitude
## wobble. Underwater moments, dizziness, power fluctuation, radio interference.
@tool
class_name JuiceeTremoloEffect
extends JuiceeEffect

## Audio bus to wobble. Typically "Master", "Music", or "SFX".
@export var bus: StringName = &"Master"
## How deep each dip goes, in dB below the current volume.
@export_range(-40.0, 0.0, 0.5) var depth_db: float = -12.0
## Wobbles per second.
@export_range(0.5, 20.0, 0.5) var rate: float = 6.0
## Total time the tremolo runs.
@export_range(0.1, 20.0, 0.05) var duration: float = 1.5

func get_category_color() -> Color:
	return Color(0.95, 0.85, 0.20)

func get_category_name() -> String:
	return "Audio"

func get_description() -> String:
	return "Rhythmically wobble an audio bus's volume up and down.\nUnderwater, dizziness, power fluctuation, radio interference."

func _apply(context: Node, intensity_mult: float) -> void:
	if Engine.is_editor_hint():
		return
	if not context or not context.is_inside_tree():
		return
	var bus_idx: int = AudioServer.get_bus_index(bus)
	if bus_idx < 0:
		push_warning("JuiceeTremoloEffect: bus '%s' not found" % bus)
		return

	var original_db: float = AudioServer.get_bus_volume_db(bus_idx)
	# stop() restores the bus; the loop's `await` would otherwise never resume.
	_on_stop(func() -> void:
		if AudioServer.get_bus_index(bus) >= 0:
			AudioServer.set_bus_volume_db(bus_idx, original_db))

	var depth: float = depth_db * intensity_mult
	var tree: SceneTree = context.get_tree()
	var start_ms: int = Time.get_ticks_msec()
	while not _cancelled:
		var elapsed: float = (Time.get_ticks_msec() - start_ms) / 1000.0
		if elapsed >= duration:
			break
		# 0 at the crest (full volume), 1 at the trough (dipped by `depth`).
		var wobble: float = (1.0 - sin(elapsed * rate * TAU)) * 0.5
		AudioServer.set_bus_volume_db(bus_idx, original_db + depth * wobble)
		await tree.process_frame

	if AudioServer.get_bus_index(bus) >= 0:
		AudioServer.set_bus_volume_db(bus_idx, original_db)
