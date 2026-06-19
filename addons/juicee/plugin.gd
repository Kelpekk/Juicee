@tool
extends EditorPlugin

const AUTOLOAD_NAME := "Juicee"
const AUTOLOAD_PATH := "res://addons/juicee/core/juicee.gd"

const JuiceeGraphEditorScene = preload("res://addons/juicee/graph/juicee_graph_editor.gd")
const JuiceeInspectorPluginScript = preload("res://addons/juicee/inspector/juicee_inspector_plugin.gd")
const JuiceeDebuggerPluginScript = preload("res://addons/juicee/graph/juicee_debugger_plugin.gd")
const JuiceeHoverPanelScript     = preload("res://addons/juicee/graph/juicee_hover_panel.gd")

var _graph_editor:    Control
var _inspector_plugin: EditorInspectorPlugin
var _debugger_plugin:  EditorDebuggerPlugin
var _hover_panel:      Control

func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	# Use load() (runtime resolve) so we don't break parse if .import isn't built yet.
	var icon: Texture2D = null
	if ResourceLoader.exists("res://addons/juicee/JuiceeEffect.svg"):
		icon = load("res://addons/juicee/JuiceeEffect.svg")
	add_custom_type("JuiceePlayer", "Node", preload("core/juicee_player.gd"), icon)

	_graph_editor = JuiceeGraphEditorScene.new()
	_graph_editor.name = "JuiceeGraph"
	_graph_editor.undo_redo = get_undo_redo()
	_graph_editor.host_plugin = self  # lets Alt+G show/hide the bottom panel
	add_control_to_bottom_panel(_graph_editor, "JuiceeGraph")

	_inspector_plugin = JuiceeInspectorPluginScript.new()
	_inspector_plugin.undo_redo = get_undo_redo()
	_inspector_plugin.graph_editor = _graph_editor
	_inspector_plugin.host_plugin = self
	add_inspector_plugin(_inspector_plugin)

	_debugger_plugin = JuiceeDebuggerPluginScript.new()
	_debugger_plugin.graph_editor = _graph_editor
	add_debugger_plugin(_debugger_plugin)

	_hover_panel = JuiceeHoverPanelScript.new()
	EditorInterface.get_base_control().add_child(_hover_panel)
	_graph_editor.hover_panel = _hover_panel
	_inspector_plugin.hover_panel = _hover_panel

func _exit_tree() -> void:
	remove_custom_type("JuiceePlayer")
	remove_autoload_singleton(AUTOLOAD_NAME)

	if _inspector_plugin:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null

	if _hover_panel:
		_hover_panel.queue_free()
		_hover_panel = null

	if _debugger_plugin:
		remove_debugger_plugin(_debugger_plugin)
		_debugger_plugin = null

	if _graph_editor:
		remove_control_from_bottom_panel(_graph_editor)
		_graph_editor.queue_free()
