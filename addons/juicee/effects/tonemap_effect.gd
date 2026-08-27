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

func get_category_name() -> String:
	return "Screen"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var env: Environment = _find_active_environment(context)
	if not env:
		push_warning("JuiceeTonemapEffect: no WorldEnvironment found")
		return

	var orig_exposure: float = _capture_state(env, "tonemap_exposure")
	var orig_white: float = _capture_state(env, "tonemap_white")
	var peak_exposure: float = orig_exposure + exposure_boost * intensity_mult

	var tween := _track(context.get_tree().create_tween()).set_parallel(true)
	if exposure_curve:
		_tween_curved(tween, env, "tonemap_exposure", orig_exposure, peak_exposure, duration * 0.3, exposure_curve)
		_tween_curved(tween, env, "tonemap_white", orig_white, white_target, duration * 0.3, exposure_curve)
	else:
		tween.tween_property(env, "tonemap_exposure", peak_exposure, duration * 0.3)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(env, "tonemap_white", white_target, duration * 0.3)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tween.finished

	if _cancelled or not is_instance_valid(env):
		_restore(env, orig_exposure, orig_white)
		return

	if fade_out:
		var back := _track(context.get_tree().create_tween()).set_parallel(true)
		back.tween_property(env, "tonemap_exposure", orig_exposure, duration * 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		back.tween_property(env, "tonemap_white", orig_white, duration * 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await back.finished

	# fade_out=false means "stays punched" - release WITHOUT restoring so it persists.
	_restore(env, orig_exposure, orig_white, fade_out)

func _restore(env: Environment, orig_exposure: float, orig_white: float, restore: bool = true) -> void:
	if restore and is_instance_valid(env):
		env.tonemap_exposure = orig_exposure
		env.tonemap_white = orig_white
	_release_state(env, "tonemap_exposure", restore)
	_release_state(env, "tonemap_white", restore)

func _find_active_environment(context: Node) -> Environment:
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree else context
	if not root:  # current_scene is null in autoload / added-to-root contexts
		root = context
	return _scan_for_env(root)

func _scan_for_env(node: Node) -> Environment:
	if node == null:
		return null
	if node is WorldEnvironment:
		var we := node as WorldEnvironment
		if we.environment:
			return we.environment
	for child in node.get_children():
		var found := _scan_for_env(child)
		if found:
			return found
	return null
