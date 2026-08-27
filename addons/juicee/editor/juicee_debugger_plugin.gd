## EditorDebuggerPlugin that bridges the running game to the JuiceeGraph panel.
##
## The game side sends:
##   EngineDebugger.send_message("juicee:block_fire",  [resource_path, node_id])
##   EngineDebugger.send_message("juicee:block_start", [resource_path, node_id])
##   EngineDebugger.send_message("juicee:block_end",   [resource_path, node_id])
##
## This plugin forwards those to JuiceeGraphEditor._debugger_on_block_fire(),
## _debugger_on_block_start(), and _debugger_on_block_end() so the graph panel
## can highlight the executing node in real-time.
##
## Registration: plugin.gd calls add_debugger_plugin() / remove_debugger_plugin().
@tool
class_name JuiceeDebuggerPlugin
extends EditorDebuggerPlugin

## Set by plugin.gd after both the graph editor and this plugin are created.
var graph_editor: Control = null

func _has_capture(prefix: String) -> bool:
	return prefix == "juicee"

func _capture(message: String, data: Array, _session_id: int) -> bool:
	if not is_instance_valid(graph_editor):
		return false

	match message:
		"juicee:block_fire":
			if data.size() >= 2:
				graph_editor.call("_debugger_on_block_fire", str(data[0]), str(data[1]))
			return true

		"juicee:block_start":
			if data.size() >= 2:
				graph_editor.call("_debugger_on_block_start", str(data[0]), str(data[1]))
			return true

		"juicee:block_end":
			if data.size() >= 2:
				graph_editor.call("_debugger_on_block_end", str(data[0]), str(data[1]))
			return true

	return false
