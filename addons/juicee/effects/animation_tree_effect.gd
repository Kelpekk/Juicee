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
## Wait for the travel to finish (only meaningful in TRAVEL mode with wait_for_finish=true).
@export var wait_for_finish: bool = false
## Safety timeout (seconds) for `wait_for_finish` in TRAVEL mode — bail out if the
## target state is never reached (e.g. a typo'd state name) instead of looping forever.
@export_range(0.1, 30.0, 0.1) var max_wait: float = 5.0

func get_category_name() -> String: return "Flow"
func get_category_color() -> Color: return Color(1.00, 0.55, 0.15)

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return

	var at: AnimationTree = null
	if not tree_path.is_empty():
		at = context.get_node_or_null(tree_path) as AnimationTree
	if not at:
		for child in context.get_children():
			if child is AnimationTree:
				at = child
				break
	if not at:
		push_warning("JuiceeAnimationTreeEffect: no AnimationTree found")
		return

	match mode:
		Mode.TRAVEL:
			var pb = at.get(playback_path) as AnimationNodeStateMachinePlayback
			if not pb:
				push_warning("JuiceeAnimationTreeEffect: no StateMachinePlayback at '%s'" % playback_path)
				return
			pb.travel(parameter)
			if wait_for_finish:
				var tree := context.get_tree()
				var elapsed := 0.0
				while not _cancelled and is_instance_valid(at) and elapsed < max_wait:
					if pb.get_current_node() == parameter and pb.get_current_play_position() >= pb.get_current_length() - 0.05:
						break
					await tree.process_frame
					elapsed += tree.root.get_process_delta_time()

		Mode.SET_PARAMETER:
			if parameter.is_empty():
				push_warning("JuiceeAnimationTreeEffect: parameter path is empty")
				return
			at.set(parameter, value)
