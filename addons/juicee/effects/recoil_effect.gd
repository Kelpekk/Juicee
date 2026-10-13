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
## Settle wobble: above 0.1 the return springs back with an elastic wobble; at or below, it overshoots once.
@export_range(0.0, 5.0, 0.5) var settle_wobble: float = 1.5

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing the spring-back for the return. FEEL-style.
@export var ease_curve: Curve
## Degrees the node also rotates on the kick (a gun barrel rising), returning with it.
@export_range(-90.0, 90.0, 1.0) var rotation_kick: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "rotation_kick"]))

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_SCREENSHAKE

func get_category_name() -> String:
	return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		_warn("JuiceeRecoilEffect: context is not a Node2D")
		return

	var dir_param: Vector2 = _param("direction", direction)
	if dir_param.length_squared() < 0.0001:
		dir_param = direction
	var dir: Vector2 = dir_param.normalized()

	var original_position: Vector2 = _capture_state(target, "position")
	var kick_offset: Vector2 = dir * (kick_distance * intensity_mult)

	# Advanced: also rotate on the kick (gun barrel rising), on its own tracked tween.
	if rotation_kick != 0.0:
		var orig_rot: float = _capture_state(target, "rotation")
		var kicked_rot := orig_rot + deg_to_rad(rotation_kick) * intensity_mult
		var rtw := _track(target.create_tween())
		rtw.tween_property(target, "rotation", kicked_rot, attack)\
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		rtw.tween_property(target, "rotation", orig_rot, return_duration)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		rtw.finished.connect(func() -> void:
			if is_instance_valid(target):
				target.rotation = orig_rot
			_release_state(target, "rotation"), CONNECT_ONE_SHOT)

	# Fast attack: snap to kicked position.
	var tween := _track(target.create_tween())
	tween.tween_property(target, "position", original_position + kick_offset, attack)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Spring back: ease_curve (advanced) if set, else elastic/back scaled by settle_wobble.
	if ease_curve:
		_tween_curved(tween, target, "position", original_position + kick_offset, original_position, return_duration, ease_curve)
	else:
		var return_tween := tween.tween_property(target, "position", original_position, return_duration)
		if settle_wobble > 0.1:
			return_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		else:
			return_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tween.finished
	if _gen != play:
		return
	if is_instance_valid(target):
		target.position = original_position
	_release_state(target, "position")
