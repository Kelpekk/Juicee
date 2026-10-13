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

@export_group("Advanced")
## Emit on this node instead of the context (e.g. an autoload event bus). Empty = the
## context node itself.
@export var target_path: NodePath
## Register the signal on the target if it does not exist yet, instead of warning. Lets
## a sequence announce a custom event without wiring it up in advance.
@export var create_if_missing: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["target_path", "create_if_missing"]))

func get_category_name() -> String: return "Flow"

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if signal_name.is_empty():
		_warn("JuiceeEmitSignalEffect: signal_name is empty")
		return
	# Advanced target_path lets a sequence announce on an event bus autoload instead
	# of on the node the effect happens to be attached to.
	var emitter: Node = context
	if not target_path.is_empty():
		emitter = context.get_node_or_null(target_path)
		if not emitter:
			_warn("JuiceeEmitSignalEffect: target_path '%s' not found" % str(target_path))
			return
	if not emitter.has_signal(signal_name):
		# create_if_missing registers the signal on the fly, so a custom game event can
		# be fired without wiring it up in advance.
		if create_if_missing:
			emitter.add_user_signal(String(signal_name))
		else:
			_warn("JuiceeEmitSignalEffect: '%s' has no signal '%s'" % [emitter.name, signal_name])
			return
	if argument != null:
		emitter.emit_signal(signal_name, argument)
	else:
		emitter.emit_signal(signal_name)
