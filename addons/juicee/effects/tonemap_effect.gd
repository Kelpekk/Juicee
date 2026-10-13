## Punch the WorldEnvironment tonemap exposure + white - the "flashbang" /
## camera-overload feel for explosions, teleports, dimension shifts.
##
## Works in 2D + 3D as long as there's a WorldEnvironment in the scene.
## Captures original env values via JuiceeStateStack for concurrent safety.
@tool
class_name JuiceeTonemapEffect
extends JuiceeEffect

## Peak exposure boost (added on top of current).
@export_range(0.0, 10.0, 0.1) var exposure_boost: float = 3.0
## Peak white shift (lower = blown out, higher = darker midtones).
@export_range(0.1, 5.0, 0.05) var white_target: float = 0.5
## Total duration (ramp up + hold + ramp down).
@export_range(0.05, 5.0, 0.05) var duration: float = 0.4
## If true, exposure fades back to original at end. If false, stays punched.
@export var fade_out: bool = true
## Optional curve for the punch shape.
@export var exposure_curve: Curve

@export_group("Advanced")
## Seconds to hold the blown-out exposure before it settles. 0 = settle immediately.
## A longer hold sells a proper flashbang.
@export_range(0.0, 10.0, 0.05) var hold_time: float = 0.0
## Fraction of the duration spent punching up. 0.3 = a fast overload, slow recovery.
@export_range(0.05, 0.95, 0.05) var attack_ratio: float = 0.3

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["hold_time", "attack_ratio"]))

func get_category_name() -> String:
	return "Screen"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var env: Environment = _find_active_environment(context)
	if not env:
		_warn("JuiceeTonemapEffect: no WorldEnvironment found")
		return

	var play := _gen
	var orig_exposure: float = _capture_state(env, "tonemap_exposure")
	var orig_white: float = _capture_state(env, "tonemap_white")
	var peak_exposure: float = orig_exposure + exposure_boost * intensity_mult

	var tween := _track(context.get_tree().create_tween()).set_parallel(true)
	if exposure_curve:
		_tween_curved(tween, env, "tonemap_exposure", orig_exposure, peak_exposure, duration * attack_ratio, exposure_curve)
		_tween_curved(tween, env, "tonemap_white", orig_white, white_target, duration * attack_ratio, exposure_curve)
	else:
		tween.tween_property(env, "tonemap_exposure", peak_exposure, duration * attack_ratio)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(env, "tonemap_white", white_target, duration * attack_ratio)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tween.finished
	# A newer play or stop() holds the exposure now.
	if _gen != play:
		return

	# Advanced: sit at the blown-out exposure before it recovers (a real flashbang).
	if hold_time > 0.0:
		await context.get_tree().create_timer(hold_time, true, false, false).timeout
		if _gen != play:
			return

	if fade_out:
		var release_t: float = duration * (1.0 - attack_ratio)
		var back := _track(context.get_tree().create_tween()).set_parallel(true)
		back.tween_property(env, "tonemap_exposure", orig_exposure, release_t)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		back.tween_property(env, "tonemap_white", orig_white, release_t)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await back.finished
		if _gen != play:
			return
		_release_state(env, "tonemap_exposure")
		_release_state(env, "tonemap_white")
	# fade_out=false means "stays punched": the exposure stays held, and stop() gives it back.
