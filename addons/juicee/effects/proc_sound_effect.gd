## Synthesize a retro game sound at runtime — ZERO audio assets required.
##
## Wraps [JuiceeSfxr] (a GDScript port of DrPetter's sfxr) in a standard Juicee
## effect, so you can drop procedural SFX into sequences, the graph editor, or
## fire them from the singleton. Great for prototyping and game jams: every
## preset (hit, pickup, explosion, …) gets sound without bundling a single .wav.
##
## Use for: coin pickups, laser shots, explosions, power-ups, hit/hurt zaps,
## jumps, UI blips — all generated on the fly.
##
## @experimental: Procedural SFX is an experimental prototyping aid (8-bit /
## chiptune quality). The API may change; for shipping audio prefer real assets
## via [JuiceeSoundEffect].
@tool
class_name JuiceeProcSoundEffect
extends JuiceeEffect

## Which classic sfxr sound family to synthesize.
@export var category: JuiceeSfxr.Category = JuiceeSfxr.Category.PICKUP_COIN
## Fixed seed → the exact same sound every play. 0 = a fresh random variation each time.
@export var sound_seed: int = 0
## Audio bus to route playback through (must exist in the project's bus layout).
@export var bus: StringName = &"Master"
## Volume in decibels (0 = as synthesized, -6 = half loudness, +6 = double).
@export_range(-80.0, 24.0, 0.5) var volume_db: float = 0.0
## Minimum pitch multiplier (randomized per play for variety).
@export_range(0.1, 4.0, 0.01) var pitch_min: float = 1.0
## Maximum pitch multiplier.
@export_range(0.1, 4.0, 0.01) var pitch_max: float = 1.0

## Cache of seeded streams so a fixed seed isn't re-synthesized on every play.
## Only seeded (deterministic) sounds are cached; seed 0 always re-generates.
static var _cache: Dictionary = {}

func get_category_name() -> String:
	return "Audio"

func get_category_color() -> Color:
	return Color(0.95, 0.85, 0.20)

func get_description() -> String:
	return "Synthesize a retro game sound at runtime (sfxr) — no audio asset needed."

func _get_stream() -> AudioStreamWAV:
	if sound_seed != 0:
		var key := "%d_%d" % [category, sound_seed]
		if not _cache.has(key):
			_cache[key] = JuiceeSfxr.make(category, sound_seed)
		return _cache[key]
	return JuiceeSfxr.make(category, 0)

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var stream := _get_stream()
	if not stream:
		return

	# intensity_mult shifts volume by ±6dB per unit deviation from 1.0 (matches JuiceeSoundEffect).
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
