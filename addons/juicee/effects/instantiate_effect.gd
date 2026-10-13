## Spawn a PackedScene at the context node's world position.
##
## Works for Node2D and Node3D contexts. The spawned instance is added to the
## current scene tree. Auto-frees after `lifetime` seconds if set.
##
## Use for: blood splats, hit sparks, custom VFX, spawning enemies / pickups /
## projectiles as a sequence step, popup UI panels, damage numbers (custom).
@tool
class_name JuiceeInstantiateEffect
extends JuiceeEffect

## Scene to spawn. Must be set - effect is a no-op if null.
@export var scene: PackedScene
## World-space offset added to the context's position.
@export var position_offset: Vector2 = Vector2.ZERO
## Optional parent node path. Empty = scene's current root scene.
@export var parent_path: NodePath = NodePath()
## Seconds until the spawned instance is queue_freed. 0 = never auto-free.
@export_range(0.0, 30.0, 0.1) var lifetime: float = 2.0
## Copy the context node's rotation to the spawned instance.
@export var inherit_rotation: bool = false
## Copy the context node's scale to the spawned instance.
@export var inherit_scale: bool = false

@export_group("Advanced")
## Spawn this many copies instead of one (a shower of debris, a burst of pickups).
@export_range(1, 64, 1) var count: int = 1
## Scatter each copy randomly within this radius (pixels) of the spawn point. 2D only.
@export_range(0.0, 500.0, 1.0) var scatter_radius: float = 0.0
## Give each copy a random rotation, so a pile of debris is not all aligned. 2D only.
@export var random_rotation: bool = false
## Randomize each copy's scale by this fraction (0.3 = 70%-130%), for natural variety. 2D only.
@export_range(0.0, 0.9, 0.05) var scale_variance: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["count", "scatter_radius", "random_rotation", "scale_variance"]))

func get_category_name() -> String: return "Object"
func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_NONE

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not scene:
		_warn("JuiceeInstantiateEffect: no scene assigned")
		return
	if not scene.can_instantiate():
		_warn("JuiceeInstantiateEffect: the scene is empty or broken, so there is nothing to instantiate")
		return

	# Advanced count spawns a whole shower in one call; each copy is placed and
	# varied independently below.
	for _copy in _capped(maxi(1, count), 1024, "count"):
		_spawn_one(context)

## Spawns and places a single copy of the scene.
func _spawn_one(context: Node) -> void:
	var instance := scene.instantiate()
	if not instance:
		return

	var parent: Node = null
	if not parent_path.is_empty():
		parent = context.get_node_or_null(parent_path)
	if not parent:
		parent = context.get_tree().current_scene
	if not parent:
		_warn("JuiceeInstantiateEffect: could not find a valid parent node")
		instance.free()
		return

	parent.add_child(instance)

	# Advanced scatter/rotation/scale variety, so a pile of debris is not a stack of
	# identical clones sitting in one spot.
	var scatter := Vector2.ZERO
	if scatter_radius > 0.0:
		scatter = Vector2.from_angle(randf() * TAU) * randf() * _px(scatter_radius)
	var var_scale: float = 1.0 + randf_range(-scale_variance, scale_variance) if scale_variance > 0.0 else 1.0

	if instance is Node2D and context is Node2D:
		var ctx2d := context as Node2D
		var inst2d := instance as Node2D
		inst2d.global_position = ctx2d.global_position + position_offset + scatter
		if inherit_rotation:
			inst2d.global_rotation = ctx2d.global_rotation
		if random_rotation:
			inst2d.rotation = randf() * TAU
		if inherit_scale:
			inst2d.scale = ctx2d.scale
		if not is_equal_approx(var_scale, 1.0):
			inst2d.scale *= var_scale
	elif instance is Node3D and context is Node3D:
		var ctx3d := context as Node3D
		var inst3d := instance as Node3D
		inst3d.global_position = ctx3d.global_position + Vector3(position_offset.x, position_offset.y, 0.0)
		if inherit_rotation:
			inst3d.global_rotation = ctx3d.global_rotation
		if inherit_scale:
			inst3d.scale = ctx3d.scale

	if lifetime > 0.0:
		var life_timer := context.get_tree().create_timer(lifetime, true, false, false)
		# By id: a lambda capturing the instance reports an error if something frees it first.
		life_timer.timeout.connect(_free_by_id.bind(instance.get_instance_id()))
