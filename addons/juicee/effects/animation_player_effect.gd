## Trigger an AnimationPlayer.play() as a step in a Juicee sequence.
##
## FEEL-style "trigger your existing animation as part of the juice stack" —
## works for sprite frame animations, mesh blend shapes, custom-tracked
## tweens, or any AnimationPlayer asset you've already authored.
##
## If `wait_for_finish` is true, the sequence stalls on this step until the
## animation finishes (or the optional timeout elapses).
@tool
class_name JuiceeAnimationPlayerEffect
extends JuiceeEffect

## Node path to the AnimationPlayer node (relative to context, or absolute).
@export_node_path("AnimationPlayer") var player_path: NodePath
## Animation name to play (must exist in the AnimationPlayer).
@export var animation_name: String = ""
## Playback speed multiplier (1.0 = normal, 2.0 = double-time, -1.0 = reverse).
@export_range(-4.0, 4.0, 0.05) var speed: float = 1.0
## Custom blend time. -1 uses the AnimationPlayer's default.
@export_range(-1.0, 5.0, 0.05) var blend_time: float = -1.0
## If true, the sequence step waits for animation_finished before continuing.
## If false, the step returns immediately (fire-and-forget).
@export var wait_for_finish: bool = true
## Safety timeout when wait_for_finish is true — bails out if anim doesn't end.
@export_range(0.1, 30.0, 0.1) var max_wait: float = 5.0

func get_category_color() -> Color:
	return Color(0.40, 0.85, 0.45)

func get_category_name() -> String:
	return "Flow"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var player: AnimationPlayer = context.get_node_or_null(player_path) as AnimationPlayer
	if not player:
		push_warning("JuiceeAnimationPlayerEffect: AnimationPlayer not found at '%s'" % str(player_path))
		return
	if animation_name.is_empty():
		push_warning("JuiceeAnimationPlayerEffect: animation_name is empty")
		return
	if not player.has_animation(animation_name):
		push_warning("JuiceeAnimationPlayerEffect: animation '%s' missing" % animation_name)
		return

	player.speed_scale = speed * intensity_mult
	player.play(animation_name, blend_time)

	if not wait_for_finish:
		return

	# Await animation_finished or timeout, whichever first.
	var tree := context.get_tree()
	var elapsed := 0.0
	while elapsed < max_wait and not _cancelled and is_instance_valid(player) and player.is_playing():
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()
