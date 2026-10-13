## Temporarily inject an AudioEffectReverb on an AudioBus - the "cathedral
## tail" / "underwater" feel for boss intros, dimension shifts, low-health
## states, dramatic moments.
##
## Adds the AudioEffectReverb at the END of the target bus's effect chain,
## animates wet level in/out, then removes it cleanly. Each call adds its own
## reverb, so overlapping calls stack.
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

@export_group("Advanced")
## Delay before the reverb tail starts (milliseconds). Larger values push the space
## further away, the difference between a tiled room and a canyon.
@export_range(0.0, 500.0, 1.0) var predelay_msec: float = 150.0
## High-pass applied to the reverb tail (0-1). Raise it to keep bass out of the wash so
## the mix stays clear.
@export_range(0.0, 1.0, 0.01) var hipass: float = 0.0
## Dry (unprocessed) signal level kept alongside the reverb.
@export_range(0.0, 1.0, 0.01) var dry: float = 1.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["predelay_msec", "hipass", "dry"]))
	_hint_audio_bus(property)

func get_category_name() -> String:
	return "Audio"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		_warn("JuiceeReverbEffect: bus '%s' not found" % bus_name)
		return

	# Build a fresh AudioEffectReverb tuned to our params.
	var reverb := AudioEffectReverb.new()
	reverb.room_size = room_size
	reverb.damping = damping
	reverb.spread = spread
	# Advanced: predelay places the space, hipass keeps bass out of the tail, dry
	# controls how much unprocessed signal stays alongside it.
	reverb.predelay_msec = predelay_msec
	reverb.hipass = hipass
	reverb.dry = dry
	reverb.wet = 0.0
	# Add to the END of the bus's effect chain so it processes last.
	AudioServer.add_bus_effect(bus_idx, reverb)
	# stop() removes our reverb - the killed tween's `await` would otherwise skip the
	# removal below and leave the reverb on the bus forever.
	_on_stop(_remove_bus_effect.bind(bus_name, reverb))

	var effective_wet: float = peak_wet * intensity_mult

	# Ramp wet up, hold, ramp down.
	var ramp_in_dur: float = duration * ramp_in_fraction
	var hold_dur: float = duration * (1.0 - ramp_in_fraction - ramp_out_fraction)
	var ramp_out_dur: float = duration * ramp_out_fraction

	var tree := context.get_tree()
	if not tree:
		_remove_bus_effect(bus_name, reverb)
		return

	var update_wet := func(v: float) -> void:
		reverb.wet = v

	var tween := _track(tree.create_tween())
	tween.tween_method(update_wet, 0.0, effective_wet, ramp_in_dur)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold_dur > 0.0:
		tween.tween_interval(hold_dur)
	tween.tween_method(update_wet, effective_wet, 0.0, ramp_out_dur)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween.finished
	if _gen != play:
		return

	# Remove our reverb cleanly (handle race where bus may have been reset).
	_remove_bus_effect(bus_name, reverb)
