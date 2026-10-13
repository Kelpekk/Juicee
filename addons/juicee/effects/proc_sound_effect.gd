## Synthesize a retro game sound at runtime - ZERO audio assets required.
##
## Wraps [JuiceeSfxr] (a GDScript port of DrPetter's sfxr) in a standard Juicee
## effect, so you can drop procedural SFX into sequences, the graph editor, or
## fire them from the singleton. Great for prototyping and game jams: every
## preset (hit, pickup, explosion, ...) gets sound without bundling a single .wav.
##
## Use for: coin pickups, laser shots, explosions, power-ups, hit/hurt zaps,
## jumps, UI blips - all generated on the fly.
##
## @experimental: Procedural SFX is an experimental prototyping aid (8-bit /
## chiptune quality). The API may change; for shipping audio prefer real assets
## via [JuiceeSoundEffect].
@tool
class_name JuiceeProcSoundEffect
extends JuiceeEffect

## Which classic sfxr sound family to synthesize.
@export var category: JuiceeSfxr.Category = JuiceeSfxr.Category.PICKUP_COIN
## A fixed seed plays the exact same sound every time. 0 = one of eight random variations.
@export var sound_seed: int = 0
## Audio bus to route playback through (must exist in the project's bus layout).
@export var bus: StringName = &"Master"
## Volume in decibels (0 = as synthesized, -6 = half loudness, +6 = double).
@export_range(-80.0, 24.0, 0.5) var volume_db: float = 0.0
## Minimum pitch multiplier (randomized per play for variety).
@export_range(0.1, 4.0, 0.01) var pitch_min: float = 1.0
## Maximum pitch multiplier.
@export_range(0.1, 4.0, 0.01) var pitch_max: float = 1.0

@export_group("Advanced")
## Fire the sound this many times in quick succession, for a burst (multi-hit, coin
## shower, rapid fire). 1 = a single shot.
@export_range(1, 12, 1) var repeat_count: int = 1
## Seconds between repeats.
@export_range(0.01, 1.0, 0.01) var repeat_interval: float = 0.06
## Each repeat is this many dB quieter than the one before, so a burst trails off.
@export_range(0.0, 12.0, 0.5) var repeat_falloff_db: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["repeat_count", "repeat_interval", "repeat_falloff_db"]))
	_hint_audio_bus(property)

## Cache of seeded streams so a fixed seed isn't re-synthesized on every play.
static var _cache: Dictionary = {}
## For seed 0, the variations made so far per category: a new one for each of the first
## VARIATIONS plays, then one of those at random. Synthesis runs in GDScript and costs from about
## twenty milliseconds to most of a second a sound, which was a hitch on every shot.
static var _variations: Dictionary = {}
const VARIATIONS := 8

func get_category_name() -> String:
	return "Audio"

func get_description() -> String:
	return "Synthesize a retro game sound at runtime (sfxr) - no audio asset needed."

func _get_stream() -> AudioStreamWAV:
	if sound_seed != 0:
		var key := "%d_%d" % [category, sound_seed]
		if not _cache.has(key):
			_cache[key] = JuiceeSfxr.make(category, sound_seed)
		return _cache[key]
	var made: Array = _variations.get(category, [])
	if made.size() >= VARIATIONS:
		return made[randi() % made.size()]
	var stream := JuiceeSfxr.make(category, 0)
	made.append(stream)
	_variations[category] = made
	return stream

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
	# A player refuses a pitch of 0 or less.
	player.pitch_scale = maxf(randf_range(pitch_min, pitch_max), 0.01)
	player.name = StringName("_juicee_proc_sound_%d" % randi())
	context.add_child(player)
	# stop() silences it. Firing again does not: a second shot rings out over the first.
	_end_sound_on_stop(player)
	player.play()
	var play := _gen
	# Advanced repeat_count fires the sound again in quick succession (multi-hit,
	# coin shower, rapid fire), each shot quieter by repeat_falloff_db.
	if repeat_count > 1:
		var tree := context.get_tree()
		# Each shot synthesizes a new sound, so a count in the thousands would stall the game.
		for i in range(1, _capped(repeat_count, 12, "repeat_count")):
			await tree.create_timer(repeat_interval, true, false, false).timeout
			if _gen != play or not is_instance_valid(context):
				break
			var extra := AudioStreamPlayer.new()
			extra.stream = _get_stream()
			extra.bus = bus
			extra.volume_db = effective_volume_db - repeat_falloff_db * float(i)
			extra.pitch_scale = maxf(randf_range(pitch_min, pitch_max), 0.01)
			extra.name = StringName("_juicee_proc_sound_%d" % randi())
			context.add_child(extra)
			_end_sound_on_stop(extra)
			extra.play()
			extra.finished.connect(func() -> void:
				if is_instance_valid(extra):
					extra.queue_free(), CONNECT_ONE_SHOT)
	# A short sound under slow repeats is over before the last one fires, and waiting for a
	# finished that has already come never returns.
	if is_instance_valid(player) and player.playing:
		await player.finished
	if is_instance_valid(player):
		player.queue_free()
