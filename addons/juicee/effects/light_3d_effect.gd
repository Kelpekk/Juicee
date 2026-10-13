## Flash a Light3D node's energy and color (OmniLight3D, SpotLight3D, DirectionalLight3D).
##
## 3D counterpart of LightFlashEffect. Tweens energy to peak then returns.
## Use for: muzzle flash in 3D, explosion light pulse, lightning strike,
## magical impact glow, flickering torch burst.
@tool
class_name JuiceeLight3DEffect
extends JuiceeEffect

## Path to the Light3D node. Empty = context must be a Light3D.
@export_node_path("Light3D") var light_path: NodePath = NodePath()
## Peak light energy at the flash moment.
@export_range(0.1, 20.0, 0.1) var peak_energy: float = 5.0
## Light color at the flash peak. White = keep current color.
@export var flash_color: Color = Color.WHITE
## Total duration of the energy ramp up + decay.
@export_range(0.05, 2.0, 0.05) var duration: float = 0.3
## Restore original energy after the flash (true) or leave at peak (false).
@export var restore_energy: bool = true

@export_group("Advanced")
## Hand-drawn curve (0..1) shaping the energy rise to the peak. FEEL-style curve control.
@export var ease_curve: Curve
## Flash this many times within the duration instead of once. 3+ reads as an alarm.
@export_range(1, 12, 1) var pulse_count: int = 1
## Each pulse is this fraction as bright as the one before, so a burst dies out.
@export_range(0.3, 1.0, 0.05) var energy_decay: float = 1.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "pulse_count", "energy_decay"]))

func get_category_name() -> String: return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var light: Light3D = null
	if not light_path.is_empty():
		light = context.get_node_or_null(light_path) as Light3D
	if not light:
		light = context as Light3D
	if not light:
		_warn("JuiceeLight3DEffect: no Light3D found")
		return

	var orig_energy: float = _capture_state(light, "light_energy")
	var orig_color: Color = _capture_state(light, "light_color")

	# Advanced pulse_count splits the duration into repeated flashes, each dimmer by
	# energy_decay, so one call can drive an alarm strobe as well as a single flash.
	var pulses: int = _capped(maxi(1, pulse_count), 1000, "pulse_count")
	var span: float = duration / float(pulses)
	for i in pulses:
		if _gen != play or not is_instance_valid(light):
			break
		var peak_i: float = peak_energy * intensity_mult * pow(energy_decay, float(i))
		var tween := _track(light.create_tween())
		tween.set_parallel(true)
		if ease_curve:
			_tween_curved(tween, light, "light_energy", light.light_energy, peak_i, span * 0.1, ease_curve)
		else:
			tween.tween_property(light, "light_energy", peak_i, span * 0.1) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		if flash_color != Color.WHITE:
			tween.tween_property(light, "light_color", flash_color, span * 0.1)
		tween.set_parallel(false)
		var is_last: bool = (i == pulses - 1)
		if restore_energy or not is_last:
			tween.tween_property(light, "light_energy", orig_energy, span * 0.9) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			if flash_color != Color.WHITE:
				tween.tween_property(light, "light_color", orig_color, span * 0.9) \
					.set_delay(- (span * 0.9))
		await tween.finished
		if _gen != play:
			return

	# restore_energy=false intentionally leaves the light at its flashed energy/colour.
	_release_state(light, "light_energy", restore_energy)
	_release_state(light, "light_color", restore_energy)
