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
## Easing curve. EASE_OUT feels best for "rolling to a stop".
@export var trans_type: Tween.TransitionType = Tween.TRANS_EXPO
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

func get_category_name() -> String:
	return "Text"

func _apply(context: Node, intensity_mult: float) -> void:
	var label: Label = context as Label
	if not label or not label.is_inside_tree():
		push_warning("JuiceeNumberCountEffect: context is not a Label")
		return

	var start_val: float = float(_runtime_params.get("from", from_value))
	var end_val: float = float(_runtime_params.get("to", to_value))

	# intensity_mult biases the duration (less intense = snappier).
	var effective_duration: float = duration / maxf(0.1, intensity_mult)

	var update_label := func(v: float) -> void:
		if is_instance_valid(label):
			label.text = prefix + (number_format % v) + suffix

	var tween := _track(label.create_tween())
	tween.tween_method(update_label, start_val, end_val, effective_duration)\
		.set_trans(trans_type).set_ease(ease_type)
	await tween.finished

	# Snap to final value in case the tween was cut off a frame early.
	if is_instance_valid(label):
		label.text = prefix + (number_format % end_val) + suffix
