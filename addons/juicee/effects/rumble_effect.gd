## Triggers gamepad vibration (console "feel").
@tool
class_name JuiceeRumbleEffect
extends JuiceeEffect

## Gamepad device index (0 = first connected, up to 7).
@export_range(0, 7, 1) var device: int = 0
## Weak (small) motor intensity (0-1). Subtle, high-frequency buzz.
@export_range(0.0, 1.0, 0.01) var weak_magnitude: float = 0.5
## Strong (large) motor intensity (0-1). Low-frequency rumble - the "thud".
@export_range(0.0, 1.0, 0.01) var strong_magnitude: float = 0.5
## How long the rumble lasts in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.2

func _apply(context: Node, intensity_mult: float) -> void:
	# Rumble fires in editor preview too - Input.start_joy_vibration works
	# from the editor process, so you can dial in the feel from the graph's
	# Test/Preview without launching the game.
	var weak := clamp(weak_magnitude * intensity_mult, 0.0, 1.0)
	var strong := clamp(strong_magnitude * intensity_mult, 0.0, 1.0)
	Input.start_joy_vibration(device, weak, strong, duration)
	if context and context.is_inside_tree():
		await context.get_tree().create_timer(duration, true, false, false).timeout
