@tool
class_name JuiceeShakeEffect
extends JuiceeEffect

enum Preset { CUSTOM, IMPACT, EARTHQUAKE, RUMBLE, HANDHELD }

## Maximum shake displacement in pixels.
@export_range(0.0, 100.0, 0.5) var intensity: float = 8.0
## Total shake duration in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.3
## Shake oscillations per second.
@export_range(1.0, 60.0, 0.5) var frequency: float = 15.0
## How quickly the shake amplitude falls off. 0 = constant, higher = faster decay.
@export_range(0.0, 5.0, 0.01) var decay: float = 0.8
## If true, uses smooth Perlin noise. If false, uses random offsets (jittery).
@export var use_noise: bool = true
## Max camera roll in degrees layered on the positional shake. A touch of rotation
## makes the same shake read much more violent. Try 1.5. 0 = position only.
@export_range(0.0, 15.0, 0.1) var roll_degrees: float = 1.2

@export_group("Advanced")
## A quick-tuned shake flavour. Anything but Custom overrides intensity / frequency /
## decay / roll with values picked for that feel; Custom uses the sliders above.
@export var preset: Preset = Preset.CUSTOM
## Shake THIS node's position instead of the camera. Empty = shake the camera (the usual
## whole-screen shake). Point it at a sprite, HUD panel or weapon to shake just that node.
@export_node_path("Node2D") var target_path: NodePath

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["preset", "target_path"]))

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_SCREENSHAKE

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return

	# Preset resolves to effective params. CUSTOM keeps the sliders, so existing setups
	# and the test suite behave exactly as before.
	var amp := intensity
	var freq := frequency
	# A negative decay grows instead, towards infinity at the end.
	var dcy := maxf(decay, 0.0)
	var roll := roll_degrees
	match preset:
		Preset.IMPACT:     amp = 14.0; freq = 30.0; dcy = 1.6; roll = 2.0
		Preset.EARTHQUAKE: amp = 10.0; freq = 8.0;  dcy = 0.2; roll = 1.0
		Preset.RUMBLE:     amp = 4.0;  freq = 22.0; dcy = 0.0; roll = 0.0
		Preset.HANDHELD:   amp = 3.0;  freq = 5.0;  dcy = 0.0; roll = 0.6

	# Choose what shakes: a specific Node2D (its position) or the camera (its offset).
	var shaker: Node2D = null
	var pos_prop := "offset"
	if not target_path.is_empty():
		shaker = context.get_node_or_null(target_path) as Node2D
		pos_prop = "position"
	if not shaker:
		shaker = context.get_viewport().get_camera_2d()
		pos_prop = "offset"
	if not shaker:
		_warn("JuiceeShakeEffect: no Camera2D in viewport (and no target_path node)")
		return

	# Directional juicee: if caller passed {"hit_direction": Vector2.LEFT}, bias the shake
	# in that direction so it "recoils" away from the hit.
	var hit_direction: Vector2 = _param("hit_direction", Vector2.ZERO)
	var has_direction: bool = hit_direction != Vector2.ZERO
	if has_direction:
		hit_direction = hit_direction.normalized()

	var noise: FastNoiseLite
	var noise_start := randf() * 1000.0
	if use_noise:
		noise = _shake_noise()

	var effective_intensity := _px(amp) * intensity_mult
	var effective_roll := deg_to_rad(roll) * intensity_mult
	var rolling := effective_roll > 0.0
	# Ref-counted state - handles concurrent shakes correctly. Rotation is only claimed
	# when we actually roll: capturing it with roll = 0 would restore the node's rotation
	# on release, clobbering whatever the game did to it during the shake.
	var play := _gen
	var original_offset: Vector2 = _capture_offset(shaker, pos_prop)
	var original_rotation: float = _capture_offset(shaker, "rotation") if rolling else 0.0
	var elapsed: float = 0.0
	var step: float = minf(1.0 / freq, SHAKE_NOISE_STEP) if use_noise else 1.0 / freq
	var tree := context.get_tree()

	while elapsed < duration and is_instance_valid(shaker) and _gen == play:
		var progress: float = elapsed / duration
		var falloff: float = pow(1.0 - progress, dcy * 2.0)
		var current_intensity: float = effective_intensity * falloff
		var offset: Vector2
		var reach := current_intensity
		if use_noise:
			offset = Vector2(
				_shake_noise_at(noise, noise_start, 0, elapsed, freq),
				_shake_noise_at(noise, noise_start, 1, elapsed, freq)
			) * current_intensity
		else:
			offset = Vector2(
				randf_range(-current_intensity, current_intensity),
				randf_range(-current_intensity, current_intensity)
			)
		# The recoil: a push along the hit direction that dies away, the same shape Directional
		# Shake kicks with. It was a sine of the shake's own frequency, and the loop samples once
		# every 1/frequency of a second, which is once per cycle of that sine, so every sample
		# landed on a zero of it and the bias did nothing at all.
		if has_direction:
			var recoil := effective_intensity * 0.6 * exp(-progress * 5.0)
			offset += hit_direction * recoil
			reach += recoil
		_write_offset(shaker, pos_prop, original_offset, offset, reach)
		if rolling:
			var r: float = _shake_noise_at(noise, noise_start, 2, elapsed, freq) if use_noise \
				else randf_range(-1.0, 1.0)
			_write_offset(shaker, "rotation", original_rotation, r * effective_roll * falloff,
					effective_roll * falloff)
		elapsed += await _wait_step(tree, step)

	# A newer play or stop() holds these now; releasing here would take them from it.
	if _gen != play:
		return
	_release_state(shaker, pos_prop)
	if rolling:
		_release_state(shaker, "rotation")
