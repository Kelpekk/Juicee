## Temporarily inject an AudioEffectReverb on an AudioBus - the "cathedral
## tail" / "underwater" feel for boss intros, dimension shifts, low-health
## states, dramatic moments.
##
## Adds the AudioEffectReverb at the END of the target bus's effect chain,
## animates wet level in/out, then removes it cleanly. Safe to spam - uses
## a uniquely-named guard so a second call replaces the first.
@tool
class_name JuiceeReverbEffect
extends JuiceeEffect

## Name of the AudioBus to apply reverb to (e.g. "Master", "SFX", "Music").
@export var bus_name: String = "Master"
## Peak wet level (0 = dry, 1 = full reverb).
@export_range(0.0, 1.0, 0.01) var peak_wet: float = 0.45
## Room size (0 = small, 1 = huge cathedral).
@export_range(0.0, 1.0, 0.01) var room_size: float = 0.8
## Damping - how much high frequencies decay.
@export_range(0.0, 1.0, 0.01) var damping: float = 0.5
## Spread - left/right reverb decorrelation (more = wider).
@export_range(0.0, 1.0, 0.01) var spread: float = 1.0
## Total duration: ramp-in + hold + ramp-out.
@export_range(0.1, 10.0, 0.05) var duration: float = 1.5
## Ramp-in fraction of duration (0.2 = 20% spent ramping up).
@export_range(0.0, 0.5, 0.01) var ramp_in_fraction: float = 0.15
## Ramp-out fraction of duration.
@export_range(0.0, 0.5, 0.01) var ramp_out_fraction: float = 0.35

func get_category_name() -> String:
	return "Audio"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		push_warning("JuiceeReverbEffect: bus '%s' not found" % bus_name)
		return

	# Build a fresh AudioEffectReverb tuned to our params.
	var reverb := AudioEffectReverb.new()
	reverb.room_size = room_size
	reverb.damping = damping
	reverb.spread = spread
	reverb.wet = 0.0
	# Add to the END of the bus's effect chain so it processes last.
	AudioServer.add_bus_effect(bus_idx, reverb)
	var our_slot: int = AudioServer.get_bus_effect_count(bus_idx) - 1
	# stop() removes our reverb - the killed tween's `await` would otherwise skip the
	# removal below and leave the reverb on the bus forever.
	_on_stop(func() -> void:
		if AudioServer.get_bus_index(bus_name) >= 0 \
				and AudioServer.get_bus_effect_count(bus_idx) > our_slot:
			AudioServer.remove_bus_effect(bus_idx, our_slot))

	var effective_wet: float = peak_wet * intensity_mult

	# Ramp wet up, hold, ramp down.
	var ramp_in_dur: float = duration * ramp_in_fraction
	var hold_dur: float = duration * (1.0 - ramp_in_fraction - ramp_out_fraction)
	var ramp_out_dur: float = duration * ramp_out_fraction

	var tree := context.get_tree()
	if not tree:
		AudioServer.remove_bus_effect(bus_idx, our_slot)
		return

	var update_wet := func(v: float) -> void:
		if AudioServer.get_bus_index(bus_name) >= 0 \
				and AudioServer.get_bus_effect_count(bus_idx) > our_slot:
			var rv := AudioServer.get_bus_effect(bus_idx, our_slot) as AudioEffectReverb
			if rv:
				rv.wet = v

	var tween := _track(tree.create_tween())
	tween.tween_method(update_wet, 0.0, effective_wet, ramp_in_dur)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold_dur > 0.0:
		tween.tween_interval(hold_dur)
	tween.tween_method(update_wet, effective_wet, 0.0, ramp_out_dur)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween.finished

	# Remove our reverb cleanly (handle race where bus may have been reset).
	if AudioServer.get_bus_index(bus_name) >= 0 \
			and AudioServer.get_bus_effect_count(bus_idx) > our_slot:
		AudioServer.remove_bus_effect(bus_idx, our_slot)
