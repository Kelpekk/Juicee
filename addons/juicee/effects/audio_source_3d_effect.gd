## Play a spatial 3D sound at the context node's world position.
##
## Spawns a temporary AudioStreamPlayer3D at the context's global_position,
## plays a random stream from the pool, then cleans up automatically.
## No persistent AudioStreamPlayer3D node required in the scene.
##
## Use for: footsteps, gunshots, explosions, ambient one-shots — all with
## proper 3D attenuation without pre-placing audio nodes.
@tool
class_name JuiceeAudioSource3DEffect
extends JuiceeEffect

## Pool of AudioStreams — one is picked at random per play.
@export var streams: Array[AudioStream] = []
## Volume offset in dB.
@export_range(-40.0, 24.0, 0.5) var volume_db: float = 0.0
## Pitch scale range.
@export_range(0.1, 4.0, 0.05) var pitch_min: float = 0.9
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

func get_category_name() -> String: return "Audio"
func get_category_color() -> Color: return Color(1.0, 0.333, 0.333)

func _apply(context: Node, intensity_mult: float) -> void:
	if streams.is_empty():
		push_warning("JuiceeAudioSource3DEffect: no streams assigned")
		return
	if not context or not context.is_inside_tree():
		return

	var stream: AudioStream = streams[randi() % streams.size()]
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.bus = bus
	player.max_distance = max_distance
	player.attenuation_model = attenuation_model
	player.autoplay = false

	# Place at context's world position (works for Node3D and Node2D via to_3d).
	var world_root := context.get_tree().root
	world_root.add_child(player)

	if context is Node3D:
		player.global_position = (context as Node3D).global_position + position_offset
	elif context is Node2D:
		var p2 := (context as Node2D).global_position
		player.global_position = Vector3(p2.x, -p2.y, 0.0) * 0.01 + position_offset

	player.play()
	player.finished.connect(func() -> void:
		if is_instance_valid(player): player.queue_free()
	)
