## Expanding impact ring + radiating spikes, drawn in 2D world space at a Node2D's
## position. An anime / action "POW" flourish for crits, parries, big landings and
## small explosions.
##
## Unlike [JuiceeShockwaveEffect] (a full-screen shader distortion), this draws real
## [Line2D] geometry that sits ON the hit object - so it needs no shaders, works in
## plain 2D, and stays exactly where the impact happened.
@tool
class_name JuiceeImpactRingEffect
extends JuiceeEffect

## Ring radius in pixels. The ring starts at half this and grows to Radius times Expand.
@export_range(2.0, 400.0, 1.0) var radius: float = 42.0
## Final scale the whole flourish expands to (2.4 = ends 2.4× its drawn size).
@export_range(1.1, 10.0, 0.1) var expand: float = 2.4
## Thickness of the ring line in pixels.
@export_range(1.0, 30.0, 0.5) var ring_width: float = 6.0
## Ring + spike colour.
@export var color: Color = Color(1.0, 0.85, 0.3)
## Number of radiating impact spikes around the ring. 0 = ring only.
@export_range(0, 24, 1) var spikes: int = 8
## How far each spike extends past the ring, in pixels.
@export_range(0.0, 120.0, 1.0) var spike_length: float = 34.0
## Total duration of the expand + fade.
@export_range(0.05, 2.0, 0.05) var duration: float = 0.45

@export_group("Advanced")
## Send a second, smaller ring out behind the first for a layered blast. 0 = one ring.
@export_range(0.0, 0.8, 0.05) var echo_ring: float = 0.0
## Degrees the ring (and its spikes) rotate as it expands, so the burst swirls.
@export_range(-360.0, 360.0, 5.0) var spin_degrees: float = 0.0
## Randomize each spike's length by this fraction, so the star reads hand-drawn
## instead of perfectly regular. 0 = uniform spikes.
@export_range(0.0, 1.0, 0.05) var spike_variance: float = 0.35

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["echo_ring", "spin_degrees", "spike_variance"]))

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Expanding ring + radiating spikes drawn at a Node2D - an anime-style impact 'POW' for crits, parries and explosions. No shaders."

func _apply(context: Node, intensity_mult: float) -> void:
	var origin: Node2D = context as Node2D
	if not origin:
		_warn("JuiceeImpactRingEffect: context is not a Node2D")
		return
	if not origin.is_inside_tree():
		return

	var root := Node2D.new()
	root.name = StringName("_juicee_impact_ring_%d" % randi())

	# The geometry is rebuilt at its real size on every step and the node is never scaled.
	# Scaling the node scaled the line width with it, so the ring got THICKER the further
	# it travelled, which is the opposite of what a ring of spreading energy does, and it
	# was most of why this read as clip art rather than an impact.
	var ring := Line2D.new()
	ring.closed = true
	ring.default_color = color
	ring.joint_mode = Line2D.LINE_JOINT_ROUND
	root.add_child(ring)

	var echo: Line2D = null
	# Advanced echo_ring: a second, smaller ring chasing the first for a layered blast.
	if echo_ring > 0.0:
		echo = Line2D.new()
		echo.closed = true
		echo.default_color = Color(color.r, color.g, color.b, color.a * echo_ring)
		echo.joint_mode = Line2D.LINE_JOINT_ROUND
		root.add_child(echo)

	# Spikes are tapered wedges, not lines of constant width. A ring of identical straight
	# lines at identical angles is a clip-art sun; a wedge that is wide where it leaves the
	# ring and comes to a point is the shape the drawing this imitates actually uses.
	var wedges: Array[Polygon2D] = []
	var dirs: Array[Vector2] = []
	var lengths: Array[float] = []
	var spike_count := _capped(spikes, 256, "spikes")
	for i in spike_count:
		var jitter: float = randf_range(-0.35, 0.35) * (TAU / float(maxi(spike_count, 1))) * spike_variance
		var a: float = TAU * float(i) / float(maxi(spike_count, 1)) + jitter
		dirs.append(Vector2(cos(a), sin(a)))
		lengths.append(spike_length * (1.0 + randf_range(-spike_variance, spike_variance)))
		var wedge := Polygon2D.new()
		wedge.color = color
		root.add_child(wedge)
		wedges.append(wedge)

	# The white core: the flash at the moment of contact, gone in a few frames. Without it
	# the ring starts from nothing and the hit has no moment of impact to sit on.
	var core := Polygon2D.new()
	core.color = Color(1.0, 1.0, 1.0, 1.0)
	var core_shape := PackedVector2Array()
	for i in 16:
		var ca := TAU * float(i) / 16.0
		core_shape.append(Vector2(cos(ca), sin(ca)))
	core.polygon = core_shape
	root.add_child(core)

	var spawn_parent: Node = _spawn_parent(origin)
	spawn_parent.add_child(root)
	root.global_position = origin.global_position   # resolve only once in-tree
	# Freed by stop(). Firing again leaves it to finish: rings stack, as hits do.
	_free_on_stop(root, true)

	var eff_expand: float = maxf(1.0, expand * intensity_mult)
	var start_r: float = radius * 0.5
	var end_r: float = radius * eff_expand

	# The ring's own tween, untracked: a new play must not freeze this one in mid-air, which a
	# killed tween did, leaving the ring on screen for good.
	var tw := root.create_tween()
	# Advanced spin: swirl the whole burst as it expands. Rotation is safe to put on the
	# node; only scale would have dragged the line widths along with it.
	if spin_degrees != 0.0:
		tw.parallel().tween_property(root, "rotation", deg_to_rad(spin_degrees), duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Linear 0..1. The shaping is done below rather than by the tween, because the radius,
	# the width, the spikes and the fade each want a different curve and a tween can only
	# carry one.
	tw.parallel().tween_method(
		func(t: float) -> void:
			_step(root, ring, echo, wedges, core, dirs, lengths, start_r, end_r, t),
		0.0, 1.0, duration)
	await _tween_done(tw)
	if is_instance_valid(root):
		root.queue_free()

## One frame of the flourish, at `t` from 0 to 1.
##
## The curves are the point of the effect, so they are written out rather than left to a
## transition name: the ring travels on a strong ease-out (fast out of the impact, coasting
## by the end), thins to almost nothing as it goes, holds full brightness for the first
## third and only then fades. The spikes travel faster than the ring and shorten as they
## go, so they read as thrown rather than drawn.
func _step(root: Node2D, ring: Line2D, echo: Line2D, wedges: Array[Polygon2D],
		core: Polygon2D, dirs: Array[Vector2], lengths: Array[float],
		start_r: float, end_r: float, t: float) -> void:
	if not is_instance_valid(root):
		return
	var out: float = 1.0 - pow(1.0 - t, 3.0)          # ring travel
	var thrown: float = 1.0 - pow(1.0 - t, 4.0)       # spikes, quicker still
	var fade: float = 1.0 - clampf((t - 0.6) / 0.4, 0.0, 1.0)

	var r: float = lerpf(start_r, end_r, out)
	var w: float = maxf(1.2, ring_width * lerpf(1.0, 0.25, out))
	ring.points = _circle(r, 40)
	ring.width = w
	if echo:
		echo.points = _circle(r * 0.62, 32)
		echo.width = maxf(0.4, w * 0.7)

	for i in wedges.size():
		var dir: Vector2 = dirs[i]
		var perp := Vector2(-dir.y, dir.x)
		var inner: Vector2 = dir * (r + w * 0.9 + lengths[i] * 0.35 * thrown)
		var span: float = lengths[i] * (1.0 - 0.65 * t)
		var half: float = maxf(1.5, w * 1.8)
		wedges[i].polygon = PackedVector2Array([
			inner + perp * half, inner - perp * half, inner + dir * span])

	# The core flash is over inside the first fifth, so it reads as the moment of contact
	# rather than as a ball sitting in the middle of the ring.
	var core_life: float = clampf(1.0 - t / 0.2, 0.0, 1.0)
	core.scale = Vector2.ONE * (start_r * 0.9 * (0.4 + 0.6 * core_life))
	core.color = Color(1.0, 1.0, 1.0, core_life * 0.9)

	root.modulate.a = fade

static func _circle(r: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
