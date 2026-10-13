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

## Input action to wait for. A dropdown of the project's real actions: ui_accept (Space,
## Enter, the A button), ui_select, ui_cancel, and anything under Project Settings > Input Map.
@export var action: StringName = &"ui_accept"
## Maximum wait time in seconds. 0 = wait indefinitely until the action fires.
@export_range(0.0, 120.0, 0.5) var timeout: float = 0.0

@export_group("Advanced")
## Also accept any of these extra actions, so a prompt can take several buttons.
@export var extra_actions: Array[StringName] = []
## Accept any key / button / click at all, not just mapped actions. Useful for a
## "press anything to continue" prompt.
@export var accept_any_input: bool = false
## Ignore input for this many seconds first, so the keypress that opened a prompt does
## not immediately dismiss it.
@export_range(0.0, 2.0, 0.05) var input_lockout: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["extra_actions", "accept_any_input", "input_lockout"]))
	_hint_input_action(property)

func get_category_name() -> String: return "Flow"

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var tree := context.get_tree()
	var elapsed := 0.0
	var play := _gen
	# An action the Input Map lacks makes the engine report an error on every frame it is asked
	# about, and if nothing else can end the wait, it never ends and holds up its sequence.
	var has_action := InputMap.has_action(action)
	var other_way := accept_any_input or timeout > 0.0
	for extra in extra_actions:
		other_way = other_way or InputMap.has_action(extra)
	if not has_action:
		if not other_way:
			_warn("JuiceeWaitForInputEffect: there is no '%s' in the Input Map and nothing else can end the wait, so it does not wait" % action)
			return
		_warn("JuiceeWaitForInputEffect: there is no '%s' in the Input Map, so only its other ways out can end the wait" % action)
	# Advanced input_lockout: ignore input briefly, so the very keypress that opened
	# a prompt does not dismiss it on the same frame.
	if input_lockout > 0.0:
		await tree.create_timer(input_lockout, true, false, false).timeout
		if _gen != play:
			return
	while _gen == play:
		if has_action and Input.is_action_just_pressed(action):
			break
		# Advanced: accept any of the extra actions, or literally any input.
		var matched := false
		for extra in extra_actions:
			if InputMap.has_action(extra) and Input.is_action_just_pressed(extra):
				matched = true
				break
		if matched:
			break
		if accept_any_input and _any_input_pressed():
			break
		if timeout > 0.0 and elapsed >= timeout:
			break
		await tree.process_frame
		if _gen != play:
			return
		elapsed += tree.root.get_process_delta_time()

## True when any key, mouse button or joypad button is down. Backs accept_any_input,
## which is what a plain "press anything to continue" prompt wants.
func _any_input_pressed() -> bool:
	for mb in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if Input.is_mouse_button_pressed(mb):
			return true
	for key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_Z, KEY_X, KEY_C]:
		if Input.is_key_pressed(key):
			return true
	for dev in Input.get_connected_joypads():
		for btn in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START]:
			if Input.is_joy_button_pressed(dev, btn):
				return true
	return false
