## Spring-based jiggle on a Node2D's scale - like a jelly cube reacting to a poke.
## Custom physics simulation per-frame (not just a Tween preset).
@tool
class_name JuiceeJigglePhysicsEffect
extends JuiceeEffect

## Spring stiffness (k). Higher = faster oscillation, snappier feel.
@export_range(0.1, 50.0, 0.1) var stiffness: float = 8.0
## Damping coefficient. Higher = settles faster, lower = wobbles longer.
@export_range(0.1, 30.0, 0.1) var damping: float = 2.5
## Initial velocity impulse on the spring (relative scale offset per axis).
@export var impulse: Vector2 = Vector2(0.4, -0.4)
## Simulation time, followed by a quick ease back to rest.
@export_range(0.1, 5.0, 0.05) var duration: float = 0.7

@export_group("Advanced")
## Degrees of rotation jiggle driven by the same spring, for a wobblier gel. 0 = scale only.
@export_range(0.0, 45.0, 1.0) var rotation_jiggle: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["rotation_jiggle"]))

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		_warn("JuiceeJigglePhysicsEffect: context is not a Node2D")
		return

	var play := _gen
	var original_scale: Vector2 = _capture_state(target, "scale")
	var jiggle_rot := rotation_jiggle > 0.0
	var orig_rot: float = _capture_state(target, "rotation") if jiggle_rot else 0.0
	var offset: Vector2 = Vector2.ZERO
	var velocity: Vector2 = impulse * intensity_mult
	var elapsed: float = 0.0
	var tree: SceneTree = target.get_tree()
	var step: float = 1.0 / 60.0

	while elapsed < duration and is_instance_valid(target) and _gen == play:
		# Spring physics: F = -k*x - d*v
		var s := _spring_step(offset, velocity, stiffness, damping, 1.0, step)
		offset = s[0]
		velocity = s[1]
		target.scale = original_scale + Vector2(original_scale.x * offset.x, original_scale.y * offset.y)
		if jiggle_rot:
			target.rotation = orig_rot + deg_to_rad(rotation_jiggle) * offset.x * 2.5
		elapsed += await _wait_step(tree, step)

	# Ease smoothly back to rest - a high-impulse spring may still be oscillating
	# when `duration` elapses, and the state-stack restore would otherwise snap it.
	if is_instance_valid(target) and _gen == play:
		var settle := _track(target.create_tween()).set_parallel(true)
		settle.tween_property(target, "scale", original_scale, 0.12)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if jiggle_rot:
			settle.tween_property(target, "rotation", orig_rot, 0.12)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await settle.finished
	# A newer play or stop() holds these now.
	if _gen != play:
		return
	_release_state(target, "scale")
	if jiggle_rot:
		_release_state(target, "rotation")
