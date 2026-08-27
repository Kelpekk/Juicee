## Pause a JuiceeSequence until a specific InputAction is pressed.
##
## Use for: dialogue advance ("press A to continue"), tutorial gate,
## rhythm-game timing window, interactive cutscene, "are you ready?" confirmation.
##
## `timeout` seconds = 0 means wait forever. Non-zero lets the sequence
## auto-advance if the player doesn't respond (e.g. idle cutscene skip).
@tool
class_name JuiceeWaitForInputEffect
extends JuiceeEffect

## InputMap action name to wait for. Default "ui_accept" = Space / Enter / A button.
@export var action: StringName = &"ui_accept"
## Maximum wait time in seconds. 0 = wait indefinitely until the action fires.
@export_range(0.0, 120.0, 0.5) var timeout: float = 0.0

func get_category_name() -> String: return "Flow"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var tree := context.get_tree()
	var elapsed := 0.0
	while not _cancelled:
		if Input.is_action_just_pressed(action):
			break
		if timeout > 0.0 and elapsed >= timeout:
			break
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()
