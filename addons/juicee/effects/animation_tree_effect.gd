## Trigger an AnimationTree state machine transition or set a parameter.
##
## Works with AnimationNodeStateMachinePlayback (travel to a state) or
## by directly setting any AnimationTree parameter (blend amount, time scale, etc.).
##
## Use for: trigger "Attack" state from a hit sequence, blend between run/walk,
## reset a one-shot animation back to idle, set speed_scale for slow-mo anim.
@tool
class_name JuiceeAnimationTreeEffect
extends JuiceeEffect

enum Mode {
	TRAVEL,        ## Call StateMachinePlayback.travel(state_name) for a smooth transition.
	SET_PARAMETER, ## Set any AnimationTree parameter directly (blend, bool, time, etc.).
}

## Path to the AnimationTree node. Empty = look for AnimationTree as a child of context.
@export_node_path("AnimationTree") var tree_path: NodePath = NodePath()
## How to drive the AnimationTree.
@export var mode: Mode = Mode.TRAVEL
## For TRAVEL: target state name (must exist in the StateMachinePlayback).
## For SET_PARAMETER: parameter path, e.g. "parameters/TimeScale/scale".
@export var parameter: String = "Idle"
## For SET_PARAMETER: the value to set. Ignored in TRAVEL mode.
@export var value: Variant = true
## For TRAVEL: path to the StateMachinePlayback parameter (default works for most trees).
@export var playback_path: String = "parameters/playback"
## Wait for the travel to finish before the step ends. TRAVEL mode only.
@export var wait_for_finish: bool = false
## Safety timeout (seconds) for `wait_for_finish` in TRAVEL mode - bail out if the
## target state is never reached (e.g. a typo'd state name) instead of looping forever.
@export_range(0.1, 30.0, 0.1) var max_wait: float = 5.0

@export_group("Advanced")
## Blend the parameter to its value over this many seconds instead of setting it
## instantly, so a state change eases rather than snaps. Numbers only: anything else
## still snaps. SET_PARAMETER mode.
@export_range(0.0, 5.0, 0.05) var blend_time: float = 0.0
## Put the parameter back where it was once the effect is done, so a dip in a blend or in
## a time scale recovers on its own. With Blend Time it eases back over the same time;
## without one it snaps there and straight back, which nobody will see.
@export var restore_on_end: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["blend_time", "restore_on_end"]))

func get_category_name() -> String: return "Flow"

func _apply(context: Node, _intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return

	var at: AnimationTree = null
	if not tree_path.is_empty():
		at = context.get_node_or_null(tree_path) as AnimationTree
	if not at:
		at = context as AnimationTree
	if not at:
		for child in context.get_children():
			if child is AnimationTree:
				at = child
				break
	if not at:
		_warn("JuiceeAnimationTreeEffect: no AnimationTree found")
		return

	match mode:
		Mode.TRAVEL:
			var pb = at.get(playback_path) as AnimationNodeStateMachinePlayback
			if not pb:
				_warn("JuiceeAnimationTreeEffect: no StateMachinePlayback at '%s'" % playback_path)
				return
			# A state the machine does not have makes the engine report an error on every travel.
			var machine := at.tree_root as AnimationNodeStateMachine
			if playback_path == "parameters/playback" and machine and not machine.has_node(StringName(parameter)):
				_warn("JuiceeAnimationTreeEffect: the state machine has no state '%s'" % parameter)
				return
			pb.travel(parameter)
			if wait_for_finish:
				var tree := context.get_tree()
				var elapsed := 0.0
				while _gen == play and is_instance_valid(at) and elapsed < max_wait:
					if pb.get_current_node() == parameter and pb.get_current_play_position() >= pb.get_current_length() - 0.05:
						break
					await tree.process_frame
					if _gen != play:
						return
					elapsed += tree.root.get_process_delta_time()

		Mode.SET_PARAMETER:
			if parameter.is_empty():
				_warn("JuiceeAnimationTreeEffect: parameter path is empty")
				return
			var before: Variant = _capture_state(at, parameter)
			# Blending needs two numbers: the one it starts from and the one it lands on.
			# A bool one-shot or a state name has nothing in between, so it snaps.
			if blend_time > 0.0 and _is_number(before) and _is_number(value):
				var tween := _track(at.create_tween())
				tween.tween_property(at, NodePath(parameter), float(value), blend_time)
				if restore_on_end:
					tween.tween_property(at, NodePath(parameter), float(before), blend_time)
				await tween.finished
				if _gen != play:
					return
			else:
				at.set(parameter, value)
			# Cancelled mid-blend, this is what puts the parameter back.
			_release_state(at, parameter, restore_on_end)

func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT
