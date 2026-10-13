## Pulse the WorldEnvironment glow (bloom) - for boss intros, level-up flashes,
## power-up activations. Works in both 2D and 3D scenes as long as there's an
## active WorldEnvironment. Glow is switched on for the play if it was off.
##
## Uses Godot's BUILT-IN post-process pipeline - no custom shader, no shader
## overlay, no SCREEN_TEXTURE sampling. Pure native performance.
##
## Captures the original glow values via JuiceeStateStack so concurrent bloom
## effects (or other systems touching glow) restore correctly.
@tool
class_name JuiceeBloomEffect
extends JuiceeEffect

## Peak glow intensity (added on top of the env's current intensity).
@export_range(0.0, 5.0, 0.05) var intensity_boost: float = 1.5
## Peak glow strength multiplier.
@export_range(1.0, 3.0, 0.05) var strength_multiplier: float = 1.2
## Peak glow bloom amount.
@export_range(0.0, 1.0, 0.01) var bloom_amount: float = 0.4
## Total duration (ramp up + hold + ramp down).
@export_range(0.05, 5.0, 0.05) var duration: float = 0.6
## If true, glow fades back to original at the end. If false, stays at peak.
@export var fade_out: bool = true
## Optional intensity curve for designer-controlled feel (replaces the built-in ease on the swell).
@export var intensity_curve: Curve

@export_group("Advanced")
## Seconds to hold at peak glow before it fades back. 0 = fade straight back.
@export_range(0.0, 30.0, 0.05) var hold_time: float = 0.0
## Throb the glow in and out this many times instead of one swell. 3+ reads as a
## charging / powering-up pulse.
@export_range(1, 12, 1) var pulse_count: int = 1

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["hold_time", "pulse_count"]))

func get_category_name() -> String:
	return "Screen"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return

	var env: Environment = _find_active_environment(context)
	if not env:
		_warn("JuiceeBloomEffect: no WorldEnvironment found")
		return

	# Glow has to be on for the boost to show. It is held on the stack like the rest, so stop()
	# turns it back off as well as the end of the play does.
	_capture_state(env, "glow_enabled")
	env.glow_enabled = true
	var play := _gen

	var orig_intensity: float = _capture_state(env, "glow_intensity")
	var orig_strength: float = _capture_state(env, "glow_strength")
	var orig_bloom: float = _capture_state(env, "glow_bloom")

	var peak_intensity: float = orig_intensity + intensity_boost * intensity_mult
	var peak_strength: float = orig_strength * strength_multiplier
	var peak_bloom: float = clamp(orig_bloom + bloom_amount * intensity_mult, 0.0, 1.0)

	var tween := _track(context.get_tree().create_tween()).set_parallel(true)
	if intensity_curve:
		_tween_curved(tween, env, "glow_intensity", orig_intensity, peak_intensity, duration * 0.3, intensity_curve)
		_tween_curved(tween, env, "glow_strength", orig_strength, peak_strength, duration * 0.3, intensity_curve)
		_tween_curved(tween, env, "glow_bloom", orig_bloom, peak_bloom, duration * 0.3, intensity_curve)
	else:
		tween.tween_property(env, "glow_intensity", peak_intensity, duration * 0.3)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(env, "glow_strength", peak_strength, duration * 0.3)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(env, "glow_bloom", peak_bloom, duration * 0.3)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tween.finished
	if _gen != play:
		return

	# Advanced: extra throbs after the first swell, then the usual hold / fade.
	if pulse_count > 1:
		var tree := context.get_tree()
		for i in pulse_count - 1:
			if not is_instance_valid(env):
				break
			var down := _track(tree.create_tween()).set_parallel(true)
			down.tween_property(env, "glow_intensity", orig_intensity, duration * 0.3)
			down.tween_property(env, "glow_bloom", orig_bloom, duration * 0.3)
			await down.finished
			if _gen != play:
				return
			if not is_instance_valid(env):
				break
			var up := _track(tree.create_tween()).set_parallel(true)
			up.tween_property(env, "glow_intensity", peak_intensity, duration * 0.3)
			up.tween_property(env, "glow_bloom", peak_bloom, duration * 0.3)
			await up.finished
			if _gen != play:
				return

	if hold_time > 0.0:
		await context.get_tree().create_timer(hold_time, true, false, false).timeout
		if _gen != play:
			return

	if fade_out:
		var back := _track(context.get_tree().create_tween()).set_parallel(true)
		back.tween_property(env, "glow_intensity", orig_intensity, duration * 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		back.tween_property(env, "glow_strength", orig_strength, duration * 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		back.tween_property(env, "glow_bloom", orig_bloom, duration * 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await back.finished

	if _gen != play:
		return
	# The stack restores, and only once the last bloom on this environment is done. fade_out=false
	# means "stays at peak": the values stay held, and stop() gives them back.
	if fade_out:
		for prop in ["glow_enabled", "glow_intensity", "glow_strength", "glow_bloom"]:
			_release_state(env, prop)
