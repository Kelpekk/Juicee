## Print a debug message when this step in a sequence is reached.
##
## Invaluable for understanding sequence timing without attaching a debugger.
## Equivalent to FEEL's MMF_DebugLog. Prints context node name + your message.
##
## Use for: tracing which branch a Random node took, confirming a condition
## evaluated correctly, timing analysis during game-feel iteration.
@tool
class_name JuiceeDebugLogEffect
extends JuiceeEffect

enum Level {
	PRINT,        ## print() - shows in Output, not in exported builds by default.
	PUSH_WARNING, ## push_warning() - yellow warning in Output + debugger.
	PUSH_ERROR,   ## push_error() - red error in Output + debugger.
}

## Message to print. Supports a basic {context} placeholder for the node name.
@export var message: String = "Juicee sequence reached this step."
## Log level.
@export var level: Level = Level.PRINT
## Also print the context node's name alongside the message.
@export var include_context_name: bool = true

func get_category_name() -> String: return "Flow"

func _apply(context: Node, _intensity_mult: float) -> void:
	var ctx_name: String = context.name if is_instance_valid(context) else "?"
	var full_msg := message.replace("{context}", ctx_name)
	if include_context_name:
		full_msg = "[%s] %s" % [ctx_name, full_msg]
	match level:
		Level.PRINT:        print(full_msg)
		Level.PUSH_WARNING: push_warning(full_msg)
		Level.PUSH_ERROR:   push_error(full_msg)
