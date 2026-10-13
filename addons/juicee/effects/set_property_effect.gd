## Instantly set any property on any node, then optionally restore after a delay.
##
## The direct-assignment version of PropertyTweenEffect - no animation, just set.
## Equivalent to FEEL's MMF_SetActive generalized to any property.
##
## Use for: toggle a bool flag mid-sequence, snap a node to a position,
## enable/disable a collision layer, change a label text, set a flag variable.
@tool
class_name JuiceeSetPropertyEffect
extends JuiceeEffect

## Node to modify. Empty = context node.
@export var target_path: NodePath = NodePath()
## Property name (supports sub-paths: "position:x", "material:albedo_color").
@export var property_name: String = ""
## Value to set.
@export var value: Variant = true
## Restore the original value after restore_delay seconds (0 = restore immediately after setting, -1 = never restore).
@export_range(-1.0, 30.0, 0.1) var restore_delay: float = -1.0

@export_group("Advanced")
## Tween to the value over this many seconds instead of setting it instantly. Works for
## numbers, vectors and colours; anything else still snaps.
@export_range(0.0, 10.0, 0.05) var tween_time: float = 0.0
## Toggle a bool property instead of writing Value, so one resource can flip a flag.
@export var toggle_bool: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["tween_time", "toggle_bool"]))

func get_category_name() -> String: return "Flow"

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if property_name.is_empty():
		_warn("JuiceeSetPropertyEffect: property_name is empty")
		return

	var target: Node = context
	if not target_path.is_empty():
		target = context.get_node_or_null(target_path)
	if not is_instance_valid(target):
		_warn("JuiceeSetPropertyEffect: target not found")
		return

	# "position:x" and the like name a property plus a component; the node has the first part.
	var wanted := property_name.split(":")[0]
	if not (wanted in target):
		var holder := _nearest_node(target, func(n: Node) -> bool: return wanted in n)
		if holder:
			target = holder
		else:
			_warn("JuiceeSetPropertyEffect: nothing here has a property '%s'" % wanted)
			return

	# The game's window refuses most of what could be set on it, with an error each time.
	if target == target.get_tree().root:
		_warn("JuiceeSetPropertyEffect: the game's window is not something it sets properties on")
		return
	var existing: Variant = target.get_indexed(property_name)
	var numbers := [TYPE_INT, TYPE_FLOAT]
	if not toggle_bool and existing != null and value != null and typeof(existing) != typeof(value) \
			and not (typeof(existing) in numbers and typeof(value) in numbers):
		_warn("JuiceeSetPropertyEffect: '%s' is %s and Value is %s, so it was left alone"
				% [property_name, type_string(typeof(existing)), type_string(typeof(value))])
		return
	var play := _gen
	# Held on the stack when it is to be put back, so stop() before the restore puts it back too.
	if restore_delay >= 0.0:
		_capture_state(target, property_name)

	# Advanced toggle_bool flips a flag instead of writing Value.
	var final_value: Variant = value
	if toggle_bool:
		var current: Variant = target.get_indexed(property_name)
		if current is bool:
			final_value = not current
	# tween_time eases numeric / vector / colour properties instead of snapping.
	var from_value: Variant = target.get_indexed(property_name)
	var tweenable: bool = from_value is float or from_value is int or from_value is Vector2 or from_value is Vector3 or from_value is Color
	if tween_time > 0.0 and tweenable and target is Node:
		var tw := _track((target as Node).create_tween())
		tw.tween_property(target, NodePath(property_name), final_value, tween_time)
		await tw.finished
		if _gen != play:
			return
	else:
		target.set_indexed(property_name, final_value)

	if restore_delay < 0.0:
		return

	if restore_delay > 0.0:
		await context.get_tree().create_timer(restore_delay, true, false, false).timeout
		if _gen != play:
			return

	_release_state(target, property_name)
