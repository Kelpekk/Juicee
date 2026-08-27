@tool
extends EditorPlugin

const AUTOLOAD_NAME := "Juicee"
const AUTOLOAD_PATH := "res://addons/juicee/core/juicee.gd"

const JuiceeGraphEditorScene = preload("res://addons/juicee/editor/juicee_graph_editor.gd")
const JuiceeInspectorPluginScript = preload("res://addons/juicee/editor/juicee_inspector_plugin.gd")
const JuiceeDebuggerPluginScript = preload("res://addons/juicee/editor/juicee_debugger_plugin.gd")
const JuiceeHoverPanelScript     = preload("res://addons/juicee/editor/juicee_hover_panel.gd")

var _graph_editor:    Control
var _inspector_plugin: EditorInspectorPlugin
var _debugger_plugin:  EditorDebuggerPlugin
var _hover_panel:      Control

func _enter_tree() -> void:
	_register_settings()
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	# Use load() (runtime resolve) so we don't break parse if .import isn't built yet.
	var icon: Texture2D = null
	if ResourceLoader.exists("res://addons/juicee/icons/juicee_player.svg"):
		icon = load("res://addons/juicee/icons/juicee_player.svg")
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

## Project Settings > Juicee. Left in place on disable, so a project that has been
## tuned doesn't silently reset by toggling the plugin off and on.
func _register_settings() -> void:
	_add_enum_setting(JuiceeGraphEditorScene.COLOR_MODE_SETTING, "Category,Dimension")
	_add_enum_setting(JuiceeGraphEditorScene.TAG_MODE_SETTING, "Generic,Per Category")
	# The editor-preview overlay: the border + label shown when you preview a
	# full-screen effect in the editor. Toggle its visibility and pick its colour.
	_add_bool_setting(JuiceeEffect.PREVIEW_HINT_SETTING, true)
	_add_color_setting(JuiceeEffect.PREVIEW_BORDER_COLOR_SETTING, JuiceeEffect.PREVIEW_BORDER_COLOR_DEFAULT)
	# The hover info panel (name, description, live mini-preview, output log). Hide the
	# whole panel, or just its description line.
	_add_bool_setting(JuiceeHoverPanel.HOVER_PANEL_SETTING, true)
	_add_bool_setting(JuiceeHoverPanel.HOVER_DESCRIPTION_SETTING, true)

func _add_enum_setting(setting: String, options: String, default: int = 0) -> void:
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, default)
	ProjectSettings.set_initial_value(setting, default)
	ProjectSettings.add_property_info({
		"name": setting,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": options,
	})
	ProjectSettings.set_as_basic(setting, true)

func _add_bool_setting(setting: String, default: bool) -> void:
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, default)
	ProjectSettings.set_initial_value(setting, default)
	ProjectSettings.add_property_info({
		"name": setting,
		"type": TYPE_BOOL,
	})
	ProjectSettings.set_as_basic(setting, true)

func _add_color_setting(setting: String, default: Color) -> void:
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, default)
	ProjectSettings.set_initial_value(setting, default)
	ProjectSettings.add_property_info({
		"name": setting,
		"type": TYPE_COLOR,
	})
	ProjectSettings.set_as_basic(setting, true)

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
