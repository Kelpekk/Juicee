@tool
extends EditorPlugin

const AUTOLOAD_NAME := "Juicee"
const AUTOLOAD_PATH := "res://addons/juicee/core/juicee.gd"

const JuiceeGraphEditorScene = preload("res://addons/juicee/editor/juicee_graph_editor.gd")
const JuiceeInspectorPluginScript = preload("res://addons/juicee/editor/juicee_inspector_plugin.gd")
const JuiceeDebuggerPluginScript = preload("res://addons/juicee/editor/juicee_debugger_plugin.gd")
const JuiceeHoverPanelScript     = preload("res://addons/juicee/editor/juicee_hover_panel.gd")
const JuiceeContextMenuPluginPath := "res://addons/juicee/editor/juicee_context_menu_plugin.gd"

var _graph_editor:    Control
var _inspector_plugin: EditorInspectorPlugin
var _debugger_plugin:  EditorDebuggerPlugin
var _hover_panel:      Control
# Untyped on purpose: EditorContextMenuPlugin postdates this addon's stated Godot 4.3
# floor, and typing this var to that class name would fail to PARSE this whole script
# on an editor old enough not to have it - worse than the feature just being absent.
var _context_menu_plugin: Object

func _enter_tree() -> void:
	_register_settings()
	# Only when it is missing. Adding it again on every editor start, over the one already there,
	# left the editor's autoload list with an entry it no longer held, and every scene played
	# from the editor then logged "Condition p_I->data != this" from list.h.
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	# Loaded at run time and only once imported, so a first open before the import neither breaks
	# the parse nor prints errors; the node then goes without its icon until the next start.
	var icon := JuiceeEditorUtil.addon_icon("res://addons/juicee/icons/juicee_player.svg")
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
	# Both parameter editors mirror changes into a running game through this bridge.
	_inspector_plugin.debugger_plugin = _debugger_plugin
	_graph_editor.debugger_plugin = _debugger_plugin

	_hover_panel = JuiceeHoverPanelScript.new()
	EditorInterface.get_base_control().add_child(_hover_panel)
	_graph_editor.hover_panel = _hover_panel
	_inspector_plugin.hover_panel = _hover_panel

	# EditorContextMenuPlugin postdates this addon's stated Godot 4.3 floor. Every
	# reference to it - the type, add_context_menu_plugin(), even the slot constant -
	# goes through ClassDB / call() / a plain int rather than being written directly in
	# this file's source, because GDScript resolves class names at PARSE time even
	# inside a branch that never runs: writing the name here would fail to parse this
	# whole script on an editor old enough not to have it, taking the entire addon down
	# with it instead of just leaving this one menu item absent.
	if ClassDB.class_exists("EditorContextMenuPlugin") and has_method("add_context_menu_plugin"):
		var script: Script = load("res://addons/juicee/editor/juicee_context_menu_plugin.gd")
		_context_menu_plugin = script.new()
		call("add_context_menu_plugin", 0, _context_menu_plugin)  # 0 = CONTEXT_SLOT_SCENE_TREE

## The editor asks this before closing, so an unsaved graph gets the same prompt an unsaved
## scene does instead of going quietly. Only for the whole editor, not per scene.
func _get_unsaved_status(for_scene: String) -> String:
	if not for_scene.is_empty() or not is_instance_valid(_graph_editor):
		return ""
	return String(_graph_editor.call("unsaved_status"))

## Ctrl+S and the editor's own save-all save a graph that already has a file.
func _save_external_data() -> void:
	if is_instance_valid(_graph_editor):
		_graph_editor.call("save_if_saved_before")

## Project Settings > Juicee. Left in place on disable, so a project that has been
## tuned doesn't silently reset by toggling the plugin off and on.
func _register_settings() -> void:
	_add_enum_setting(JuiceeEffectCatalog.COLOR_MODE_SETTING, "Category,Dimension")
	_add_enum_setting(JuiceeGraphEditorScene.TAG_MODE_SETTING, "Generic,Per Category")
	# The editor-preview overlay: the border + label shown when you preview a
	# full-screen effect in the editor. Toggle its visibility and pick its colour.
	_add_bool_setting(JuiceeEffect.PREVIEW_HINT_SETTING, true)
	_add_color_setting(JuiceeEffect.PREVIEW_BORDER_COLOR_SETTING, JuiceeEffect.PREVIEW_BORDER_COLOR_DEFAULT)
	# The hover info panel (name, description, live mini-preview, output log). Hide the
	# whole panel, or just its description line.
	_add_bool_setting(JuiceeHoverPanel.HOVER_PANEL_SETTING, true)
	_add_bool_setting(JuiceeHoverPanel.HOVER_DESCRIPTION_SETTING, true)
	# One multiplier for every pixel-distance the effects move or spawn over, so the
	# whole library scales from a 32px pixel-art game up to 1080p in one place.
	_add_float_setting(JuiceeEffect.PIXEL_SCALE_SETTING, 1.0, "0.1,8.0,0.05,or_greater")
	# Off by default: effects show a small curated parameter set. On reveals the advanced
	# knobs (extra modes, presets, fine controls) on the effects that carry them.
	_add_bool_setting(JuiceeEffect.ADVANCED_SETTING, false)
	# Folders of your own effects. Empty by default; the addon's own folder is always
	# scanned. Custom effects kept inside the addon are at risk on update: the Update button
	# writes over that folder, and a reinstall deletes it.
	_add_dirs_setting(JuiceeEffect.EFFECT_FOLDERS_SETTING)

## A list of directories, shown as folder pickers rather than as free text.
func _add_dirs_setting(setting: String) -> void:
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, PackedStringArray())
	ProjectSettings.set_initial_value(setting, PackedStringArray())
	ProjectSettings.add_property_info({
		"name": setting,
		"type": TYPE_PACKED_STRING_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d/%d:" % [TYPE_STRING, PROPERTY_HINT_DIR],
	})
	ProjectSettings.set_as_basic(setting, true)

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

func _add_float_setting(setting: String, default: float, range_hint: String = "") -> void:
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, default)
	ProjectSettings.set_initial_value(setting, default)
	ProjectSettings.add_property_info({
		"name": setting,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE if not range_hint.is_empty() else PROPERTY_HINT_NONE,
		"hint_string": range_hint,
	})
	ProjectSettings.set_as_basic(setting, true)

## The autoload goes when the plugin is switched off, not every time the editor closes.
func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)

func _exit_tree() -> void:
	remove_custom_type("JuiceePlayer")

	if _context_menu_plugin and has_method("remove_context_menu_plugin"):
		call("remove_context_menu_plugin", _context_menu_plugin)
		_context_menu_plugin = null

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
