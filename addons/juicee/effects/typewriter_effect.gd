## Typewriter text reveal - characters appear one-by-one for dialog, intros,
## terminal-style status messages.
##
## Targets a `Label` (or any node with `visible_ratio`). Optionally plays a
## random AudioStream per character revealed for that classic click-clack feel.
##
## Caller can override the text via runtime params:
## [codeblock]
## juice.play({"text": "He turned to face you, blade drawn."})
## [/codeblock]
@tool
class_name JuiceeTypewriterEffect
extends JuiceeEffect

## Default text to type. If empty, uses the Label's current `text` as-is.
@export_multiline var full_text: String = ""
## Characters revealed per second (higher = faster typing).
@export_range(1.0, 200.0, 1.0) var chars_per_second: float = 30.0
## Optional click sounds. One is picked at random per character revealed.
## Leave empty for silent typewriter.
@export var click_sounds: Array[AudioStream] = []
## Click sound volume in dB.
@export_range(-40.0, 6.0, 0.5) var click_volume_db: float = -6.0
## Random pitch range for variation (1.0 = no variance).
@export_range(1.0, 2.0, 0.01) var click_pitch_variance: float = 1.15
## Skip whitespace silently (don't play click for spaces).
@export var skip_whitespace_clicks: bool = true
## Extra pause in seconds after sentence punctuation (. ! ?), half of it after , ; :
## so the typing breathes like speech. Try 0.25. Note that a pause makes the reveal
## outlast `chars_per_second`, so 0 = even typing, and predictable total duration.
@export_range(0.0, 1.0, 0.05) var punctuation_pause: float = 0.0

@export_group("Advanced")
## Blinking cursor appended while typing (e.g. "_" or "|"). Empty = no cursor.
@export var cursor_char: String = ""
## Cursor blinks per second.
@export_range(0.5, 10.0, 0.5) var cursor_blink_rate: float = 2.0
## Keep the cursor visible after the text finishes typing (a waiting-for-input prompt).
@export var cursor_after_finish: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["cursor_char", "cursor_blink_rate", "cursor_after_finish"]))

func get_category_name() -> String:
	return "Text"

func _apply(context: Node, _intensity_mult: float) -> void:
	var play := _gen
	# Label and RichTextLabel both expose `text` + `visible_ratio`, so drive either.
	var label: Control = context as Control
	if not label or not label.is_inside_tree() or not ("visible_ratio" in label):
		_warn("JuiceeTypewriterEffect: context is not a Label or RichTextLabel")
		return

	# Pick text source: runtime param > @export full_text > current label text.
	var text_source: String = str(_runtime_params.get("text", full_text))
	if text_source.is_empty():
		text_source = label.text
	if text_source.is_empty():
		return  # nothing to type

	# Advanced cursor: visible_ratio hides the tail, so a cursor at the typing position
	# needs prefix mode instead - write the revealed substring plus the blinking cursor.
	var use_cursor: bool = not cursor_char.is_empty()

	# What the label showed before, held on the stack: stop() mid-typing puts it back, and the
	# end of the typing lets go without restoring, so the typed text stays.
	_capture_state(label, "text")
	_capture_state(label, "visible_ratio")
	label.text = text_source
	label.visible_ratio = 0.0
	var total_chars: int = text_source.length()
	var duration: float = total_chars / maxf(1.0, chars_per_second)

	# Optional audio player parented to label so it dies with the label.
	var sfx: AudioStreamPlayer = null
	if not click_sounds.is_empty():
		sfx = AudioStreamPlayer.new()
		sfx.volume_db = click_volume_db
		sfx.name = StringName("_juicee_typewriter_sfx_%d" % randi())
		label.add_child(sfx)
		_free_on_stop(sfx)

	# In an array: a lambda gets its own copy of a captured int back on every call, so a plain
	# counter here stayed 0 and every step clicked for every character so far.
	var last_revealed := [0]
	var advance := func(ratio: float) -> void:
		if not is_instance_valid(label):
			return
		var now_chars: int = int(ratio * float(total_chars))
		if use_cursor:
			# Prefix mode: show the typed text plus a cursor that blinks on wall time.
			var blink_on: bool = fmod(unscaled_seconds() * cursor_blink_rate, 1.0) < 0.5
			label.text = text_source.substr(0, now_chars) + (cursor_char if blink_on else "")
			label.visible_ratio = 1.0
		else:
			label.visible_ratio = ratio
		# Trigger click sounds for each NEW character revealed since last frame.
		if sfx and now_chars > last_revealed[0]:
			for i in range(last_revealed[0], now_chars):
				if i >= text_source.length():
					break
				var ch: String = text_source.substr(i, 1)
				if skip_whitespace_clicks and ch.strip_edges().is_empty():
					continue
				sfx.stream = click_sounds.pick_random()
				sfx.pitch_scale = randf_range(1.0 / click_pitch_variance, click_pitch_variance)
				sfx.play()
		last_revealed[0] = now_chars

	if punctuation_pause <= 0.0:
		# Even pacing: one linear tween, reveals multiple chars per frame at high cps.
		var tween := _track(label.create_tween())
		tween.tween_method(advance, 0.0, 1.0, duration).set_trans(Tween.TRANS_LINEAR)
		await tween.finished
		if _gen != play:
			return
	else:
		# Per-char pacing with pauses on punctuation. Waits are batched so a fast
		# typing speed isn't capped at one char per frame.
		var base_step: float = 1.0 / maxf(1.0, chars_per_second)
		var tree := label.get_tree()
		var pending: float = 0.0
		for i in range(1, total_chars + 1):
			if not is_instance_valid(label):
				break
			advance.call(float(i) / float(total_chars))
			var ch: String = text_source.substr(i - 1, 1)
			pending += base_step
			if ch == "." or ch == "!" or ch == "?":
				pending += punctuation_pause
			elif ch == "," or ch == ";" or ch == ":":
				pending += punctuation_pause * 0.5
			if pending >= 0.016 and i < total_chars:
				await tree.create_timer(pending, true, false, false).timeout
				if _gen != play:
					return
				pending = 0.0

	# Ensure full text is shown at the end even if a frame was skipped.
	if is_instance_valid(label):
		label.text = text_source
		label.visible_ratio = 1.0
	# The typing is done, and the typed text stays whatever ends the play from here.
	_release_state(label, "text", false)
	_release_state(label, "visible_ratio", false)
	if is_instance_valid(sfx):
		sfx.queue_free()

	# Advanced: keep blinking the cursor after typing, as a waiting-for-input prompt. It blinks
	# until stop() or the next line, and either one takes the cursor off.
	if use_cursor and cursor_after_finish and is_instance_valid(label):
		_on_stop(_set_by_id.bind(label.get_instance_id(), &"text", text_source))
		var tree2 := label.get_tree()
		var on := true
		while _gen == play and is_instance_valid(label):
			label.text = text_source + (cursor_char if on else "")
			on = not on
			await tree2.create_timer(0.5 / maxf(0.1, cursor_blink_rate), true, false, false).timeout
