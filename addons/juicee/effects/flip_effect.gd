## Set flip_h / flip_v on a Sprite2D or AnimatedSprite2D, optionally restoring after a delay.
##
## Use for: directional facing on movement, reveal a hidden face, mirror a hit reaction,
## fighting-game orientation, coin/card flip reveal.
@tool
class_name JuiceeFlipEffect
extends JuiceeEffect

enum Mode {
	TOGGLE,   ## Flip the current state (true->false, false->true).
	SET_TRUE, ## Force flip to true regardless of current state.
	SET_FALSE,## Force flip to false regardless of current state.
}

## How to apply the flip_h change.
@export var flip_h_mode: Mode = Mode.TOGGLE
## How to apply the flip_v change. The default SET_FALSE leaves an unflipped sprite as it is (and un-flips one already flipped).
@export var flip_v_mode: Mode = Mode.SET_FALSE
## If true, restore original flip state after hold_duration.
@export var restore_on_end: bool = false
## Seconds to hold the new flip state before restoring. 0 = restore immediately.
@export_range(0.0, 10.0, 0.05) var hold_duration: float = 0.0

@export_group("Advanced")
## Animate the flip as a card/coin turn (the node squashes edge-on and back) instead of
## an instant swap. The boolean flips at the halfway point, hidden by the squash.
@export var animate: bool = false
## Duration of the animated flip (only when Animate is on).
@export_range(0.05, 2.0, 0.05) var flip_duration: float = 0.3

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["animate", "flip_duration"]))

func get_category_name() -> String: return "Object"
func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_NONE

func _apply(context: Node, _intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	if not (context is Sprite2D or context is AnimatedSprite2D):
		_warn("JuiceeFlipEffect: context must be Sprite2D or AnimatedSprite2D")
		return

	# Both Sprite2D and AnimatedSprite2D expose flip_h / flip_v, so drive them via get/set. Held
	# on the state stack, so stop() mid-flip puts the sprite back; a flip that stays is let go
	# at the end without restoring.
	var new_h := _apply_mode(context.get("flip_h"), flip_h_mode)
	var new_v := _apply_mode(context.get("flip_v"), flip_v_mode)
	var original_h: bool = _capture_state(context, "flip_h")
	var original_v: bool = _capture_state(context, "flip_v")
	var turning := animate and context is Node2D
	if turning:
		_capture_state(context, "scale")

	await _do_flip(context, new_h, new_v)
	if _gen != play:
		return

	if restore_on_end:
		if hold_duration > 0.0:
			await context.get_tree().create_timer(hold_duration, true, false, false).timeout
			if _gen != play:
				return
		if is_instance_valid(context):
			await _do_flip(context, original_h, original_v)
			if _gen != play:
				return
	_release_state(context, "flip_h", restore_on_end)
	_release_state(context, "flip_v", restore_on_end)
	if turning:
		_release_state(context, "scale")

## Sets flip_h/flip_v, animating an edge-on card turn when `animate` is on.
func _do_flip(context: Node, h: bool, v: bool) -> void:
	if animate and context is Node2D:
		var node2d := context as Node2D
		var orig_x := node2d.scale.x
		var tw := _track(node2d.create_tween())
		tw.tween_property(node2d, "scale:x", 0.0, flip_duration * 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			if is_instance_valid(context):
				context.set("flip_h", h)
				context.set("flip_v", v))
		tw.tween_property(node2d, "scale:x", orig_x, flip_duration * 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tw.finished
	else:
		context.set("flip_h", h)
		context.set("flip_v", v)

static func _apply_mode(current: bool, mode: Mode) -> bool:
	match mode:
		Mode.TOGGLE:   return not current
		Mode.SET_TRUE: return true
		Mode.SET_FALSE:return false
	return current
