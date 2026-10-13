## Play a spatial 3D sound at the context node's world position.
##
## Spawns a temporary AudioStreamPlayer3D at the context's global_position,
## plays a random stream from the pool, then cleans up automatically.
## No persistent AudioStreamPlayer3D node required in the scene.
##
## Use for: footsteps, gunshots, explosions, ambient one-shots - all with
## proper 3D attenuation without pre-placing audio nodes.
@tool
class_name JuiceeAudioSource3DEffect
extends JuiceeEffect

## Pool of AudioStreams - one is picked at random per play.
@export var streams: Array[AudioStream] = []
## Volume offset in dB.
@export_range(-40.0, 24.0, 0.5) var volume_db: float = 0.0
## Lower end of the pitch range a play picks from at random.
@export_range(0.1, 4.0, 0.05) var pitch_min: float = 0.9
## Upper end of that range. Equal to Pitch Min for no variation at all.
@export_range(0.1, 4.0, 0.05) var pitch_max: float = 1.1
## Target audio bus name.
@export var bus: StringName = &"Master"
## Maximum audible distance in metres.
@export_range(1.0, 500.0, 1.0) var max_distance: float = 40.0
## Attenuation model (maps to AudioStreamPlayer3D.AttenuationModel).
## 0=InverseDistance, 1=InverseSquareDistance, 2=Logarithmic, 3=Disabled.
@export_range(0, 3, 1) var attenuation_model: int = 0
## Offset the playback position in 3D space relative to the context.
@export var position_offset: Vector3 = Vector3.ZERO

@export_group("Advanced")
## Size of the sound's "unit" sphere. Larger values keep it loud further out before the
## attenuation curve takes over.
@export_range(0.1, 100.0, 0.1) var unit_size: float = 10.0
## Pitch-shift the sound based on relative motion (the doppler effect), tracked in idle
## or physics step. Off = no doppler.
@export_enum("Disabled", "Idle", "Physics") var doppler_tracking: int = 0
## How strongly the sound is panned across the stereo field by its position.
@export_range(0.0, 3.0, 0.05) var panning_strength: float = 1.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["unit_size", "doppler_tracking", "panning_strength"]))
	_hint_audio_bus(property)

func get_category_name() -> String: return "Audio"

func _apply(context: Node, intensity_mult: float) -> void:
	if streams.is_empty():
		_warn("JuiceeAudioSource3DEffect: no streams assigned")
		return
	if not context or not context.is_inside_tree():
		return

	var stream: AudioStream = streams[randi() % streams.size()]
	if not stream:
		_warn("JuiceeAudioSource3DEffect: the stream it picked is empty")
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	# Same curve as JuiceeSoundEffect: 6 dB per unit of intensity away from 1.
	player.volume_db = volume_db + (intensity_mult - 1.0) * 6.0
	# A player refuses a pitch of 0 or less.
	player.pitch_scale = maxf(randf_range(pitch_min, pitch_max), 0.01)
	player.bus = bus
	# The player refuses a negative distance or panning and a model outside its four, with an
	# error each time, so those are brought into its range.
	player.max_distance = maxf(max_distance, 0.0)
	player.attenuation_model = clampi(attenuation_model, 0, 3) as AudioStreamPlayer3D.AttenuationModel
	# Advanced 3D placement: how big the sound's loud zone is, whether motion
	# pitch-shifts it (doppler), and how hard it pans across the stereo field.
	player.unit_size = maxf(unit_size, 0.01)
	player.doppler_tracking = clampi(doppler_tracking, 0, 2) as AudioStreamPlayer3D.DopplerTracking
	player.panning_strength = maxf(panning_strength, 0.0)
	player.autoplay = false

	# Place at context's world position (works for Node3D and Node2D via to_3d).
	var world_root := context.get_tree().root
	player.name = StringName("_juicee_audio_3d_%d" % randi())
	world_root.add_child(player)
	# The play is over as soon as the sound starts; stop() still silences it while it rings, a
	# looping stream included. Firing again does not: shots overlap.
	_end_sound_on_stop(player)

	if context is Node3D:
		player.global_position = (context as Node3D).global_position + position_offset
	elif context is Node2D:
		var p2 := (context as Node2D).global_position
		player.global_position = Vector3(p2.x, -p2.y, 0.0) * 0.01 + position_offset

	player.play()
	player.finished.connect(func() -> void:
		if is_instance_valid(player): player.queue_free()
	)
