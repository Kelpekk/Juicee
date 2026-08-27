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

func _apply(context: Node, intensity_mult: float) -> void:
	if Engine.is_editor_hint():
		return
	if not context or not context.is_inside_tree():
		return
	var bus_idx: int = AudioServer.get_bus_index(bus)
	if bus_idx < 0:
		push_warning("JuiceeMusicDuckEffect: bus '%s' not found" % bus)
		return

	var original_db: float = AudioServer.get_bus_volume_db(bus_idx)
	# stop() restores the bus - the killed tween's `await` would otherwise skip the
	# restore below and leave the bus ducked forever.
	_on_stop(func() -> void:
		if AudioServer.get_bus_index(bus) >= 0:
			AudioServer.set_bus_volume_db(bus_idx, original_db))
	var effective_duck_db: float = duck_db * intensity_mult
	var target_db: float = original_db + effective_duck_db

	var tree: SceneTree = context.get_tree()
	var t1: Tween = _track(tree.create_tween())
	t1.tween_method(_set_bus_db.bind(bus_idx), original_db, target_db, ramp_in)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t1.finished

	await tree.create_timer(hold, true, false, false).timeout

	var t2: Tween = _track(tree.create_tween())
	t2.tween_method(_set_bus_db.bind(bus_idx), target_db, original_db, ramp_out)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t2.finished

	AudioServer.set_bus_volume_db(bus_idx, original_db)

func _set_bus_db(db: float, bus_idx: int) -> void:
	AudioServer.set_bus_volume_db(bus_idx, db)
