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
## How long each crack lasts, fade included: it snaps out, holds, then fades.
@export_range(0.05, 2.0, 0.05) var duration: float = 0.5
## Crack color.
@export var color: Color = Color(0.95, 0.95, 1.0, 0.9)

@export_group("Advanced")
## Zig-zag resolution: points per crack. More = finer, more organic fractures.
@export_range(2, 12, 1) var segments: int = 4
## Cone (degrees) the cracks spread over, centred on Aim Degrees. 360 = a full radial
## burst (the default); 90 = a directional fan, e.g. cracks away from an impact face.
@export_range(10.0, 360.0, 5.0) var spread_angle: float = 360.0
## Direction the cone points, in degrees. Only meaningful when Spread Angle < 360.
@export_range(-180.0, 180.0, 5.0) var aim_degrees: float = 0.0
## Random length variation per crack (0.4 = each is 60%-140% of Length). 0 = all equal.
@export_range(0.0, 0.9, 0.05) var length_variance: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["segments", "spread_angle", "aim_degrees", "length_variance"]))

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Jagged fracture lines bursting from a point.\nHeavy landings, boss slams, shatters, big impacts."

func _apply(context: Node, intensity_mult: float) -> void:
	var origin: Node2D = context as Node2D
	if not origin or not origin.is_inside_tree():
		_warn("JuiceeCrackEffect: context is not a Node2D")
		return

	var n: int = _capped(maxi(2, count), 256, "count")
	if segments > 64:
		_warn("JuiceeCrackEffect: segments is %d, more than one crack is drawn with, so it uses 64" % segments)
	var base_pos := origin.global_position
	var spawn_parent: Node = _spawn_parent(origin)
	# Full circle spaces the spokes evenly; a narrower cone fans them around aim_degrees.
	var full_circle: bool = spread_angle >= 359.9
	var cone := deg_to_rad(spread_angle)
	var aim := deg_to_rad(aim_degrees)
	for i in n:
		var angle: float
		if full_circle:
			angle = TAU * (float(i) / n) + randf_range(-0.3, 0.3)
		else:
			var t: float = 0.5 if n == 1 else float(i) / float(n - 1)
			angle = aim - cone * 0.5 + cone * t + randf_range(-0.08, 0.08)
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
	var seg_len: float = _px(length) * mult
	if length_variance > 0.0:
		seg_len *= 1.0 + randf_range(-length_variance, length_variance)
	var segs: int = clampi(segments, 2, 64)
	for s in segs + 1:
		var t: float = float(s) / segs
		# Inner and tip points sit on the spoke; middle points jitter sideways.
		var jitter: float = 0.0 if (s == 0 or s == segs) else randf_range(-1.0, 1.0) * jaggedness * seg_len * 0.15
		line.add_point(dir * (seg_len * t) + perp * jitter)
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
	line.name = StringName("_juicee_crack_%d" % randi())
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
