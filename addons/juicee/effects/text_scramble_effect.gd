## Text scramble: reveals a Label's text by cycling random characters that lock in left
## to right, the decoding / hacker-terminal effect. Pass the text via the {"text": ...} param.
@tool
class_name JuiceeTextScrambleEffect
extends JuiceeEffect

## Text shown when the caller doesn't pass {"text": ...}.
@export var default_text: String = "DECODING"
## How long the scramble takes to fully resolve.
@export_range(0.1, 5.0, 0.05) var duration: float = 0.8
## Characters cycled through for the not-yet-locked positions.
@export var charset: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%&*"

enum LockOrder { LEFT_TO_RIGHT, RIGHT_TO_LEFT, CENTER_OUT, RANDOM }

@export_group("Advanced")
## The order characters lock into place: left to right (a terminal decode), right to
## left, from the centre outward, or in a random scatter.
@export var lock_order: LockOrder = LockOrder.LEFT_TO_RIGHT
## How many times per second the unlocked characters re-roll. Lower = a chunkier,
## more readable churn; higher = frantic static.
@export_range(5.0, 60.0, 1.0) var scramble_rate: float = 30.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["lock_order", "scramble_rate"]))

func get_category_name() -> String:
	return "Text"

func get_description() -> String:
	return "Reveal a Label's text by locking in scrambling characters.\nDecoding, hacker terminals, glitchy reveals."

func _apply(context: Node, _intensity_mult: float) -> void:
	var play := _gen
	# Label, RichTextLabel and Button all expose `text`, so drive any of them.
	var label: Control = context as Control
	if not label or not label.is_inside_tree() or not ("text" in label):
		_warn("JuiceeTextScrambleEffect: context has no text property (Label / RichTextLabel / Button)")
		return

	var final_text: String = str(_runtime_params.get("text", default_text))
	var n := final_text.length()
	if n == 0:
		return
	var cs := charset if charset.length() > 0 else "0123456789"
	# Advanced lock_order: the sequence positions resolve in. Built once so RANDOM keeps
	# a stable scatter instead of re-shuffling every frame.
	var order: Array[int] = []
	for i in n:
		order.append(i)
	match lock_order:
		LockOrder.RIGHT_TO_LEFT:
			order.reverse()
		LockOrder.CENTER_OUT:
			order.sort_custom(func(a: int, b: int) -> bool:
				return absf(a - (n - 1) * 0.5) < absf(b - (n - 1) * 0.5))
		LockOrder.RANDOM:
			order.shuffle()
		_:
			pass
	# The text it said before, held on the stack: stop() mid-scramble puts it back, and the end
	# lets go without restoring, so the decoded text stays.
	_capture_state(label, "text")
	var elapsed := 0.0
	var step := 1.0 / maxf(1.0, scramble_rate)
	var tree := label.get_tree()
	while elapsed < duration and is_instance_valid(label) and _gen == play:
		var locked := int(floor((elapsed / duration) * n))
		# Positions occupying the first `locked` slots of the order are resolved.
		var is_locked := {}
		for k in mini(locked, n):
			is_locked[order[k]] = true
		var s := ""
		for i in n:
			if is_locked.has(i) or final_text[i] == " ":
				s += final_text[i]
			else:
				s += cs[randi() % cs.length()]
		label.text = s
		elapsed += await _wait_step(tree, step)
	# A newer play or stop() holds what this one held.
	if _gen != play:
		return
	if is_instance_valid(label):
		label.text = final_text
	_release_state(label, "text", false)
