## Radiating impact cracks: jagged Line2D fracture lines bursting from a point.
@tool
class_name JuiceeCrackEffect
extends JuiceeEffect

## Shared pool so repeated impacts reuse the crack lines instead of new + free each.
static var _pool := JuiceeNodePool.new()

static func _new_line() -> Node:
	return Line2D.new()

## How many cracks radiate out from the impact point.
@export_range(2, 16, 1) var count: int = 5
## How far each crack reaches, in pixels.
@export_range(10.0, 400.0, 1.0) var length: float = 70.0
## Jaggedness, how much each crack zig-zags off a straight line (0 = straight spokes).
@export_range(0.0, 1.0, 0.05) var jaggedness: float = 0.4
## Line thickness at the base (each crack tapers to a point at its tip).
@export_range(1.0, 20.0, 0.5) var thickness: float = 5.0
## How long the cracks stay before fading out.
@export_range(0.05, 2.0, 0.05) var duration: float = 0.5
## Crack color.
@export var color: Color = Color(0.95, 0.95, 1.0, 0.9)

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Jagged fracture lines bursting from a point.\nHeavy landings, boss slams, shatters, big impacts."

func _apply(context: Node, intensity_mult: float) -> void:
	var origin: Node2D = context as Node2D
	if not origin or not origin.is_inside_tree():
		push_warning("JuiceeCrackEffect: context is not a Node2D")
		return

	var n: int = max(2, count)
	var base_pos := origin.global_position
	# current_scene is null in autoload / added-to-root contexts, fall back to origin.
	var spawn_parent: Node = origin.get_tree().current_scene
	if not spawn_parent:
		spawn_parent = origin
	for i in n:
		var angle: float = TAU * (float(i) / n) + randf_range(-0.3, 0.3)
		_spawn_crack(origin, spawn_parent, base_pos, angle, intensity_mult)

	# Hold until the cracks have faded; each one releases itself to the pool.
	await origin.get_tree().create_timer(duration, true, false, false).timeout

## Builds one jagged crack line from the impact point outward at `angle`, snaps it in
## then fades it, and parks it back in the pool. Each crack is independent.
func _spawn_crack(origin: Node2D, parent: Node, base_pos: Vector2, angle: float, mult: float) -> void:
	var line: Line2D = _pool.acquire(_new_line)
	line.rotation = 0.0
	line.modulate = Color.WHITE
	line.clear_points()
	var dir := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-dir.y, dir.x)
	var len: float = length * mult
	var segments := 4
	for s in segments + 1:
		var t: float = float(s) / segments
		# Inner and tip points sit on the spoke; middle points jitter sideways.
		var jitter: float = 0.0 if (s == 0 or s == segments) else randf_range(-1.0, 1.0) * jaggedness * len * 0.15
		line.add_point(dir * (len * t) + perp * jitter)
	line.width = thickness
	# Thick at the base, tapering to a point at the tip.
	var wc := Curve.new()
	wc.add_point(Vector2(0.0, 1.0))
	wc.add_point(Vector2(1.0, 0.0))
	line.width_curve = wc
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = origin.z_index + 1
	parent.add_child(line)
	# World position AFTER parenting, so a non-origin scene root doesn't double the offset.
	line.global_position = base_pos

	# Snap out from the centre, hold, then fade. Ghost-owned tween, independent of the effect.
	line.scale = Vector2(0.6, 0.6)
	var tw := line.create_tween()
	tw.tween_property(line, "scale", Vector2.ONE, duration * 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(duration * 0.45)
	tw.tween_property(line, "modulate:a", 0.0, duration * 0.4)
	tw.finished.connect(func() -> void:
		if is_instance_valid(line):
			_pool.release(line), CONNECT_ONE_SHOT)
