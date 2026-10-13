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

@export_group("Advanced")
## Hand-drawn curve (0..1) shaping the energy rise to the peak. FEEL-style curve control.
@export var ease_curve: Curve
## Flash this many times in the duration instead of once. 3+ reads as an alarm.
@export_range(1, 12, 1) var pulse_count: int = 1
## Also scale the light's texture_scale at the peak, so the pool of light swells with
## the flash. 1 = the size never changes.
@export_range(1.0, 4.0, 0.05) var size_boost: float = 1.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "pulse_count", "size_boost"]))

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var resolved: Node = context.get_node_or_null(target) if not target.is_empty() else context
	var light: Light2D = resolved as Light2D
	if not light:
		_warn("JuiceeLightFlashEffect: target is not a Light2D")
		return

	var original_energy: float = _capture_state(light, "energy")
	var original_color: Color = _capture_state(light, "color")
	var effective_energy := peak_energy * intensity_mult

	# Advanced size_boost also swells the pool of light with the flash.
	var swelling: bool = not is_equal_approx(size_boost, 1.0)
	var original_tex_scale: float = _capture_state(light, "texture_scale") if swelling else 1.0
	var pulses: int = _capped(maxi(1, pulse_count), 1000, "pulse_count")
	var span: float = duration / float(pulses)

	for i in pulses:
		var is_last: bool = (i == pulses - 1)
		var tween := _track(light.create_tween()).set_parallel(true)
		# ease_curve (advanced) overrides the expo ramp on the way up.
		if ease_curve:
			_tween_curved(tween, light, "energy", light.energy, effective_energy, span * 0.3, ease_curve)
		else:
			tween.tween_property(light, "energy", effective_energy, span * 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(light, "color", flash_color, span * 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		if swelling:
			tween.tween_property(light, "texture_scale", original_tex_scale * size_boost, span * 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		await tween.finished
		if _gen != play:
			return
		if not is_instance_valid(light):
			break
		# Every pulse falls back; only the last one honours return_to_original.
		if return_to_original or not is_last:
			var back := _track(light.create_tween()).set_parallel(true)
			back.tween_property(light, "energy", original_energy, span * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			back.tween_property(light, "color", original_color, span * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			if swelling:
				back.tween_property(light, "texture_scale", original_tex_scale, span * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			await back.finished
			if _gen != play:
				return
	# return_to_original=false intentionally leaves the light at its flashed state.
	_release_state(light, "energy", return_to_original)
	_release_state(light, "color", return_to_original)
	if swelling:
		_release_state(light, "texture_scale", return_to_original)
