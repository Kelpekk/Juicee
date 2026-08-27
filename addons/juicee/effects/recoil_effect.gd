## Directional position kick on a Node2D - the snap-back of firing a gun,
## absorbing a hit, or stiff-arming an opponent.
##
## Unlike `JuiceePositionEffect` (omnidirectional offset), Recoil takes a
## specific direction (typically `-aim_direction`) and ramps it back fast.
## Use `direction` @export or pass `{"direction": Vector2(...)}` via runtime
## params for dynamic kicks (e.g. point AWAY from the bullet's travel
## direction every time the player fires).
@tool
class_name JuiceeRecoilEffect
extends JuiceeEffect

## Direction of the kick (gets normalized). Pass via runtime params for dynamic
## per-shot direction.
@export var direction: Vector2 = Vector2(-1, 0)
## Magnitude in pixels of the initial kick.
@export_range(0.0, 200.0, 1.0) var kick_distance: float = 12.0
## How long the kick spends extending out (very brief).
@export_range(0.02, 1.0, 0.01) var attack: float = 0.05
## How long the spring-back lasts (longer than attack for "ease-back" feel).
@export_range(0.02, 2.0, 0.01) var return_duration: float = 0.18
## Settle wobble - number of small overshoot oscillations during return.
@export_range(0.0, 5.0, 0.5) var settle_wobble: float = 1.5

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_SCREENSHAKE

func get_category_name() -> String:
	return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		push_warning("JuiceeRecoilEffect: context is not a Node2D")
		return

	var dir_param: Vector2 = _runtime_params.get("direction", direction)
	if dir_param.length_squared() < 0.0001:
		dir_param = direction
	var dir: Vector2 = dir_param.normalized()

	var original_position: Vector2 = _capture_state(target, "position")
	var kick_offset: Vector2 = dir * (kick_distance * intensity_mult)

	# Fast attack: snap to kicked position.
	var tween := _track(target.create_tween())
	tween.tween_property(target, "position", original_position + kick_offset, attack)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Spring back: elastic-out with overshoot scaled by settle_wobble.
	var return_tween := tween.tween_property(target, "position", original_position, return_duration)
	if settle_wobble > 0.1:
		return_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		return_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tween.finished
	if is_instance_valid(target):
		target.position = original_position
	_release_state(target, "position")
