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

## Sessions the editor is currently debugging, kept so parameter changes can be pushed
## the other way - editor to game - for live tuning. The bridge above was one-way
## (game reporting what fired); this is the return channel.
var _sessions: Array[EditorDebuggerSession] = []

## Fires when a debugged game starts or stops, so the Inspector can show or hide its
## live-tuning affordances instead of polling for a running game every frame.
signal live_state_changed(is_live: bool)

func _setup_session(session_id: int) -> void:
	var session := get_session(session_id)
	if not session or _sessions.has(session):
		return
	_sessions.append(session)
	# Methods, not lambdas: a lambda holds this plugin, and the plugin holds the session, so the
	# two kept each other alive and the editor reported both as leaked when it closed.
	session.started.connect(_on_session_started)
	session.stopped.connect(_on_session_stopped)

func _on_session_started() -> void:
	live_state_changed.emit(true)

func _on_session_stopped() -> void:
	live_state_changed.emit(has_live_session())

## True while at least one debugged game is running and reachable.
func has_live_session() -> bool:
	for s in _sessions:
		if is_instance_valid(s) and s.is_active():
			return true
	return false

## Pushes a message to every running game. Silently does nothing when none is running,
## which is the common case while editing.
func send_to_game(message: String, data: Array) -> void:
	for s in _sessions:
		if is_instance_valid(s) and s.is_active():
			s.send_message(message, data)

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
