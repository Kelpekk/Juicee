## Flashes a Light2D's energy and/or color for impact moments.
@tool
class_name JuiceeLightFlashEffect
extends JuiceeEffect

## Path to the Light2D to flash. If empty, the context itself must be a Light2D.
@export_node_path("Light2D") var target: NodePath
## Peak energy value at the top of the flash.
@export_range(0.0, 16.0, 0.1) var peak_energy: float = 3.0
## Color the light tweens to at peak.
@export var flash_color: Color = Color.WHITE
## Total flash duration (30% ramp-in + 70% ramp-out).
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## If true, light returns to its original energy/color after the flash.
@export var return_to_original: bool = true

func get_category_color() -> Color:
	return Color(0.95, 0.85, 0.20)

func _apply(context: Node, intensity_mult: float) -> void:
	var resolved: Node = context.get_node_or_null(target) if not target.is_empty() else context
	var light: Light2D = resolved as Light2D
	if not light:
		push_warning("JuiceeLightFlashEffect: target is not a Light2D")
		return

	var original_energy: float = _capture_state(light, "energy")
	var original_color: Color = _capture_state(light, "color")
	var effective_energy := peak_energy * intensity_mult

	var tween := _track(light.create_tween()).set_parallel(true)
	tween.tween_property(light, "energy", effective_energy, duration * 0.3)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(light, "color", flash_color, duration * 0.3)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	if return_to_original:
		var back := _track(light.create_tween()).set_parallel(true)
		back.tween_property(light, "energy", original_energy, duration * 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(duration * 0.3)
		back.tween_property(light, "color", original_color, duration * 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(duration * 0.3)
		await back.finished
	else:
		await tween.finished
	# return_to_original=false intentionally leaves the light at its flashed state.
	_release_state(light, "energy", return_to_original)
	_release_state(light, "color", return_to_original)
