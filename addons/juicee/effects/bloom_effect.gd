## Pulse the WorldEnvironment glow (bloom) - for boss intros, level-up flashes,
## power-up activations. Works in both 2D and 3D scenes as long as there's an
## active WorldEnvironment with `glow_enabled = true` in its Environment.
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
## Optional intensity curve for designer-controlled feel (overrides linear ramp).
@export var intensity_curve: Curve

func get_category_name() -> String:
	return "Screen"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return

	var env: Environment = _find_active_environment(context)
	if not env:
		push_warning("JuiceeBloomEffect: no WorldEnvironment with glow_enabled found")
		return

	# Force glow on if currently off (caller might rely on the effect to enable it).
	var was_glow_enabled: bool = env.glow_enabled
	if not was_glow_enabled:
		env.glow_enabled = true

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

	if _cancelled:
		_restore_env(env, was_glow_enabled, orig_intensity, orig_strength, orig_bloom)
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

	# fade_out=false means "stays at peak" - release WITHOUT restoring so it persists.
	_restore_env(env, was_glow_enabled, orig_intensity, orig_strength, orig_bloom, fade_out)

func _restore_env(env: Environment, was_glow_enabled: bool, orig_intensity: float,
		orig_strength: float, orig_bloom: float, restore: bool = true) -> void:
	if not is_instance_valid(env):
		_release_state(env, "glow_intensity")
		_release_state(env, "glow_strength")
		_release_state(env, "glow_bloom")
		return
	# Restore from the stack (handles concurrent effects correctly), unless we're
	# intentionally leaving the glow boosted (fade_out=false).
	if restore:
		env.glow_intensity = orig_intensity
		env.glow_strength = orig_strength
		env.glow_bloom = orig_bloom
		if not was_glow_enabled:
			env.glow_enabled = false
	_release_state(env, "glow_intensity", restore)
	_release_state(env, "glow_strength", restore)
	_release_state(env, "glow_bloom", restore)

# Walks the scene tree looking for an active WorldEnvironment node and returns
# its Environment resource. WorldEnvironment nodes can be 2D or 3D scoped
# (Camera2D/Camera3D environment overrides also count, but most projects use
# a single WorldEnvironment under the scene root).
func _find_active_environment(context: Node) -> Environment:
	# Prefer the WorldEnvironment in the context's OWN viewport. That's the one that
	# actually affects how the context renders, it keeps an effect fired inside a
	# SubViewport (like the editor's hover preview) from reaching into another scene,
	# and it's correct for split-screen / multi-viewport setups. Fall back to the
	# current scene for the plain single-viewport case.
	var vp := context.get_viewport()
	if vp:
		var in_viewport := _scan_for_env(vp)
		if in_viewport:
			return in_viewport
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
