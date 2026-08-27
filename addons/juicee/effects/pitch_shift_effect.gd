## Temporarily pitch-shift an entire AudioBus - the "underwater" / "slow-mo
## audio" / "demon transformation voice" feel. Animates an AudioEffectPitchShift
## from 1.0 (normal) -> target_pitch -> back.
##
## Pair with TimeScaleRamp for proper slow-mo (visuals + audio both slow).
## Pair with negative shift for low-health / dread states.
##
## Adds and removes its own pitch-shift effect on the bus so it doesn't fight
## with user-installed bus effects.
@tool
class_name JuiceePitchShiftEffect
extends JuiceeEffect

## Name of the AudioBus to pitch-shift.
@export var bus_name: String = "Master"
## Target pitch scale. 1.0 = normal, 0.5 = octave down (deep), 2.0 = octave up.
@export_range(0.1, 4.0, 0.01) var target_pitch: float = 0.7
## Total duration: ramp-in + hold + ramp-out.
@export_range(0.05, 10.0, 0.05) var duration: float = 1.0
## Ramp-in fraction.
@export_range(0.0, 0.5, 0.01) var ramp_in_fraction: float = 0.2
## Ramp-out fraction.
@export_range(0.0, 0.5, 0.01) var ramp_out_fraction: float = 0.3

func get_category_name() -> String:
	return "Audio"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		push_warning("JuiceePitchShiftEffect: bus '%s' not found" % bus_name)
		return

	var shifter := AudioEffectPitchShift.new()
	shifter.pitch_scale = 1.0
	AudioServer.add_bus_effect(bus_idx, shifter)
	var our_slot: int = AudioServer.get_bus_effect_count(bus_idx) - 1
	# stop() removes our pitch-shift - the killed tween's `await` would otherwise skip
	# the removal below and leave the bus pitched forever.
	_on_stop(func() -> void:
		if AudioServer.get_bus_index(bus_name) >= 0 \
				and AudioServer.get_bus_effect_count(bus_idx) > our_slot:
			AudioServer.remove_bus_effect(bus_idx, our_slot))

	# Effective target = lerp(1.0, target_pitch, intensity_mult).
	var effective_pitch: float = lerp(1.0, target_pitch, clamp(intensity_mult, 0.0, 1.0))
	var ramp_in_dur: float = duration * ramp_in_fraction
	var hold_dur: float = duration * (1.0 - ramp_in_fraction - ramp_out_fraction)
	var ramp_out_dur: float = duration * ramp_out_fraction

	var tree := context.get_tree()
	if not tree:
		AudioServer.remove_bus_effect(bus_idx, our_slot)
		return

	var update_pitch := func(v: float) -> void:
		if AudioServer.get_bus_index(bus_name) >= 0 \
				and AudioServer.get_bus_effect_count(bus_idx) > our_slot:
			var ps := AudioServer.get_bus_effect(bus_idx, our_slot) as AudioEffectPitchShift
			if ps:
				ps.pitch_scale = v

	var tween := _track(tree.create_tween())
	tween.tween_method(update_pitch, 1.0, effective_pitch, ramp_in_dur)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold_dur > 0.0:
		tween.tween_interval(hold_dur)
	tween.tween_method(update_pitch, effective_pitch, 1.0, ramp_out_dur)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween.finished

	if AudioServer.get_bus_index(bus_name) >= 0 \
			and AudioServer.get_bus_effect_count(bus_idx) > our_slot:
		AudioServer.remove_bus_effect(bus_idx, our_slot)
