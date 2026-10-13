## Rhythmic sinusoidal Camera2D bob.
##
## Use for: walking footstep camera, ship rocking on waves, breathing idle animation,
## hypnotic pendulum, drunk/dizzy state camera.
##
## The bob amplitude swells and fades on a sin(t * PI) envelope across `duration`,
## so it never pops in or out abruptly.
@tool
class_name JuiceeCameraBobEffect
extends JuiceeEffect

## Per-axis bob amplitude in pixels. (0, 4) = vertical only, (3, 3) = circular.
@export var amplitude: Vector2 = Vector2(0.0, 4.0)
## Bob cycles per second (2.0 = leisurely walk, 3.5 = run, 0.5 = breathing).
@export_range(0.1, 15.0, 0.1) var frequency: float = 2.0
## Total duration in seconds.
@export_range(0.1, 30.0, 0.1) var duration: float = 2.0
## Phase offset in radians. PI/2 = start at peak instead of zero crossing.
@export_range(0.0, 6.283, 0.01) var phase_offset: float = 0.0

@export_group("Advanced")
## Bob until stop() is called, ignoring Duration. For a walk cycle that runs while the
## player is moving.
@export var loop: bool = false
## Camera roll in degrees synced to the bob, so footsteps also tilt the view. 0 = none.
@export_range(0.0, 10.0, 0.1) var roll_degrees: float = 0.0
## Horizontal bob runs at half the vertical rate, the way a real walk cycle does
## (one sway per two steps). Off = both axes share the same frequency.
@export var figure_eight: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["loop", "roll_degrees", "figure_eight"]))

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_SCREENSHAKE
func get_category_name() -> String: return "Camera"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	var cam: Camera2D = context.get_viewport().get_camera_2d()
	if not cam:
		_warn("JuiceeCameraBobEffect: no Camera2D in viewport")
		return

	# `offset` and not `position`. Camera2D adds offset on top of wherever the camera
	# actually is, so a shake composes with a camera that is following something.
	# Writing position instead pins the camera to where it stood when the effect
	# started: measured on a camera moving the way a follow script moves one, this
	# dragged the view back by 228px mid-effect. JuiceeShakeEffect already used offset.
	var original_pos: Vector2 = _capture_offset(cam, "offset")
	# Camera2D ignores its own rotation by default, so a roll needs that turned off.
	var rolling := roll_degrees > 0.0
	var original_rot: float = 0.0
	var had_ignore := false
	if rolling:
		original_rot = _capture_offset(cam, "rotation")
		had_ignore = cam.ignore_rotation
		if had_ignore:
			cam.ignore_rotation = false
			_on_stop(_set_by_id.bind(cam.get_instance_id(), &"ignore_rotation", true))
	var elapsed := 0.0
	var tree := context.get_tree()
	var eff_amp := amplitude * intensity_mult

	while (loop or elapsed < duration) and is_instance_valid(cam) and _gen == play:
		# Smooth fade-in / fade-out, except in loop mode where it holds steady.
		var env: float = 1.0 if loop else sin((elapsed / duration) * PI)
		# figure_eight halves the horizontal rate, the way a walk cycle sways once
		# per two footfalls.
		var x_rate: float = frequency * (0.5 if figure_eight else 1.0)
		var wave_x := sin(elapsed * x_rate * TAU + phase_offset)
		var bob := Vector2(
			wave_x * eff_amp.x,
			sin(elapsed * frequency * TAU + phase_offset + PI * 0.5) * eff_amp.y
		) * env
		_write_offset(cam, "offset", original_pos, bob, eff_amp.length() * env)
		if rolling:
			_write_offset(cam, "rotation", original_rot, deg_to_rad(roll_degrees) * wave_x * env,
					deg_to_rad(roll_degrees) * env)
		await tree.process_frame
		if _gen != play:
			return
		elapsed += tree.root.get_process_delta_time()

	# A newer play or stop() holds what this one held.
	if _gen != play:
		return
	_release_state(cam, "offset")
	if rolling:
		_release_state(cam, "rotation")
		if is_instance_valid(cam) and had_ignore:
			cam.ignore_rotation = true
