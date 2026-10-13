## Trigger an AnimationPlayer.play() as a step in a Juicee sequence.
##
## FEEL-style "trigger your existing animation as part of the juice stack" -
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
## Playback speed multiplier (1.0 = normal, 2.0 = double-time). To reverse, use Play Backwards.
@export_range(-4.0, 4.0, 0.05) var speed: float = 1.0
## Custom blend time. -1 uses the AnimationPlayer's default.
@export_range(-1.0, 5.0, 0.05) var blend_time: float = -1.0
## If true, the sequence step waits for animation_finished before continuing.
## If false, the step returns immediately (fire-and-forget).
@export var wait_for_finish: bool = true
## Safety timeout when wait_for_finish is true - bails out if anim doesn't end.
@export_range(0.1, 30.0, 0.1) var max_wait: float = 5.0

@export_group("Advanced")
## Start the animation this far in (0-1 of its length) instead of from the beginning,
## so a reaction can skip a wind-up that already played.
@export_range(0.0, 0.99, 0.01) var start_at_ratio: float = 0.0
## Play the animation backwards from its end.
@export var play_backwards: bool = false
## Randomize the playback speed by this fraction each time, so repeated plays of the
## same clip do not look mechanically identical.
@export_range(0.0, 0.9, 0.05) var speed_variance: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["start_at_ratio", "play_backwards", "speed_variance"]))

func get_category_name() -> String:
	return "Flow"

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	# An empty path means the context, which is where _retarget leaves a player it found.
	var player: AnimationPlayer = context as AnimationPlayer
	if not player_path.is_empty():
		player = context.get_node_or_null(player_path) as AnimationPlayer
	if not player:
		if player_path.is_empty():
			_warn("JuiceeAnimationPlayerEffect: no AnimationPlayer found")
		else:
			_warn("JuiceeAnimationPlayerEffect: AnimationPlayer not found at '%s'" % str(player_path))
		return
	if animation_name.is_empty():
		_warn("JuiceeAnimationPlayerEffect: animation_name is empty")
		return
	if not player.has_animation(animation_name):
		_warn("JuiceeAnimationPlayerEffect: animation '%s' missing" % animation_name)
		return

	# Advanced speed_variance keeps repeated plays of one clip from looking identical.
	# Speed is timing, so intensity leaves it alone.
	var eff_speed: float = speed
	if speed_variance > 0.0:
		eff_speed *= 1.0 + randf_range(-speed_variance, speed_variance)
	# The speed is this clip's, not the player's: it was left set for every animation after it,
	# so a clip played at 2 sped up the character's own animations for good.
	var play := _gen
	_capture_state(player, "speed_scale")
	player.speed_scale = absf(eff_speed)
	# play_backwards runs the clip from its end, which is how a lot of open/close
	# pairs are built from a single animation.
	if play_backwards:
		player.play_backwards(animation_name, blend_time)
	else:
		player.play(animation_name, blend_time)
	# start_at_ratio skips a wind-up that has already been seen.
	if start_at_ratio > 0.0:
		var anim := player.get_animation(animation_name)
		if anim:
			player.seek(anim.length * start_at_ratio, true)

	if not wait_for_finish:
		# Back to the player's own speed once the clip ends or something else starts playing.
		var pid := player.get_instance_id()
		var give_back := func(_name: StringName) -> void:
			if _gen == play:
				_release_state(instance_from_id(pid), "speed_scale")
		player.animation_finished.connect(give_back, CONNECT_ONE_SHOT)
		player.current_animation_changed.connect(give_back, CONNECT_ONE_SHOT)
		return

	# stop() stops the clip it is waiting on as well, and puts the speed back.
	var clip := StringName(animation_name)
	_on_stop(func() -> void:
		var p := instance_from_id(player.get_instance_id()) as AnimationPlayer
		if p and p.current_animation == clip:
			p.stop())
	# Await animation_finished or timeout, whichever first.
	var tree := context.get_tree()
	var elapsed := 0.0
	while elapsed < max_wait and _gen == play and is_instance_valid(player) and player.is_playing():
		await tree.process_frame
		if _gen != play:
			return
		elapsed += tree.root.get_process_delta_time()
	if _gen != play:
		return
	_release_state(player, "speed_scale")
