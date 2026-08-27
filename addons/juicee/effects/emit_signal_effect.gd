## Emit a signal on the context node as a sequence step.
##
## The bridge between Juicee sequences and your game logic. Fire a signal at
## a specific point in a chain without writing a one-off script.
##
## Use for: trigger game events mid-sequence (spawn enemy, open door, start
## dialogue), decouple sequence timing from game logic, integration testing.
@tool
class_name JuiceeEmitSignalEffect
extends JuiceeEffect

## Name of the signal to emit on the context node.
@export var signal_name: StringName = &""
## Optional first argument passed with the signal.
## Only used if the signal expects arguments - leave null for no-arg signals.
@export var argument: Variant = null

func get_category_name() -> String: return "Flow"

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if signal_name.is_empty():
		push_warning("JuiceeEmitSignalEffect: signal_name is empty")
		return
	if not context.has_signal(signal_name):
		push_warning("JuiceeEmitSignalEffect: '%s' has no signal '%s'" % [context.name, signal_name])
		return
	if argument != null:
		context.emit_signal(signal_name, argument)
	else:
		context.emit_signal(signal_name)
