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

func get_category_name() -> String:
	return "Text"

func _apply(context: Node, intensity_mult: float) -> void:
	var label: Label = context as Label
	if not label or not label.is_inside_tree():
		push_warning("JuiceeTypewriterEffect: context is not a Label")
		return

	# Pick text source: runtime param > @export full_text > current label text.
	var text_source: String = str(_runtime_params.get("text", full_text))
	if text_source.is_empty():
		text_source = label.text
	if text_source.is_empty():
		return  # nothing to type

	label.text = text_source
	label.visible_ratio = 0.0
	var total_chars: int = text_source.length()
	var duration: float = total_chars / maxf(1.0, chars_per_second * intensity_mult)

	# Optional audio player parented to label so it dies with the label.
	var sfx: AudioStreamPlayer = null
	if not click_sounds.is_empty():
		sfx = AudioStreamPlayer.new()
		sfx.volume_db = click_volume_db
		label.add_child(sfx)

	var last_revealed_chars: int = 0
	var advance := func(ratio: float) -> void:
		if not is_instance_valid(label):
			return
		label.visible_ratio = ratio
		var now_chars: int = int(ratio * float(total_chars))
		# Trigger click sounds for each NEW character revealed since last frame.
		if sfx and now_chars > last_revealed_chars:
			for i in range(last_revealed_chars, now_chars):
				if i >= text_source.length():
					break
				var ch: String = text_source.substr(i, 1)
				if skip_whitespace_clicks and ch.strip_edges().is_empty():
					continue
				sfx.stream = click_sounds.pick_random()
				sfx.pitch_scale = randf_range(1.0 / click_pitch_variance, click_pitch_variance)
				sfx.play()
		last_revealed_chars = now_chars

	if punctuation_pause <= 0.0:
		# Even pacing: one linear tween, reveals multiple chars per frame at high cps.
		var tween := _track(label.create_tween())
		tween.tween_method(advance, 0.0, 1.0, duration).set_trans(Tween.TRANS_LINEAR)
		await tween.finished
	else:
		# Per-char pacing with pauses on punctuation. Waits are batched so a fast
		# typing speed isn't capped at one char per frame.
		var base_step: float = 1.0 / maxf(1.0, chars_per_second * intensity_mult)
		var tree := label.get_tree()
		var pending: float = 0.0
		for i in range(1, total_chars + 1):
			if _cancelled or not is_instance_valid(label):
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
				pending = 0.0

	# Ensure full text is shown at the end even if a frame was skipped.
	if is_instance_valid(label):
		label.visible_ratio = 1.0
	if is_instance_valid(sfx):
		sfx.queue_free()
