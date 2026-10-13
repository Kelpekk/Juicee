## Temporarily inject an AudioEffectDistortion on an AudioBus, the blown-speaker /
## radio / damaged feel. Ramps the drive in then out and removes its own effect.
@tool
class_name JuiceeDistortionEffect
extends JuiceeEffect

## Name of the AudioBus to distort (e.g. "Master", "SFX", "Music").
@export var bus_name: String = "Master"
## Peak distortion drive.
@export_range(0.0, 1.0, 0.01) var peak_drive: float = 0.5
## Distortion flavour.
@export_enum("Clip", "ATan", "LoFi", "Overdrive", "WaveShape") var mode: int = 0
## Total duration: ramp-in + hold + ramp-out.
@export_range(0.1, 10.0, 0.05) var duration: float = 0.8
## Ramp-in fraction of duration.
@export_range(0.0, 0.5, 0.01) var ramp_in_fraction: float = 0.15
## Ramp-out fraction of duration.
@export_range(0.0, 0.5, 0.01) var ramp_out_fraction: float = 0.35

@export_group("Advanced")
## Pre-gain in dB applied before the distortion stage. Pushing this harder drives the
## signal further into the shaping curve.
@export_range(-60.0, 60.0, 1.0) var pre_gain_db: float = 0.0
## Post-gain in dB to bring the level back down after distorting.
@export_range(-80.0, 24.0, 1.0) var post_gain_db: float = 0.0
## Frequencies above this (Hz) pass through clean and only the ones below it are
## distorted. Lower it to keep more of the top end clear.
@export_range(1.0, 20000.0, 10.0) var keep_hf_hz: float = 16000.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["pre_gain_db", "post_gain_db", "keep_hf_hz"]))
	_hint_audio_bus(property)

func get_category_name() -> String:
	return "Audio"

func get_description() -> String:
	return "Ramp a temporary AudioEffectDistortion on a bus.\nBlown speakers, radio, damage, glitch moments."

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		_warn("JuiceeDistortionEffect: bus '%s' not found" % bus_name)
		return

	var dist := AudioEffectDistortion.new()
	dist.mode = mode as AudioEffectDistortion.Mode
	# Advanced: drive the signal in harder (pre_gain), pull the result back down
	# (post_gain), and keep the low end clean while the top grinds (keep_hf).
	dist.pre_gain = pre_gain_db
	dist.post_gain = post_gain_db
	dist.keep_hf_hz = keep_hf_hz
	dist.drive = 0.0
	AudioServer.add_bus_effect(bus_idx, dist)
	# stop() removes our distortion; the killed tween's await would otherwise skip it.
	_on_stop(_remove_bus_effect.bind(bus_name, dist))

	var peak: float = peak_drive * intensity_mult
	var ramp_in_dur: float = duration * ramp_in_fraction
	var hold_dur: float = duration * (1.0 - ramp_in_fraction - ramp_out_fraction)
	var ramp_out_dur: float = duration * ramp_out_fraction
	var tree := context.get_tree()
	if not tree:
		_remove_bus_effect(bus_name, dist)
		return

	var set_drive := func(v: float) -> void:
		dist.drive = v

	var tween := _track(tree.create_tween())
	tween.tween_method(set_drive, 0.0, peak, ramp_in_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold_dur > 0.0:
		tween.tween_interval(hold_dur)
	tween.tween_method(set_drive, peak, 0.0, ramp_out_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	if _gen != play:
		return

	_remove_bus_effect(bus_name, dist)
