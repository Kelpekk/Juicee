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
## How to apply the flip_v change. SET_FALSE = no change by default.
@export var flip_v_mode: Mode = Mode.SET_FALSE
## If true, restore original flip state after hold_duration.
@export var restore_on_end: bool = false
## Seconds to hold the new flip state before restoring. 0 = restore immediately.
@export_range(0.0, 10.0, 0.05) var hold_duration: float = 0.0

func get_category_name() -> String: return "Object"
func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_NONE

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return

	var original_h := false
	var original_v := false

	if context is Sprite2D:
		var s := context as Sprite2D
		original_h = s.flip_h
		original_v = s.flip_v
		s.flip_h = _apply_mode(s.flip_h, flip_h_mode)
		s.flip_v = _apply_mode(s.flip_v, flip_v_mode)
	elif context is AnimatedSprite2D:
		var s := context as AnimatedSprite2D
		original_h = s.flip_h
		original_v = s.flip_v
		s.flip_h = _apply_mode(s.flip_h, flip_h_mode)
		s.flip_v = _apply_mode(s.flip_v, flip_v_mode)
	else:
		push_warning("JuiceeFlipEffect: context must be Sprite2D or AnimatedSprite2D")
		return

	if not restore_on_end:
		return

	if hold_duration > 0.0:
		await context.get_tree().create_timer(hold_duration, true, false, false).timeout
		if _cancelled:
			return

	if not is_instance_valid(context):
		return

	if context is Sprite2D:
		var s := context as Sprite2D
		s.flip_h = original_h
		s.flip_v = original_v
	elif context is AnimatedSprite2D:
		var s := context as AnimatedSprite2D
		s.flip_h = original_h
		s.flip_v = original_v

static func _apply_mode(current: bool, mode: Mode) -> bool:
	match mode:
		Mode.TOGGLE:   return not current
		Mode.SET_TRUE: return true
		Mode.SET_FALSE:return false
	return current
