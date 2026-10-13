## Gentle sine-wave vertical (or custom-axis) bob on a Node2D.
##
## Unlike CameraBob (which moves the camera), this moves the TARGET NODE.
## Use for: floating pickup item, idle NPC hover, UI element breathe,
## torch flame sway, buoy on water, space station drift.
##
## The amplitude fades in at the start and out at the end (sin(t*PI) envelope)
## so it never pops on or off.
@tool
class_name JuiceeSpriteBobEffect
extends JuiceeEffect

## Peak displacement in pixels.
@export_range(0.0, 100.0, 0.5) var amplitude: float = 4.0
## Bob cycles per second. 1.5 = gentle float, 3.0 = nervous flutter.
@export_range(0.1, 15.0, 0.1) var frequency: float = 1.5
## Total duration in seconds.
@export_range(0.1, 30.0, 0.1) var duration: float = 2.0
## Phase offset in radians (PI/2 = start at peak).
@export_range(0.0, 6.283, 0.01) var phase_offset: float = 0.0
## Direction of the bob. (0, 1) = vertical, (1, 0) = horizontal.
@export var bob_axis: Vector2 = Vector2(0.0, 1.0)

@export_group("Advanced")
## Bob forever (ignores Duration, no fade in/out) until stop() - a true idle loop.
@export var loop: bool = false
## Tilt this many degrees in sync with the bob, for a rocking float. 0 = position only.
@export_range(0.0, 45.0, 1.0) var rotation_sway: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["loop", "rotation_sway"]))

func get_category_name() -> String: return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	if not context is Node2D:
		_warn("JuiceeSpriteBobEffect: context must be a Node2D")
		return
	var target := context as Node2D
	var original_pos: Vector2 = _capture_offset(target, "position")
	var swaying := rotation_sway > 0.0
	var orig_rot: float = _capture_offset(target, "rotation") if swaying else 0.0
	var elapsed := 0.0
	var tree := context.get_tree()
	var eff_amp := _px(amplitude) * intensity_mult
	var axis_norm := bob_axis.normalized() if bob_axis.length_squared() > 0.0001 else Vector2.DOWN
	var total: float = INF if loop else duration

	while elapsed < total and is_instance_valid(target) and _gen == play:
		# loop skips the fade-in/out envelope so an idle loop stays steady.
		var env: float = 1.0 if loop else sin((elapsed / duration) * PI)
		var wave := sin(elapsed * frequency * TAU + phase_offset)
		_write_offset(target, "position", original_pos, axis_norm * (wave * eff_amp * env),
				eff_amp * env)
		if swaying:
			_write_offset(target, "rotation", orig_rot, deg_to_rad(rotation_sway) * wave * env,
					deg_to_rad(rotation_sway) * env)
		await tree.process_frame
		if _gen != play:
			return
		elapsed += tree.root.get_process_delta_time()

	# A newer play or stop() holds what this one held.
	if _gen != play:
		return
	_release_state(target, "position")
	if swaying:
		_release_state(target, "rotation")
