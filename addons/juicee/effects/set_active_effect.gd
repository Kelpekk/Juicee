## Show/hide a node for the duration of the effect, then restore its
## original visibility. FEEL's MMF_SetActive parity.
##
## Use for: muzzle flashes, hit sparks, "explosion mark" sprites, item
## highlights, debug overlays - anything you want flickering on briefly as
## part of a juice sequence without manual show()/hide() bookkeeping.
@tool
class_name JuiceeSetActiveEffect
extends JuiceeEffect

enum Action { SHOW, HIDE, TOGGLE }

## Node path to toggle (relative to context, or absolute).
@export var target_path: NodePath
## What to do for the duration: show it, hide it, or flip its current state.
@export var action: Action = Action.SHOW
## How long to keep the new state before restoring the original visibility.
@export_range(0.05, 30.0, 0.05) var duration: float = 0.5
## If true, the original visibility is restored at the end. If false, the
## change is permanent (useful for one-shot reveals).
@export var restore_on_end: bool = true

@export_group("Advanced")
## Blink the node this many times across the duration instead of holding one state,
## which is the usual damage / respawn i-frame flicker.
@export_range(1, 32, 1) var blink_count: int = 1
## Also toggle the node's processing and physics, so a hidden node stops running its
## logic instead of just going invisible.
@export var affect_processing: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["blink_count", "affect_processing"]))

func get_category_name() -> String:
	return "Flow"

func _apply(context: Node, _intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	# Typed as Node (not CanvasItem) so it covers Node2D, Control AND Node3D - anything
	# with a `visible` property. Access via get()/set() since `visible` isn't a member
	# of the Node base type. (Typing this CanvasItem crashed on Node3D targets.)
	# Empty target_path means the context node itself, matching every other
	# target_path effect (SetProperty, Spring, Knockback...). Without this fallback
	# the effect dropped straight onto a node with no path set silently did nothing.
	var target: Node = context
	if not target_path.is_empty():
		target = context.get_node_or_null(target_path)
	if not target or not ("visible" in target):
		_warn("JuiceeSetActiveEffect: target '%s' not found / not visibility-toggleable" % str(target_path))
		return

	# A state that comes back is held on the state stack, so stop() puts it back too.
	var original_visible: bool = _capture_state(target, "visible") if restore_on_end else target.get("visible")
	var new_visible: bool
	match action:
		Action.SHOW:   new_visible = true
		Action.HIDE:   new_visible = false
		Action.TOGGLE: new_visible = not original_visible

	# Advanced affect_processing stops a hidden node running its logic, instead of
	# leaving it invisibly ticking away.
	var had_process: bool = target.is_processing() if affect_processing else true
	var had_physics: bool = target.is_physics_processing() if affect_processing else true
	if restore_on_end and affect_processing:
		_on_stop(_resume_by_id.bind(target.get_instance_id(), had_process, had_physics))
	var apply_state := func(v: bool) -> void:
		if not is_instance_valid(target):
			return
		target.set("visible", v)
		if affect_processing:
			target.set_process(had_process and v)
			target.set_physics_process(had_physics and v)

	apply_state.call(new_visible)

	var tree := context.get_tree()
	if not tree:
		return
	# Advanced blink_count flickers between the two states across the duration, which
	# is the standard damage / respawn i-frame blink.
	var blinks: int = _capped(maxi(1, blink_count), 1000, "blink_count")
	if blinks > 1:
		var span: float = duration / float(blinks * 2)
		for i in blinks:
			if not is_instance_valid(target):
				break
			apply_state.call(new_visible)
			await tree.create_timer(span, true, false, false).timeout
			if _gen != play:
				return
			if not is_instance_valid(target):
				break
			apply_state.call(original_visible)
			await tree.create_timer(span, true, false, false).timeout
			if _gen != play:
				return
	else:
		await tree.create_timer(duration, true, false, false).timeout

	if _gen != play or not is_instance_valid(target):
		return
	if restore_on_end:
		_release_state(target, "visible")
		if affect_processing:
			_resume_by_id(target.get_instance_id(), had_process, had_physics)
	elif affect_processing:
		# Leaving it hidden is intentional, but processing should follow that state.
		target.set_process(had_process and new_visible)
		target.set_physics_process(had_physics and new_visible)

## Gives a node back the processing it had, if it is still there.
static func _resume_by_id(id: int, process: bool, physics: bool) -> void:
	var node := instance_from_id(id) as Node
	if node:
		node.set_process(process)
		node.set_physics_process(physics)
