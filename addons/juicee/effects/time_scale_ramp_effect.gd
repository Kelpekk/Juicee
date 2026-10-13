## Smooth slow-motion ramp via Engine.time_scale.
## Unlike JuiceeHitStopEffect (which is instant freeze + restore), this ramps
## time_scale -> target -> back with easing for cinematic slow-mo.
@tool
class_name JuiceeTimeScaleRampEffect
extends JuiceeEffect

## Engine.time_scale at the bottom of the ramp. 0.2 = cinematic slow-mo, 0.5 = subtle.
@export_range(0.0, 1.0, 0.01) var target_scale: float = 0.2
## Time to ramp down to target_scale.
@export_range(0.05, 5.0, 0.05) var ramp_in: float = 0.15
## How long to hold at target_scale before ramping back.
@export_range(0.05, 5.0, 0.05) var hold: float = 0.4
## Time to ramp back up to normal speed.
@export_range(0.05, 5.0, 0.05) var ramp_out: float = 0.3
## Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest.
@export var trans_type: Tween.TransitionType = Tween.TRANS_SINE

@export_group("Advanced")
## Hand-drawn curve (0..1) shaping the ramp into slow motion. FEEL-style curve control.
@export var ease_curve: Curve
## Pitch the audio bus down with the slow motion, so the whole moment sags together
## instead of the music carrying on at full speed. Empty = leave audio alone.
@export var pitch_bus: StringName = &""

func _validate_property(property_info: Dictionary) -> void:
	_gate_advanced(property_info, PackedStringArray(["ease_curve", "pitch_bus"]))
	_hint_audio_bus(property_info, true)

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if Engine.is_editor_hint():
		return
	if not context or not context.is_inside_tree():
		return

	# Ref-counted via JuiceeStateStack so a ramp starting during a hit-stop/freeze
	# captures the TRUE original (not the frozen 0.0) and only restores when it's
	# the last time-effect to release - otherwise the ramp would restore to 0 and
	# leave the game frozen.
	var original: float = _capture_state(Engine, "time_scale")
	var effective_target := lerpf(original, target_scale, clampf(intensity_mult, 0.0, 1.0))
	var tree := context.get_tree()

	# Use unscaled timers so the ramp itself plays in real time.
	# Advanced pitch_bus sags the audio with the slow motion, so the whole moment drops
	# together instead of the music carrying on at full speed.
	var pitch_idx: int = AudioServer.get_bus_index(pitch_bus) if not pitch_bus.is_empty() else -1
	var pitch_fx: AudioEffectPitchShift = null
	if pitch_idx >= 0:
		pitch_fx = AudioEffectPitchShift.new()
		pitch_fx.pitch_scale = 1.0
		AudioServer.add_bus_effect(pitch_idx, pitch_fx)
		_on_stop(_remove_bus_effect.bind(String(pitch_bus), pitch_fx))

	var apply_scale := func(v: float) -> void:
		_set_time_scale(v)
		if pitch_fx:
			pitch_fx.pitch_scale = clampf(v, 0.05, 4.0)

	# Counted on unscaled_seconds(): a tween runs on scaled time and would slow itself down, and
	# Tween.set_ignore_time_scale only exists from Godot 4.4.
	# A play stopped or replaced on the way returns at once: stop() has put the time scale back
	# and taken the pitch effect off the bus.
	await _ramp(tree, apply_scale, original, effective_target, ramp_in, Tween.EASE_OUT, ease_curve, play)
	if _gen != play:
		return

	await tree.create_timer(hold, true, false, true).timeout
	if _gen != play:
		return

	await _ramp(tree, apply_scale, effective_target, original, ramp_out, Tween.EASE_IN, null, play)
	if _gen != play:
		return
	# Take the temporary pitch effect back off the bus now that time is normal again.
	_drop_pitch(pitch_fx)
	_release_state(Engine, "time_scale")

## Moves time_scale from one value to another over `duration` seconds of unscaled time, one
## write per frame. Stops early if the play is stopped or replaced.
func _ramp(tree: SceneTree, apply_scale: Callable, start_scale: float, end_scale: float,
		duration: float, ease_type: Tween.EaseType, curve: Curve, gen: int) -> void:
	var began := unscaled_seconds()
	while _gen == gen:
		# A ramp of no length is already at its end; 0 / 0 would put NaN into the time scale.
		var t: float = 1.0 if duration <= 0.0 else clampf((unscaled_seconds() - began) / duration, 0.0, 1.0)
		var k: float = curve.sample(t) if curve else float(Tween.interpolate_value(0.0, 1.0, t, 1.0, trans_type, ease_type))
		apply_scale.call(lerpf(start_scale, end_scale, k))
		if t >= 1.0:
			return
		await tree.process_frame

func _drop_pitch(fx: AudioEffectPitchShift) -> void:
	if fx:
		_remove_bus_effect(String(pitch_bus), fx)

func _set_time_scale(v: float) -> void:
	Engine.time_scale = v

func create_unscaled_tween(tree: SceneTree) -> Tween:
	var t := tree.create_tween()
	# Ignores Engine.time_scale on Godot 4.4 and later. Called by name so 4.3 still parses this.
	if t.has_method("set_ignore_time_scale"):
		t.call("set_ignore_time_scale", true)
	return t
