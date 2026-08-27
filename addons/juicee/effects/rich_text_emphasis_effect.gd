## Rich text emphasis: temporarily wraps a RichTextLabel's text (or one phrase in it)
## in an animated BBCode tag (wave / shake / rainbow / tornado), then puts it back.
@tool
class_name JuiceeRichTextEmphasisEffect
extends JuiceeEffect

## Animation applied to the text.
@export_enum("Wave", "Shake", "Rainbow", "Tornado") var mode: int = 0
## Phrase to emphasize. Empty = the whole text. Override per play with {"phrase": ...}.
@export var phrase: String = ""
## How long the emphasis lasts. 0 = stays until stop().
@export_range(0.0, 30.0, 0.1) var duration: float = 1.5

func get_category_color() -> Color:
	return Color(0.95, 0.42, 0.21)

func get_category_name() -> String:
	return "Text"

func get_description() -> String:
	return "Wrap a RichTextLabel's text (or one phrase) in wave / shake / rainbow / tornado.\nDialogue emphasis, tutorial callouts, cursed item names."

func _apply(context: Node, intensity_mult: float) -> void:
	var rtl: RichTextLabel = context as RichTextLabel
	if not rtl or not rtl.is_inside_tree():
		push_warning("JuiceeRichTextEmphasisEffect: context is not a RichTextLabel")
		return

	var tag_open: String
	var tag_close: String
	match mode:
		1:
			tag_open = "[shake rate=20 level=%.0f]" % (8.0 * intensity_mult)
			tag_close = "[/shake]"
		2:
			tag_open = "[rainbow freq=0.6 sat=0.8]"
			tag_close = "[/rainbow]"
		3:
			tag_open = "[tornado radius=%.0f freq=4]" % (6.0 * intensity_mult)
			tag_close = "[/tornado]"
		_:
			tag_open = "[wave amp=%.0f freq=6]" % (24.0 * intensity_mult)
			tag_close = "[/wave]"

	var original: String = rtl.text
	var was_bbcode: bool = rtl.bbcode_enabled
	var target_phrase: String = str(_runtime_params.get("phrase", phrase))
	if target_phrase.is_empty() or not original.contains(target_phrase):
		rtl.text = tag_open + original + tag_close
	else:
		rtl.text = original.replace(target_phrase, tag_open + target_phrase + tag_close)
	rtl.bbcode_enabled = true

	var restore := func() -> void:
		if is_instance_valid(rtl):
			rtl.text = original
			rtl.bbcode_enabled = was_bbcode
	_on_stop(restore)
	if duration <= 0.0:
		return

	await rtl.get_tree().create_timer(duration, true, false, false).timeout
	if not _cancelled:
		restore.call()
