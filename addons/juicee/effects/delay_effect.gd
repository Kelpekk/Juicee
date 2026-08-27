@tool
class_name JuiceeDelayEffect
extends JuiceeEffect

## Seconds to wait. Used inside sequences to space effects apart.
@export_range(0.01, 10.0, 0.05) var duration: float = 0.5

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	await context.get_tree().create_timer(duration * intensity_mult, true, false, false).timeout
