@tool
class_name JuiceeSoundEffect
extends JuiceeEffect

## One or more AudioStream resources - one is picked at random each play.
@export var streams: Array[AudioStream] = []
## Audio bus to route playback through (must exist in the project's audio bus layout).
@export var bus: StringName = &"Master"
## Minimum pitch multiplier (1.0 = original pitch, 0.5 = octave down).
@export_range(0.1, 4.0, 0.01) var pitch_min: float = 0.9
## Maximum pitch multiplier (1.0 = original pitch, 2.0 = octave up).
@export_range(0.1, 4.0, 0.01) var pitch_max: float = 1.1
## Volume in decibels (0 = original, -6 = half loudness, +6 = double).
@export_range(-80.0, 24.0, 0.5) var volume_db: float = 0.0

@export_group("Advanced")
## Never play the same stream twice in a row when picking at random. With a handful of
## footstep or hit variations this alone removes most of the machine-gun repetition.
@export var avoid_repeats: bool = true
## Fade the sound in over this many seconds instead of starting at full volume.
@export_range(0.0, 5.0, 0.05) var fade_in: float = 0.0
## Fade the sound out over the last seconds of its length. 0 = it ends naturally.
@export_range(0.0, 5.0, 0.05) var fade_out: float = 0.0
## Random delay before the sound fires, so a burst of them scatters instead of landing
## on one frame.
@export_range(0.0, 2.0, 0.01) var random_delay: float = 0.0

## Index of the last stream played, so avoid_repeats can skip it next time.
static var _last_played: Dictionary = {}

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["avoid_repeats", "fade_in", "fade_out", "random_delay"]))
	_hint_audio_bus(property)

func _apply(context: Node, intensity_mult: float) -> void:
	if streams.is_empty():
		_warn("JuiceeSoundEffect: no streams assigned")
		return
	if not context or not context.is_inside_tree():
		return

	# Advanced avoid_repeats: skip whatever played last, which kills most of the
	# machine-gun repetition you get from picking purely at random.
	var pick: int = randi() % streams.size()
	if avoid_repeats and streams.size() > 1:
		var key: int = get_instance_id()
		var last: int = _last_played.get(key, -1)
		if pick == last:
			pick = (pick + 1 + (randi() % (streams.size() - 1))) % streams.size()
		_last_played[key] = pick
	var stream := streams[pick]
	if not stream:
		return

	# Advanced random_delay scatters a burst of calls instead of stacking them.
	if random_delay > 0.0:
		await context.get_tree().create_timer(randf() * random_delay, true, false, false).timeout
		if _cancelled or not is_instance_valid(context):
			return

	# intensity_mult shifts volume by ±6dB per unit deviation from 1.0
	var effective_volume_db := volume_db + (intensity_mult - 1.0) * 6.0
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = effective_volume_db
	# A player refuses a pitch of 0 or less.
	player.pitch_scale = maxf(randf_range(pitch_min, pitch_max), 0.01)
	player.name = StringName("_juicee_sound_%d" % randi())
	context.add_child(player)
	# stop() silences it. Firing again does not: a second shot rings out over the first.
	_end_sound_on_stop(player)
	# Advanced fades: ease the sound in, and out over its final seconds.
	if fade_in > 0.0:
		player.volume_db = -60.0
		var fin := player.create_tween()
		fin.tween_property(player, "volume_db", effective_volume_db, fade_in)
	player.play()
	if fade_out > 0.0 and stream.get_length() > fade_out:
		var lead: float = (stream.get_length() / maxf(0.01, player.pitch_scale)) - fade_out
		var fout := player.create_tween()
		fout.tween_interval(lead)
		fout.tween_property(player, "volume_db", -60.0, fade_out)
	await player.finished
	if is_instance_valid(player):
		player.queue_free()
