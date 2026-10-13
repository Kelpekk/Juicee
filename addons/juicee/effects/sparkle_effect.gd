## Sparkle / twinkle: a scatter of little star pops around the node.
@tool
class_name JuiceeSparkleEffect
extends JuiceeEffect

enum SpawnShape { SCATTER, RING, BURST }

## Shared pool so a stream of pickups reuses the sparkle sprites instead of new + free.
static var _pool := JuiceeNodePool.new()

static func _new_sparkle() -> Node:
	return Sprite2D.new()

## Star textures cached per point-count (a 4-point vs 6-point star differ).
static var _star_cache: Dictionary = {}

## A crisp N-point twinkle, built once per point-count and cached. Hard-edged spikes (not
## a soft gradient) so it reads as a real sparkle, not a glowing blob, and stays sharp in
## pixel-art projects.
static func _sparkle_tex(points: int) -> Texture2D:
	points = clampi(points, 3, 12)
	if _star_cache.has(points):
		return _star_cache[points]
	var size := 32
	var c: float = (size - 1) * 0.5
	var px := 1.0 / c # one pixel in normalized units, for a 1px anti-alias feather
	var arm := 0.14 # arm half-thickness at the centre; tapers to a point at each tip
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var nx: float = (float(x) - c) / c
			var ny: float = (float(y) - c) / c
			# One tapered spike per point, evenly spaced. Rotate the pixel into each
			# spike's frame and measure the same thin-triangle coverage the 4-point star used.
			var best := 0.0
			for k in points:
				var ang := TAU * float(k) / float(points)
				var rx := nx * cos(ang) + ny * sin(ang)
				var ry := -nx * sin(ang) + ny * cos(ang)
				if rx >= 0.0 and rx < 1.0:
					best = maxf(best, clampf((arm * (1.0 - rx) - absf(ry)) / px + 0.5, 0.0, 1.0))
			# Small solid core so the centre reads bright and solid.
			var r := sqrt(nx * nx + ny * ny)
			var core := clampf((0.28 - r) / px + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, maxf(best, core)))
	var tex := ImageTexture.create_from_image(img)
	_star_cache[points] = tex
	return tex

## How many sparkles scatter around the node.
@export_range(1, 24, 1) var count: int = 9
## Radius of the area the sparkles scatter over.
@export_range(4.0, 200.0, 1.0) var spread: float = 64.0
## Visual size of each sparkle.
@export_range(0.2, 8.0, 0.1) var sparkle_scale: float = 2.0
## Sparkle color. Ignored when an Advanced palette is set.
@export var color: Color = Color(1.0, 1.0, 0.7, 1.0)
## Total time over which the sparkles appear and fade.
@export_range(0.1, 3.0, 0.05) var duration: float = 0.6

@export_group("Advanced")
## Points on each star. 4 = classic twinkle, 5-6 = a fuller sparkle, 8 = a starburst.
@export_range(3, 12, 1) var star_points: int = 4
## How the sparkles are placed: SCATTER (random within the radius), RING (evenly on the
## circle), or BURST (all from the centre, thrown outward - pair with Drift).
@export var spawn_shape: SpawnShape = SpawnShape.SCATTER
## Optional colours to pick from per sparkle. Non-empty overrides Color, so a pickup can
## sparkle in a gold/white mix or a full rainbow.
@export var palette: PackedColorArray = PackedColorArray()
## Extra distance (px) each sparkle drifts outward over its life. 0 = it pops in place.
@export_range(0.0, 200.0, 1.0) var drift: float = 0.0
## Degrees each sparkle spins over its life. 0 = a fixed random tilt.
@export_range(-720.0, 720.0, 5.0) var spin: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["star_points", "spawn_shape", "palette", "drift", "spin"]))

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "A scatter of little star pops around the node.\nPickups, collectibles, level-ups, UI shine."

func _apply(context: Node, intensity_mult: float) -> void:
	var origin: Node2D = context as Node2D
	if not origin or not origin.is_inside_tree():
		_warn("JuiceeSparkleEffect: context is not a Node2D")
		return

	var n: int = _capped(maxi(1, int(count * accessibility.density_scale())), 1024, "count")
	var base_pos := origin.global_position
	var radius := _px(spread) * intensity_mult
	# Shared, so this also lands correctly when the target is inside a SubViewport rather
	# than under the running scene. Its own copy of the lookup did not.
	var spawn_parent: Node = _spawn_parent(origin)
	for i in n:
		var dir: Vector2
		var off: Vector2
		match spawn_shape:
			SpawnShape.RING:
				dir = Vector2.from_angle(TAU * float(i) / float(n))
				off = dir * radius
			SpawnShape.BURST:
				dir = Vector2.from_angle(randf() * TAU)
				off = Vector2.ZERO
			_:
				dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).limit_length(1.0)
				off = dir * radius
		var wait := randf() * duration * 0.35
		_spawn_sparkle(origin, spawn_parent, base_pos + off, dir, wait)

	# Hold until the sparkles have run; each one releases itself to the pool.
	await origin.get_tree().create_timer(duration, true, false, false).timeout

## Pops one sparkle in at `pos` (after `delay`), fades it, and parks it. Independent of
## the effect so re-triggering layers new sparkles instead of cancelling old ones.
func _spawn_sparkle(origin: Node2D, parent: Node, pos: Vector2, dir: Vector2, wait: float) -> void:
	var s: Sprite2D = _pool.acquire(_new_sparkle)
	s.texture = _sparkle_tex(clampi(star_points, 3, 64))
	# Nearest keeps the twinkle crisp when scaled up instead of blurring into a soft
	# halo under a project's default linear filter. A sharp star reads well in pixel
	# art and HD alike.
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.modulate = palette[randi() % palette.size()] if palette.size() > 0 else color
	s.rotation = randf() * TAU
	s.scale = Vector2.ZERO
	s.z_index = origin.z_index + 1
	s.name = StringName("_juicee_sparkle_%d" % randi())
	parent.add_child(s)
	# World position AFTER parenting, so a non-origin scene root doesn't double the offset.
	s.global_position = pos

	var life := 0.4
	var tw := s.create_tween()
	if wait > 0.0:
		tw.tween_interval(wait)
	# Every sparkle the same size reads as one shape drawn several times. A range of
	# makes a handful of them look like a shower rather than one stamp repeated.
	var size: float = sparkle_scale * randf_range(0.55, 1.3)
	tw.tween_property(s, "scale", Vector2.ONE * size, life * 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "scale", Vector2.ONE * size * 0.2, life * 0.65)\
		.set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(s, "modulate:a", 0.0, life * 0.65)
	# Advanced motion: drift outward and/or spin over the sparkle's life.
	if drift > 0.0:
		tw.parallel().tween_property(s, "global_position", pos + dir * _px(drift), life)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if spin != 0.0:
		tw.parallel().tween_property(s, "rotation", s.rotation + deg_to_rad(spin), life)
	tw.finished.connect(func() -> void:
		if is_instance_valid(s):
			_pool.release(s), CONNECT_ONE_SHOT)
