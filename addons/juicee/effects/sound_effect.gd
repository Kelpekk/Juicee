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

func _apply(context: Node, intensity_mult: float) -> void:
	if streams.is_empty():
		push_warning("JuiceeSoundEffect: no streams assigned")
		return
	if not context or not context.is_inside_tree():
		return

	var stream := streams[randi() % streams.size()]
	if not stream:
		return

	# intensity_mult shifts volume by ±6dB per unit deviation from 1.0
	var effective_volume_db := volume_db + (intensity_mult - 1.0) * 6.0
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = effective_volume_db
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	context.add_child(player)
	player.play()
	await player.finished
	if is_instance_valid(player):
		player.queue_free()
