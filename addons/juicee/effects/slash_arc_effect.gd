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
@export_range(1.0, 40.0, 0.5) var thickness: float = 22.0
## How long the slash lasts before it's gone.
@export_range(0.05, 1.0, 0.05) var duration: float = 0.26
## Slash color.
@export var color: Color = Color(1.0, 1.0, 1.0, 1.0)
## Facing used when the caller doesn't pass {"hit_direction": ...}, the arc centers here.
@export var default_direction: Vector2 = Vector2.RIGHT

@export_group("Advanced")
## Sweep the arc through this many extra degrees during its life, so the slash travels
## instead of appearing whole. 0 = it flashes in place.
@export_range(0.0, 360.0, 5.0) var sweep_degrees: float = 55.0
## Draw a fainter echo arc just behind the main one, for a layered double-slash.
@export_range(0.0, 1.0, 0.05) var echo_strength: float = 0.0
## How much the arc expands outward as it fades. 1.15 is the default flare; 1 = no growth.
@export_range(1.0, 2.0, 0.05) var expand: float = 1.15

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["sweep_degrees", "echo_strength", "expand"]))

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Crescent melee swoosh drawn at the node.\nSword swings, claws, dash-attacks. Aim with hit_direction."

func _apply(context: Node, intensity_mult: float) -> void:
	var origin: Node2D = context as Node2D
	if not origin or not origin.is_inside_tree():
		_warn("JuiceeSlashArcEffect: context is not a Node2D")
		return

	var dir: Vector2 = _param("hit_direction", default_direction)
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
		line.add_point(Vector2(cos(a), sin(a)) * _px(radius))
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

	# Shared, so this also lands correctly when the target is inside a SubViewport rather
	# than under the running scene. Its own copy of the lookup did not.
	var spawn_parent: Node = _spawn_parent(origin)
	line.name = StringName("_juicee_slash_%d" % randi())
	spawn_parent.add_child(line)
	# World position AFTER parenting, so a non-origin scene root doesn't double the offset.
	line.global_position = origin.global_position

	# Advanced echo: a fainter trailing arc just behind the main one, so the swing reads
	# as a double slash. It is a plain Line2D copy that fades on its own.
	if echo_strength > 0.0:
		var echo := Line2D.new()
		echo.points = line.points
		echo.width = line.width * 0.7
		echo.width_curve = wc
		echo.default_color = Color(color.r, color.g, color.b, color.a * echo_strength)
		echo.joint_mode = Line2D.LINE_JOINT_ROUND
		echo.begin_cap_mode = Line2D.LINE_CAP_ROUND
		echo.end_cap_mode = Line2D.LINE_CAP_ROUND
		echo.z_index = line.z_index - 1
		echo.name = StringName("_juicee_slash_echo_%d" % randi())
		spawn_parent.add_child(echo)
		echo.global_position = line.global_position
		echo.rotation = -deg_to_rad(sweep_degrees) * 0.35
		var etw := echo.create_tween().set_parallel(true)
		etw.tween_property(echo, "modulate:a", 0.0, duration * 1.2).set_ease(Tween.EASE_IN)
		etw.tween_property(echo, "scale", Vector2.ONE * expand, duration * 1.2).set_ease(Tween.EASE_OUT)
		etw.finished.connect(func() -> void:
			if is_instance_valid(echo):
				echo.queue_free(), CONNECT_ONE_SHOT)

	# Fade out with a touch of expand, then park the Line2D for reuse.
	var tw := line.create_tween().set_parallel(true)
	tw.tween_property(line, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.tween_property(line, "scale", Vector2.ONE * expand, duration).set_ease(Tween.EASE_OUT)
	# Advanced sweep: rotate the arc through the swing instead of flashing in place.
	if sweep_degrees != 0.0:
		tw.tween_property(line, "rotation", deg_to_rad(sweep_degrees), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _tween_done(tw)
	if is_instance_valid(line):
		_pool.release(line)
