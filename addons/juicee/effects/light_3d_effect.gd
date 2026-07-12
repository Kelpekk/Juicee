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

func get_category_color() -> Color: return Color(1.0, 0.333, 0.333)
func get_category_name() -> String: return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var light: Light3D = null
	if not light_path.is_empty():
		light = context.get_node_or_null(light_path) as Light3D
	if not light:
		light = context as Light3D
	if not light:
		push_warning("JuiceeLight3DEffect: no Light3D found")
		return

	var orig_energy: float = _capture_state(light, "light_energy")
	var orig_color: Color = _capture_state(light, "light_color")

	var tween := _track(light.create_tween())
	tween.set_parallel(true)
	tween.tween_property(light, "light_energy", peak_energy * intensity_mult, duration * 0.1) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if flash_color != Color.WHITE:
		tween.tween_property(light, "light_color", flash_color, duration * 0.1)
	tween.set_parallel(false)
	if restore_energy:
		tween.tween_property(light, "light_energy", orig_energy, duration * 0.9) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		if flash_color != Color.WHITE:
			tween.tween_property(light, "light_color", orig_color, duration * 0.9) \
				.set_delay(- (duration * 0.9))
	await tween.finished

	# restore_energy=false intentionally leaves the light at its flashed energy/colour.
	_release_state(light, "light_energy", restore_energy)
	_release_state(light, "light_color", restore_energy)
