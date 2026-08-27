## Gentle continuous rotation sway - a pendulum-like rock back and forth, driven by a
## smooth sine wave. Unlike [JuiceeWiggleEffect] (random position jitter) or
## [JuiceeSpinEffect] (a full revolution), this is a soft, looping tilt.
##
## Great for idle "alive" UI, hanging signs, floating pickups, swinging lanterns,
## or a title that subtly breathes. Set [member cycles] to 0 to sway forever
## (until [method JuiceeEffect.stop]).
@tool
class_name JuiceeSwayEffect
extends JuiceeEffect

## Peak sway angle to each side, in degrees.
@export_range(0.5, 90.0, 0.5) var angle: float = 6.0
## Seconds for one full left->right->left cycle.
@export_range(0.1, 10.0, 0.05) var period: float = 1.2
## Number of full cycles to run. 0 = sway forever (until stop()).
@export_range(0.0, 100.0, 0.5) var cycles: float = 2.0
## For Control targets, rotate around the centre instead of the top-left corner.
@export var center_pivot: bool = true

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "Smooth pendulum rotation sway (sine). cycles=0 loops forever - idle 'alive' UI, hanging signs, swinging lanterns, breathing titles."

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not (context is Node2D or context is Control):
		push_warning("JuiceeSwayEffect: context must be a Node2D or Control")
		return

	# Control nodes rotate around their top-left by default; pivot to centre so the
	# sway reads as a tilt rather than a swing from the corner.
	if center_pivot and context is Control:
		var c := context as Control
		if c.size != Vector2.ZERO:
			c.pivot_offset = c.size * 0.5

	var base: float = _capture_state(context, "rotation")
	var amp: float = deg_to_rad(angle) * intensity_mult
	var tree: SceneTree = context.get_tree()
	var total: float = cycles * period      # 0 -> infinite
	var elapsed: float = 0.0

	while is_instance_valid(context) and not _cancelled:
		if total > 0.0 and elapsed >= total:
			break
		context.set("rotation", base + sin(elapsed / period * TAU) * amp)
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()

	_release_state(context, "rotation")
