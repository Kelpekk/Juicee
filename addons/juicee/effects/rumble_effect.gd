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

@export_group("Advanced")
## Fade the rumble out over its duration instead of cutting off, which reads as an
## impact settling rather than a switch flipping.
@export var fade_out: bool = false
## Rumble every connected controller, not just Device.
@export var all_devices: bool = false
## Pulse the rumble this many times across the duration (a heartbeat / alarm buzz).
@export_range(1, 16, 1) var pulse_count: int = 1

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["fade_out", "all_devices", "pulse_count"]))

## Vibration reaches the player physically, so it belongs behind a switch like
## flashing and screen shake do.
func get_accessibility_tag() -> int:
	return JuiceeAccessibility.TAG_HAPTIC

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	# Rumble fires in editor preview too - Input.start_joy_vibration works
	# from the editor process, so you can dial in the feel from the graph's
	# Test/Preview without launching the game.
	var weak := clampf(weak_magnitude * intensity_mult, 0.0, 1.0)
	var strong := clampf(strong_magnitude * intensity_mult, 0.0, 1.0)
	# Advanced all_devices buzzes every connected pad (co-op hit feedback); pulse_count
	# splits it into bursts (heartbeat, alarm); fade_out lets an impact settle.
	var devices: Array = Input.get_connected_joypads() if all_devices else [device]
	if devices.is_empty():
		devices = [device]
	# Each pulse waits at least a frame, so a million of them rumbled for hours.
	var pulses: int = _capped(maxi(1, pulse_count), 256, "pulse_count")
	var span: float = duration / float(pulses)
	for i in pulses:
		if _gen != play:
			break
		var decay: float = (1.0 - float(i) / float(pulses)) if fade_out else 1.0
		var span_on: float = span * (0.6 if pulses > 1 else 1.0)
		for d in devices:
			if haptics:
				# Through the mixer, so overlapping with another rumble combines
				# instead of one silently replacing the other.
				_on_stop(haptics.stop.bind(
					haptics.play(int(d), weak * decay, strong * decay, span_on, fade_out and pulses == 1)))
			else:
				# No autoload: the old direct call, so effects still work standalone.
				Input.start_joy_vibration(int(d), weak * decay, strong * decay, span_on)
		if context and context.is_inside_tree():
			await context.get_tree().create_timer(span, true, false, false).timeout
