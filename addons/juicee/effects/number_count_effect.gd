## Tween a Label's numeric text from one value to another - the satisfying
## "score rolls up" feeling. Use for score counters, money displays, XP gains,
## resource accumulation.
##
## Caller can override from/to dynamically via runtime params:
## [codeblock]
## # Current score is 1200, player just earned 800
## juice.play({"from": 1200, "to": 2000})
## [/codeblock]
@tool
class_name JuiceeNumberCountEffect
extends JuiceeEffect

## Default starting value when no `from` runtime param is provided.
@export var from_value: float = 0.0
## Default end value when no `to` runtime param is provided.
@export var to_value: float = 100.0
## Total animation duration.
@export_range(0.1, 10.0, 0.05) var duration: float = 1.0
## printf-style format for the number (e.g. "%d" for integer, "%.2f" for 2 decimals).
@export var number_format: String = "%d"
## Text shown BEFORE the number (e.g. "$", "Score: ").
@export var prefix: String = ""
## Text shown AFTER the number (e.g. " pts", " coins", "%").
@export var suffix: String = ""
## Shape of the tween curve. Expo with Ease Out rolls to a stop.
@export var trans_type: Tween.TransitionType = Tween.TRANS_EXPO
## Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends.
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

@export_group("Advanced")
## Hand-drawn easing curve (0..1) replacing Transition/Ease for the count. FEEL-style.
@export var ease_curve: Curve
## Group the integer part with this separator ("," or " " or "."), so 1234567 reads as
## 1,234,567. Empty = no grouping.
@export var thousands_separator: String = ""
## Pad the integer part with leading zeros to this many digits (e.g. 5 = "00042").
## 0 = no padding.
@export_range(0, 12, 1) var pad_digits: int = 0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "thousands_separator", "pad_digits"]))

func get_category_name() -> String:
	return "Text"

func _apply(context: Node, _intensity_mult: float) -> void:
	# Label, RichTextLabel and Button all expose `text`, so drive any of them.
	var label: Control = context as Control
	if not label or not label.is_inside_tree() or not ("text" in label):
		_warn("JuiceeNumberCountEffect: context has no text property (Label / RichTextLabel / Button)")
		return

	var play := _gen
	_fmt = _usable_format()
	# The text it said before, held on the stack: stop() mid-count puts it back, and the end of
	# the count lets go without restoring, so the final number stays.
	_capture_state(label, "text")
	var start_val: float = _param("from", from_value)
	var end_val: float = _param("to", to_value)

	# The count takes the time it says, whatever the intensity.
	var effective_duration: float = duration

	var update_label := func(v: float) -> void:
		if is_instance_valid(label):
			label.text = _format(v)

	var tween := _track(label.create_tween())
	# ease_curve (advanced) overrides the built-in transition/ease when set.
	if ease_curve:
		tween.tween_method(func(t: float) -> void:
			update_label.call(lerpf(start_val, end_val, ease_curve.sample(t))),
			0.0, 1.0, effective_duration)
	else:
		tween.tween_method(update_label, start_val, end_val, effective_duration)\
			.set_trans(trans_type).set_ease(ease_type)
	await tween.finished
	if _gen != play:
		return

	# Snap to final value in case the tween was cut off a frame early.
	if is_instance_valid(label):
		label.text = _format(end_val)
	_release_state(label, "text", false)

## The format this play counts with: number_format when it formats one number, "%d" with a
## warning when it does not. The % operator reports an error on every frame of the count for a
## format with no placeholder, two of them or a stray %, and leaves the text empty.
var _fmt := ""
static var _format_spec: RegEx = null

func _usable_format() -> String:
	if _format_spec == null:
		_format_spec = RegEx.create_from_string("%[-+ 0#]*[0-9]*([.][0-9]+)?[sdoxXf]")
	var plain := number_format.replace("%%", "")
	var specs := _format_spec.search_all(plain)
	if specs.size() == 1 and plain.count("%") == 1:
		return number_format
	_warn("JuiceeNumberCountEffect: number_format '%s' is not a format for one number, so it counts with %%d" % number_format)
	return "%d"

## Formats a value with the number_format, then applies the advanced padding and
## thousands grouping to the integer part.
func _format(v: float) -> String:
	var body: String = (_fmt if not _fmt.is_empty() else number_format) % v
	if pad_digits > 0 or not thousands_separator.is_empty():
		# Split off a sign and any decimal tail so grouping only touches the digits.
		var sign_str := ""
		if body.begins_with("-") or body.begins_with("+"):
			sign_str = body.substr(0, 1)
			body = body.substr(1)
		var tail := ""
		var dot := body.find(".")
		if dot >= 0:
			tail = body.substr(dot)
			body = body.substr(0, dot)
		if pad_digits > 0:
			body = body.lpad(mini(pad_digits, 64), "0")
		if not thousands_separator.is_empty() and body.length() > 3:
			var grouped := ""
			var count := 0
			for i in range(body.length() - 1, -1, -1):
				grouped = body[i] + grouped
				count += 1
				if count % 3 == 0 and i > 0:
					grouped = thousands_separator + grouped
			body = grouped
		body = sign_str + body + tail
	return prefix + body + suffix
