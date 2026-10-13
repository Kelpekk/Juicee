## Organic random visibility flicker on a CanvasItem.
##
## Unlike StrobeLight (square-wave on a Light2D) this flickers the node's
## modulate between two colors at random intervals - mimicking a dying neon sign,
## flickering torch, damaged HUD element, or haunted light.
##
## Use for: broken lights, haunted/damaged objects, EMP effects, glitch-UI.
@tool
class_name JuiceeFlickerEffect
extends JuiceeEffect

## Color during the "off" phase. Default is transparent, so the node blinks out and
## back (damage i-frames, respawn). For a dying-neon dim, set a dark opaque colour.
@export var off_color: Color = Color(1.0, 1.0, 1.0, 0.0)
## Minimum interval between state changes (seconds).
@export_range(0.01, 0.5, 0.01) var min_interval: float = 0.04
## Maximum interval between state changes (seconds).
@export_range(0.01, 1.0, 0.01) var max_interval: float = 0.15
## Total duration. 0 = flicker until stop() is called.
@export_range(0.0, 10.0, 0.1) var duration: float = 1.0
## Probability (0-1) that any given interval toggles to OFF. Lower = mostly on with rare flickers.
@export_range(0.1, 0.9, 0.05) var off_chance: float = 0.4

@export_group("Advanced")
## Analogue mode: instead of snapping between on and off, drift the brightness randomly
## between Min Brightness and 1 for a guttering candle / dying-neon glow.
@export var analog: bool = false
## Analogue mode only: dimmest the node gets while guttering.
@export_range(0.0, 1.0, 0.05) var min_brightness: float = 0.35

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["analog", "min_brightness"]))

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_FLASH
func get_category_name() -> String: return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var target := context as CanvasItem
	if not target or not target.is_inside_tree():
		_warn("JuiceeFlickerEffect: context is not a CanvasItem")
		return

	var original: Color = _capture_state(target, "modulate")
	var tree := context.get_tree()
	var elapsed := 0.0
	var run_forever := duration <= 0.0

	while (run_forever or elapsed < duration) and _gen == play and is_instance_valid(target):
		if analog:
			# Guttering: drift brightness randomly instead of snapping on/off.
			var b := randf_range(min_brightness, 1.0)
			target.modulate = Color(original.r * b, original.g * b, original.b * b, original.a)
		else:
			var is_off := randf() < off_chance
			target.modulate = off_color if is_off else original
		var wait := randf_range(min_interval, max_interval) / intensity_mult
		elapsed += await _wait_step(tree, wait)

	# A newer play or stop() holds what this one held.
	if _gen != play:
		return
	if is_instance_valid(target):
		target.modulate = original
	_release_state(target, "modulate")
