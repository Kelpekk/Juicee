## Embeds another JuiceeSequence as a single effect.
## Use this for reusable composite effects: build "hit_combo.tres", then drop
## it as one step inside a bigger sequence like "boss_kill.tres".
@tool
class_name JuiceeSequenceEffect
extends JuiceeEffect

## Nested JuiceeSequence to play as a single step.
## Use for reusable presets: build "hit_combo.tres" once, drop it into bigger sequences.
@export var sequence: JuiceeSequence

@export_group("Advanced")
## Play the nested sequence this many times back to back. 1 = once.
@export_range(1, 32, 1) var repeat_count: int = 1
## Pause between repeats, in seconds.
@export_range(0.0, 10.0, 0.05) var repeat_delay: float = 0.0
## Keep replaying until stop() is called, for an ambient loop built from a sequence.
@export var loop_forever: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["repeat_count", "repeat_delay", "loop_forever"]))

func _apply(context: Node, _intensity_mult: float) -> void:
	if not sequence:
		_warn("JuiceeSequenceEffect: no sequence assigned")
		return
	if _leads_to(sequence, self):
		_warn("JuiceeSequenceEffect: its sequence holds this step, and would play it again play after play for good, so it did not play (loop_forever is the way to repeat it)")
		return
	# Stopping this step stops the sequence it is playing, and the effects in it.
	_on_stop(sequence.stop)
	# Advanced repeats let one nested sequence cover a burst or an ambient loop without
	# duplicating it in the graph.
	var passes: int = maxi(1, repeat_count)
	var tree := context.get_tree() if context else null
	var play := _gen
	var i := 0
	while (loop_forever or i < passes) and _gen == play and is_instance_valid(context):
		var began := Engine.get_process_frames()
		await sequence.play(context, _runtime_params)
		if _gen != play:
			return
		i += 1
		if (loop_forever or i < passes) and repeat_delay > 0.0 and tree:
			await tree.create_timer(repeat_delay, true, false, false).timeout
			if _gen != play:
				return
		elif Engine.get_process_frames() == began and tree:
			# A pass that took no time at all (instant, muted or empty steps) would loop forever
			# inside one frame and freeze the game.
			await tree.process_frame
