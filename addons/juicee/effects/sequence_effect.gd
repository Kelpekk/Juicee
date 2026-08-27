## Embeds another JuiceeSequence as a single effect.
## Use this for reusable composite effects: build "hit_combo.tres", then drop
## it as one step inside a bigger sequence like "boss_kill.tres".
@tool
class_name JuiceeSequenceEffect
extends JuiceeEffect

## Nested JuiceeSequence to play as a single step.
## Use for reusable presets: build "hit_combo.tres" once, drop it into bigger sequences.
@export var sequence: JuiceeSequence

func _apply(context: Node, _intensity_mult: float) -> void:
	if not sequence:
		return
	await sequence.play(context)
