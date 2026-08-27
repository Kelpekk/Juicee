## Slash arc: a crescent melee swoosh (tapering Line2D) drawn at the node, aimed
## by the "hit_direction" param.
@tool
class_name JuiceeSlashArcEffect
extends JuiceeEffect

## Shared pool so repeated swings reuse the Line2D instead of new + free each time.
static var _pool := JuiceeNodePool.new()

static func _new_line() -> Node:
	return Line2D.new()

## Radius of the arc, how far from the node the slash sweeps.
@export_range(8.0, 400.0, 1.0) var radius: float = 60.0
## Angular length of the arc in degrees, how wide the swoosh is.
@export_range(20.0, 300.0, 5.0) var arc_degrees: float = 140.0
## Thickness of the slash at its fattest point (the ends taper to nothing).
@export_range(1.0, 40.0, 0.5) var thickness: float = 14.0
## How long the slash lasts before it's gone.
@export_range(0.05, 1.0, 0.05) var duration: float = 0.22
## Slash color.
@export var color: Color = Color(1.0, 1.0, 1.0, 0.9)
## Facing used when the caller doesn't pass {"hit_direction": ...}, the arc centers here.
@export var default_direction: Vector2 = Vector2.RIGHT

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Crescent melee swoosh drawn at the node.\nSword swings, claws, dash-attacks. Aim with hit_direction."

func _apply(context: Node, intensity_mult: float) -> void:
	var origin: Node2D = context as Node2D
	if not origin or not origin.is_inside_tree():
		push_warning("JuiceeSlashArcEffect: context is not a Node2D")
		return

	var dir: Vector2 = _runtime_params.get("hit_direction", default_direction)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var center_angle := dir.angle()

	var line: Line2D = _pool.acquire(_new_line)
	line.rotation = 0.0
	line.scale = Vector2.ONE
	line.modulate = Color.WHITE
	line.clear_points()
	var span := deg_to_rad(arc_degrees)
	var segments := 16
	for i in segments + 1:
		var a: float = center_angle - span * 0.5 + span * (float(i) / segments)
		line.add_point(Vector2(cos(a), sin(a)) * radius)
	line.width = thickness * intensity_mult
	# Taper both ends to a point so it reads as a crescent, not a fat band.
	var wc := Curve.new()
	wc.add_point(Vector2(0.0, 0.0))
	wc.add_point(Vector2(0.5, 1.0))
	wc.add_point(Vector2(1.0, 0.0))
	line.width_curve = wc
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = origin.z_index + 1

	# current_scene is null in autoload / added-to-root contexts, fall back to origin.
	var spawn_parent: Node = origin.get_tree().current_scene
	if not spawn_parent:
		spawn_parent = origin
	spawn_parent.add_child(line)
	# World position AFTER parenting, so a non-origin scene root doesn't double the offset.
	line.global_position = origin.global_position

	# Fade out with a touch of expand, then park the Line2D for reuse.
	var tw := line.create_tween().set_parallel(true)
	tw.tween_property(line, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.tween_property(line, "scale", Vector2.ONE * 1.15, duration).set_ease(Tween.EASE_OUT)
	await tw.finished
	if is_instance_valid(line):
		_pool.release(line)
