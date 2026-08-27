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

func get_category_name() -> String: return "Object"
func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_NONE

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not scene:
		push_warning("JuiceeInstantiateEffect: no scene assigned")
		return

	var instance := scene.instantiate()
	if not instance:
		return

	var parent: Node = null
	if not parent_path.is_empty():
		parent = context.get_node_or_null(parent_path)
	if not parent:
		parent = context.get_tree().current_scene
	if not parent:
		push_warning("JuiceeInstantiateEffect: could not find a valid parent node")
		instance.free()
		return

	parent.add_child(instance)

	if instance is Node2D and context is Node2D:
		var ctx2d := context as Node2D
		var inst2d := instance as Node2D
		inst2d.global_position = ctx2d.global_position + position_offset
		if inherit_rotation:
			inst2d.global_rotation = ctx2d.global_rotation
		if inherit_scale:
			inst2d.scale = ctx2d.scale
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
		life_timer.timeout.connect(func() -> void:
			if is_instance_valid(instance):
				instance.queue_free()
		)
