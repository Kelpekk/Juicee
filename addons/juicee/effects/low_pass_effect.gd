## Temporarily low-pass filter ("muffle") an entire AudioBus - the classic
## muffled-on-hit, underwater, behind-a-wall, or stunned/concussed feel. Ramps an
## AudioEffectLowPassFilter from fully open (20 kHz) -> target_cutoff -> back open.
##
## Pairs beautifully with HitStop: muffle the audio during the impact freeze, then
## open it back up as time resumes. Lower target_cutoff = more muffled.
##
## Adds and removes its own filter on the bus so it doesn't fight user bus effects.
@tool
class_name JuiceeLowPassEffect
extends JuiceeEffect

const OPEN_HZ := 20000.0  # effectively unfiltered

## Name of the AudioBus to muffle.
@export var bus_name: String = "Master"
## Cutoff frequency at full muffle, in Hz. Lower = more muffled (500 ≈ "behind a wall").
@export_range(80.0, 20000.0, 10.0) var target_cutoff: float = 500.0
## Total duration: ramp-in + hold + ramp-out.
@export_range(0.05, 10.0, 0.05) var duration: float = 0.6
## Ramp-in fraction (how fast it muffles).
@export_range(0.0, 0.5, 0.01) var ramp_in_fraction: float = 0.15
## Ramp-out fraction (how fast it opens back up).
@export_range(0.0, 0.5, 0.01) var ramp_out_fraction: float = 0.35

func get_category_name() -> String:
	return "Audio"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		push_warning("JuiceeLowPassEffect: bus '%s' not found" % bus_name)
		return

	var filter := AudioEffectLowPassFilter.new()
	filter.cutoff_hz = OPEN_HZ
	AudioServer.add_bus_effect(bus_idx, filter)
	var our_slot: int = AudioServer.get_bus_effect_count(bus_idx) - 1
	# stop() removes our filter - the killed tween's `await` would otherwise skip the
	# removal below and leave the bus muffled forever.
	_on_stop(func() -> void:
		if AudioServer.get_bus_index(bus_name) >= 0 \
				and AudioServer.get_bus_effect_count(bus_idx) > our_slot:
			AudioServer.remove_bus_effect(bus_idx, our_slot))

	# Effective cutoff = lerp(open, target, intensity_mult) - weaker intensity muffles less.
	var effective_cutoff: float = lerp(OPEN_HZ, target_cutoff, clamp(intensity_mult, 0.0, 1.0))
	var ramp_in_dur: float = duration * ramp_in_fraction
	var hold_dur: float = duration * (1.0 - ramp_in_fraction - ramp_out_fraction)
	var ramp_out_dur: float = duration * ramp_out_fraction

	var tree := context.get_tree()
	if not tree:
		AudioServer.remove_bus_effect(bus_idx, our_slot)
		return

	var update_cutoff := func(v: float) -> void:
		if AudioServer.get_bus_index(bus_name) >= 0 \
				and AudioServer.get_bus_effect_count(bus_idx) > our_slot:
			var lp := AudioServer.get_bus_effect(bus_idx, our_slot) as AudioEffectLowPassFilter
			if lp:
				lp.cutoff_hz = v

	var tween := _track(tree.create_tween())
	tween.tween_method(update_cutoff, OPEN_HZ, effective_cutoff, ramp_in_dur)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold_dur > 0.0:
		tween.tween_interval(hold_dur)
	tween.tween_method(update_cutoff, effective_cutoff, OPEN_HZ, ramp_out_dur)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween.finished

	if AudioServer.get_bus_index(bus_name) >= 0 \
			and AudioServer.get_bus_effect_count(bus_idx) > our_slot:
		AudioServer.remove_bus_effect(bus_idx, our_slot)
