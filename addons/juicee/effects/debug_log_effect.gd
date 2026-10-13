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
	PUSH_WARNING, ## _warn() - yellow warning in Output + debugger.
	PUSH_ERROR,   ## push_error() - red error in Output + debugger.
}

## Message to print. Supports a basic {context} placeholder for the node name.
@export var message: String = "Juicee sequence reached this step."
## Log level.
@export var level: Level = Level.PRINT
## Also print the context node's name alongside the message.
@export var include_context_name: bool = true

@export_group("Advanced")
## Prefix each line with the time since the game started, so you can read the spacing
## between steps in a sequence.
@export var include_timestamp: bool = false
## Only log when the project is running a debug build, so release builds stay quiet.
@export var debug_builds_only: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["include_timestamp", "debug_builds_only"]))

func get_category_name() -> String: return "Flow"

func _apply(context: Node, _intensity_mult: float) -> void:
	# Advanced debug_builds_only keeps release builds quiet without editing the graph.
	if debug_builds_only and not OS.is_debug_build():
		return
	var ctx_name: String = String(context.name) if is_instance_valid(context) else "?"
	var full_msg := message.replace("{context}", ctx_name)
	if include_context_name:
		full_msg = "[%s] %s" % [ctx_name, full_msg]
	# A timestamp makes the spacing between sequence steps readable in the log.
	if include_timestamp:
		full_msg = "%8.3fs %s" % [Time.get_ticks_msec() / 1000.0, full_msg]
	match level:
		Level.PRINT:        print(full_msg)
		Level.PUSH_WARNING: _warn(full_msg)
		Level.PUSH_ERROR:   push_error(full_msg)
