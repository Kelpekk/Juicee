## Smooth slow-motion ramp via Engine.time_scale.
## Unlike JuiceeHitStopEffect (which is instant freeze + restore), this tweens
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
@export var trans_type: Tween.TransitionType = Tween.TRANS_SINE

func _apply(context: Node, intensity_mult: float) -> void:
	if Engine.is_editor_hint():
		return
	if not context or not context.is_inside_tree():
		return

	# Ref-counted via JuiceeStateStack so a ramp starting during a hit-stop/freeze
	# captures the TRUE original (not the frozen 0.0) and only restores when it's
	# the last time-effect to release - otherwise the ramp would restore to 0 and
	# leave the game frozen.
	var original: float = _capture_state(Engine, "time_scale")
	var effective_target := lerp(original, target_scale, clamp(intensity_mult, 0.0, 1.0))
	var tree := context.get_tree()

	# Use unscaled timers so the ramp itself plays in real time.
	var t1 := _track(create_unscaled_tween(tree))
	t1.tween_method(_set_time_scale, original, effective_target, ramp_in)\
		.set_trans(trans_type).set_ease(Tween.EASE_OUT)
	await t1.finished
	if _cancelled:
		_release_state(Engine, "time_scale")
		return

	await tree.create_timer(hold, true, false, true).timeout
	if _cancelled:
		_release_state(Engine, "time_scale")
		return

	var t2 := _track(create_unscaled_tween(tree))
	t2.tween_method(_set_time_scale, effective_target, original, ramp_out)\
		.set_trans(trans_type).set_ease(Tween.EASE_IN)
	await t2.finished

	_release_state(Engine, "time_scale")

func _set_time_scale(v: float) -> void:
	Engine.time_scale = v

func create_unscaled_tween(tree: SceneTree) -> Tween:
	var t := tree.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)  # physics-frame ticking ignores Engine.time_scale partially
	return t
