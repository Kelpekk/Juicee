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

@export_group("Advanced")
## Size of the motion: wave height, shake level, or tornado radius, depending on Mode.
## Rainbow ignores it.
@export_range(1.0, 60.0, 1.0) var amplitude: float = 24.0
## Speed of the motion: wave/tornado frequency, or shake rate.
@export_range(1.0, 40.0, 1.0) var rate: float = 6.0
## Rainbow only: colour saturation of the sweep.
@export_range(0.0, 1.0, 0.05) var rainbow_saturation: float = 0.8

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["amplitude", "rate", "rainbow_saturation"]))

func get_category_name() -> String:
	return "Text"

func get_description() -> String:
	return "Wrap a RichTextLabel's text (or one phrase) in wave / shake / rainbow / tornado.\nDialogue emphasis, tutorial callouts, cursed item names."

func _apply(context: Node, intensity_mult: float) -> void:
	var rtl: RichTextLabel = context as RichTextLabel
	if not rtl or not rtl.is_inside_tree():
		_warn("JuiceeRichTextEmphasisEffect: context is not a RichTextLabel")
		return

	var tag_open: String
	var tag_close: String
	match mode:
		1:
			tag_open = "[shake rate=%.0f level=%.0f]" % [rate * 3.0, amplitude * 0.33 * intensity_mult]
			tag_close = "[/shake]"
		2:
			tag_open = "[rainbow freq=%.2f sat=%.2f]" % [rate * 0.1, rainbow_saturation]
			tag_close = "[/rainbow]"
		3:
			tag_open = "[tornado radius=%.0f freq=%.0f]" % [amplitude * 0.25 * intensity_mult, rate * 0.67]
			tag_close = "[/tornado]"
		_:
			tag_open = "[wave amp=%.0f freq=%.0f]" % [amplitude * intensity_mult, rate]
			tag_close = "[/wave]"

	# The text and its bbcode switch are held on the state stack: emphases, counts and reveals on
	# one label all come back to its text from before the first of them, and stop() or a new play,
	# which would otherwise wrap the wrapped text again, puts it back.
	_capture_state(rtl, "text")
	_capture_state(rtl, "bbcode_enabled")
	var shown: String = rtl.text
	var target_phrase: String = str(_runtime_params.get("phrase", phrase))
	if target_phrase.is_empty() or not shown.contains(target_phrase):
		rtl.text = tag_open + shown + tag_close
	else:
		rtl.text = shown.replace(target_phrase, tag_open + target_phrase + tag_close)
	rtl.bbcode_enabled = true
	# No duration holds the emphasis until stop() or the next play puts the text back.
	if duration <= 0.0:
		return

	var play := _gen
	var tree := rtl.get_tree()
	await tree.create_timer(duration, true, false, false).timeout
	if _gen != play:
		return
	_release_state(rtl, "text")
	_release_state(rtl, "bbcode_enabled")
