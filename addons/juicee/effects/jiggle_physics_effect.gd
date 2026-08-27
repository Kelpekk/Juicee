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
## Maximum simulation time. The spring may settle before this elapses.
@export_range(0.1, 5.0, 0.05) var duration: float = 0.7

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		push_warning("JuiceeJigglePhysicsEffect: context is not a Node2D")
		return

	var original_scale: Vector2 = _capture_state(target, "scale")
	var offset: Vector2 = Vector2.ZERO
	var velocity: Vector2 = impulse * intensity_mult
	var elapsed: float = 0.0
	var tree: SceneTree = target.get_tree()
	var step: float = 1.0 / 60.0

	while elapsed < duration and is_instance_valid(target) and not _cancelled:
		# Spring physics: F = -k*x - d*v
		var force: Vector2 = -stiffness * offset - damping * velocity
		velocity += force * step
		offset += velocity * step
		target.scale = original_scale + Vector2(original_scale.x * offset.x, original_scale.y * offset.y)
		await tree.create_timer(step, true, false, false).timeout
		elapsed += step

	# Ease smoothly back to rest - a high-impulse spring may still be oscillating
	# when `duration` elapses, and the state-stack restore would otherwise snap it.
	if is_instance_valid(target) and not _cancelled:
		var settle := _track(target.create_tween())
		settle.tween_property(target, "scale", original_scale, 0.12)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await settle.finished

	_release_state(target, "scale")
