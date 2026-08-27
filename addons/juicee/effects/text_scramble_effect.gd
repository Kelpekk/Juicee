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

func get_category_name() -> String:
	return "Text"

func get_description() -> String:
	return "Reveal a Label's text by locking in scrambling characters.\nDecoding, hacker terminals, glitchy reveals."

func _apply(context: Node, intensity_mult: float) -> void:
	var label: Label = context as Label
	if not label or not label.is_inside_tree():
		push_warning("JuiceeTextScrambleEffect: context is not a Label")
		return

	var final_text: String = str(_runtime_params.get("text", default_text))
	var n := final_text.length()
	if n == 0:
		return
	var cs := charset if charset.length() > 0 else "0123456789"
	var elapsed := 0.0
	var step := 1.0 / 30.0
	var tree := label.get_tree()
	while elapsed < duration and is_instance_valid(label) and not _cancelled:
		var locked := int(floor((elapsed / duration) * n))
		var s := ""
		for i in n:
			if i < locked or final_text[i] == " ":
				s += final_text[i]
			else:
				s += cs[randi() % cs.length()]
		label.text = s
		await tree.create_timer(step, true, false, false).timeout
		elapsed += step
	if is_instance_valid(label):
		label.text = final_text
