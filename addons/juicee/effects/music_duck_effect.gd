## Temporarily ducks (lowers) an audio bus's volume - for dialogue moments, dramatic beats.
@tool
class_name JuiceeMusicDuckEffect
extends JuiceeEffect

## Audio bus to duck (lower volume of). Typically "Music" or "Master".
@export var bus: StringName = &"Master"
## How much to lower volume in dB. -15 = noticeably quieter, -30 = barely audible.
@export_range(-60.0, 0.0, 0.5) var duck_db: float = -15.0
## Time to ramp volume down.
@export_range(0.05, 5.0, 0.05) var ramp_in: float = 0.15
## How long to hold at lowered volume.
@export_range(0.05, 10.0, 0.05) var hold: float = 1.0
## Time to ramp volume back up.
@export_range(0.05, 5.0, 0.05) var ramp_out: float = 0.5

@export_group("Advanced")
## Pump the duck repeatedly instead of holding it, the classic sidechain pulse under a
## kick drum. 1 = one plain duck.
@export_range(1, 32, 1) var pump_count: int = 1
## Beats per minute the pumping follows (only used when Pump Count is above 1).
@export_range(40.0, 220.0, 1.0) var pump_bpm: float = 120.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["pump_count", "pump_bpm"]))
	_hint_audio_bus(property)

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if Engine.is_editor_hint():
		return
	if not context or not context.is_inside_tree():
		return
	var bus_idx: int = AudioServer.get_bus_index(bus)
	if bus_idx < 0:
		_warn("JuiceeMusicDuckEffect: bus '%s' not found" % bus)
		return

	# Held on the state stack: ducks and tremolos on one bus all come back to its volume from
	# before the first of them, where each used to restore the volume it found, ducked or not.
	var level := _bus_volume(bus)
	var original_db: float = _capture_state(level, "volume_db")
	var effective_duck_db: float = duck_db * intensity_mult
	var target_db: float = original_db + effective_duck_db

	var tree: SceneTree = context.get_tree()
	# Advanced pump_count turns the duck into a repeating sidechain pulse, the
	# classic pumping you hear under a kick drum.
	if pump_count > 1:
		var beat: float = 60.0 / pump_bpm
		for i in _capped(pump_count, 1000, "pump_count"):
			if _gen != play:
				break
			var pump: Tween = _track(tree.create_tween())
			pump.tween_property(level, "volume_db", target_db, beat * 0.15).from(original_db)\
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			pump.tween_property(level, "volume_db", original_db, beat * 0.85)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			await tree.create_timer(beat, true, false, false).timeout
			if _gen != play:
				return
		_release_state(level, "volume_db")
		return

	var t1: Tween = _track(tree.create_tween())
	t1.tween_property(level, "volume_db", target_db, ramp_in).from(original_db)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t1.finished
	if _gen != play:
		return

	await tree.create_timer(hold, true, false, false).timeout
	if _gen != play:
		return

	var t2: Tween = _track(tree.create_tween())
	t2.tween_property(level, "volume_db", original_db, ramp_out)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t2.finished
	if _gen != play:
		return

	_release_state(level, "volume_db")
