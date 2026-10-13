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

@export_group("Advanced")
## Shape of the volume wobble: a smooth Sine, a hard on/off Square (helicopter chop), or
## a Saw that drops sharply and rises.
@export_enum("Sine", "Square", "Saw") var waveform: int = 0
## Ease the tremolo in and out over this fraction of the duration, so it doesn't start
## and stop mid-wobble.
@export_range(0.0, 0.5, 0.05) var fade_fraction: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["waveform", "fade_fraction"]))
	_hint_audio_bus(property)

func get_category_name() -> String:
	return "Audio"

func get_description() -> String:
	return "Rhythmically wobble an audio bus's volume up and down.\nUnderwater, dizziness, power fluctuation, radio interference."

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if Engine.is_editor_hint():
		return
	if not context or not context.is_inside_tree():
		return
	var bus_idx: int = AudioServer.get_bus_index(bus)
	if bus_idx < 0:
		_warn("JuiceeTremoloEffect: bus '%s' not found" % bus)
		return

	# Held on the state stack: tremolos and ducks on one bus all come back to its volume from
	# before the first of them, and stop() puts it back.
	var level := _bus_volume(bus)
	var original_db: float = _capture_offset(level, "volume_db")

	var depth: float = depth_db * intensity_mult
	var tree: SceneTree = context.get_tree()
	var start := unscaled_seconds()
	while _gen == play:
		var elapsed: float = unscaled_seconds() - start
		if elapsed >= duration:
			break
		# 0 at the crest (full volume), 1 at the trough (dipped by `depth`).
		# Advanced waveform picks the wobble shape: smooth Sine, hard Square (a
		# helicopter chop), or Saw (drops sharply then rises).
		var phase: float = fposmod(elapsed * rate, 1.0)
		var wobble: float
		match waveform:
			1:
				wobble = 0.0 if phase < 0.5 else 1.0
			2:
				wobble = phase
			_:
				wobble = (1.0 - sin(phase * TAU)) * 0.5
		# Advanced fade_fraction eases the tremolo in and out so it never starts or
		# stops mid-wobble.
		if fade_fraction > 0.0:
			var k: float = elapsed / duration
			var env: float = clampf(minf(k, 1.0 - k) / fade_fraction, 0.0, 1.0)
			wobble *= env
		_write_offset(level, "volume_db", original_db, depth * wobble, absf(depth))
		await tree.process_frame

	# A newer play or stop() holds what this one held.
	if _gen != play:
		return
	_release_state(level, "volume_db")
