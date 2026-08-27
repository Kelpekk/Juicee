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

## Ring radius in pixels at full scale (the geometry is then scaled out from small).
@export_range(2.0, 400.0, 1.0) var radius: float = 42.0
## Final scale the whole flourish expands to (2.4 = ends 2.4× its drawn size).
@export_range(1.1, 10.0, 0.1) var expand: float = 2.4
## Thickness of the ring line in pixels.
@export_range(1.0, 30.0, 0.5) var ring_width: float = 5.0
## Ring + spike colour.
@export var color: Color = Color(1.0, 0.85, 0.3)
## Number of radiating impact spikes around the ring. 0 = ring only.
@export_range(0, 24, 1) var spikes: int = 8
## How far each spike extends past the ring, in pixels.
@export_range(0.0, 120.0, 1.0) var spike_length: float = 26.0
## Total duration of the expand + fade.
@export_range(0.05, 2.0, 0.05) var duration: float = 0.36

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Expanding ring + radiating spikes drawn at a Node2D - an anime-style impact 'POW' for crits, parries and explosions. No shaders."

func _apply(context: Node, intensity_mult: float) -> void:
	var origin: Node2D = context as Node2D
	if not origin:
		push_warning("JuiceeImpactRingEffect: context is not a Node2D")
		return
	if not origin.is_inside_tree():
		return

	var root := Node2D.new()
	root.name = StringName("_juicee_impact_ring_%d" % randi())
	root.scale = Vector2(0.4, 0.4)

	# The ring itself (a closed Line2D circle).
	var ring := Line2D.new()
	ring.closed = true
	ring.width = ring_width
	ring.default_color = color
	ring.joint_mode = Line2D.LINE_JOINT_ROUND
	var pts := PackedVector2Array()
	var segments := 32
	for i in segments:
		var a := TAU * i / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	ring.points = pts
	root.add_child(ring)

	# Radiating spikes ("pow" lines) just outside the ring.
	for i in spikes:
		var a := TAU * i / float(spikes)
		var dir := Vector2(cos(a), sin(a))
		var spike := Line2D.new()
		spike.width = ring_width * 0.8
		spike.default_color = color
		spike.points = PackedVector2Array([dir * (radius + 4.0), dir * (radius + 4.0 + spike_length)])
		root.add_child(spike)

	var spawn_parent: Node = _spawn_parent(origin)
	spawn_parent.add_child(root)
	root.global_position = origin.global_position   # resolve only once in-tree

	var eff_expand := expand * intensity_mult
	var tw := _track(root.create_tween()).set_parallel(true)
	tw.tween_property(root, "scale", Vector2(eff_expand, eff_expand), duration)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	if is_instance_valid(root):
		root.queue_free()
