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

func get_category_name() -> String:
	return "Audio"

func get_description() -> String:
	return "Ramp a temporary AudioEffectDistortion on a bus.\nBlown speakers, radio, damage, glitch moments."

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		push_warning("JuiceeDistortionEffect: bus '%s' not found" % bus_name)
		return

	var dist := AudioEffectDistortion.new()
	dist.mode = mode
	dist.drive = 0.0
	AudioServer.add_bus_effect(bus_idx, dist)
	var our_slot: int = AudioServer.get_bus_effect_count(bus_idx) - 1
	# stop() removes our distortion; the killed tween's await would otherwise skip it.
	_on_stop(func() -> void:
		if AudioServer.get_bus_index(bus_name) >= 0 \
				and AudioServer.get_bus_effect_count(bus_idx) > our_slot:
			AudioServer.remove_bus_effect(bus_idx, our_slot))

	var peak: float = peak_drive * intensity_mult
	var ramp_in_dur: float = duration * ramp_in_fraction
	var hold_dur: float = duration * (1.0 - ramp_in_fraction - ramp_out_fraction)
	var ramp_out_dur: float = duration * ramp_out_fraction
	var tree := context.get_tree()
	if not tree:
		AudioServer.remove_bus_effect(bus_idx, our_slot)
		return

	var set_drive := func(v: float) -> void:
		if AudioServer.get_bus_index(bus_name) >= 0 \
				and AudioServer.get_bus_effect_count(bus_idx) > our_slot:
			var d := AudioServer.get_bus_effect(bus_idx, our_slot) as AudioEffectDistortion
			if d:
				d.drive = v

	var tween := _track(tree.create_tween())
	tween.tween_method(set_drive, 0.0, peak, ramp_in_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold_dur > 0.0:
		tween.tween_interval(hold_dur)
	tween.tween_method(set_drive, peak, 0.0, ramp_out_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

	if AudioServer.get_bus_index(bus_name) >= 0 \
			and AudioServer.get_bus_effect_count(bus_idx) > our_slot:
		AudioServer.remove_bus_effect(bus_idx, our_slot)
