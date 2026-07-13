@tool
class_name JuiceeInspectorPlugin
extends EditorInspectorPlugin

## Editor display scale (HiDPI). Every hardcoded pixel size multiplies by this
## so the UI matches the editor at 150%/200% display scale. 1.0 = no-op.
static var EDSCALE: float = (EditorInterface.get_editor_scale() if Engine.is_editor_hint() else 1.0)

const EFFECTS_DIR := "res://addons/juicee/effects/"
const BASE_EFFECT_FILE := "juicee_effect.gd"

# Passed in by plugin.gd at registration — used to wrap mutations so Ctrl+S
# sees the scene as dirty and undo/redo (Ctrl+Z) works as expected.
var undo_redo: EditorUndoRedoManager
## Reference to the JuiceeGraphEditor bottom panel — set by plugin.gd at registration.
## Used by the "Edit in Graph" button on JuiceePlayer to open the current sequence visually.
var graph_editor: Control
## Reference to the host EditorPlugin — needed for make_bottom_panel_item_visible
## (Godot 4.6 doesn't expose that method statically on EditorInterface).
var host_plugin: EditorPlugin
## Shared hover info-panel. Set by plugin.gd after both objects are created.
var hover_panel: Control = null

## Undo now fires `changed` on the sequence, which rebuilds the cards. Guards against
## a rebuild re-entering itself while the panel is mid-teardown.
var _rebuilding := false

const COL_BG_HEADER := Color(0.11, 0.12, 0.16)
const COL_BG_CARD := Color(0.13, 0.14, 0.18)
const COL_BG_CARD_HOVER := Color(0.16, 0.17, 0.22)
const COL_TEXT_DIM := Color(0.55, 0.58, 0.65)
const COL_TEXT_BRIGHT := Color(0.92, 0.94, 0.97)
const COL_ACCENT := Color(0.95, 0.42, 0.21)

func _can_handle(object: Object) -> bool:
	return object is JuiceePlayer or object is JuiceeSequence

func _parse_begin(object: Object) -> void:
	if object is JuiceePlayer:
		var player := object as JuiceePlayer
		add_custom_control(_build_player_header(player))
		add_custom_control(_build_preview_button(player))
		add_custom_control(_build_open_in_graph_button(player))
	elif object is JuiceeSequence:
		add_custom_control(_build_sequence_header(object as JuiceeSequence))

func _parse_property(object: Object, _type: int, name: String, _hint_type: int,
		_hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	# Replace the 'effects' Array with a custom card-based UI for JuiceeSequence.
	if object is JuiceeSequence and name == "effects":
		add_custom_control(_build_effects_panel(object as JuiceeSequence))
		return true
	return false

# ─── Header for JuiceePlayer ──────────────────────────────────────────────────

func _build_player_header(player: JuiceePlayer) -> Control:
	var count := 0
	if player.sequence:
		count = player.sequence.effects.size()
	var subtitle := "%d effect%s in sequence" % [count, "" if count == 1 else "s"]
	return _build_header("Juicee Player", subtitle, "")

# ─── "Preview Effect" button for JuiceePlayer ────────────────────────────────
# Custom inspector button — supports Godot 4.2+ (the @export_tool_button macro
# alternative would require 4.4+, which we don't want to gate on).

func _build_preview_button(player: JuiceePlayer) -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", int(4 * EDSCALE))
	wrap.add_theme_constant_override("margin_bottom", int(2 * EDSCALE))

	var btn := Button.new()
	btn.text = "▶  Preview Effect"
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.tooltip_text = "Run the assigned sequence on this node's parent (no need to launch the game)."
	btn.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	btn.pressed.connect(func() -> void:
		player.call("_editor_preview")
	)
	wrap.add_child(btn)
	return wrap

# ─── "Edit in Graph" button for JuiceePlayer ──────────────────────────────────

func _build_open_in_graph_button(player: JuiceePlayer) -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", int(4 * EDSCALE))
	wrap.add_theme_constant_override("margin_bottom", int(4 * EDSCALE))

	var btn := Button.new()
	btn.text = "📝  Edit Sequence in Graph"
	btn.flat = false
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.tooltip_text = "Loads this player's sequence as a fresh linear graph in the JuiceeGraph\nbottom panel for visual editing. Click Save / Export Sequence there to persist."
	btn.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	btn.pressed.connect(func() -> void:
		if not player.sequence:
			push_warning("JuiceePlayer: no sequence to open in graph editor")
			return
		if not graph_editor:
			push_warning("JuiceeInspectorPlugin: graph_editor reference not set")
			return
		if not graph_editor.has_method("load_from_sequence"):
			push_warning("JuiceeInspectorPlugin: graph editor missing load_from_sequence method")
			return
		var label: String = player.name if player.name else "sequence"
		graph_editor.call("load_from_sequence", player.sequence, label)
		# Show the JuiceeGraph bottom panel. This method lives on the EditorPlugin instance
		# in Godot 4.6 (calling it statically on EditorInterface throws a Parse Error).
		if host_plugin:
			host_plugin.make_bottom_panel_item_visible(graph_editor)
	)

	# Disabled state hint if no sequence assigned
	if not player.sequence:
		btn.disabled = true
		btn.tooltip_text = "Assign a sequence first."

	wrap.add_child(btn)
	return wrap

# ─── Header for JuiceeSequence ────────────────────────────────────────────────

func _build_sequence_header(seq: JuiceeSequence) -> Control:
	var mode := "parallel" if seq.parallel else "sequential"
	var subtitle := "%d effects · %s" % [seq.effects.size(), mode]
	return _build_header("Sequence", subtitle, "")

# ─── Shared elegant header ───────────────────────────────────────────────────

func _build_header(title_text: String, subtitle_text: String, icon_path: String) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG_HEADER
	sb.border_color = COL_ACCENT
	sb.border_width_left = maxi(1, int(2 * EDSCALE))
	sb.content_margin_left = 8 * EDSCALE
	sb.content_margin_right = 8 * EDSCALE
	sb.content_margin_top = 4 * EDSCALE
	sb.content_margin_bottom = 4 * EDSCALE
	panel.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(6 * EDSCALE))
	panel.add_child(hbox)

	var tex := _try_load_texture(icon_path)
	if tex:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(14, 14) * EDSCALE
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon)

	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	title.add_theme_font_size_override("font_size", int(11 * EDSCALE))
	hbox.add_child(title)

	if not subtitle_text.is_empty():
		var subtitle := Label.new()
		subtitle.text = " · " + subtitle_text
		subtitle.add_theme_color_override("font_color", COL_TEXT_DIM)
		subtitle.add_theme_font_size_override("font_size", int(10 * EDSCALE))
		subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(subtitle)

	return panel

# ─── Custom 'effects' array panel — colored cards instead of generic Array UI ─

func _build_effects_panel(seq: JuiceeSequence) -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", int(6 * EDSCALE))
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Dictionary box workaround: lambdas capture by value at definition time,
	# so a self-referencing var Callable would be null inside the lambda body.
	# A dictionary entry is dereferenced dynamically, breaking the cycle.
	var holder: Dictionary = {}
	holder["fn"] = func() -> void:
		if is_instance_valid(root):
			_populate_effects_panel(root, seq, holder["fn"])
	_populate_effects_panel(root, seq, holder["fn"])

	# Auto-refresh cards when the sequence changes externally (load, undo, etc).
	if not seq.changed.is_connected(holder["fn"]):
		seq.changed.connect(holder["fn"])
	# Disconnect when root is freed so we don't leak signal handlers.
	root.tree_exiting.connect(func() -> void:
		if seq and seq.changed.is_connected(holder["fn"]):
			seq.changed.disconnect(holder["fn"])
	)
	return root

func _populate_effects_panel(root: VBoxContainer, seq: JuiceeSequence, rebuild: Callable) -> void:
	if _rebuilding:
		return
	_rebuilding = true

	# Clear immediately (not queue_free, which is deferred).
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()

	# Section label
	var sec_label := Label.new()
	sec_label.text = "EFFECTS"
	sec_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	sec_label.add_theme_font_size_override("font_size", int(10 * EDSCALE))
	root.add_child(sec_label)

	# Effect cards
	for i in seq.effects.size():
		var effect: JuiceeEffect = seq.effects[i]
		root.add_child(_build_effect_card(seq, effect, i, rebuild))

	# Empty hint
	if seq.effects.is_empty():
		var hint := Label.new()
		hint.text = "(no effects yet — click '+ Add Effect' below)"
		hint.add_theme_color_override("font_color", COL_TEXT_DIM)
		hint.add_theme_font_size_override("font_size", int(11 * EDSCALE))
		root.add_child(hint)

	# Add Effect button
	root.add_child(_build_add_button(seq, rebuild))

	if not seq.changed.is_connected(rebuild):
		seq.changed.connect(rebuild)
	_rebuilding = false

func _build_effect_card(seq: JuiceeSequence, effect: JuiceeEffect, index: int, rebuild: Callable) -> Control:
	var panel := PanelContainer.new()
	var sb := _card_stylebox(effect.get_category_color() if effect else Color.GRAY)
	panel.add_theme_stylebox_override("panel", sb)

	# Hover info panel wiring — shows description + live preview on mouse-over.
	if is_instance_valid(hover_panel) and effect:
		panel.mouse_entered.connect(func() -> void:
			if is_instance_valid(hover_panel) and is_instance_valid(effect) and is_instance_valid(panel):
				hover_panel.call("show_for_effect", effect, panel)
		)
		panel.mouse_exited.connect(func() -> void:
			if is_instance_valid(hover_panel):
				hover_panel.call("schedule_hide")
		)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(10 * EDSCALE))
	panel.add_child(hbox)

	# Drag-handle / index
	var idx_label := Label.new()
	idx_label.text = "%d" % (index + 1)
	idx_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	idx_label.add_theme_font_size_override("font_size", int(11 * EDSCALE))
	idx_label.custom_minimum_size = Vector2(16, 0) * EDSCALE
	hbox.add_child(idx_label)

	# Icon
	var icon_path := effect.get_icon_path() if effect else ""
	var tex := _try_load_texture(icon_path)
	if tex:
		var tex_rect := TextureRect.new()
		tex_rect.texture = tex
		tex_rect.custom_minimum_size = Vector2(22, 22) * EDSCALE
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(tex_rect)

	# Name + type info
	var label_box := VBoxContainer.new()
	label_box.add_theme_constant_override("separation", int(0 * EDSCALE))
	label_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label_box)

	var name_label := Label.new()
	name_label.text = effect.get_display_name() if effect else "(empty)"
	name_label.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	name_label.add_theme_font_size_override("font_size", int(12 * EDSCALE))
	label_box.add_child(name_label)

	# Category + dimension tags under the name
	if effect:
		var script_path: String = (effect.get_script() as Script).resource_path
		var basename: String = script_path.get_file().get_basename()
		var cat: String = effect.get_category_name()
		if cat.is_empty():
			cat = JuiceeGraphEditor.EFFECT_CATEGORIES.get(basename, "")
		var dims: Array = JuiceeGraphEditor.EFFECT_DIMENSIONS.get(basename, [])
		if not cat.is_empty() or not dims.is_empty():
			var tag_row := HBoxContainer.new()
			tag_row.add_theme_constant_override("separation", int(4 * EDSCALE))
			label_box.add_child(tag_row)
			if not cat.is_empty():
				var cat_lbl := Label.new()
				cat_lbl.text = cat
				cat_lbl.add_theme_font_size_override("font_size", int(9 * EDSCALE))
				cat_lbl.add_theme_color_override("font_color",
					effect.get_category_color().lightened(0.1).darkened(0.1))
				tag_row.add_child(cat_lbl)
			for dim in dims:
				var dim_lbl := Label.new()
				dim_lbl.text = dim.to_upper()
				dim_lbl.add_theme_font_size_override("font_size", int(9 * EDSCALE))
				dim_lbl.add_theme_color_override("font_color", Color(0.5, 0.58, 0.75, 0.8))
				tag_row.add_child(dim_lbl)

	# Move up
	var up_btn := _icon_button("▲", "Move up")
	up_btn.disabled = index == 0
	up_btn.pressed.connect(func() -> void:
		_move_effect(seq, index, -1)
		rebuild.call()
	)
	hbox.add_child(up_btn)

	# Move down
	var down_btn := _icon_button("▼", "Move down")
	down_btn.disabled = index == seq.effects.size() - 1
	down_btn.pressed.connect(func() -> void:
		_move_effect(seq, index, +1)
		rebuild.call()
	)
	hbox.add_child(down_btn)

	# Edit (opens in a separate Inspector dock). Deferred: edit_resource rebuilds the
	# inspector, which frees this very button mid-`pressed` emission and crashes the
	# editor (issue #5).
	var edit_btn := _icon_button("✎", "Edit properties (opens in Inspector)")
	edit_btn.pressed.connect(func() -> void: EditorInterface.edit_resource(effect),
		CONNECT_DEFERRED)
	hbox.add_child(edit_btn)

	# Delete
	var del_btn := _icon_button("✕", "Remove")
	del_btn.add_theme_color_override("font_color", Color(0.92, 0.32, 0.32))
	del_btn.pressed.connect(func() -> void:
		_remove_effect(seq, index)
		rebuild.call()
	)
	hbox.add_child(del_btn)

	return panel

func _build_add_button(seq: JuiceeSequence, rebuild: Callable) -> Control:
	var btn := MenuButton.new()
	btn.text = "+ Add Effect"
	btn.flat = false
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var popup := btn.get_popup()
	popup.clear()

	var scripts := _scan_effect_scripts()
	# Build category → [{id, script, label}] map.
	var by_cat: Dictionary = {}
	for cat in JuiceeGraphEditor.CATEGORY_ORDER:
		by_cat[cat] = []
	by_cat["Misc"] = []

	var id_to_script: Dictionary = {}
	var next_id := 0
	for script: Script in scripts:
		var inst = script.new()
		if not inst or not (inst is JuiceeEffect):
			continue
		var eff := inst as JuiceeEffect
		var label: String = eff.get_display_name()
		var basename: String = (script.resource_path as String).get_file().get_basename()
		var cat: String = eff.get_category_name()
		if cat.is_empty():
			cat = JuiceeGraphEditor.EFFECT_CATEGORIES.get(basename, "Misc")
		if not by_cat.has(cat):
			cat = "Misc"
		by_cat[cat].append({"id": next_id, "script": script, "label": label})
		id_to_script[next_id] = script
		next_id += 1

	for cat in JuiceeGraphEditor.CATEGORY_ORDER:
		var items: Array = by_cat.get(cat, [])
		if items.is_empty():
			continue
		var suppopup := PopupMenu.new()
		for item in items:
			suppopup.add_item(item["label"], item["id"])
		suppopup.id_pressed.connect(func(id: int) -> void:
			if id_to_script.has(id):
				_add_effect_from_script(seq, id_to_script[id])
				rebuild.call())
		popup.add_submenu_node_item(cat, suppopup)
	var misc_items: Array = by_cat.get("Misc", [])
	if not misc_items.is_empty():
		var suppopup2 := PopupMenu.new()
		for item in misc_items:
			suppopup2.add_item(item["label"], item["id"])
		suppopup2.id_pressed.connect(func(id: int) -> void:
			if id_to_script.has(id):
				_add_effect_from_script(seq, id_to_script[id])
				rebuild.call())
		popup.add_submenu_node_item("Misc", suppopup2)

	return btn

# ─── Mutations ────────────────────────────────────────────────────────────────

func _add_effect_from_script(seq: JuiceeSequence, script: Script) -> void:
	var inst = script.new()
	if not inst is JuiceeEffect:
		return
	var effect: JuiceeEffect = inst
	var snapshot: Array[JuiceeEffect] = _snapshot(seq)
	var new_state: Array[JuiceeEffect] = snapshot.duplicate()
	new_state.append(effect)
	_apply_with_undo(seq, snapshot, new_state, "Juicee: Add %s" % effect.get_display_name())

func _remove_effect(seq: JuiceeSequence, index: int) -> void:
	if index < 0 or index >= seq.effects.size():
		return
	var snapshot: Array[JuiceeEffect] = _snapshot(seq)
	var new_state: Array[JuiceeEffect] = snapshot.duplicate()
	new_state.remove_at(index)
	_apply_with_undo(seq, snapshot, new_state, "Juicee: Remove effect")

func _move_effect(seq: JuiceeSequence, index: int, delta: int) -> void:
	var target_idx := index + delta
	if target_idx < 0 or target_idx >= seq.effects.size():
		return
	var snapshot: Array[JuiceeEffect] = _snapshot(seq)
	var new_state: Array[JuiceeEffect] = snapshot.duplicate()
	var effect: JuiceeEffect = new_state[index]
	new_state.remove_at(index)
	new_state.insert(target_idx, effect)
	_apply_with_undo(seq, snapshot, new_state, "Juicee: Reorder effects")

# ─── Undo/Redo wrapping ───────────────────────────────────────────────────────

## Typed, because `effects` is an Array[JuiceeEffect]: assigning a plain Array to it
## is silently ignored, and the undo below would look like it did nothing.
func _snapshot(seq: JuiceeSequence) -> Array[JuiceeEffect]:
	var arr: Array[JuiceeEffect] = []
	for e in seq.effects:
		arr.append(e)
	return arr

func _apply_with_undo(seq: JuiceeSequence, before: Array[JuiceeEffect],
		after: Array[JuiceeEffect], action_name: String) -> void:
	if undo_redo:
		# Every entry has to name `seq` and nothing else. The editor decides which undo
		# history an action belongs to from the objects that action touches, and the
		# plugin belongs to no scene while the sequence does. Naming both is what raised
		# "UndoRedo history mismatch: expected 0, got 1" on add/remove/reorder.
		undo_redo.create_action(action_name)
		undo_redo.add_do_property(seq, "effects", after)
		undo_redo.add_undo_property(seq, "effects", before)
		# The cards redraw on `changed` (see _build_effects_panel), so undo has to fire it.
		undo_redo.add_do_method(seq, "emit_changed")
		undo_redo.add_undo_method(seq, "emit_changed")
		undo_redo.commit_action()
	else:
		# Fallback if plugin wasn't given undo_redo for some reason.
		seq.effects = after
		seq.emit_changed()

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _scan_effect_scripts() -> Array[Script]:
	var result: Array[Script] = []
	var dir := DirAccess.open(EFFECTS_DIR)
	if not dir:
		return result
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".gd") and f != BASE_EFFECT_FILE:
			var script := load(EFFECTS_DIR + f) as Script
			if script and script.can_instantiate():
				result.append(script)
		f = dir.get_next()
	dir.list_dir_end()
	return result

func _try_load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _card_stylebox(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG_CARD
	sb.border_color = color
	sb.border_width_left = maxi(1, int(3 * EDSCALE))
	sb.border_width_right = maxi(1, int(0 * EDSCALE))
	sb.border_width_top = maxi(1, int(0 * EDSCALE))
	sb.border_width_bottom = maxi(1, int(0 * EDSCALE))
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 10 * EDSCALE
	sb.content_margin_right = 8 * EDSCALE
	sb.content_margin_top = 8 * EDSCALE
	sb.content_margin_bottom = 8 * EDSCALE
	return sb

func _icon_button(text: String, tooltip: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(22, 22) * EDSCALE
	btn.focus_mode = Control.FOCUS_NONE
	return btn
