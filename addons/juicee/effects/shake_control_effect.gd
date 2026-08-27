## Horizontal shake on a Control node - the classic "wrong answer" UI response.
##
## Use for: wrong password / PIN entry, invalid form input, locked button,
## "you can't go there" door, tutorial "not yet" block.
@tool
class_name JuiceeShakeControlEffect
extends JuiceeEffect

## Peak horizontal displacement in pixels. Vertical adds ±30% of this for realism.
@export_range(0.0, 100.0, 0.5) var intensity: float = 10.0
## Total shake duration in seconds.
@export_range(0.05, 2.0, 0.05) var duration: float = 0.3
## Updates per second (higher = more jittery).
@export_range(5.0, 60.0, 1.0) var frequency: float = 20.0

func get_category_name() -> String: return "Text"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not context is Control:
		push_warning("JuiceeShakeControlEffect: context must be a Control node")
		return
	var target := context as Control
	var original_pos: Vector2 = _capture_state(target, "position")
	var elapsed := 0.0
	var step := 1.0 / frequency
	var tree := context.get_tree()
	var eff := intensity * intensity_mult

	while elapsed < duration and is_instance_valid(target) and not _cancelled:
		var decay := 1.0 - elapsed / duration
		var offset := Vector2(
			randf_range(-eff, eff) * decay,
			randf_range(-eff * 0.3, eff * 0.3) * decay
		)
		target.position = original_pos + offset
		await tree.create_timer(step, true, false, false).timeout
		elapsed += step

	_release_state(target, "position")
