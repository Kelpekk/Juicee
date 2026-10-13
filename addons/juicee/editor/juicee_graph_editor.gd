@tool
class_name JuiceeGraphEditor
extends Control


const EFFECTS_DIR := "res://addons/juicee/effects/"
const BASE_EFFECT_FILE := "juicee_effect.gd"


# Loaded when a tag is first drawn, not preloaded. Godot 4.3 parses this script before a
# fresh project has imported the icons, and a preload of a file that is not imported yet
# fails the whole script. plugin.gd loads its own icon at runtime for the same reason.
const ICON_2D_PATH := "res://addons/juicee/icons/2dtag.svg"
const ICON_3D_PATH := "res://addons/juicee/icons/3dtag.svg"

## Project Settings > Juicee > Graph > Effect Tag Icons. 0 = Generic, 1 = Per Category.
const TAG_MODE_SETTING := "juicee/graph/effect_tag_icons"

enum TagMode { GENERIC, PER_CATEGORY }

static func tag_mode() -> int:
	return int(ProjectSettings.get_setting(TAG_MODE_SETTING, TagMode.GENERIC))

## The little 2D / 3D badge on an effect's titlebar.
##
## Generic mode shows the same 2D / 3D badge everywhere. Per Category shows the node
## the effect actually wants, a Camera2D rather than "some 2D node", by loading
## `icons/{category}{dim}tag.svg`. A category with no icon of its own falls back to
## the generic badge, so adding one is a matter of dropping in a file.
static var _tag_cache: Dictionary = {}

static func dimension_tag(dim: String, category: String = "") -> Texture2D:
	var per_cat := tag_mode() == TagMode.PER_CATEGORY
	var key := "%s|%s|%s" % [category.to_lower(), dim, per_cat]
	if _tag_cache.has(key):
		return _tag_cache[key]

	var tex: Texture2D = null
	if per_cat and not category.is_empty():
		tex = JuiceeEditorUtil.addon_icon("res://addons/juicee/icons/%s%stag.svg" % [category.to_lower(), dim])
	if not tex:
		tex = JuiceeEditorUtil.addon_icon(ICON_2D_PATH if dim == "2d" else (ICON_3D_PATH if dim == "3d" else ""))

	# Not remembered when missing: before the first import there is no icon yet, and there will be.
	if tex:
		_tag_cache[key] = tex
	return tex

## The tag as the small icon both pickers and the block titles put after a name, or null when the
## effect has none. px is its size at 100% editor scale.
static func dimension_tag_icon(dim: String, category: String, px: float) -> TextureRect:
	var tex := dimension_tag(dim, category)
	if not tex:
		return null
	var icon_rect := TextureRect.new()
	icon_rect.texture = tex
	icon_rect.custom_minimum_size = Vector2(px, px) * JuiceeEditorUtil.EDSCALE
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.modulate = Color(1, 1, 1, 0.9)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon_rect

## The parameter editors on the right. Building them from an effect's @export list
## is a job of its own, so it lives in its own file.
## The GitHub update check and its dialogs. Added to the tree in _build_ui so the
## dialogs have somewhere to pop.
var _update_prompt := JuiceeUpdatePrompt.new()

var _props := JuiceePropertyPanel.new()

## Set by JuiceePlugin on startup so graph operations register with Ctrl+Z / Ctrl+Y.
var undo_redo: EditorUndoRedoManager = null:
	set(v):
		undo_redo = v
		_props.undo_redo = v

var _resource: JuiceeGraphResource = null
var _resource_path: String = ""
var _dirty: bool = false

## Copy/paste clipboard: deep-copied node data + the connections internal to the
## copied set. `_clipboard_paste_count` cascades each consecutive paste so they
## don't stack exactly on top of each other. `_paste_counter` guarantees unique ids.
var _clipboard_nodes: Array[JuiceeGraphNodeData] = []
var _clipboard_connections: PackedStringArray = []
var _clipboard_paste_count: int = 0
var _paste_counter: int = 0

var _graph: GraphEdit
var _props_title: Label
var _props_content: VBoxContainer
var _file_label: Label
var _popup: PopupPanel
var _popup_search: LineEdit
var _popup_list: VBoxContainer
var _popup_scroll: ScrollContainer
## Currently-visible effect buttons (display order) and the highlighted index,
## for keyboard navigation in the add-node popup.
var _popup_nav_buttons: Array[Button] = []
var _popup_nav_index: int = -1
## Original category-grouped child order, restored when the search box is cleared.
var _popup_build_order: Array[Node] = []
## Collapsible categories in the add-node popup: category -> expanded(bool), and
## category -> its clickable header Button (for the ▸/▾ arrow). Effect categories
## start collapsed so you expand just the one you want instead of scrolling all.
var _popup_category_expanded: Dictionary = {}
var _popup_headers: Dictionary = {}
var _popup_current_category: String = ""

## Transient "toast" banner for rejected actions (invalid connections, etc.).
var _toast: PanelContainer = null
var _toast_label: Label = null
var _toast_gen: int = 0

## Right-click context menu for a graph block.
var _node_menu: PopupMenu = null
var _node_menu_block: JuiceeGraphBlock = null
var _popup_pos: Vector2

# When the popup was opened by dragging a wire to empty space:
# remember the source so the new node gets auto-connected.
var _pending_connect_from: StringName = ""
var _pending_connect_from_port: int = -1

# Hand/pan tool state
var _pan_btn: Button
var _minimap_btn: Button
## The toolbar row, and the buttons in it that can fall back to their icon alone.
var _toolbar_bar: HBoxContainer
var _compact_btns: Array[Button] = []
var _toolbar_full_width := 0.0
## How many entries each category of the add-node popup holds, for its header.
var _popup_counts: Dictionary = {}
var _advanced_btn: Button
var _pan_mode: bool = false
var _is_panning: bool = false
var _file_dialog: EditorFileDialog
## What the shared file dialog was opened for. One handler reads it, so a cancelled dialog
## leaves no handler connected for the next one.
var _file_dialog_purpose := ""
## Test run state. A run checks its generation at every step, so Stop ends it wherever it is.
var _test_btn: Button
var _test_gen := 0
var _test_running := false
var _selected_block: JuiceeGraphBlock = null
var _hovered_block:  JuiceeGraphBlock = null

## Shared hover info-panel. Set by plugin.gd after both objects are created.
var hover_panel: Control = null

## Set by plugin.gd. The return channel to a running game, so a slider dragged in the
## graph retunes the live effect rather than only the saved resource.
var debugger_plugin: EditorDebuggerPlugin = null:
	set(v):
		debugger_plugin = v
		if v and not v.is_connected("live_state_changed", _on_live_state_changed):
			v.connect("live_state_changed", _on_live_state_changed)
		_refresh_live_badge()

## Says a game is running and the values edited here are reaching it. The Inspector has
## had one since live tuning existed; the graph pushed the same values with nothing to
## say it was, so the only way to know was to go and look at the other panel.
var _live_label: Label = null

# id_in_popup -> effect Script (or null for builtins)
var _popup_items: Dictionary = {}
var _effect_scripts: Array[Script] = []

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# The bottom dock sizes a panel by its minimum size and a plain Control reports none, so a
	# fresh layout on Godot 4.6+ opened this at zero height with the toolbar over the tab bar.
	custom_minimum_size.y = 260 * JuiceeEditorUtil.EDSCALE
	clip_contents = true
	JuiceeEditorUtil.english_only(self)
	_scan_effects()
	_build_ui()
	_new_graph()
	resized.connect(_fit_toolbar)
	# A field the panel cannot draw is edited in the Inspector, so an edit there to one of this
	# graph's effects is an edit to the graph.
	EditorInterface.get_inspector().property_edited.connect(_on_inspector_property_edited)

func _on_inspector_property_edited(_property: String) -> void:
	var edited := EditorInterface.get_inspector().get_edited_object()
	if not (edited is JuiceeEffect) or not _resource:
		return
	for d in _resource.nodes:
		if d.effect == edited:
			_mark_dirty()
			var block := _graph.get_node_or_null(NodePath(d.id)) as JuiceeGraphBlock
			if block:
				block.refresh_subtitle()
			if _selected_block and _selected_block.node_data == d:
				_show_props.call_deferred(_selected_block)
			return

func _scan_effects() -> void:
	_effect_scripts = JuiceeEditorUtil.effect_scripts(EFFECTS_DIR, BASE_EFFECT_FILE)

func _build_ui() -> void:
	# No background ColorRect - the host EditorPlugin bottom panel paints its own
	# (matches Animation / Shader Editor docks).
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", int(0 * JuiceeEditorUtil.EDSCALE))
	add_child(vbox)

	vbox.add_child(_build_toolbar())

	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.split_offset = -280
	vbox.add_child(hsplit)

	_graph = GraphEdit.new()
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.right_disconnects = true
	# Off until asked for, as the toolbar button and its tooltip already said, and at the size
	# meant for it: on by default at Godot's 240x160 it covered half the canvas of a fresh panel.
	_graph.minimap_enabled = false
	_graph.minimap_size = Vector2(200, 140) * JuiceeEditorUtil.EDSCALE
	_graph.minimap_opacity = 0.7
	_graph.show_grid = true
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	_graph.popup_request.connect(_on_popup_request)
	_graph.connection_to_empty.connect(_on_connection_to_empty)
	_graph.gui_input.connect(_on_graph_gui_input)
	_graph.node_selected.connect(_on_node_selected)
	_graph.node_deselected.connect(_on_node_deselected)
	_graph.delete_nodes_request.connect(_on_delete_nodes_request)
	# Copy / paste / duplicate. GraphEdit's own signals only fire when it holds
	# focus (rare in a bottom panel), so the real handling is in _input below -
	# these connections are just a harmless fallback for the focused case.
	_graph.copy_nodes_request.connect(_on_copy_nodes_request)
	_graph.paste_nodes_request.connect(_on_paste_nodes_request)
	_graph.duplicate_nodes_request.connect(_on_duplicate_nodes_request)
	set_process_input(true)  # ensure _input fires for the Ctrl+C/V/D shortcuts
	# Dismiss the hover panel the instant a block starts moving - during a drag the
	# block stays under the cursor so `unhovered` never fires, leaving the panel
	# stranded at the block's old spot.
	_graph.begin_node_move.connect(_on_graph_node_move_begin)
	_style_graph()
	hsplit.add_child(_graph)

	hsplit.add_child(_build_props_panel())

	_popup = PopupPanel.new()
	_popup.size = Vector2i(int(260 * JuiceeEditorUtil.EDSCALE), int(360 * JuiceeEditorUtil.EDSCALE))
	# Popup uses the editor's native PopupPanel stylebox.

	var popup_vbox := VBoxContainer.new()
	popup_vbox.add_theme_constant_override("separation", int(6 * JuiceeEditorUtil.EDSCALE))
	_popup.add_child(popup_vbox)

	_popup_search = LineEdit.new()
	_popup_search.placeholder_text = "Search effects..."
	_popup_search.clear_button_enabled = true
	_popup_search.text_changed.connect(_on_popup_search_changed)
	_popup_search.gui_input.connect(_on_popup_search_gui_input)
	popup_vbox.add_child(_popup_search)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(240, 300) * JuiceeEditorUtil.EDSCALE
	popup_vbox.add_child(scroll)
	_popup_scroll = scroll

	_popup_list = VBoxContainer.new()
	_popup_list.add_theme_constant_override("separation", int(3 * JuiceeEditorUtil.EDSCALE))
	_popup_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_popup_list)

	# The same keys work here as in the Inspector's picker, so it says so the same way.
	var key_hint := Label.new()
	key_hint.text = JuiceeEditorUtil.PICKER_KEY_HINT
	key_hint.modulate = Color(1, 1, 1, 0.5)
	popup_vbox.add_child(key_hint)

	_build_popup()
	_popup.popup_hide.connect(_on_popup_hide)
	add_child(_popup)

	_file_dialog = EditorFileDialog.new()
	# Godot's own dialog, so it stays in the editor's language.
	_file_dialog.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_file_dialog.add_filter("*.tres", "Juicee Graph / Sequence Resource")
	_file_dialog.file_selected.connect(_on_file_dialog_selected)
	add_child(_file_dialog)

func _style_graph() -> void:
	# Slim, antialiased connection lines (these are GraphEdit PROPERTIES in Godot 4;
	# default thickness 4.0 reads chunky). The in-progress drag preview is rendered
	# by the engine and isn't separately controllable from here.
	_graph.connection_lines_thickness = 3.0 * JuiceeEditorUtil.EDSCALE
	_graph.connection_lines_antialiased = true

func _build_popup() -> void:
	_popup_items.clear()
	_popup_headers.clear()
	_popup_counts.clear()
	for c in _popup_list.get_children():
		c.queue_free()

	# Flow control built-ins (graph topology, not effects).
	# Colours come from JuiceeGraphBlock.BUILTIN_META so the popup swatch and the
	# block you drop on the canvas can't drift apart.
	_add_popup_section_label("Flow control")
	var flow := JuiceeGraphBlock.FLOW_COLOR
	_add_popup_item("Trigger",   JuiceeGraphBlock.FLOW_ENTRY_COLOR, "res://addons/juicee/icons/trigger.svg", "builtin:trigger",   "The entry point. Every graph needs exactly one. Execution starts here when play() is called.")
	_add_popup_item("Split",     flow, "res://addons/juicee/icons/split.svg",   "builtin:split",     "Fan-out. All connected outputs fire at the same time and run independently.")
	_add_popup_item("Loop",      flow, "res://addons/juicee/icons/loop.svg",    "builtin:loop",      "Repeat the next chain N times in a row (sequential).")
	_add_popup_item("Random",    flow, "res://addons/juicee/icons/random.svg",  "builtin:random",    "Pick exactly one connected output at random (weighted) and run only that branch.")
	_add_popup_item("Condition", flow, "",                                      "builtin:condition", "Evaluates a GDScript expression against 'context'.\nPort 0 = True  ·  Port 1 = False.\nExamples: context.health < 20  |  context.visible")
	_add_popup_item("Comment",   flow, "",                                      "builtin:comment",   "Visual annotation, no ports, never executes.\nDocument sections or leave notes for teammates.")

	# Group effect scripts by category, then alphabetically.
	var entries: Array = []
	for script in _effect_scripts:
		var inst = script.new()
		if not inst or not (inst is JuiceeEffect):
			continue
		var eff := inst as JuiceeEffect
		var basename: String = script.resource_path.get_file().get_basename()
		# Prefer effect's own override; fall back to central map; finally "Misc".
		var category: String = eff.get_category_name()
		if category.is_empty():
			category = JuiceeEffectCatalog.EFFECT_CATEGORIES.get(basename, "Misc")
		var description: String = eff.get_description()
		if description.is_empty():
			description = JuiceeEffectCatalog.EFFECT_DESCRIPTIONS.get(basename, "")
		entries.append({
			"script": script,
			"name": eff.get_display_name(),
			"color": eff.get_category_color(),
			"icon": eff.get_icon_path(),
			"category": category,
			"description": description,
			"dims": JuiceeEffectCatalog.restrictive_dims(basename),
		})

	# Sort by (category index in JuiceeEffectCatalog.CATEGORY_ORDER, then name).
	entries.sort_custom(func(a, b) -> bool:
		var ai: int = JuiceeEffectCatalog.CATEGORY_ORDER.find(a["category"])
		var bi: int = JuiceeEffectCatalog.CATEGORY_ORDER.find(b["category"])
		if ai < 0: ai = 999
		if bi < 0: bi = 999
		if ai != bi:
			return ai < bi
		return a["name"] < b["name"]
	)

	var current_cat: String = ""
	for entry in entries:
		if entry["category"] != current_cat:
			current_cat = entry["category"]
			_add_popup_section_label(current_cat)
		_add_popup_item(entry["name"], entry["color"], entry["icon"], entry["script"], entry["description"], entry["dims"], entry["category"])

	# Every header was made before the rows under it were counted, so they say so now.
	for cat in _popup_headers:
		_update_header_text(_popup_headers[cat] as Button, cat)
	# Remember the grouped order so clearing the search box can restore it.
	_popup_build_order = _popup_list.get_children()

## A clickable category header that folds/unfolds its effect rows. "Flow control"
## (the graph built-ins) starts expanded; effect categories start collapsed.
func _add_popup_section_label(text: String) -> void:
	var category := text
	_popup_current_category = category
	if not _popup_category_expanded.has(category):
		_popup_category_expanded[category] = (category == "Flow control")

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 30) * JuiceeEditorUtil.EDSCALE
	btn.modulate = Color(1, 1, 1, 0.85)
	# Bold via the editor font so category headers read as headers through weight,
	# consistent with the props-panel section titles.
	var hf := JuiceeEditorUtil.editor_font("bold")
	if hf:
		btn.add_theme_font_override("font", hf)
	btn.set_meta("is_header", true)
	btn.set_meta("category", category)
	btn.tooltip_text = JuiceeEditorUtil.PICKER_HEADER_TIP
	btn.pressed.connect(func() -> void: _toggle_popup_category(category))
	_popup_list.add_child(btn)
	_popup_headers[category] = btn
	_update_header_text(btn, category)

func _update_header_text(btn: Button, category: String) -> void:
	btn.text = JuiceeEditorUtil.picker_header_text(category,
			bool(_popup_category_expanded.get(category, false)), int(_popup_counts.get(category, -1)))

func _toggle_popup_category(category: String) -> void:
	var expanded: bool = not _popup_category_expanded.get(category, false)
	_popup_category_expanded[category] = expanded
	if _popup_headers.has(category):
		_update_header_text(_popup_headers[category] as Button, category)
	# Only re-show rows when not mid-search (search drives its own visibility).
	if _popup_search and not _popup_search.text.strip_edges().is_empty():
		return
	var keep_scroll: int = _popup_scroll.scroll_vertical if is_instance_valid(_popup_scroll) else 0
	for c in _popup_list.get_children():
		if c is HBoxContainer and c.has_meta("category") and str(c.get_meta("category")) == category:
			c.visible = expanded
	_rebuild_popup_nav(false, false)
	# The list relays out this frame; restore the scroll so a fold/unfold keeps the
	# view where it was instead of snapping to the top or bottom.
	if is_instance_valid(_popup_scroll):
		_popup_scroll.set_deferred("scroll_vertical", keep_scroll)

func _add_popup_item(label: String, color: Color, _icon_path: String, entry: Variant, tooltip: String = "", dims: Array = [], category: String = "") -> void:
	_popup_counts[_popup_current_category] = int(_popup_counts.get(_popup_current_category, 0)) + 1
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(6 * JuiceeEditorUtil.EDSCALE))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_list.add_child(row)
	# Belongs to the current category section; hidden unless that section is expanded.
	var row_cat := category if not category.is_empty() else _popup_current_category
	row.set_meta("category", row_cat)
	row.visible = _popup_category_expanded.get(row_cat, false)
	# Trigger / Comment have no input port - flagged so they can be hidden when the
	# popup is opened by dragging a wire (you can't connect a wire into them).
	if entry is String and (str(entry) == "builtin:trigger" or str(entry) == "builtin:comment"):
		row.set_meta("no_input", true)

	# A 3px sliver made every colour look the same. Wide enough to actually read.
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(6, 18) * JuiceeEditorUtil.EDSCALE
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)

	var btn := Button.new()
	btn.text = ""  # text is drawn by the RichTextLabel overlay so matches can be bolded
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 26) * JuiceeEditorUtil.EDSCALE
	btn.set_meta("entry", entry)
	btn.set_meta("label", label.to_lower())
	btn.set_meta("display", label)
	# Combined text searched when the user types in the popup - includes label,
	# description, and category so "screen", "camera", "impact" etc. all work.
	btn.set_meta("search_text", (label + " " + tooltip + " " + category).to_lower())
	if not tooltip.is_empty():
		btn.tooltip_text = "%s\n\n%s" % [label, tooltip]
	btn.pressed.connect(func() -> void: _on_popup_choice(entry))
	# Hovering a row moves the highlight onto it (mouse and keyboard share one cursor).
	btn.mouse_entered.connect(func() -> void: _hover_popup_item(btn))
	row.add_child(btn)

	# Rich-text overlay: shows the label and bolds the matched characters. Ignores
	# the mouse so clicks pass through to the Button behind it.
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.scroll_active = false
	rtl.fit_content = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The editor theme gives RichTextLabel a bordered/filled "normal" stylebox
	# (it's used for doc panels) - clear it so list items don't render in boxes.
	rtl.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	rtl.set_anchors_preset(Control.PRESET_FULL_RECT)
	rtl.offset_left = 4 * JuiceeEditorUtil.EDSCALE
	rtl.offset_top = 5 * JuiceeEditorUtil.EDSCALE  # vertically centers the single line in the 26px row
	rtl.text = label
	btn.add_child(rtl)
	btn.set_meta("rtl", rtl)

	# 2D / 3D tag icons - right-aligned after the label.
	for dim in dims:
		var icon_rect := dimension_tag_icon(dim, category, 18)
		if icon_rect:
			row.add_child(icon_rect)

func _on_popup_search_changed(text: String) -> void:
	var q := text.strip_edges().to_lower()

	# Empty query -> restore the category-grouped layout, fold rows back to their
	# category's expanded state, show headers, and clear any match-bolding.
	if q.is_empty():
		_restore_popup_order()
		for c in _popup_list.get_children():
			if c is HBoxContainer:
				var cat := str(c.get_meta("category", ""))
				c.visible = _popup_category_expanded.get(cat, false)
				var btn := _row_button(c)
				if btn and btn.has_meta("rtl"):
					(btn.get_meta("rtl") as RichTextLabel).text = str(btn.get_meta("display", ""))
			else:
				c.visible = true  # category header
		_rebuild_popup_nav(false, false)
		return

	# Score every effect row (>0 = match), then show the matches as a flat,
	# best-first list. Category headers are hidden while searching.
	var scored: Array = []  # [score, row]
	for c in _popup_list.get_children():
		if c is HBoxContainer:
			var btn := _row_button(c)
			var label: String = str(btn.get_meta("label", "")) if btn else ""
			var search_text: String = str(btn.get_meta("search_text", label)) if btn else ""
			var score := _match_score(q, label, search_text)
			c.visible = score > 0
			if score > 0:
				scored.append([score, c])
				if btn and btn.has_meta("rtl"):
					(btn.get_meta("rtl") as RichTextLabel).text = _highlight_bbcode(str(btn.get_meta("display", "")), q)
		else:
			c.visible = false  # category header - hidden during a ranked search

	scored.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	for i in scored.size():
		_popup_list.move_child(scored[i][1], i)

	_rebuild_popup_nav()

func _row_button(row: Node) -> Button:
	for sub in row.get_children():
		if sub is Button:
			return sub
	return null

## Restores the popup children to their original category-grouped build order.
func _restore_popup_order() -> void:
	for i in _popup_build_order.size():
		var node: Node = _popup_build_order[i]
		if is_instance_valid(node):
			_popup_list.move_child(node, i)

## Relevance score for `q` against an effect. 0 = no match. Ranks
## prefix > name-substring > description/category-substring > tight fuzzy.
## Loose, spread-out subsequence matches are rejected, so "man" no longer pulls in
## "ani-m-a-tio-n" or "film gr-a-i-n" - only genuinely close matches survive.
static func _match_score(q: String, label: String, search_text: String) -> int:
	if label.begins_with(q):
		return 10000 - label.length()
	var idx := label.find(q)
	if idx >= 0:
		return 8000 - idx * 10 - label.length()
	# Description / category: only at a WORD START, so "man" matches "manual" but
	# not "perfor(man)ce". Mid-word matches in prose are almost always noise.
	var sidx := _word_start_find(search_text, q)
	if sidx >= 0:
		return 4000 - sidx
	var span := _subsequence_span(q, label)
	# Accept fuzzy only when the matched letters sit close together (tight typo /
	# abbreviation), not scattered across the whole name.
	if span > 0 and span <= q.length() + 2:
		return 2000 - span * 20
	return 0

## Index of the first occurrence of `q` in `text` that starts a word (preceded by
## a non-letter/digit), or -1. Keeps prose matches meaningful ("manual", not
## "permanent") without rejecting mid-name matches like "lash" -> "Flash".
static func _word_start_find(text: String, q: String) -> int:
	var from := 0
	while from <= text.length() - q.length():
		var idx := text.find(q, from)
		if idx < 0:
			return -1
		if idx == 0 or not _is_word_char(text.unicode_at(idx - 1)):
			return idx
		from = idx + 1
	return -1

static func _is_word_char(c: int) -> bool:
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57)

## Span of a greedy subsequence match of `q` in `text` (last index − first + 1),
## or -1 if `q` is not a subsequence. A small span means the letters are adjacent.
static func _subsequence_span(q: String, text: String) -> int:
	if q.is_empty():
		return 0
	var first := -1
	var ti := 0
	var tl := text.length()
	for qi in q.length():
		var ch := q[qi]
		while ti < tl and text[ti] != ch:
			ti += 1
		if ti >= tl:
			return -1
		if first < 0:
			first = ti
		ti += 1
	return ti - first

## Returns `display` as BBCode with the characters matched by `q` bolded white.
## Bolds a contiguous substring if present, else the tight-fuzzy character
## positions; a description-only match leaves the name unbolded.
static func _highlight_bbcode(display: String, q: String) -> String:
	var lower := display.to_lower()
	var bold := {}
	var idx := lower.find(q)
	if idx >= 0:
		for i in range(idx, idx + q.length()):
			bold[i] = true
	else:
		# Tight fuzzy: bold each matched letter, but only when they sit close
		# together (same gate as scoring) so we don't speckle the whole name.
		var positions: Array[int] = []
		var ti := 0
		var matched := true
		for qi in q.length():
			var ch := q[qi]
			while ti < lower.length() and lower[ti] != ch:
				ti += 1
			if ti >= lower.length():
				matched = false
				break
			positions.append(ti)
			ti += 1
		if matched and not positions.is_empty() and (positions[-1] - positions[0] + 1) <= q.length() + 2:
			for p in positions:
				bold[p] = true

	var out := ""
	var i := 0
	var n := display.length()
	while i < n:
		var is_b: bool = bold.has(i)
		var run := ""
		while i < n and bold.has(i) == is_b:
			run += "[lb]" if display[i] == "[" else display[i]
			i += 1
		out += ("[b][color=#ffffff]" + run + "[/color][/b]") if is_b else run
	return out

## Rebuilds the list of visible effect buttons and highlights the first, so the
## user can type then press Enter to drop the top match.
func _rebuild_popup_nav(scroll: bool = true, highlight_first: bool = true) -> void:
	_popup_nav_buttons.clear()
	for c in _popup_list.get_children():
		if c is HBoxContainer and c.visible:
			var btn := _row_button(c)
			if btn:
				_popup_nav_buttons.append(btn)
	# Browsing: no row is pre-highlighted - the highlight follows the mouse (or the
	# arrow keys). Only a search pre-selects the top match so Enter can drop it.
	_popup_nav_index = 0 if (highlight_first and not _popup_nav_buttons.is_empty()) else -1
	_apply_popup_highlight(scroll)

func _apply_popup_highlight(scroll: bool = false) -> void:
	for i in _popup_nav_buttons.size():
		var btn := _popup_nav_buttons[i]
		if i == _popup_nav_index:
			btn.flat = false
			btn.add_theme_stylebox_override("normal", _popup_highlight_box())
			btn.add_theme_stylebox_override("hover", _popup_highlight_box())
			# Only chase the highlight into view when actually navigating (arrows /
			# search) - never on a fold/unfold, or the list jumps to the top.
			if scroll and is_instance_valid(_popup_scroll):
				_popup_scroll.ensure_control_visible(btn)
		else:
			btn.flat = true
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("hover")

var _popup_hl_box: StyleBoxFlat = null

func _popup_highlight_box() -> StyleBoxFlat:
	if _popup_hl_box == null:
		var accent := Color(0.26, 0.59, 0.98)
		if has_theme_color("accent_color", "Editor"):
			accent = get_theme_color("accent_color", "Editor")
		_popup_hl_box = StyleBoxFlat.new()
		_popup_hl_box.bg_color = Color(accent.r, accent.g, accent.b, 0.28)
		_popup_hl_box.set_corner_radius_all(int(3 * JuiceeEditorUtil.EDSCALE))
		_popup_hl_box.content_margin_left = 4 * JuiceeEditorUtil.EDSCALE
		_popup_hl_box.content_margin_right = 4 * JuiceeEditorUtil.EDSCALE
		_popup_hl_box.content_margin_top = 2 * JuiceeEditorUtil.EDSCALE
		_popup_hl_box.content_margin_bottom = 2 * JuiceeEditorUtil.EDSCALE
	return _popup_hl_box

## Mouse hover takes over the highlight, so it tracks the cursor (no scroll jump).
func _hover_popup_item(btn: Button) -> void:
	var idx := _popup_nav_buttons.find(btn)
	if idx >= 0 and idx != _popup_nav_index:
		_popup_nav_index = idx
		_apply_popup_highlight(false)

func _move_popup_nav(delta: int) -> void:
	if _popup_nav_buttons.is_empty():
		return
	# From "no selection" the first key picks the top (↓) or bottom (↑) row.
	if _popup_nav_index < 0:
		_popup_nav_index = 0 if delta > 0 else _popup_nav_buttons.size() - 1
	else:
		_popup_nav_index = wrapi(_popup_nav_index + delta, 0, _popup_nav_buttons.size())
	_apply_popup_highlight(true)

func _activate_popup_nav() -> void:
	if _popup_nav_index < 0 or _popup_nav_index >= _popup_nav_buttons.size():
		return
	_on_popup_choice(_popup_nav_buttons[_popup_nav_index].get_meta("entry"))

## Up/Down move the highlight, Enter drops the highlighted effect. The LineEdit
## ignores these keys anyway, so we consume them for navigation.
func _on_popup_search_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_DOWN:
			_move_popup_nav(1)
			_popup_search.accept_event()
		KEY_UP:
			_move_popup_nav(-1)
			_popup_search.accept_event()
		KEY_ENTER, KEY_KP_ENTER:
			_activate_popup_nav()
			_popup_search.accept_event()

func _on_popup_choice(entry: Variant) -> void:
	# Snapshot drag-connect state BEFORE hiding - _on_popup_hide will clear it.
	var pending_from := _pending_connect_from
	var pending_port := _pending_connect_from_port
	_popup.hide()

	var pos: Vector2 = (_popup_pos if _popup_pos != Vector2.ZERO \
			else (_graph.scroll_offset + _graph.size * 0.5) / _graph.zoom) / JuiceeEditorUtil.EDSCALE
	var no_input := false
	var type := ""
	if entry is String and (entry as String).begins_with("builtin:"):
		type = (entry as String).substr("builtin:".length())
		# Trigger (graph entry point) and Comment have no input port.
		no_input = type == "trigger" or type == "comment"
	# A graph runs from its one Trigger; a second would be ignored without a word.
	if type == "trigger" and _resource.find_trigger():
		_show_graph_toast("A graph has one Trigger; this one already does")
		var existing := _graph.get_node_or_null(NodePath(_resource.find_trigger().id)) as JuiceeGraphBlock
		if existing:
			_select_only_block(existing)
		return
	# A wire dragged out to empty space is connected to the new block in the same undo step.
	var wire: Array = []
	if not pending_from.is_empty():
		if no_input:
			_show_graph_toast("Trigger / Comment has no input - added unconnected")
		else:
			wire = [String(pending_from), pending_port]
	if not type.is_empty():
		_add_builtin(type, pos, wire)
	elif entry is Script:
		_add_effect(entry as Script, pos, wire)

func _build_toolbar() -> Control:
	# Toolbar uses Godot's native bottom-panel toolbar look - a thin HBox with
	# small margin, no custom background. Matches the Animation / Shader Editor
	# tabs row.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(4 * JuiceeEditorUtil.EDSCALE))
	margin.add_theme_constant_override("margin_right", int(4 * JuiceeEditorUtil.EDSCALE))
	margin.add_theme_constant_override("margin_top", int(4 * JuiceeEditorUtil.EDSCALE))
	margin.add_theme_constant_override("margin_bottom", int(4 * JuiceeEditorUtil.EDSCALE))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(4 * JuiceeEditorUtil.EDSCALE))
	margin.add_child(bar)

	var btn_new := _toolbar_btn("New", func() -> void: _confirm_discard(_new_graph), "New")
	btn_new.tooltip_text = "Start a new graph"
	bar.add_child(btn_new)
	var btn_open := _toolbar_btn("Open", _open_dialog, "Load")
	btn_open.tooltip_text = "Open a graph, or a JuiceeSequence as a straight graph"
	bar.add_child(btn_open)
	var btn_save := _toolbar_btn("Save", _save, "Save")
	btn_save.tooltip_text = "Save the graph as a .tres"
	bar.add_child(btn_save)
	bar.add_child(_vsep())
	_test_btn = _toolbar_btn("Test", _test_sequence, "Play")
	_test_btn.tooltip_text = "Play the graph on the scene you are editing. Blocks light up as they run;\npress again to stop.\n\nFull-screen shader effects preview at the editor viewport's size.\nRun the project (F5/F6) to see them at full screen."
	bar.add_child(_test_btn)
	var btn_export := _toolbar_btn("Export Sequence", _export_sequence)
	# Its own icon, so it still differs from Save when the toolbar shows icons only.
	btn_export.icon = JuiceeEditorUtil.addon_icon("res://addons/juicee/icons/juicee_resource.svg")
	btn_export.tooltip_text = "Export current graph as a JuiceeSequence .tres for use with JuiceePlayer"
	bar.add_child(btn_export)
	bar.add_child(_vsep())
	var btn_fit := _toolbar_btn("Fit", _zoom_to_fit, "CenterView")
	btn_fit.tooltip_text = "Zoom and center the graph to fit all nodes"
	bar.add_child(btn_fit)

	_pan_btn = _toolbar_btn("", _toggle_pan_mode)
	_pan_btn.toggle_mode = true
	_pan_btn.tooltip_text = "Hand tool - drag with LMB to pan\n(MMB drag always pans regardless of this toggle)"
	var pan_icon := JuiceeEditorUtil.editor_icon("ToolPan")
	if pan_icon:
		_pan_btn.icon = pan_icon
	else:
		_pan_btn.text = "✋"
	bar.add_child(_pan_btn)
	# Minimap: a big graph is hard to navigate without an overview, and Godot's
	# GraphEdit ships one - it just needs a switch.
	_minimap_btn = _toolbar_btn("", _toggle_minimap)
	_minimap_btn.toggle_mode = true
	_minimap_btn.tooltip_text = "Show the minimap overview"
	var mm_icon := JuiceeEditorUtil.editor_icon("GridMinimap")
	if mm_icon:
		_minimap_btn.icon = mm_icon
	else:
		_minimap_btn.text = "Map"
	bar.add_child(_minimap_btn)

	var btn_align := _toolbar_btn("Align", _align_selected, "HorizontalAlignCenter")
	btn_align.tooltip_text = "Line the selected blocks up and space them evenly.\nHold Shift for a vertical column."
	bar.add_child(btn_align)

	# Advanced Properties lives in Project Settings, but it changes what every block's
	# property panel shows, so it belongs one click away from the graph too.
	_advanced_btn = _toolbar_btn("", _toggle_advanced)
	_advanced_btn.toggle_mode = true
	_advanced_btn.text = "Advanced"
	_advanced_btn.button_pressed = JuiceeEffect.advanced_enabled()
	_advanced_btn.tooltip_text = "Reveal every effect's advanced parameters\n(Project Settings > juicee > advanced_properties)"
	bar.add_child(_advanced_btn)
	bar.add_child(_vsep())

	var btn_rescan := _toolbar_btn("Rescan", _rescan_effects, "Reload")
	btn_rescan.tooltip_text = "Look again for effect scripts, in the addon and in your effect folders"
	bar.add_child(btn_rescan)
	var btn_update := _toolbar_btn("Update", _update_prompt.check)
	btn_update.tooltip_text = "Check GitHub for a newer release of Juicee\n(current: v%s)" % JuiceeUpdater.get_current_version()
	bar.add_child(btn_update)
	bar.add_child(_vsep())

	_file_label = Label.new()
	_file_label.text = "untitled"
	_file_label.modulate = Color(1, 1, 1, 0.65)
	_file_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# A long file name gives way rather than widening the panel.
	_file_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(_file_label)

	# Same word and same colour as the Inspector's, because it is the same fact.
	_live_label = Label.new()
	_live_label.text = "live"
	_live_label.add_theme_color_override("font_color", Color(0.42, 0.72, 0.50))
	_live_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_live_label.tooltip_text = "A game is running. Values you change here are pushed to it live."
	_live_label.visible = false
	bar.add_child(_live_label)
	_refresh_live_badge()

	_toolbar_bar = bar
	for c in bar.get_children():
		if c is Button and (c as Button).icon and not (c as Button).text.is_empty():
			c.set_meta("label", (c as Button).text)
			_compact_btns.append(c as Button)
	return margin

## Icons only when the toolbar does not fit, so the panel is never laid out wider than the dock.
func _fit_toolbar() -> void:
	if not _toolbar_bar or _compact_btns.is_empty():
		return
	var compact := _compact_btns[0].text.is_empty()
	if not compact:
		_toolbar_full_width = _toolbar_bar.get_combined_minimum_size().x
	var want := size.x < _toolbar_full_width + 8.0 * JuiceeEditorUtil.EDSCALE
	if want == compact:
		return
	for b in _compact_btns:
		b.text = "" if want else String(b.get_meta("label"))

func _vsep() -> VSeparator:
	var s := VSeparator.new()
	s.add_theme_constant_override("separation", int(8 * JuiceeEditorUtil.EDSCALE))
	return s

func _build_props_panel() -> Control:
	# No custom bg - let the editor theme's panel style apply. Matches inspector
	# sidebars in built-in panels (Animation params, Shader editor sidebars).
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 260 * JuiceeEditorUtil.EDSCALE

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   int(10 * JuiceeEditorUtil.EDSCALE))
	m.add_theme_constant_override("margin_right",  int(10 * JuiceeEditorUtil.EDSCALE))
	m.add_theme_constant_override("margin_top",    int(10 * JuiceeEditorUtil.EDSCALE))
	m.add_theme_constant_override("margin_bottom", int(10 * JuiceeEditorUtil.EDSCALE))
	panel.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(8 * JuiceeEditorUtil.EDSCALE))
	m.add_child(vbox)

	_props_title = Label.new()
	_props_title.text = "Properties"
	JuiceeEditorUtil.bold_label(_props_title)
	vbox.add_child(_props_title)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_props_content = VBoxContainer.new()
	_props_content.add_theme_constant_override("separation", int(10 * JuiceeEditorUtil.EDSCALE))
	_props_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_props_content)

	# The panel fills these and owns nothing else of the editor's. The two things it
	# cannot do for itself come back as signals rather than as calls into the host.
	_props.content = _props_content
	_props.title = _props_title
	_props.graph = _graph
	_props.undo_redo = undo_redo
	_props.changed.connect(_mark_dirty)
	_props.delete_requested.connect(_delete_block)
	_props.property_committed.connect(_push_live)
	_props.property_committed.connect(_on_props_committed)
	_props.rebuild_requested.connect(_on_props_rebuild_requested)
	add_child(_update_prompt)

	return panel

# ─── Undo/Redo internal helpers ──────────────────────────────────────────────
# These are called by EditorUndoRedoManager on Ctrl+Z / Ctrl+Y.
# They operate directly on _resource + sync the visual graph.

func _ur_add_node(data: JuiceeGraphNodeData) -> void:
	if not _resource.find_node(data.id):
		_resource.add_node(data)
	_rebuild_graph()
	_mark_dirty()

func _ur_remove_node(node_id: String) -> void:
	_resource.remove_node(node_id)
	_rebuild_graph()
	_mark_dirty()

func _ur_add_node_with_connections(data: JuiceeGraphNodeData, connections_snapshot: PackedStringArray) -> void:
	if not _resource.find_node(data.id):
		_resource.add_node(data)
	_resource.connections = connections_snapshot.duplicate()
	_rebuild_graph()
	_mark_dirty()

func _ur_move_node(node_id: String, pos: Vector2) -> void:
	var data := _resource.find_node(node_id)
	if data:
		data.graph_position = pos
		if data.effect:
			data.effect.graph_position = pos
	var block := _graph.get_node_or_null(NodePath(node_id)) as JuiceeGraphBlock
	if block:
		block.position_offset = pos * JuiceeEditorUtil.EDSCALE
	_mark_dirty()

func _ur_add_connection(from_id: String, from_port: int, to_id: String, to_port: int) -> void:
	_resource.add_connection(from_id, from_port, to_id, to_port)
	_graph.connect_node(from_id, from_port, to_id, to_port)
	_mark_dirty()

func _ur_remove_connection(from_id: String, from_port: int, to_id: String, to_port: int) -> void:
	_resource.remove_connection(from_id, from_port, to_id, to_port)
	_graph.disconnect_node(from_id, from_port, to_id, to_port)
	_mark_dirty()

## An undo or redo wrote a parameter behind the panel's back, so the widget showing it
## is stale. Rebuilding covers array add and remove too, which change how many widgets
## there are rather than just what they read.
func _on_props_rebuild_requested(effect: JuiceeEffect) -> void:
	_refresh_block_for(effect)
	if _selected_block and _selected_block.node_data.effect == effect:
		_show_props(_selected_block)

## A parameter changed in the panel: the block shows the new length, and a muted or unmuted
## effect looks it on the canvas.
func _on_props_committed(effect: JuiceeEffect, _property: String, _value: Variant) -> void:
	_refresh_block_for(effect)

func _refresh_block_for(effect: JuiceeEffect) -> void:
	for c in _graph.get_children():
		if c is JuiceeGraphBlock and (c as JuiceeGraphBlock).node_data and (c as JuiceeGraphBlock).node_data.effect == effect:
			(c as JuiceeGraphBlock).refresh_subtitle()
			_refresh_block_mute(c as JuiceeGraphBlock)

func _on_live_state_changed(_is_live: bool) -> void:
	_refresh_live_badge()

## Asks the bridge rather than trusting the signal's argument, so a second debugged
## game stopping while a first is still running does not clear the badge.
func _refresh_live_badge() -> void:
	if not is_instance_valid(_live_label):
		return
	_live_label.visible = debugger_plugin != null \
			and bool(debugger_plugin.call("has_live_session"))

## Mirrors a parameter edit into a running game, over the same bridge the Inspector
## uses. An unsaved graph has no resource path to address, so nothing is pushed until
## it has been saved once.
func _push_live(effect: JuiceeEffect, pname: String, value: Variant) -> void:
	if not debugger_plugin or not is_instance_valid(effect):
		return
	if effect.resource_path.is_empty():
		return
	debugger_plugin.call("send_to_game", "juicee_tune:set", [effect.resource_path, pname, value])

# ─── Graph operations ─────────────────────────────────────────────────────────

func _new_graph() -> void:
	_resource = JuiceeGraphResource.new()
	_resource_path = ""
	_dirty = false
	_file_label.text = "untitled"
	# Seed the graph with a Trigger so first-time users immediately see the
	# entry point. They can right-click anywhere to attach effects.
	_resource.add_node(JuiceeGraphNodeData.create_for_builtin("trigger", Vector2(120, 80)))
	_rebuild_graph()
	_show_props_placeholder()

## Public API: convert a JuiceeSequence into a fresh linear graph (Trigger -> effect -> effect ...)
## and load it into the editor. Used by the JuiceePlayer inspector "Edit in Graph" button.
func load_from_sequence(seq: JuiceeSequence, source_label: String = "from sequence") -> void:
	if not seq:
		push_warning("JuiceeGraphEditor: load_from_sequence got null")
		return
	_confirm_discard(_load_from_sequence.bind(seq, source_label))

func _load_from_sequence(seq: JuiceeSequence, source_label: String) -> void:
	var res := JuiceeGraphResource.new()

	# Layout: Trigger on the left, effects flow right at fixed spacing.
	var x: float = 80.0
	var y: float = 80.0
	var step_x: float = 250.0

	var trigger := JuiceeGraphNodeData.create_for_builtin("trigger", Vector2(x, y))
	res.add_node(trigger)
	var prev_id: String = trigger.id
	x += step_x

	for effect in seq.effects:
		if not effect:
			continue
		var data := JuiceeGraphNodeData.new()
		var script := effect.get_script() as Script
		var slug := "effect"
		if script:
			slug = script.resource_path.get_file().get_basename()
		data.id = "%s_%d" % [slug, Time.get_ticks_msec() + randi() % 9999]
		data.type = "effect"
		data.graph_position = Vector2(x, y)
		# A copy: the graph is a new thing until it is saved or exported, and editing the player's
		# own instances would change the scene without marking it unsaved.
		data.effect = effect.duplicate(true)
		data.effect.graph_position = data.graph_position
		res.add_node(data)
		res.add_connection(prev_id, 0, data.id, 0)
		prev_id = data.id
		x += step_x

	_resource = res
	_resource_path = ""
	_dirty = true
	_file_label.text = "* " + source_label
	_rebuild_graph()
	_show_props_placeholder()

func _rescan_effects() -> void:
	_scan_effects()
	_build_popup()

func _rebuild_graph() -> void:
	# Out of the tree now, not at the end of the frame: a block added while one of the same id is
	# still a child is renamed, and every wire and lookup by id then misses it.
	for child in _graph.get_children():
		if child is GraphNode:
			_graph.remove_child(child)
			child.queue_free()
	_graph.clear_connections()
	_selected_block = null
	_clear_props()

	if not _resource:
		return

	for data in _resource.nodes:
		var block := JuiceeGraphBlock.create(data)
		_graph.add_child(block)
		_wire_block(block)
		# Carry a saved mute state onto the freshly built block.
		_refresh_block_mute(block)

	await get_tree().process_frame

	for conn in _resource.connections:
		var p := conn.split(":")
		if p.size() == 4:
			_graph.connect_node(p[0], int(p[1]), p[2], int(p[3]))

func _add_builtin(type: String, at_position: Vector2, wire: Array = []) -> String:
	var data := JuiceeGraphNodeData.create_for_builtin(type, at_position)
	_place_new_block(data, "Add %s Node" % data.type.capitalize(), wire)
	return data.id

func _add_effect(script: Script, at_position: Vector2, wire: Array = []) -> String:
	var data := JuiceeGraphNodeData.create_for_effect(script, at_position)
	var label := data.effect.get_display_name() if data.effect else script.resource_path.get_file().get_basename()
	_place_new_block(data, "Add %s" % label, wire)
	return data.id

## Adds a block, and the wire it was dragged from if there is one, as one undo step.
func _place_new_block(data: JuiceeGraphNodeData, action_name: String, wire: Array) -> void:
	var conns_before := _resource.connections.duplicate()
	_resource.add_node(data)
	var block := JuiceeGraphBlock.create(data)
	_graph.add_child(block)
	_wire_block(block)
	if not wire.is_empty():
		_graph.connect_node(wire[0], wire[1], data.id, 0)
		_resource.add_connection(wire[0], wire[1], data.id, 0)
	_mark_dirty()
	if undo_redo:
		undo_redo.create_action(action_name)
		undo_redo.add_do_method(self, "_ur_add_node_with_connections", data, _resource.connections.duplicate())
		undo_redo.add_undo_method(self, "_ur_remove_nodes", PackedStringArray([data.id]), conns_before)
		undo_redo.commit_action(false)

func _wire_block(block: JuiceeGraphBlock) -> void:
	block.dragged.connect(_on_block_dragged.bind(block))
	block.preview_requested.connect(_on_block_preview_requested.bind(block))
	block.ports_changed.connect(_on_block_ports_changed.bind(block))
	block.hovered.connect(_on_block_hovered.bind(block))
	block.unhovered.connect(_on_block_unhovered.bind(block))

func _on_block_ports_changed(new_count: int, block: JuiceeGraphBlock) -> void:
	var data := block.node_data
	data.properties["port_count"] = new_count
	# Keep the weights array (for Random) aligned with port count.
	if data.type == "random":
		var weights: Array = data.properties.get("weights", [])
		while weights.size() < new_count:
			weights.append(1.0)
		while weights.size() > new_count:
			weights.pop_back()
		data.properties["weights"] = weights
	# Drop any connection that referenced a now-removed output port.
	var kept: PackedStringArray = []
	for c in _resource.connections:
		var p := c.split(":")
		if p.size() == 4 and p[0] == data.id and int(p[1]) >= new_count:
			continue
		kept.append(c)
	_resource.connections = kept
	_mark_dirty()
	_rebuild_graph()

func _delete_block(block: JuiceeGraphBlock) -> void:
	_delete_blocks([block])

## Deletes blocks and every wire touching them as one undo step, however many there are.
func _delete_blocks(blocks: Array) -> void:
	var datas: Array[JuiceeGraphNodeData] = []
	var ids: PackedStringArray = []
	for b in blocks:
		if is_instance_valid(b) and (b as JuiceeGraphBlock).node_data:
			datas.append((b as JuiceeGraphBlock).node_data)
			ids.append((b as JuiceeGraphBlock).node_data.id)
	if datas.is_empty():
		return
	var connections_before := _resource.connections.duplicate()
	_ur_remove_nodes(ids, PackedStringArray())
	if undo_redo:
		var label: String = (datas[0].effect.get_display_name() if datas[0].effect else datas[0].type.capitalize()) \
				if datas.size() == 1 else "%d Blocks" % datas.size()
		undo_redo.create_action("Delete %s" % label)
		undo_redo.add_do_method(self, "_ur_remove_nodes", ids, PackedStringArray())
		undo_redo.add_undo_method(self, "_ur_restore_nodes", datas, connections_before)
		undo_redo.commit_action(false)

## Removes nodes; `conns` replaces the connection list when given, and otherwise the
## wires touching the removed nodes go with them.
func _ur_remove_nodes(ids: PackedStringArray, conns: PackedStringArray) -> void:
	for id in ids:
		_resource.remove_node(id)
	if not conns.is_empty():
		_resource.connections = conns.duplicate()
	_rebuild_graph()
	_mark_dirty()

func _ur_restore_nodes(datas: Array, conns: PackedStringArray) -> void:
	for d in datas:
		if not _resource.find_node(d.id):
			_resource.add_node(d)
	_resource.connections = conns.duplicate()
	_rebuild_graph()
	_mark_dirty()

# ─── File I/O ─────────────────────────────────────────────────────────────────

func _save() -> void:
	if _resource_path.is_empty():
		_file_dialog_purpose = "save"
		_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		_file_dialog.popup_centered_ratio(0.6)
	else:
		_do_save(_resource_path)

func _on_file_dialog_selected(path: String) -> void:
	var purpose := _file_dialog_purpose
	_file_dialog_purpose = ""
	match purpose:
		"save":
			_do_save(path)
		"open":
			_on_open_path_selected(path)

func _do_save(path: String) -> void:
	# Every position in the editor is at 100%, whether the graph was new or converted on opening.
	_resource.positions_at_100 = true
	# The graph and its effects take the file's paths, so a running game can address them:
	# the live highlight and live tuning both go by path.
	var err := ResourceSaver.save(_resource, path,
			ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	if err != OK:
		_show_graph_toast("Could not save %s (%s)" % [path.get_file(), error_string(err)])
		return
	# FLAG_CHANGE_PATH set the effects' paths but left the graph's own empty in the editor.
	if _resource.resource_path != path:
		_resource.take_over_path(path)
	_resource_path = path
	_dirty = false
	_file_label.text = path.get_file()
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().update_file(path)

func _open_dialog() -> void:
	_confirm_discard(func() -> void:
		_file_dialog_purpose = "open"
		_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.popup_centered_ratio(0.6))

## Runs `then` straight away when nothing is unsaved, and after a confirmation when something is.
func _confirm_discard(then: Callable) -> void:
	if not _dirty:
		then.call()
		return
	var confirm := ConfirmationDialog.new()
	confirm.title = "Unsaved graph"
	confirm.dialog_text = "%s has unsaved changes. Discard them?" % _file_label.text.trim_prefix("* ")
	confirm.ok_button_text = "Discard"
	add_child(confirm)
	confirm.confirmed.connect(func() -> void:
		confirm.queue_free()
		then.call(), CONNECT_ONE_SHOT)
	confirm.canceled.connect(func() -> void: confirm.queue_free(), CONNECT_ONE_SHOT)
	confirm.popup_centered()

## For the editor's own "save before closing" prompt and for Ctrl+S, through plugin.gd.
func unsaved_status() -> String:
	if not _dirty:
		return ""
	if _resource_path.is_empty():
		return "The JuiceeGraph panel has an unsaved graph. It has never been saved, so closing loses it."
	return "Save changes to %s in the JuiceeGraph panel?" % _resource_path.get_file()

func save_if_saved_before() -> void:
	if _dirty and not _resource_path.is_empty():
		_do_save(_resource_path)

func _on_open_path_selected(path: String) -> void:
	var res := load(path)
	if res is JuiceeGraphResource:
		_resource = res
		_resource.convert_old_positions(JuiceeEditorUtil.EDSCALE)
		_resource_path = path
		_dirty = false
		_file_label.text = path.get_file()
		_rebuild_graph()
	elif res is JuiceeSequence:
		# A JuiceeSequence is converted to a fresh linear graph (Trigger -> effect -> effect ...).
		# It loads as "untitled" since we'd need to re-export to keep the sequence in sync.
		_load_from_sequence(res as JuiceeSequence, path.get_file())
	else:
		push_error("JuiceeGraphEditor: file is neither a JuiceeGraphResource nor a JuiceeSequence: " + path)

func _graph_has_flow_control() -> bool:
	for n in _resource.nodes:
		if n.type in ["split", "random", "condition", "loop"]:
			return true
	return false

func _export_sequence() -> void:
	if not _resource:
		return
	# A flat JuiceeSequence can't represent branching - warn before flattening.
	if _graph_has_flow_control():
		var confirm := ConfirmationDialog.new()
		confirm.title = "Flow control will be flattened"
		confirm.dialog_text = "This graph uses flow control (Split / Random / Condition / Loop).\n\nA JuiceeSequence is a flat list and can't represent branching, so the export FLATTENS it (Random/Condition run every branch, Loop runs once, Split becomes sequential).\n\nTo keep the branching, use Save instead and play the .tres with\nJuiceeGraphPlayer.play(graph, context).\n\nExport the flattened sequence anyway?"
		confirm.ok_button_text = "Export flattened"
		add_child(confirm)
		confirm.popup_centered()
		confirm.confirmed.connect(func() -> void:
			confirm.queue_free()
			_do_export_sequence()
		, CONNECT_ONE_SHOT)
		confirm.canceled.connect(func() -> void: confirm.queue_free(), CONNECT_ONE_SHOT)
		return
	_do_export_sequence()

func _do_export_sequence() -> void:
	var seq := _resource.to_sequence()
	var dlg := EditorFileDialog.new()
	dlg.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	dlg.access = EditorFileDialog.ACCESS_RESOURCES
	dlg.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dlg.add_filter("*.tres", "JuiceeSequence")
	add_child(dlg)
	dlg.popup_centered_ratio(0.6)
	dlg.file_selected.connect(func(path: String) -> void:
		var err := ResourceSaver.save(seq, path)
		if err != OK:
			_show_graph_toast("Could not export %s (%s)" % [path.get_file(), error_string(err)])
		elif Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().update_file(path)
		dlg.queue_free()
	, CONNECT_ONE_SHOT)
	dlg.canceled.connect(func() -> void: dlg.queue_free(), CONNECT_ONE_SHOT)

func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		_file_label.text = ("* " + _file_label.text) if not _file_label.text.begins_with("* ") else _file_label.text

# ─── Signal handlers ──────────────────────────────────────────────────────────

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if not _is_valid_connection(str(from_node), str(to_node)):
		return  # self-loop or cycle - rejected (with a toast)
	_graph.connect_node(from_node, from_port, to_node, to_port)
	_resource.add_connection(from_node, from_port, to_node, to_port)
	_mark_dirty()
	if undo_redo:
		undo_redo.create_action("Connect Nodes")
		undo_redo.add_do_method(self, "_ur_add_connection", str(from_node), from_port, str(to_node), to_port)
		undo_redo.add_undo_method(self, "_ur_remove_connection", str(from_node), from_port, str(to_node), to_port)
		undo_redo.commit_action(false)

## Rejects connections that would corrupt the flow graph: a node wired to itself,
## or one that closes a cycle (the Trigger walk + JuiceeGraphPlayer assume a DAG).
func _is_valid_connection(from_id: String, to_id: String) -> bool:
	if from_id == to_id:
		_show_graph_toast("Can't connect a node to itself")
		return false
	if _creates_cycle(from_id, to_id):
		_show_graph_toast("That would create a loop")
		return false
	return true

## Adding from_id -> to_id closes a cycle iff to_id can ALREADY reach from_id by
## following existing connections.
func _creates_cycle(from_id: String, to_id: String) -> bool:
	var stack: Array[String] = [to_id]
	var seen := {}
	while not stack.is_empty():
		var cur: String = stack.pop_back()
		if cur == from_id:
			return true
		if seen.has(cur):
			continue
		seen[cur] = true
		for nxt in _resource.get_next(cur):
			stack.append(nxt.id)
	return false

## Transient red banner at the top of the graph (auto-hides). Used for rejected
## actions like invalid connections.
func _show_graph_toast(msg: String) -> void:
	if not is_instance_valid(_toast):
		_toast = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.5, 0.12, 0.12, 0.92)
		sb.set_corner_radius_all(int(4 * JuiceeEditorUtil.EDSCALE))
		sb.content_margin_left = 10 * JuiceeEditorUtil.EDSCALE
		sb.content_margin_right = 10 * JuiceeEditorUtil.EDSCALE
		sb.content_margin_top = 5 * JuiceeEditorUtil.EDSCALE
		sb.content_margin_bottom = 5 * JuiceeEditorUtil.EDSCALE
		_toast.add_theme_stylebox_override("panel", sb)
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast.z_index = 100
		_toast_label = Label.new()
		_toast_label.add_theme_color_override("font_color", Color(1, 0.9, 0.9))
		_toast.add_child(_toast_label)
		_graph.add_child(_toast)
	_toast_label.text = msg
	_toast.visible = true
	_toast.reset_size()
	_toast.position = Vector2((_graph.size.x - _toast.size.x) * 0.5, 12 * JuiceeEditorUtil.EDSCALE)
	_toast_gen += 1
	var my := _toast_gen
	await get_tree().create_timer(1.6).timeout
	if my == _toast_gen and is_instance_valid(_toast):
		_toast.visible = false

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	_graph.disconnect_node(from_node, from_port, to_node, to_port)
	_resource.remove_connection(from_node, from_port, to_node, to_port)
	_mark_dirty()
	if undo_redo:
		undo_redo.create_action("Disconnect Nodes")
		undo_redo.add_do_method(self, "_ur_remove_connection", str(from_node), from_port, str(to_node), to_port)
		undo_redo.add_undo_method(self, "_ur_add_connection", str(from_node), from_port, str(to_node), to_port)
		undo_redo.commit_action(false)

func _on_popup_request(at_position: Vector2) -> void:
	_pending_connect_from = ""
	_pending_connect_from_port = -1
	_popup_pos = (_graph.scroll_offset + at_position) / _graph.zoom
	_open_add_popup(at_position)

func _on_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2) -> void:
	_pending_connect_from = from_node
	_pending_connect_from_port = from_port
	_popup_pos = (_graph.scroll_offset + release_position) / _graph.zoom
	# release_position is in graph-local coords; convert to popup screen position.
	var screen_pos := _graph.global_position + release_position
	_open_add_popup_at_screen(screen_pos)

func _open_add_popup(at_local_position: Vector2) -> void:
	_open_add_popup_at_screen(get_screen_position() + at_local_position)

func _open_add_popup_at_screen(screen_pos: Vector2) -> void:
	_popup_search.text = ""
	_on_popup_search_changed("")
	# Opened by dragging a wire -> hide the input-less nodes (Trigger / Comment);
	# they can't be a connection target. (Right-click opens with everything.)
	if not _pending_connect_from.is_empty():
		var hid := false
		for c in _popup_list.get_children():
			if c is HBoxContainer and bool(c.get_meta("no_input", false)):
				c.visible = false
				hid = true
		if hid:
			_rebuild_popup_nav(false, false)
	_popup.popup(Rect2i(Vector2i(screen_pos), Vector2i(260, 360)))
	_popup_search.grab_focus.call_deferred()

func _on_popup_hide() -> void:
	# Clear pending drag-connect state if user dismissed without picking.
	_pending_connect_from = ""
	_pending_connect_from_port = -1

func _on_node_selected(node: Node) -> void:
	if node is JuiceeGraphBlock:
		_show_props(node as JuiceeGraphBlock)

func _on_node_deselected(_node: Node) -> void:
	_clear_props()
	_show_props_placeholder()
	_selected_block = null

func _on_delete_nodes_request(nodes: Array) -> void:
	var blocks: Array = []
	for node_name in nodes:
		var block := _graph.get_node_or_null(NodePath(str(node_name))) as JuiceeGraphBlock
		if block:
			blocks.append(block)
	_delete_blocks(blocks)

func _on_block_dragged(from: Vector2, to: Vector2, block: JuiceeGraphBlock) -> void:
	# The canvas works at the editor's scale, the stored graph at 100%.
	var gfrom := from / JuiceeEditorUtil.EDSCALE
	var gto := to / JuiceeEditorUtil.EDSCALE
	block.node_data.graph_position = gto
	if block.node_data.effect:
		block.node_data.effect.graph_position = gto
	_mark_dirty()
	if undo_redo and from.distance_squared_to(to) > 1.0:
		undo_redo.create_action("Move Node")
		undo_redo.add_do_method(self, "_ur_move_node", block.node_data.id, gto)
		undo_redo.add_undo_method(self, "_ur_move_node", block.node_data.id, gfrom)
		undo_redo.commit_action(false)

# ─── Copy / Paste / Duplicate ─────────────────────────────────────────────────

## Ctrl+C - snapshot the selected nodes (deep-copied) plus the connections that
## are internal to that set, into the clipboard.
func _on_copy_nodes_request() -> void:
	var blocks := _selected_blocks()
	if blocks.is_empty():
		return
	_clipboard_nodes.clear()
	var ids: PackedStringArray = []
	for b in blocks:
		var d := b.node_data
		if d == null:
			continue
		_clipboard_nodes.append(_deep_copy_data(d))
		ids.append(d.id)
	_clipboard_connections = _internal_connections(ids)
	_clipboard_paste_count = 0

## Ctrl+V - instantiate the clipboard with fresh ids, cascading the offset on each
## consecutive paste so copies don't stack exactly on top of one another.
func _on_paste_nodes_request() -> void:
	if _clipboard_nodes.is_empty():
		return
	_clipboard_paste_count += 1
	var offset := Vector2(30, 30) * _clipboard_paste_count
	_commit_paste(_clipboard_nodes, _clipboard_connections, offset, "Paste Nodes")

## Ctrl+X - copy the selection to the clipboard, then delete it.
func _on_cut_nodes_request() -> void:
	var blocks := _selected_blocks()
	if blocks.is_empty():
		return
	_on_copy_nodes_request()
	_delete_blocks(blocks)

## Ctrl+A - select every block in the graph.
func _select_all_blocks() -> void:
	var first: JuiceeGraphBlock = null
	for c in _graph.get_children():
		if c is JuiceeGraphBlock:
			(c as JuiceeGraphBlock).selected = true
			if first == null:
				first = c
	if first:
		_show_props(first)

## Escape - clear the selection and the props panel.
func _deselect_all_blocks() -> void:
	for c in _graph.get_children():
		if c is JuiceeGraphBlock:
			(c as JuiceeGraphBlock).selected = false
	_selected_block = null
	_clear_props()
	_show_props_placeholder()

## Shows the node context menu if the right-click landed on a block. When over
## empty canvas it returns without consuming, so GraphEdit's popup_request (the
## add-effect search) still fires there.
func _try_block_context_menu() -> void:
	if not is_instance_valid(_graph) or not _graph.is_visible_in_tree():
		return
	if not _graph.get_global_rect().has_point(_graph.get_global_mouse_position()):
		return
	var gpos := (_graph.scroll_offset + _graph.get_local_mouse_position()) / _graph.zoom
	var blk := _block_at(gpos)
	if blk:
		_show_node_context_menu(blk)
		get_viewport().set_input_as_handled()

## The graph block whose rect contains the given graph-space point, or null.
func _block_at(graph_pos: Vector2) -> JuiceeGraphBlock:
	for c in _graph.get_children():
		if c is JuiceeGraphBlock:
			var b := c as JuiceeGraphBlock
			if Rect2(b.position_offset, b.size).has_point(graph_pos):
				return b
	return null

func _show_node_context_menu(block: JuiceeGraphBlock) -> void:
	if not is_instance_valid(_node_menu):
		_node_menu = PopupMenu.new()
		_node_menu.id_pressed.connect(_on_node_menu_id)
		add_child(_node_menu)
	_node_menu_block = block
	_node_menu.clear()
	_node_menu.add_item("Duplicate", 0)
	_node_menu.add_item("Copy", 1)
	# Mute is only meaningful on a block that actually runs an effect; flow-control
	# blocks (branch, random, delay) have nothing to silence.
	if block.node_data and block.node_data.effect:
		_node_menu.add_item(
			"Unmute" if not block.node_data.effect.enabled else "Mute", 4)
	_node_menu.add_item("Disconnect all", 2)
	_node_menu.add_separator()
	_node_menu.add_item("Delete", 3)
	_node_menu.reset_size()
	_node_menu.popup(Rect2i(DisplayServer.mouse_get_position(), Vector2i.ZERO))

func _on_node_menu_id(id: int) -> void:
	var b := _node_menu_block
	if not is_instance_valid(b):
		return
	match id:
		0:  # Duplicate
			_select_only_block(b)
			_on_duplicate_nodes_request()
		1:  # Copy
			_select_only_block(b)
			_on_copy_nodes_request()
		2:  # Disconnect all
			_disconnect_block(b)
		3:  # Delete
			_delete_block(b)
		4:  # Mute / unmute
			_toggle_block_mute(b)

## Mutes or unmutes the effect on a block, through undo, and restyles the block so the
## state is visible on the canvas rather than only in the property panel.
func _toggle_block_mute(b: JuiceeGraphBlock) -> void:
	if not b.node_data or not b.node_data.effect:
		return
	var eff := b.node_data.effect
	var was: bool = eff.enabled
	if undo_redo:
		undo_redo.create_action("Juicee: %s Block" % ("Unmute" if not was else "Mute"))
		undo_redo.add_do_property(eff, "enabled", not was)
		undo_redo.add_undo_property(eff, "enabled", was)
		undo_redo.add_do_method(self, "_refresh_block_mute", b)
		undo_redo.add_undo_method(self, "_refresh_block_mute", b)
		undo_redo.commit_action()
	else:
		eff.enabled = not was
		_refresh_block_mute(b)
	_mark_dirty()
	# The panel shows Enabled too; redraw it rather than leave it saying the old state.
	if _selected_block == b:
		_show_props(b)

## Fades a muted block and tags its title, so a silenced step reads at a glance the way
## a disabled track does in a DAW.
func _refresh_block_mute(b: JuiceeGraphBlock) -> void:
	if not is_instance_valid(b) or not b.node_data or not b.node_data.effect:
		return
	var muted: bool = not b.node_data.effect.enabled
	b.rest_modulate = Color(1, 1, 1, 0.45) if muted else Color.WHITE
	b.modulate = b.rest_modulate
	var base := String(b.title).trim_suffix(" (muted)")
	b.title = base + (" (muted)" if muted else "")

func _select_only_block(b: JuiceeGraphBlock) -> void:
	for c in _graph.get_children():
		if c is JuiceeGraphBlock:
			(c as JuiceeGraphBlock).selected = (c == b)
	_selected_block = b
	_show_props(b)

## Remove every connection touching this block, as one undoable action.
func _disconnect_block(b: JuiceeGraphBlock) -> void:
	var id: String = b.node_data.id
	var touching: Array = []
	for conn in _resource.connections:
		var p := conn.split(":")
		if p.size() == 4 and (p[0] == id or p[2] == id):
			touching.append([p[0], int(p[1]), p[2], int(p[3])])
	if touching.is_empty():
		return
	for t in touching:  # pre-apply, then register undo (same pattern as add/delete)
		_ur_remove_connection(t[0], t[1], t[2], t[3])
	if undo_redo:
		undo_redo.create_action("Disconnect Node")
		for t in touching:
			undo_redo.add_do_method(self, "_ur_remove_connection", t[0], t[1], t[2], t[3])
			undo_redo.add_undo_method(self, "_ur_add_connection", t[0], t[1], t[2], t[3])
		undo_redo.commit_action(false)

## Ctrl+D - copy the current selection and re-insert it at a small offset in one
## step, without touching the copy/paste clipboard.
func _on_duplicate_nodes_request() -> void:
	var blocks := _selected_blocks()
	if blocks.is_empty():
		return
	var src: Array[JuiceeGraphNodeData] = []
	var ids: PackedStringArray = []
	for b in blocks:
		var d := b.node_data
		if d == null:
			continue
		src.append(_deep_copy_data(d))
		ids.append(d.id)
	if src.is_empty():
		return
	_commit_paste(src, _internal_connections(ids), Vector2(30, 30), "Duplicate Nodes")

## Builds fresh nodes (new ids, remapped internal connections) and commits them as
## a single undoable action that also selects the new nodes.
func _commit_paste(src_nodes: Array, src_conns: PackedStringArray, offset: Vector2, action_name: String) -> void:
	var made := _instantiate_copies(src_nodes, src_conns, offset)
	var new_nodes: Array = made[0]
	var new_conns: PackedStringArray = made[1]
	if new_nodes.is_empty():
		return
	var new_ids: PackedStringArray = []
	for nd in new_nodes:
		new_ids.append(nd.id)
	# Apply immediately, then register undo with execute=false - exactly how the
	# add/delete actions in this file work. Relying on commit_action(true) to run
	# the do-method proved unreliable for the bottom panel's history context.
	_ur_paste(new_nodes, new_conns, new_ids)
	if undo_redo:
		undo_redo.create_action(action_name)
		undo_redo.add_do_method(self, "_ur_paste", new_nodes, new_conns, new_ids)
		undo_redo.add_undo_method(self, "_ur_unpaste", new_ids)
		undo_redo.commit_action(false)

## Returns [Array[JuiceeGraphNodeData] new_nodes, PackedStringArray new_conns].
## Each source node is cloned with a new unique id; connections whose BOTH
## endpoints are in the source set are remapped onto the new ids.
func _instantiate_copies(src_nodes: Array, src_conns: PackedStringArray, offset: Vector2) -> Array:
	var id_map := {}
	var new_nodes: Array[JuiceeGraphNodeData] = []
	var left_trigger := false
	for s in src_nodes:
		# The graph already has its Trigger, and a second would be ignored when it runs.
		if s.type == "trigger" and _resource.find_trigger():
			left_trigger = true
			continue
		var nd := JuiceeGraphNodeData.new()
		nd.type = s.type
		nd.graph_position = s.graph_position + offset
		nd.properties = s.properties.duplicate(true)
		if s.effect:
			nd.effect = s.effect.duplicate(true)
			nd.effect.graph_position = nd.graph_position
		nd.id = _unique_id(_base_of(s.id))
		id_map[s.id] = nd.id
		new_nodes.append(nd)
	var new_conns: PackedStringArray = []
	for c in src_conns:
		var p := c.split(":")
		if p.size() == 4 and id_map.has(p[0]) and id_map.has(p[2]):
			new_conns.append("%s:%s:%s:%s" % [id_map[p[0]], p[1], id_map[p[2]], p[3]])
	if left_trigger:
		_show_graph_toast("The Trigger was left out: a graph has only one")
	return [new_nodes, new_conns]

func _deep_copy_data(src: JuiceeGraphNodeData) -> JuiceeGraphNodeData:
	var nd := JuiceeGraphNodeData.new()
	nd.id = src.id  # keep original id so connections remap; a new id is assigned at paste
	nd.type = src.type
	nd.graph_position = src.graph_position
	nd.properties = src.properties.duplicate(true)
	if src.effect:
		nd.effect = src.effect.duplicate(true)
		nd.effect.graph_position = src.graph_position
	return nd

func _internal_connections(ids: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = []
	for c in _resource.connections:
		var p := c.split(":")
		if p.size() == 4 and p[0] in ids and p[2] in ids:
			result.append(c)
	return result

## Strips the trailing "_<number>" id suffix to recover a readable base name.
func _base_of(id: String) -> String:
	var parts := id.rsplit("_", true, 1)
	return parts[0] if parts.size() > 1 else id

func _unique_id(base: String) -> String:
	_paste_counter += 1
	var id := "%s_%d_%d" % [base, Time.get_ticks_msec(), _paste_counter]
	while _resource.find_node(id) != null:
		_paste_counter += 1
		id = "%s_%d_%d" % [base, Time.get_ticks_msec(), _paste_counter]
	return id

func _selected_blocks() -> Array[JuiceeGraphBlock]:
	var result: Array[JuiceeGraphBlock] = []
	for child in _graph.get_children():
		if child is JuiceeGraphBlock and (child as JuiceeGraphBlock).selected:
			result.append(child)
	return result

func _select_blocks_by_id(ids: PackedStringArray) -> void:
	var first: JuiceeGraphBlock = null
	for child in _graph.get_children():
		if child is JuiceeGraphBlock:
			var b := child as JuiceeGraphBlock
			var sel := String(b.name) in ids
			b.selected = sel
			if sel and first == null:
				first = b
	if first:
		_selected_block = first
		_show_props(first)

func _ur_paste(nodes: Array, conns: PackedStringArray, new_ids: PackedStringArray) -> void:
	for nd in nodes:
		if not _resource.find_node(nd.id):
			_resource.add_node(nd)
	for c in conns:
		if c not in _resource.connections:
			_resource.connections.append(c)
	_rebuild_graph()
	_mark_dirty()
	_select_blocks_by_id(new_ids)

func _ur_unpaste(new_ids: PackedStringArray) -> void:
	for id in new_ids:
		_resource.remove_node(id)
	_rebuild_graph()
	_mark_dirty()
	_show_props_placeholder()
	_selected_block = null

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _toolbar_btn(label: String, callback: Callable, icon_name: String = "") -> Button:
	var btn := Button.new()
	btn.text = label
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	# Prefer a native editor icon so the row reads like Godot's own toolbars
	# (Animation, Shader Editor). Falls back to plain text if the icon isn't there.
	if not icon_name.is_empty():
		var tex := JuiceeEditorUtil.editor_icon(icon_name)
		if tex:
			btn.icon = tex
	btn.pressed.connect(callback)
	return btn

func _test_sequence() -> void:
	if _test_running:
		_stop_test()
		return
	if not _resource:
		return
	var ctx: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	if not ctx:
		_show_graph_toast("Open a scene to test the graph on")
		return
	var trigger := _resource.find_trigger()
	if not trigger:
		_show_graph_toast("Add a Trigger: a graph runs from it")
		return
	# Wipe any overlay a previous (possibly spammed) Test left behind before this run.
	JuiceeEffect.clear_editor_overlays(ctx)
	_test_gen += 1
	var gen := _test_gen
	_set_test_running(true)
	# The game's own walk, watched so each block lights up as it is reached: a Test runs the way
	# the game will, limits included. A copy of the walk kept here drifted from it, read a False
	# output as True and had none of the limits, so a muted block wired to itself froze the editor.
	await JuiceeGraphPlayer.run(_resource, ctx, _on_test_block,
			func() -> bool: return gen == _test_gen)
	if gen == _test_gen:
		_set_test_running(false)

## Ends a Test run where it is: every effect in the graph stops and puts back what it changed.
func _stop_test() -> void:
	_test_gen += 1
	if _resource:
		for d in _resource.nodes:
			if d.effect:
				d.effect.stop()
	var ctx: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	if ctx:
		JuiceeEffect.clear_editor_overlays(ctx)
	_set_test_running(false)

func _set_test_running(on: bool) -> void:
	_test_running = on
	if not is_instance_valid(_test_btn):
		return
	var label := "Stop" if on else "Test"
	_test_btn.set_meta("label", label)
	if not _test_btn.text.is_empty():
		_test_btn.text = label
	var icon := JuiceeEditorUtil.editor_icon("Stop" if on else "Play")
	if icon:
		_test_btn.icon = icon

## What a Test shows on a block as the walk reaches it. A flow block pulses. An effect block is
## watched while it plays: its delay fills a progress bar, its start pulses it, and a warning
## flashes it and stays as its tooltip, so a bad setup shows on the block itself rather than only
## in the Output panel, which is easy to have scrolled past or not have open at all.
func _on_test_block(event: String, data: JuiceeGraphNodeData, message: String) -> void:
	var block := _find_block_for(data)
	match event:
		"fire":
			if not data.effect:
				if is_instance_valid(block):
					block.pulse_highlight()
				return
			_test_watch_end(data)
			# Bound methods of the block rather than lambdas that captured it: the block can be
			# freed by an edit while the Test runs, and the engine drops a call to a freed one.
			if not is_instance_valid(block):
				return
			var watched := [
				[data.effect.delay_started, Callable(block, "show_delay_progress")],
				[data.effect.started, Callable(block, "pulse_highlight")],
				[data.effect.warning, Callable(block, "flash_warning")],
			]
			for pair in watched:
				if not (pair[0] as Signal).is_connected(pair[1]):
					(pair[0] as Signal).connect(pair[1])
			_test_watched[data] = watched
		"end":
			_test_watch_end(data)
		"warn":
			if is_instance_valid(block):
				block.flash_warning(message + " (taking the True branch)")

## The signals a Test connected for each effect block it is watching.
var _test_watched: Dictionary = {}

func _test_watch_end(data: JuiceeGraphNodeData) -> void:
	for pair in _test_watched.get(data, []):
		if (pair[1] as Callable).is_valid() and (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	_test_watched.erase(data)

func _pulse_block_for(data: JuiceeGraphNodeData) -> void:
	var block := _find_block_for(data)
	if block:
		block.pulse_highlight()

func _find_block_for(data: JuiceeGraphNodeData) -> JuiceeGraphBlock:
	for c in _graph.get_children():
		if c is JuiceeGraphBlock and (c as JuiceeGraphBlock).node_data == data:
			return c
	return null

func _on_block_preview_requested(block: JuiceeGraphBlock) -> void:
	if not block.node_data or not block.node_data.effect:
		return
	var ctx: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	if not ctx:
		_show_graph_toast("Open a scene to preview the effect on")
		return
	# Same visual feedback as the toolbar Test: bar during delay, pulse on start.
	# Spam-clicking is now safe - JuiceeEffect's generation counter supersedes the
	# previous in-flight apply so only the latest play actually runs.
	var effect := block.node_data.effect
	var delay_cb := func(seconds: float) -> void:
		if is_instance_valid(block):
			block.show_delay_progress(seconds)
	var start_cb := func() -> void:
		if is_instance_valid(block):
			block.pulse_highlight()
	effect.delay_started.connect(delay_cb)
	effect.started.connect(start_cb)
	await effect.apply(ctx)
	if effect.delay_started.is_connected(delay_cb):
		effect.delay_started.disconnect(delay_cb)
	if effect.started.is_connected(start_cb):
		effect.started.disconnect(start_cb)


## Shows or hides GraphEdit's built-in minimap. Sized as a corner overview rather than
## a second canvas, so it helps on a big graph without eating the working area.
func _toggle_minimap() -> void:
	if not _graph:
		return
	var on: bool = _minimap_btn.button_pressed if _minimap_btn else not _graph.minimap_enabled
	_graph.minimap_enabled = on
	_graph.minimap_size = Vector2(200, 140) * JuiceeEditorUtil.EDSCALE
	_graph.minimap_opacity = 0.7

## Flips the Advanced Properties project setting and refreshes the open property panel,
## so newly revealed parameters appear immediately instead of after a reselect.
func _toggle_advanced() -> void:
	var on: bool = _advanced_btn.button_pressed if _advanced_btn else not JuiceeEffect.advanced_enabled()
	ProjectSettings.set_setting(JuiceeEffect.ADVANCED_SETTING, on)
	ProjectSettings.save()
	# Rebuild whatever the props panel is currently showing.
	var sel := _selected_blocks()
	if sel.size() == 1:
		_show_props(sel[0])
	else:
		_show_props_placeholder()

## Lines the selected blocks up on one axis and spaces them evenly. Shift switches to a
## vertical column. Tidying a graph by hand is fiddly; this is one click and one undo.
func _align_selected() -> void:
	var blocks := _selected_blocks()
	if blocks.size() < 2:
		return
	var vertical := Input.is_key_pressed(KEY_SHIFT)
	# Sort along the axis being spread so blocks keep their reading order.
	blocks.sort_custom(func(a: JuiceeGraphBlock, b: JuiceeGraphBlock) -> bool:
		return (a.position_offset.y < b.position_offset.y) if vertical \
			else (a.position_offset.x < b.position_offset.x))

	# Average the cross-axis so the row sits where the group already was.
	var cross := 0.0
	for b in blocks:
		cross += b.position_offset.y if not vertical else b.position_offset.x
	cross /= float(blocks.size())

	var gap := 40.0 * JuiceeEditorUtil.EDSCALE
	var run := blocks[0].position_offset.y if vertical else blocks[0].position_offset.x

	if undo_redo:
		undo_redo.create_action("Juicee: Align Blocks")
	for b in blocks:
		# Worked out on the canvas, stored at 100%.
		var old_pos: Vector2 = b.position_offset / JuiceeEditorUtil.EDSCALE
		var new_pos: Vector2 = (Vector2(cross, run) if vertical else Vector2(run, cross)) / JuiceeEditorUtil.EDSCALE
		if undo_redo:
			undo_redo.add_do_method(self, "_ur_move_node", b.node_data.id, new_pos)
			undo_redo.add_undo_method(self, "_ur_move_node", b.node_data.id, old_pos)
		else:
			_ur_move_node(b.node_data.id, new_pos)
		run += (b.size.y if vertical else b.size.x) + gap
	if undo_redo:
		undo_redo.commit_action()
	_mark_dirty()

## Ctrl+F: jump to a block by name. On a graph with dozens of blocks, scrolling around
## hunting for one is the slow part; this filters as you type, then selects and centres
## the match so you land on it.
func _open_node_finder() -> void:
	if not _graph:
		return
	var blocks: Array[JuiceeGraphBlock] = []
	for c in _graph.get_children():
		if c is JuiceeGraphBlock:
			blocks.append(c as JuiceeGraphBlock)
	if blocks.is_empty():
		return

	var popup := PopupPanel.new()
	popup.size = Vector2(340, 380) * JuiceeEditorUtil.EDSCALE
	add_child(popup)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(4 * JuiceeEditorUtil.EDSCALE))
	popup.add_child(box)

	var search := LineEdit.new()
	search.placeholder_text = "Find block..."
	search.clear_button_enabled = true
	box.add_child(search)

	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(list)

	var shown: Array[JuiceeGraphBlock] = []

	var refill := func(query: String) -> void:
		list.clear()
		shown.clear()
		var q := query.strip_edges().to_lower()
		for b in blocks:
			var title := String(b.title)
			if q.is_empty() or title.to_lower().contains(q):
				list.add_item(title)
				shown.append(b)
		if list.item_count > 0:
			list.select(0)

	var jump := func() -> void:
		var sel := list.get_selected_items()
		if sel.is_empty() or sel[0] >= shown.size():
			return
		var target := shown[sel[0]]
		_deselect_all_blocks()
		target.selected = true
		_show_props(target)
		# Centre the view on the block: scroll_offset is in graph space, so offset by
		# half the viewport to put the block in the middle rather than the corner.
		_graph.scroll_offset = target.position_offset * _graph.zoom - _graph.size * 0.5 \
			+ target.size * _graph.zoom * 0.5
		popup.hide()

	search.text_changed.connect(func(t: String) -> void: refill.call(t))
	search.text_submitted.connect(func(_t: String) -> void: jump.call())
	list.item_activated.connect(func(_i: int) -> void: jump.call())
	search.gui_input.connect(func(event: InputEvent) -> void:
		var key := event as InputEventKey
		if not key or not key.pressed:
			return
		if key.keycode == KEY_DOWN or key.keycode == KEY_UP:
			if list.item_count == 0:
				return
			var sel := list.get_selected_items()
			var cur: int = sel[0] if not sel.is_empty() else 0
			cur = clampi(cur + (1 if key.keycode == KEY_DOWN else -1), 0, list.item_count - 1)
			list.select(cur)
			list.ensure_current_is_visible()
			search.accept_event()
		elif key.keycode == KEY_ESCAPE:
			popup.hide())
	popup.popup_hide.connect(func() -> void: popup.queue_free())

	refill.call("")
	popup.popup(Rect2i(Vector2i(get_screen_position() + size * 0.5 - popup.size * 0.5), Vector2i(popup.size)))
	search.grab_focus()

func _toggle_pan_mode() -> void:
	_pan_mode = _pan_btn.button_pressed
	if _pan_mode:
		_graph.mouse_default_cursor_shape = Control.CURSOR_DRAG
	else:
		_graph.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_is_panning = false

## Keyboard shortcuts for the graph panel, handled in _input (runs before the
## editor's global shortcuts):
##   • Alt+G          - toggle the JuiceeGraph bottom panel (works while hidden)
##   • Ctrl/Cmd+C/V/D - copy / paste / duplicate the selected blocks
## GraphEdit only emits its own copy/paste signals while it holds keyboard focus,
## which is rare in a bottom panel, so we drive them ourselves.
func _input(event: InputEvent) -> void:
	# Right-click a block -> context menu. Handled here (not via the block's own
	# gui_input) because an effect block's child controls consume the click first;
	# _input runs before GUI dispatch, so it sees the right-click regardless.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_try_block_context_menu()
		return
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	# Alt+G toggles the panel - must work even while the graph is hidden, so it is
	# deliberately NOT gated by _graph_is_active().
	if k.keycode == KEY_G and k.alt_pressed and not k.is_command_or_control_pressed() and not k.shift_pressed:
		_toggle_panel()
		get_viewport().set_input_as_handled()
		return
	# Escape - deselect everything (let an open popup consume its own Escape first).
	if k.keycode == KEY_ESCAPE and not k.is_command_or_control_pressed() and not k.alt_pressed and not k.shift_pressed:
		if is_instance_valid(_popup) and _popup.visible:
			return
		if _graph_is_active():
			_deselect_all_blocks()
			get_viewport().set_input_as_handled()
		return
	# Ctrl/Cmd shortcuts - only while actually working in the graph.
	if not k.is_command_or_control_pressed() or k.shift_pressed or k.alt_pressed:
		return
	if not _graph_is_active():
		return
	match k.keycode:
		KEY_F:
			_open_node_finder()
			get_viewport().set_input_as_handled()
		KEY_C:
			_on_copy_nodes_request()
			get_viewport().set_input_as_handled()
		KEY_V:
			_on_paste_nodes_request()
			get_viewport().set_input_as_handled()
		KEY_D:
			_on_duplicate_nodes_request()
			get_viewport().set_input_as_handled()
		KEY_X:
			_on_cut_nodes_request()
			get_viewport().set_input_as_handled()
		KEY_A:
			_select_all_blocks()
			get_viewport().set_input_as_handled()

## Set by JuiceePlugin so Alt+G can show/hide this bottom panel.
var host_plugin: EditorPlugin = null

func _toggle_panel() -> void:
	if not is_instance_valid(host_plugin):
		return
	if is_visible_in_tree():
		host_plugin.hide_bottom_panel()
	else:
		host_plugin.make_bottom_panel_item_visible(self)

## True when the graph panel should receive copy/paste shortcuts. Active when the
## graph is visible AND (focus is inside it, OR a block is selected, OR the mouse
## hovers the canvas). Never steals the shortcut while typing in a text field
## that lives outside the graph (props panel, search box).
func _graph_is_active() -> bool:
	if not is_instance_valid(_graph) or not _graph.is_visible_in_tree():
		return false
	var vp := _graph.get_viewport()
	var focus_owner: Control = (vp.gui_get_focus_owner() if vp else null)
	var owner_in_graph := focus_owner != null and (focus_owner == _graph or _graph.is_ancestor_of(focus_owner))
	# Typing in a text field outside the graph -> leave the shortcut alone.
	if (focus_owner is LineEdit or focus_owner is TextEdit) and not owner_in_graph:
		return false
	if owner_in_graph:
		return true
	if not _selected_blocks().is_empty():
		return true
	return _graph.get_global_rect().has_point(_graph.get_global_mouse_position())

func _on_graph_gui_input(event: InputEvent) -> void:
	if not _pan_mode:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_panning = event.pressed
			if event.pressed:
				_graph.mouse_default_cursor_shape = Control.CURSOR_DRAG
			else:
				_graph.mouse_default_cursor_shape = Control.CURSOR_DRAG
			_graph.accept_event()
	elif event is InputEventMouseMotion and _is_panning:
		_graph.scroll_offset -= event.relative
		_graph.accept_event()

func _zoom_to_fit() -> void:
	var blocks: Array[GraphNode] = []
	for c in _graph.get_children():
		if c is GraphNode:
			blocks.append(c)
	if blocks.is_empty():
		return
	var min_p := blocks[0].position_offset
	var max_p := blocks[0].position_offset + blocks[0].size
	for b in blocks:
		min_p.x = min(min_p.x, b.position_offset.x)
		min_p.y = min(min_p.y, b.position_offset.y)
		max_p.x = max(max_p.x, b.position_offset.x + b.size.x)
		max_p.y = max(max_p.y, b.position_offset.y + b.size.y)
	var bounds := max_p - min_p
	var padding := Vector2(40, 24) * JuiceeEditorUtil.EDSCALE
	var available: Vector2 = _graph.size - padding * 2.0
	if available.x <= 0 or available.y <= 0:
		return
	# Not below half size: in a short bottom panel a whole graph fits only at a zoom where no
	# block can be read, so a big graph is centred and scrolled instead.
	var zoom := clampf(minf(minf(available.x / bounds.x, available.y / bounds.y), 1.0), 0.5, 1.0)
	_graph.zoom = zoom
	var center := (min_p + max_p) * 0.5
	_graph.scroll_offset = center * zoom - _graph.size * 0.5

# ─── Block hover handlers ─────────────────────────────────────────────────────

func _on_block_hovered(block: JuiceeGraphBlock) -> void:
	_hovered_block = block
	if not is_instance_valid(hover_panel):
		return
	var data := block.node_data
	if data.type == "effect" and data.effect:
		hover_panel.call("show_for_effect", data.effect, block)
	else:
		var meta: Dictionary = JuiceeGraphBlock.BUILTIN_META.get(
			data.type, {"title": data.type, "sub": "", "color": Color.WHITE, "tip": ""})
		hover_panel.call("show_for_builtin",
			meta.get("title", data.type),
			meta.get("sub", ""),
			meta.get("tip", ""),
			meta.get("color", Color.WHITE),
			block)

func _on_block_unhovered(block: JuiceeGraphBlock) -> void:
	# Only schedule a hide if we're still on this block - if the mouse already
	# entered another block (enter-before-exit ordering), that block owns the panel
	# now and must not have its pending show cancelled by this stale exit.
	if _hovered_block == block:
		_hovered_block = null
		if is_instance_valid(hover_panel):
			hover_panel.call("schedule_hide")

func _on_graph_node_move_begin() -> void:
	_hovered_block = null
	if is_instance_valid(hover_panel):
		hover_panel.call("force_hide")

# ─── Live debugger callbacks (called from JuiceeDebuggerPlugin) ───────────────

func _debugger_on_block_fire(resource_path: String, node_id: String) -> void:
	if not _resource or _resource.resource_path != resource_path:
		return
	var block := _graph.get_node_or_null(NodePath(node_id)) as JuiceeGraphBlock
	if block:
		block.flash_debug()
		if is_instance_valid(hover_panel) and block == _hovered_block:
			var label := block.node_data.effect.get_display_name() if block.node_data.effect else block.node_data.type
			hover_panel.call("add_log_entry", "▶ %s fired" % label)

func _debugger_on_block_start(resource_path: String, node_id: String) -> void:
	if not _resource or _resource.resource_path != resource_path:
		return
	var block := _graph.get_node_or_null(NodePath(node_id)) as JuiceeGraphBlock
	if block:
		block.set_debug_active(true)
		if is_instance_valid(hover_panel) and block == _hovered_block:
			hover_panel.call("add_log_entry", "● Running...")

func _debugger_on_block_end(resource_path: String, node_id: String) -> void:
	if not _resource or _resource.resource_path != resource_path:
		return
	var block := _graph.get_node_or_null(NodePath(node_id)) as JuiceeGraphBlock
	if block:
		block.set_debug_active(false)
		if is_instance_valid(hover_panel) and block == _hovered_block:
			hover_panel.call("add_log_entry", "✓ Done")

# ─── Properties panel ────────────────────────────────────────────────────────
# Selecting a block is the editor's business, drawing its parameters is the
# panel's. These keep the two in step from one place, so every call site reads the
# same as it did before the panel moved out.

func _show_props(block: JuiceeGraphBlock) -> void:
	_selected_block = block
	_props.show_for(block)

func _show_props_placeholder() -> void:
	_props.show_placeholder()

func _clear_props() -> void:
	# Nothing selected is the placeholder's job; a bare title read as a panel that failed to load.
	_props.show_placeholder()
