## Text wobble / shake - the Label shakes for emphasis. Drama text like
## "GAME OVER", "BOSS APPROACHING", "WAVE COMPLETE", or damage-state callouts.
##
## Targets a `Control` (typically `Label` or `RichTextLabel`) and oscillates
## its position with a sine-wave wobble that decays over the duration.
## Uses `JuiceeStateStack` for the position baseline so concurrent wobbles
## (or wobble during a different effect) restore correctly.
@tool
class_name JuiceeTextWobbleEffect
extends JuiceeEffect

## Peak wobble offset in pixels.
@export_range(0.0, 50.0, 0.5) var amplitude: float = 8.0
## Oscillations per second. Higher = jittery, lower = smooth.
@export_range(1.0, 60.0, 0.5) var frequency: float = 12.0
## Total wobble duration.
@export_range(0.05, 10.0, 0.05) var duration: float = 0.5
## How quickly the wobble decays. 0 = constant wobble, 1 = full fadeout at end.
@export_range(0.0, 1.0, 0.05) var decay: float = 0.7
## Vertical-to-horizontal wobble ratio (1 = equal both axes, 0 = horizontal only).
@export_range(0.0, 1.0, 0.05) var y_axis_ratio: float = 0.6

@export_group("Advanced")
## Rotation wobble in degrees, layered on the positional sway. Drama text tilts as it
## shakes. 0 = position only.
@export_range(0.0, 30.0, 0.5) var rotation_wobble: float = 0.0
## Scale pulse amount synced to the wobble (0.1 = 10% throb). 0 = no scale change.
@export_range(0.0, 0.5, 0.01) var scale_pulse: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["rotation_wobble", "scale_pulse"]))

func get_category_name() -> String:
	return "Text"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Control = context as Control
	if not target or not target.is_inside_tree():
		_warn("JuiceeTextWobbleEffect: context is not a Control")
		return

	var play := _gen
	var original_pos: Vector2 = _capture_offset(target, "position")
	var effective_amplitude: float = amplitude * intensity_mult
	# Independent phases on X and Y for organic wobble.
	var phase_x_offset: float = randf() * TAU
	var phase_y_offset: float = randf() * TAU
	var elapsed: float = 0.0
	var tree := target.get_tree()
	if not tree:
		_release_state(target, "position")
		return

	var wobble_rot := rotation_wobble > 0.0
	var pulsing := scale_pulse > 0.0
	var orig_rot: float = _capture_offset(target, "rotation") if wobble_rot else 0.0
	var orig_scale: Vector2 = _capture_offset(target, "scale") if pulsing else Vector2.ONE
	var pivoting := (wobble_rot or pulsing) and target.size != Vector2.ZERO
	if pivoting:
		# Rotate / scale around the centre so drama text tilts in place. Held on the stack and
		# given back at the end: it was left at the centre for good.
		_capture_state(target, "pivot_offset")
		target.pivot_offset = target.size * 0.5
	while elapsed < duration and _gen == play and is_instance_valid(target):
		var t: float = elapsed / duration
		var decay_factor: float = 1.0 - (decay * t)
		var current_amp: float = effective_amplitude * decay_factor
		var wave: float = sin(elapsed * TAU * frequency + phase_x_offset)
		var dx: float = wave * current_amp
		var dy: float = cos(elapsed * TAU * frequency * 1.3 + phase_y_offset) * current_amp * y_axis_ratio
		_write_offset(target, "position", original_pos, Vector2(dx, dy),
				absf(current_amp) * maxf(1.0, absf(y_axis_ratio)))
		if wobble_rot:
			_write_offset(target, "rotation", orig_rot, deg_to_rad(rotation_wobble) * wave * decay_factor,
					deg_to_rad(rotation_wobble) * absf(decay_factor))
		if pulsing:
			_write_offset(target, "scale", orig_scale, orig_scale * scale_pulse * wave * decay_factor,
					orig_scale.length() * scale_pulse * absf(decay_factor))
		await tree.process_frame
		if _gen != play:
			return
		elapsed += tree.root.get_process_delta_time()

	# A newer play or stop() holds these now. Otherwise the stack gives them back, and only once
	# the last effect on this text is done.
	if _gen != play:
		return
	_release_state(target, "position")
	if wobble_rot:
		_release_state(target, "rotation")
	if pulsing:
		_release_state(target, "scale")
	if pivoting:
		_release_state(target, "pivot_offset")
