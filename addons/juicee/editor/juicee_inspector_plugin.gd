@tool
class_name JuiceeInspectorPlugin
extends EditorInspectorPlugin

## Editor display scale (HiDPI). Every hardcoded pixel size multiplies by this
## so the UI matches the editor at 150%/200% display scale. 1.0 = no-op.
static var EDSCALE: float = (EditorInterface.get_editor_scale() if Engine.is_editor_hint() else 1.0)

const EFFECTS_DIR := "res://addons/juicee/effects/"
const BASE_EFFECT_FILE := "juicee_effect.gd"

# Passed in by plugin.gd at registration - used to wrap mutations so Ctrl+S
# sees the scene as dirty and undo/redo (Ctrl+Z) works as expected.
var undo_redo: EditorUndoRedoManager
## Reference to the JuiceeGraphEditor bottom panel - set by plugin.gd at registration.
## Used by the "Edit in Graph" button on JuiceePlayer to open the current sequence visually.
var graph_editor: Control
## Reference to the host EditorPlugin - needed for make_bottom_panel_item_visible
## (Godot 4.6 doesn't expose that method statically on EditorInterface).
var host_plugin: EditorPlugin
## Shared hover info-panel. Set by plugin.gd after both objects are created.
var hover_panel: Control = null

## Undo now fires `changed` on the sequence, which rebuilds the cards. Guards against
## a rebuild re-entering itself while the panel is mid-teardown.
var _rebuilding := false
## Effect resource -> its card Control, so Preview can pulse each card as it fires.
var _effect_cards: Dictionary = {}
## Effect resource -> whether its inline mini-editor foldout is open. Kept across the
## panel rebuilds so expanding a row doesn't snap shut on the next redraw.
var _expanded: Dictionary = {}

# Palette derived from the editor theme so this reads as a native inspector section
# rather than a separately-skinned box. Neutral greys off the editor base, and the
# editor's own accent instead of a loud brand orange. Falls back to neutral darks.
static var _ed_base: Color = _editor_color("base_color", Color(0.16, 0.16, 0.18))
static var COL_BG_HEADER: Color = _ed_base.lightened(0.02)
static var COL_BG_CARD: Color = _ed_base.lightened(0.04)
static var COL_BG_CARD_HOVER: Color = _ed_base.lightened(0.08)
static var COL_TEXT_BRIGHT: Color = _editor_color("font_color", Color(0.87, 0.89, 0.92))
static var COL_TEXT_DIM: Color = _editor_color("font_color", Color(0.87, 0.89, 0.92)).darkened(0.38)
static var COL_ACCENT: Color = _editor_color("accent_color", Color(0.55, 0.60, 0.72))

# Dimension badge colours - the blue Godot paints Node2D with, the red for Node3D.
const DIM_2D_COLOR := Color(0.45, 0.62, 0.99)
const DIM_3D_COLOR := Color(0.99, 0.45, 0.45)

static func _editor_color(name: String, fallback: Color) -> Color:
	if Engine.is_editor_hint():
		var et := EditorInterface.get_editor_theme()
		if et and et.has_color(name, "Editor"):
			return et.get_color(name, "Editor")
	return fallback

func _can_handle(object: Object) -> bool:
	return object is JuiceePlayer or object is JuiceeSequence

func _parse_begin(object: Object) -> void:
	# No custom "Juicee Player" / "Sequence" banner - Godot already labels the node and
	# the resource above, so a second styled header just reads as a foreign box.
	if object is JuiceePlayer:
		var player := object as JuiceePlayer
		add_custom_control(_build_preview_button(player))
		add_custom_control(_build_open_in_graph_button(player))

func _parse_property(object: Object, _type: int, name: String, _hint_type: int,
		_hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	# Replace the 'effects' Array with a custom card-based UI for JuiceeSequence.
	if object is JuiceeSequence and name == "effects":
		add_custom_control(_build_effects_panel(object as JuiceeSequence))
		return true
	return false

# --- "Preview Effect" button for JuiceePlayer --------------------------------
# Custom inspector button - supports Godot 4.2+ (the @export_tool_button macro
# alternative would require 4.4+, which we don't want to gate on).

func _build_preview_button(player: JuiceePlayer) -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", int(4 * EDSCALE))
	wrap.add_theme_constant_override("margin_bottom", int(2 * EDSCALE))

	var btn := Button.new()
	btn.text = "Preview Effect"
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.tooltip_text = "Run the assigned sequence on this node's parent (no need to launch the game)."
	btn.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	btn.pressed.connect(func() -> void:
		# Pulse each effect's card as it fires, mirroring the graph's live feedback.
		if player.sequence:
			for eff in player.sequence.effects:
				if eff and _effect_cards.has(eff):
					eff.started.connect(_pulse_card.bind(_effect_cards[eff]), CONNECT_ONE_SHOT)
		player.call("_editor_preview")
	)
	wrap.add_child(btn)
	return wrap

## Brief highlight flash on an effect card, matching JuiceeGraphBlock.pulse_highlight().
func _pulse_card(panel: Control) -> void:
	if not is_instance_valid(panel):
		return
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate", Color(1.35, 1.35, 1.35, 1.0), 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

# --- "Edit in Graph" button for JuiceePlayer ----------------------------------

func _build_open_in_graph_button(player: JuiceePlayer) -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", int(4 * EDSCALE))
	wrap.add_theme_constant_override("margin_bottom", int(4 * EDSCALE))

	var btn := Button.new()
	btn.text = "Edit in Graph"
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

# --- Custom 'effects' array panel - colored cards instead of generic Array UI -

func _build_effects_panel(seq: JuiceeSequence) -> Control:
	_effect_cards.clear()
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", int(4 * EDSCALE))
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

	# Section label with a live count, like GameFeelFlow's "Effects (N)".
	var sec_label := Label.new()
	sec_label.text = "Effects (%d)" % seq.effects.size()
	sec_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	root.add_child(sec_label)

	# Effect cards
	for i in seq.effects.size():
		var effect: JuiceeEffect = seq.effects[i]
		root.add_child(_build_effect_card(seq, effect, i, rebuild))

	# Empty hint
	if seq.effects.is_empty():
		var hint := Label.new()
		hint.text = "No effects yet."
		hint.add_theme_color_override("font_color", COL_TEXT_DIM)
		root.add_child(hint)

	# Add Effect button
	root.add_child(_build_add_button(seq, rebuild))

	if not seq.changed.is_connected(rebuild):
		seq.changed.connect(rebuild)
	_rebuilding = false

func _build_effect_card(seq: JuiceeSequence, effect: JuiceeEffect, index: int, rebuild: Callable) -> Control:
	# The wrapper holds the row and, when the foldout is open, the inline mini-editor
	# beneath it (row + body as one visual unit).
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var is_open: bool = bool(_expanded.get(effect, false)) if effect else false

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		_card_stylebox(effect.get_category_color() if effect else Color.GRAY))
	if effect:
		_effect_cards[effect] = panel
	wrap.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(6 * EDSCALE))
	panel.add_child(hbox)

	# Foldout triangle - opens the effect's properties inline (FEEL-style).
	var fold := Button.new()
	fold.flat = true
	fold.focus_mode = Control.FOCUS_NONE
	fold.custom_minimum_size = Vector2(16, 20) * EDSCALE
	fold.tooltip_text = "Collapse" if is_open else "Edit inline"
	var tri := _editor_icon("GuiTreeArrowDown" if is_open else "GuiTreeArrowRight")
	if tri:
		fold.icon = tri
	else:
		fold.text = "v" if is_open else ">"
		fold.add_theme_color_override("font_color", COL_TEXT_DIM)
	fold.pressed.connect(func() -> void:
		if effect:
			_expanded[effect] = not is_open
		rebuild.call())
	hbox.add_child(fold)

	# Name, expanding so the tags and timing sit to the right, one row, not stacked.
	var name_label := Label.new()
	name_label.text = effect.get_display_name() if effect else "(empty)"
	name_label.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(name_label)

	# Category word + dimension badge. The left stripe already carries the category
	# colour, so the word stays muted to match Godot's neutral rows.
	if effect:
		var script_path: String = (effect.get_script() as Script).resource_path
		var basename: String = script_path.get_file().get_basename()
		var cat: String = effect.get_category_name()
		if cat.is_empty():
			cat = JuiceeGraphEditor.EFFECT_CATEGORIES.get(basename, "")
		if not cat.is_empty():
			var cat_lbl := Label.new()
			cat_lbl.text = cat
			cat_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
			cat_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(cat_lbl)
		for dim in JuiceeGraphEditor.EFFECT_DIMENSIONS.get(basename, []):
			hbox.add_child(_make_dim_badge(dim))

	# Spacer pushes the actions + timing badge to the right edge.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Row actions - hidden until the row is hovered, so a resting list stays quiet.
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", int(1 * EDSCALE))
	acts.modulate = Color(1, 1, 1, 0)
	hbox.add_child(acts)

	var up_btn := _icon_button("^", "Move up", "ArrowUp")
	up_btn.disabled = index == 0
	up_btn.pressed.connect(func() -> void:
		_move_effect(seq, index, -1)
		rebuild.call())
	acts.add_child(up_btn)

	var down_btn := _icon_button("v", "Move down", "ArrowDown")
	down_btn.disabled = index == seq.effects.size() - 1
	down_btn.pressed.connect(func() -> void:
		_move_effect(seq, index, +1)
		rebuild.call())
	acts.add_child(down_btn)

	# Edit opens the effect in the main Inspector dock - the full native editor,
	# for the rare fields the inline mini-editor doesn't cover (curves, arrays).
	# Deferred: edit_resource rebuilds the inspector, which frees this very button
	# mid-`pressed` emission and crashes the editor (issue #5).
	var edit_btn := _icon_button("...", "Open in the main Inspector dock", "ExternalLink")
	edit_btn.pressed.connect(func() -> void: EditorInterface.edit_resource(effect),
		CONNECT_DEFERRED)
	acts.add_child(edit_btn)

	var del_btn := _icon_button("x", "Remove", "Remove")
	del_btn.add_theme_color_override("font_color", Color(0.78, 0.47, 0.46))
	del_btn.add_theme_color_override("icon_normal_color", Color(0.78, 0.47, 0.46))
	del_btn.pressed.connect(func() -> void:
		_remove_effect(seq, index)
		rebuild.call())
	acts.add_child(del_btn)

	# Timing badge - the effect's duration, right-aligned, tabular. FEEL's signature.
	var dur := _effect_duration(effect)
	if not dur.is_empty():
		hbox.add_child(_make_time_badge(dur))

	# Hover: surface the actions and the info panel.
	panel.mouse_entered.connect(func() -> void:
		if is_instance_valid(acts):
			acts.modulate = Color.WHITE
		if is_instance_valid(hover_panel) and is_instance_valid(effect) and is_instance_valid(panel):
			hover_panel.call("show_for_effect", effect, panel))
	panel.mouse_exited.connect(func() -> void:
		# Moving the cursor onto one of the row's own buttons also fires this exit -
		# the button grabs the hover. Only really hide once the cursor has left the
		# whole row rect, or the actions vanish exactly as you reach for them.
		if is_instance_valid(panel) and panel.get_global_rect().has_point(panel.get_global_mouse_position()):
			return
		if is_instance_valid(acts):
			acts.modulate = Color(1, 1, 1, 0)
		if is_instance_valid(hover_panel):
			hover_panel.call("schedule_hide"))

	# Inline mini-editor, only built when the foldout is open.
	if effect and is_open:
		wrap.add_child(_build_effect_editor(effect))

	return wrap

func _build_add_button(seq: JuiceeSequence, rebuild: Callable) -> Control:
	var btn := MenuButton.new()
	btn.text = "+ Add Effect"
	btn.flat = false
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var popup := btn.get_popup()
	popup.clear()

	var scripts := _scan_effect_scripts()
	# Build category -> [{id, script, label}] map.
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

# --- Inline mini-editor -------------------------------------------------------

## Builds the effect's editable properties as compact native rows under the card.
## Iterates the effect's own @export vars and picks a native widget per type; the
## rare types it can't render (curves, colour arrays) are left to the "..." dock button.
func _build_effect_editor(effect: JuiceeEffect) -> Control:
	var body := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.16)
	sb.content_margin_left = 22 * EDSCALE
	sb.content_margin_right = 8 * EDSCALE
	sb.content_margin_top = 5 * EDSCALE
	sb.content_margin_bottom = 8 * EDSCALE
	body.add_theme_stylebox_override("panel", sb)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(10 * EDSCALE))
	grid.add_theme_constant_override("v_separation", int(4 * EDSCALE))
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)

	var shown := 0
	var skipped := 0
	for p in effect.get_property_list():
		var usage: int = p["usage"]
		if not (usage & PROPERTY_USAGE_EDITOR):
			continue
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var pname: String = p["name"]
		# graph_position is where the graph editor parks the node - not a gameplay knob.
		if pname == "graph_position" or pname == "script":
			continue
		var field := _make_field(effect, p)
		if field == null:
			skipped += 1  # Curve / Array / sub-resource / Variant - dock-only.
			continue
		shown += 1

		var key := Label.new()
		key.text = String(pname).capitalize()
		key.add_theme_color_override("font_color", COL_TEXT_DIM)
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(key)

		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(field)

	if shown == 0:
		body.remove_child(grid)
		grid.queue_free()
		var note := Label.new()
		note.text = "No inline-editable fields - use the ... button."
		note.add_theme_color_override("font_color", COL_TEXT_DIM)
		body.add_child(note)
	elif skipped > 0:
		# A quiet footnote so a missing field doesn't read as a bug - it's a complex
		# type (curve, array, sub-resource) that lives in the full dock behind "...".
		var more := Label.new()
		more.text = "+ %d more in the ... dock" % skipped
		more.add_theme_color_override("font_color", COL_TEXT_DIM)
		var wrap_more := VBoxContainer.new()
		body.remove_child(grid)
		wrap_more.add_theme_constant_override("separation", int(4 * EDSCALE))
		wrap_more.add_child(grid)
		wrap_more.add_child(more)
		body.add_child(wrap_more)

	return body

## Picks a native editor widget for one property, or null for a type we don't
## render inline. Sets the current value BEFORE wiring the signal so the initial
## assignment doesn't fire a spurious (and self-cancelling) commit.
func _make_field(effect: JuiceeEffect, p: Dictionary) -> Control:
	var pname: String = p["name"]
	var ptype: int = p["type"]
	var hint: int = int(p.get("hint", 0))
	var hint_string: String = String(p.get("hint_string", ""))

	# Enum int -> dropdown.
	if ptype == TYPE_INT and hint == PROPERTY_HINT_ENUM:
		var ob := OptionButton.new()
		var idx := 0
		for opt in hint_string.split(",", false):
			ob.add_item(opt.strip_edges(), idx)
			idx += 1
		ob.selected = clampi(int(effect.get(pname)), 0, max(0, idx - 1))
		ob.item_selected.connect(func(sel: int) -> void: _commit_prop(effect, pname, sel))
		return ob

	match ptype:
		TYPE_BOOL:
			var cb := CheckButton.new()
			cb.button_pressed = bool(effect.get(pname))
			cb.toggled.connect(func(v: bool) -> void: _commit_prop(effect, pname, v))
			return cb
		TYPE_INT, TYPE_FLOAT:
			var spin := _make_spin(hint, hint_string, ptype == TYPE_INT)
			spin.value = float(effect.get(pname))
			var is_int := ptype == TYPE_INT
			spin.value_changed.connect(func(v: float) -> void:
				_commit_prop(effect, pname, (int(round(v)) if is_int else v)))
			return spin
		TYPE_COLOR:
			var cpb := ColorPickerButton.new()
			cpb.custom_minimum_size = Vector2(0, 18) * EDSCALE
			cpb.color = effect.get(pname)
			cpb.color_changed.connect(func(c: Color) -> void: _commit_prop(effect, pname, c))
			return cpb
		TYPE_VECTOR2:
			return _make_vector_field(effect, pname, hint, hint_string, 2)
		TYPE_VECTOR3:
			return _make_vector_field(effect, pname, hint, hint_string, 3)
		TYPE_STRING, TYPE_STRING_NAME:
			var le := LineEdit.new()
			le.text = String(effect.get(pname))
			le.custom_minimum_size = Vector2(120, 0) * EDSCALE
			var as_name := ptype == TYPE_STRING_NAME
			le.text_submitted.connect(func(t: String) -> void:
				_commit_prop(effect, pname, (StringName(t) if as_name else t)))
			le.focus_exited.connect(func() -> void:
				_commit_prop(effect, pname, (StringName(le.text) if as_name else le.text)))
			return le
		TYPE_NODE_PATH:
			# No inline node-picker, but a text field beats sending 19 effects to the
			# dock just to set a target. Type or paste the path.
			var np := LineEdit.new()
			np.text = String(effect.get(pname))
			np.placeholder_text = "node path"
			np.custom_minimum_size = Vector2(120, 0) * EDSCALE
			np.text_submitted.connect(func(t: String) -> void: _commit_prop(effect, pname, NodePath(t)))
			np.focus_exited.connect(func() -> void: _commit_prop(effect, pname, NodePath(np.text)))
			return np
	# Unhandled type (Curve, sub-resource, Array, Variant, ...) - the dock button covers it.
	return null

## One numeric editor configured from a PROPERTY_HINT_RANGE "min,max,step" string.
## EditorSpinSlider (the native inspector slider) can only be built inside the editor;
## outside it - a headless test - fall back to a plain SpinBox. Both extend Range, so
## the caller wires `value` / `value_changed` the same either way.
func _make_spin(hint: int, hint_string: String, is_int: bool) -> Range:
	var spin: Range = EditorSpinSlider.new() if Engine.is_editor_hint() else SpinBox.new()
	spin.custom_minimum_size = Vector2(120, 0) * EDSCALE
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if hint == PROPERTY_HINT_RANGE:
		var parts := hint_string.split(",", false)
		if parts.size() >= 2:
			spin.min_value = float(parts[0])
			spin.max_value = float(parts[1])
		if parts.size() >= 3:
			spin.step = float(parts[2])
		elif is_int:
			spin.step = 1.0
	else:
		# No range hint - give it room and a sensible step.
		spin.min_value = -99999.0
		spin.max_value = 99999.0
		spin.step = 1.0 if is_int else 0.01
		spin.allow_greater = true
		spin.allow_lesser = true
	spin.rounded = is_int
	return spin

## Vector2/Vector3 as a row of component spin sliders, each committing the whole vector.
func _make_vector_field(effect: JuiceeEffect, pname: String, hint: int, hint_string: String, dims: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(4 * EDSCALE))
	for a in dims:
		var spin := _make_spin(hint, hint_string, false)
		spin.custom_minimum_size = Vector2(52, 0) * EDSCALE
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var comp := a  # integer component index; Vector2/3 index reliably by int
		spin.value = float(effect.get(pname)[comp])
		spin.value_changed.connect(func(v: float) -> void:
			var cur = effect.get(pname)
			cur[comp] = v
			_commit_prop(effect, pname, cur))
		row.add_child(spin)
	return row

## Set one effect property through the undo manager so Ctrl+Z works and the scene
## dirties. MERGE_ENDS collapses a slider drag into a single undo step. No emit_changed
## here on purpose: the sequence doesn't listen to effect changes, so the panel does
## not rebuild and the open foldout survives the edit.
func _commit_prop(effect: JuiceeEffect, pname: String, new_value: Variant) -> void:
	var old_value: Variant = effect.get(pname)
	if old_value == new_value:
		return
	if undo_redo:
		undo_redo.create_action("Juicee: Set %s" % String(pname).capitalize(), UndoRedo.MERGE_ENDS)
		undo_redo.add_do_property(effect, pname, new_value)
		undo_redo.add_undo_property(effect, pname, old_value)
		undo_redo.commit_action()
	else:
		effect.set(pname, new_value)

# --- Mutations ----------------------------------------------------------------

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
	# Forget any foldout state for the effect we're dropping.
	if index < seq.effects.size() and seq.effects[index]:
		_expanded.erase(seq.effects[index])
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

# --- Undo/Redo wrapping -------------------------------------------------------

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

# --- Helpers ------------------------------------------------------------------

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

## Variant B: a quiet ~7% category wash behind the row plus the solid 2px stripe -
## FEEL's colour-coded list dialled down so it still reads as a native inspector row.
func _card_stylebox(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var tint := color
	tint.a = 0.07
	sb.bg_color = tint
	sb.border_color = color
	sb.border_width_left = maxi(2, int(2 * EDSCALE))
	sb.border_width_right = 0
	sb.border_width_top = 0
	sb.border_width_bottom = 0
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.content_margin_left = 8 * EDSCALE
	sb.content_margin_right = 6 * EDSCALE
	sb.content_margin_top = 3 * EDSCALE
	sb.content_margin_bottom = 3 * EDSCALE
	return sb

## Small bright pill carrying the 2D / 3D dimension, matching the graph's badges.
func _make_dim_badge(dim: String) -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = DIM_2D_COLOR if dim == "2d" else DIM_3D_COLOR
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	sb.content_margin_left = 4 * EDSCALE
	sb.content_margin_right = 4 * EDSCALE
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	pc.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = dim.to_upper()
	l.add_theme_color_override("font_color", Color(0.06, 0.07, 0.09))
	pc.add_child(l)
	return pc

## Right-aligned duration pill, e.g. "0.30s" - the rhythm of the sequence at a glance.
func _make_time_badge(text: String) -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = _ed_base.darkened(0.28)
	sb.border_color = _ed_base.darkened(0.45)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.content_margin_left = 6 * EDSCALE
	sb.content_margin_right = 6 * EDSCALE
	sb.content_margin_top = 1 * EDSCALE
	sb.content_margin_bottom = 1 * EDSCALE
	pc.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", COL_TEXT_DIM)
	pc.add_child(l)
	return pc

## The effect's duration for the timing badge. Prefers an explicit `duration`, then
## the other timing props effects use; returns "" when there's nothing meaningful.
func _effect_duration(effect: JuiceeEffect) -> String:
	if not effect:
		return ""
	for prop in ["duration", "lifetime", "hold", "pulse_interval", "interval"]:
		var v = effect.get(prop)
		if typeof(v) == TYPE_FLOAT and v > 0.0:
			return "%.2fs" % v
		if typeof(v) == TYPE_INT and v > 0:
			return "%.2fs" % float(v)
	return ""

func _icon_button(glyph: String, tooltip: String, editor_icon: String = "") -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(20, 20) * EDSCALE
	btn.focus_mode = Control.FOCUS_NONE
	# Prefer the editor's own icon so the row matches Godot's native array controls;
	# fall back to the text glyph if the theme doesn't have it.
	var tex := _editor_icon(editor_icon)
	if tex:
		btn.icon = tex
	else:
		btn.text = glyph
	return btn

func _editor_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty() or not Engine.is_editor_hint():
		return null
	var et := EditorInterface.get_editor_theme()
	if et and et.has_icon(icon_name, "EditorIcons"):
		return et.get_icon(icon_name, "EditorIcons")
	return null
