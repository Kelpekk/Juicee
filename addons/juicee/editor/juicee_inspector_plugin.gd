@tool
class_name JuiceeInspectorPlugin
extends EditorInspectorPlugin


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
## Debugger bridge, set by plugin.gd. Used to mirror parameter changes into a running
## game for live tuning. Typed loosely so this file never hard-depends on it existing.
var debugger_plugin: EditorDebuggerPlugin = null
## Whether a value change should also replay the effect in the running game. Kept on the
## plugin rather than per-panel so it survives selecting a different node.
var _refire_on_change: bool = false

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

## The player's buttons go under its own heading, with the properties they act on, rather
## than above everything at the top of the Inspector.
func _parse_category(object: Object, category: String) -> void:
	if object is JuiceePlayer and (category == "JuiceePlayer" or category == "juicee_player.gd"):
		var toolbar := _build_player_toolbar(object as JuiceePlayer)
		JuiceeEditorUtil.english_only(toolbar)
		add_custom_control(toolbar)

func _parse_property(object: Object, _type: int, name: String, _hint_type: int,
		_hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	# Replace the 'effects' Array with a custom card-based UI for JuiceeSequence.
	if object is JuiceeSequence and name == "effects":
		var panel := _build_effects_panel(object as JuiceeSequence)
		JuiceeEditorUtil.english_only(panel)
		add_custom_control(panel)
		return true
	return false

# --- "Preview Effect" button for JuiceePlayer --------------------------------
# Custom inspector button - supports Godot 4.2+ (the @export_tool_button macro
# alternative would require 4.4+, which we don't want to gate on).

## Preview and Edit in Graph share one row. Two full-width buttons stacked cost a whole
## row of height each, which is a lot of the panel before a single effect is listed.
func _build_player_toolbar(player: JuiceePlayer) -> Control:
	var box := MarginContainer.new()
	box.add_theme_constant_override("margin_top", int(2 * JuiceeEditorUtil.EDSCALE))
	box.add_theme_constant_override("margin_bottom", int(2 * JuiceeEditorUtil.EDSCALE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(4 * JuiceeEditorUtil.EDSCALE))
	box.add_child(row)
	row.add_child(_build_preview_button(player))
	row.add_child(_build_open_in_graph_button(player))
	return box

func _build_preview_button(player: JuiceePlayer) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = "Preview Effect"
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.tooltip_text = "Play a sequence on this player's target, Target Path or its parent,\nwithout running the game. With several sequences it asks which."
	btn.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	btn.disabled = _player_sequences(player).is_empty()
	btn.pressed.connect(func() -> void:
		_pick_sequence(player, btn, func(seq: JuiceeSequence) -> void: _preview_sequence(seq, player)))
	return btn

## Every sequence a player holds, the default first, each once.
func _player_sequences(player: JuiceePlayer) -> Array[JuiceeSequence]:
	var out: Array[JuiceeSequence] = []
	for s in [player.sequence] + player.sequences:
		if s and not out.has(s):
			out.append(s)
	return out

## Runs `then` on the player's only sequence, or on the one picked from a menu under `anchor`.
func _pick_sequence(player: JuiceePlayer, anchor: Control, then: Callable) -> void:
	var all := _player_sequences(player)
	if all.size() <= 1:
		if not all.is_empty():
			then.call(all[0])
		return
	var menu := PopupMenu.new()
	JuiceeEditorUtil.english_only(menu)
	for i in all.size():
		var nm := String(JuiceePlayer.name_of(all[i]))
		if nm.is_empty():
			nm = "(unnamed sequence %d)" % (i + 1)
		menu.add_item(nm + ("  (default)" if all[i] == player.sequence else ""), i)
	anchor.add_child(menu)
	menu.id_pressed.connect(func(id: int) -> void: then.call(all[id]))
	menu.popup_hide.connect(func() -> void: menu.queue_free())
	menu.popup(Rect2i(Vector2i(anchor.get_screen_position() + Vector2(0, anchor.size.y)), Vector2i.ZERO))

## Plays a sequence in the editor and lights up its rows as each effect fires, or flashes the
## row that warned. Hooks from an earlier preview are dropped first, since a one-shot hook
## stays behind when its effect never starts.
var _preview_hooks: Array = []

func _preview_sequence(seq: JuiceeSequence, player: JuiceePlayer = null) -> void:
	if not seq:
		return
	_clear_preview_hooks()
	for eff in seq.effects:
		if eff and _effect_cards.has(eff):
			_hook(eff.started, _pulse_card.bind(_effect_cards[eff]))
			_hook(eff.warning, _flash_card_warning.bind(_effect_cards[eff]))
	if not player:
		player = _player_for(seq)
	if player:
		player.call("_editor_preview", seq)
		return
	var root := EditorInterface.get_edited_scene_root()
	if root:
		JuiceeEffect.clear_editor_overlays(root)
		seq.play(root)

func _hook(sig: Signal, cb: Callable) -> void:
	sig.connect(cb, CONNECT_ONE_SHOT)
	_preview_hooks.append([sig, cb])

func _clear_preview_hooks() -> void:
	for h in _preview_hooks:
		var sig: Signal = h[0]
		if sig.get_object() and sig.is_connected(h[1]):
			sig.disconnect(h[1])
	_preview_hooks.clear()

## Plays one effect from its row, on the same node its sequence would play on.
func _preview_effect(seq: JuiceeSequence, effect: JuiceeEffect) -> void:
	if not effect:
		return
	var ctx := _preview_context(seq)
	if not ctx:
		return
	_clear_preview_hooks()
	if _effect_cards.has(effect):
		_hook(effect.started, _pulse_card.bind(_effect_cards[effect]))
		_hook(effect.warning, _flash_card_warning.bind(_effect_cards[effect]))
	var root := EditorInterface.get_edited_scene_root()
	if root:
		JuiceeEffect.clear_editor_overlays(root)
	effect.apply(ctx)

## The JuiceePlayer this sequence belongs to, when one is selected in the Scene dock.
func _player_for(seq: JuiceeSequence) -> JuiceePlayer:
	if not Engine.is_editor_hint():
		return null
	for n in EditorInterface.get_selection().get_selected_nodes():
		if n is JuiceePlayer and _player_sequences(n as JuiceePlayer).has(seq):
			return n as JuiceePlayer
	return null

## Where an effect of this sequence plays: its player's target, or the edited scene's root.
func _preview_context(seq: JuiceeSequence) -> Node:
	var player := _player_for(seq)
	if player:
		return player.call("_resolve_context")
	return EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null

## Brief highlight flash on an effect card, matching JuiceeGraphBlock.pulse_highlight().
func _pulse_card(panel: Control) -> void:
	if not is_instance_valid(panel):
		return
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate", Color(1.35, 1.35, 1.35, 1.0), 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Flags that an effect bailed out on a bad setup during Preview - an amber/red flash
## held much longer than the fire-pulse above (1.4s vs 0.35s), and the message rides
## the card's tooltip while the flash lasts. Matches JuiceeGraphBlock.flash_warning().
func _flash_card_warning(message: String, panel: Control) -> void:
	if not is_instance_valid(panel):
		return
	var prior_tooltip := panel.tooltip_text
	panel.tooltip_text = "⚠ " + message
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate", Color(2.0, 0.85, 0.6, 1.0), 0.06)\
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(panel, "modulate", Color.WHITE, 1.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if is_instance_valid(panel):
			panel.tooltip_text = prior_tooltip)

# --- "Edit in Graph" button for JuiceePlayer ----------------------------------

func _build_open_in_graph_button(player: JuiceePlayer) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = "Edit in Graph"
	btn.flat = false
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.tooltip_text = "Open a copy of a sequence as a straight graph in the JuiceeGraph panel.\nSave or Export Sequence there keeps it; the player's own sequence is left as it is."
	btn.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	btn.pressed.connect(func() -> void:
		if not graph_editor or not graph_editor.has_method("load_from_sequence"):
			push_warning("JuiceeInspectorPlugin: graph_editor reference not set")
			return
		_pick_sequence(player, btn, func(seq: JuiceeSequence) -> void:
			var nm := String(JuiceePlayer.name_of(seq))
			var label: String = "%s: %s" % [player.name, nm] if not nm.is_empty() else String(player.name)
			graph_editor.call("load_from_sequence", seq, label)
			# Show the JuiceeGraph bottom panel. This method lives on the EditorPlugin instance
			# in Godot 4.6 (calling it statically on EditorInterface throws a Parse Error).
			if host_plugin:
				host_plugin.make_bottom_panel_item_visible(graph_editor)))

	if _player_sequences(player).is_empty():
		btn.disabled = true
		btn.tooltip_text = "Assign a sequence first."

	return btn

# --- Custom 'effects' array panel - colored cards instead of generic Array UI -

func _build_effects_panel(seq: JuiceeSequence) -> Control:
	_effect_cards.clear()
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", int(1 * JuiceeEditorUtil.EDSCALE))
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
	# Same for a game starting or stopping, so the LIVE badge and Re-fire toggle appear
	# and disappear with it rather than only on the next reselect.
	var live_cb := func(_is_live: bool) -> void: holder["fn"].call()
	if debugger_plugin and not debugger_plugin.is_connected("live_state_changed", live_cb):
		debugger_plugin.connect("live_state_changed", live_cb)
	# Disconnect when root is freed so we don't leak signal handlers.
	root.tree_exiting.connect(func() -> void:
		if seq and seq.changed.is_connected(holder["fn"]):
			seq.changed.disconnect(holder["fn"])
		if debugger_plugin and debugger_plugin.is_connected("live_state_changed", live_cb):
			debugger_plugin.disconnect("live_state_changed", live_cb)
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

	# Header row: live count, the sequence's total runtime, and a shortcut to the
	# Advanced Properties project setting so the deeper knobs are one click away
	# instead of buried in Project Settings.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", int(6 * JuiceeEditorUtil.EDSCALE))
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header)

	# Count, runtime and muted count are one sentence about the sequence, so they read as
	# one quiet line rather than a strip of separate chips competing with each other.
	var muted_count := 0
	for e in seq.effects:
		if e and not e.enabled:
			muted_count += 1
	var parts: Array[String] = ["%d effects" % seq.effects.size()]
	var total := _sequence_duration(seq)
	if total > 0.0:
		parts.append("%.2fs" % total)
	if muted_count > 0:
		parts.append("%d muted" % muted_count)

	# Plays the whole sequence from here, next to what it is, as well as from the player's toolbar.
	var play := _icon_button(">", "Preview this sequence on its player's target\n(the scene's root when no player is selected)", "Play")
	play.disabled = seq.effects.is_empty()
	play.pressed.connect(func() -> void: _preview_sequence(seq))
	header.add_child(play)

	var sec_label := Label.new()
	sec_label.text = ", ".join(parts)
	sec_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	header.add_child(sec_label)

	var head_spacer := Control.new()
	head_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(head_spacer)

	# Every row open or every row shut, in one click.
	var any_open := false
	for e in seq.effects:
		if e and bool(_expanded.get(e, false)):
			any_open = true
	var fold_all := _icon_button("v" if any_open else ">", "Collapse every effect" if any_open else "Expand every effect",
			"GuiTreeArrowDown" if any_open else "GuiTreeArrowRight")
	fold_all.disabled = seq.effects.is_empty()
	fold_all.pressed.connect(func() -> void:
		for e in seq.effects:
			if e:
				_expanded[e] = not any_open
		rebuild.call())
	header.add_child(fold_all)

	# While a game is running, every value edited below is mirrored into it. Say so, and
	# offer the re-fire toggle here, or the whole thing is invisible and nobody finds it.
	if debugger_plugin and debugger_plugin.call("has_live_session"):
		header.add_child(_make_live_badge())
		var refire := CheckBox.new()
		refire.text = "Re-fire"
		refire.tooltip_text = "Replay the effect every time you change a value, so you feel\nthe change now instead of at its next natural trigger."
		refire.focus_mode = Control.FOCUS_NONE
		refire.button_pressed = _refire_on_change
		refire.toggled.connect(func(on: bool) -> void:
			_refire_on_change = on
			debugger_plugin.call("send_to_game", "juicee_tune:refire", [on]))
		header.add_child(refire)

	var adv := CheckBox.new()
	adv.text = "Advanced"
	adv.tooltip_text = "Project Settings > juicee > advanced_properties.\nReveals the deeper parameters on every effect."
	adv.focus_mode = Control.FOCUS_NONE
	adv.button_pressed = JuiceeEffect.advanced_enabled()
	adv.toggled.connect(func(on: bool) -> void:
		ProjectSettings.set_setting(JuiceeEffect.ADVANCED_SETTING, on)
		ProjectSettings.save()
		# Property visibility is cached per object, so nudge the whole panel.
		rebuild.call())
	header.add_child(adv)

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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var is_open: bool = bool(_expanded.get(effect, false)) if effect else false

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		_card_stylebox(effect.get_category_color() if effect else Color.TRANSPARENT))
	if effect:
		_effect_cards[effect] = panel
	box.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(6 * JuiceeEditorUtil.EDSCALE))
	panel.add_child(hbox)

	# Foldout triangle - opens the effect's properties inline (FEEL-style).
	var fold := Button.new()
	fold.flat = true
	fold.focus_mode = Control.FOCUS_NONE
	fold.custom_minimum_size = Vector2(14, 16) * JuiceeEditorUtil.EDSCALE
	fold.tooltip_text = "Collapse" if is_open else "Edit inline"
	var tri := JuiceeEditorUtil.editor_icon("GuiTreeArrowDown" if is_open else "GuiTreeArrowRight")
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
	# It truncates rather than setting a floor under the whole dock's width: a Label
	# reports its full text as its minimum size unless it is allowed to trim, and that
	# minimum is what stops the inspector being dragged narrower.
	var name_label := Label.new()
	name_label.text = effect.get_display_name() if effect else "(empty)"
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A muted step reads as greyed out, the way a disabled track does in a DAW.
	if effect and not effect.enabled:
		name_label.text += "  (muted)"
		name_label.add_theme_color_override("font_color", COL_TEXT_DIM)
		# The whole row, not only the name, the way a muted track greys out in a mixer.
		hbox.modulate.a = 0.55
	else:
		name_label.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(name_label)

	# Category word + dimension badge. The left stripe already carries the category
	# colour, so the word stays muted to match Godot's neutral rows.
	var cat := ""
	var badged := false
	if effect:
		var script_path: String = (effect.get_script() as Script).resource_path
		var basename: String = script_path.get_file().get_basename()
		cat = effect.get_category_name()
		if cat.is_empty():
			cat = JuiceeEffectCatalog.EFFECT_CATEGORIES.get(basename, "")
		# Marked only when the effect works in one dimension and the edited scene is the other.
		var dims: Array = JuiceeEffectCatalog.EFFECT_DIMENSIONS.get(basename, [])
		if dims.size() == 1 and String(dims[0]) != JuiceeEditorUtil.scene_dimension():
			hbox.add_child(_make_dim_badge(String(dims[0])))
			badged = true

	# Category and length share one quiet label, written the way the graph block writes them.
	# It does not trim: a trimming Label asks for 1 px, and next to the expanding name it vanished.
	var meta: Array[String] = []
	# A row with a dimension marker drops the category word, or the name is what gets cut.
	if not cat.is_empty() and not badged:
		meta.append(cat)
	var dur := _effect_duration(effect)
	if not dur.is_empty():
		meta.append(dur)
	if not meta.is_empty():
		var dur_lbl := Label.new()
		var full_meta := "  ·  ".join(meta)
		dur_lbl.text = full_meta
		dur_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		dur_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(dur_lbl)
		# The name comes first: in a narrow dock the category word goes, then the length.
		var steps: Array[String] = [full_meta]
		if meta.size() > 1:
			steps.append(meta[meta.size() - 1])
		steps.append("")
		# Stepped by the width the name label actually got, one step per resize.
		var state := {"step": 0}
		var fit := func() -> void:
			if not is_instance_valid(name_label) or not is_instance_valid(dur_lbl):
				return
			var font := name_label.get_theme_font("font")
			var fsize := name_label.get_theme_font_size("font_size")
			var gap := float(hbox.get_theme_constant("separation"))
			var width := func(s: String) -> float:
				return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + gap if not s.is_empty() else 0.0
			var natural := font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x \
					+ name_label.get_theme_stylebox("normal").get_minimum_size().x
			var step: int = state["step"]
			if name_label.size.x + 0.5 < natural and step < steps.size() - 1:
				step += 1
			elif step > 0 and name_label.size.x - natural >= width.call(steps[step - 1]) - width.call(steps[step]) + 1.0:
				step -= 1
			if step != state["step"]:
				state["step"] = step
				dur_lbl.text = steps[step]
				dur_lbl.visible = not steps[step].is_empty()
		name_label.resized.connect(fit)

	if effect:
		var prev := _icon_button(">", "Preview this effect", "Play")
		prev.pressed.connect(func() -> void: _preview_effect(seq, effect))
		hbox.add_child(prev)
		panel.gui_input.connect(func(event: InputEvent) -> void:
			var mb := event as InputEventMouseButton
			if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				_show_row_menu(seq, effect, index, rebuild, panel)
				panel.accept_event())
		panel.tooltip_text = "Drag to reorder, right-click for more"
		panel.set_drag_forwarding(
			_row_drag.bind(seq, index, effect),
			_row_can_drop.bind(seq, panel),
			_row_drop.bind(seq, index, rebuild))

	# Hover: lighten the row and show the info panel.
	var rest_sb := _card_stylebox(effect.get_category_color() if effect else Color.TRANSPARENT)
	var hover_sb := _card_stylebox(effect.get_category_color() if effect else Color.TRANSPARENT)
	hover_sb.bg_color = COL_BG_CARD_HOVER
	panel.mouse_entered.connect(func() -> void:
		if is_instance_valid(panel):
			panel.add_theme_stylebox_override("panel", hover_sb)
		if is_instance_valid(hover_panel) and is_instance_valid(effect) and is_instance_valid(panel):
			var player := _player_for(seq)
			hover_panel.call("show_for_effect", effect, panel,
					player.call("_resolve_context") if player else null, false))
	panel.mouse_exited.connect(func() -> void:
		if is_instance_valid(panel):
			panel.add_theme_stylebox_override("panel", rest_sb)
		if is_instance_valid(hover_panel):
			hover_panel.call("schedule_hide"))

	# Inline mini-editor, only built when the foldout is open. It carries the actions,
	# so a collapsed row builds no buttons at all.
	if effect and is_open:
		box.add_child(_build_effect_editor(effect,
			_build_action_bar(seq, effect, index, rebuild), seq))

	return box

## The per-effect toolbar. It sits at the top of the expanded body rather than in the
## row: in the row it had to appear on hover, which shifted the name as it came and
## kept six buttons' worth of width reserved on every row whether shown or not.
func _build_action_bar(seq: JuiceeSequence, effect: JuiceeEffect, index: int,
		rebuild: Callable) -> Control:
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", int(1 * JuiceeEditorUtil.EDSCALE))

	# Mute: silence one step while tuning without deleting and rebuilding it.
	var mute_btn := _icon_button("m", "Mute this effect", "GuiVisibilityVisible")
	if effect:
		var is_muted := not effect.enabled
		mute_btn.tooltip_text = "Unmute this effect" if is_muted else "Mute this effect"
		var mute_icon := JuiceeEditorUtil.editor_icon("GuiVisibilityHidden" if is_muted else "GuiVisibilityVisible")
		if mute_icon:
			mute_btn.icon = mute_icon
		else:
			mute_btn.text = "-" if is_muted else "m"
		mute_btn.pressed.connect(func() -> void:
			_toggle_mute(effect)
			rebuild.call())
	acts.add_child(mute_btn)

	var dup_btn := _icon_button("+", "Duplicate", "Duplicate")
	dup_btn.pressed.connect(func() -> void:
		_duplicate_effect(seq, index)
		rebuild.call())
	acts.add_child(dup_btn)

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
	var edit_btn := _icon_button("...", "Open this effect on its own in the Inspector", "ExternalLink")
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
	return acts

## Everything a row can do, under the right mouse button, whether the row is open or not.
func _show_row_menu(seq: JuiceeSequence, effect: JuiceeEffect, index: int, rebuild: Callable,
		anchor: Control) -> void:
	var menu := PopupMenu.new()
	JuiceeEditorUtil.english_only(menu)
	menu.add_item("Preview", 0)
	menu.add_item("Unmute" if not effect.enabled else "Mute", 1)
	menu.add_item("Duplicate", 2)
	menu.add_separator()
	menu.add_item("Move up", 3)
	menu.set_item_disabled(menu.get_item_index(3), index == 0)
	menu.add_item("Move down", 4)
	menu.set_item_disabled(menu.get_item_index(4), index == seq.effects.size() - 1)
	menu.add_separator()
	menu.add_item("Reset to defaults", 5)
	menu.add_item("Open in Inspector", 6)
	menu.add_separator()
	menu.add_item("Remove", 7)
	anchor.add_child(menu)
	menu.id_pressed.connect(_on_row_menu.bind(seq, effect, index, rebuild))
	menu.popup_hide.connect(func() -> void: menu.queue_free())
	menu.popup(Rect2i(Vector2i(DisplayServer.mouse_get_position()), Vector2i.ZERO))

func _on_row_menu(id: int, seq: JuiceeSequence, effect: JuiceeEffect, index: int, rebuild: Callable) -> void:
	match id:
		0:
			_preview_effect(seq, effect)
			return
		1:
			_toggle_mute(effect)
		2:
			_duplicate_effect(seq, index)
		3:
			_move_effect(seq, index, -1)
		4:
			_move_effect(seq, index, 1)
		5:
			_reset_effect(effect)
		6:
			EditorInterface.edit_resource.call_deferred(effect)
			return
		7:
			_remove_effect(seq, index)
	rebuild.call()

## Every setting back to what a new effect of this kind has, as one undo step. Where its block
## sits in a graph is kept.
func _reset_effect(effect: JuiceeEffect) -> void:
	var fresh = (effect.get_script() as Script).new()
	if not fresh:
		return
	var changes: Array = []
	for p in effect.get_property_list():
		var usage: int = p["usage"]
		if not (usage & PROPERTY_USAGE_STORAGE) or not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var pname: String = p["name"]
		if pname == "graph_position":
			continue
		var now: Variant = effect.get(pname)
		var was: Variant = fresh.get(pname)
		if now != was:
			changes.append([pname, now, was])
	if changes.is_empty():
		return
	if undo_redo:
		undo_redo.create_action("Juicee: Reset %s" % effect.get_display_name())
		for c in changes:
			undo_redo.add_do_property(effect, c[0], c[2])
			undo_redo.add_undo_property(effect, c[0], c[1])
		undo_redo.commit_action()
	else:
		for c in changes:
			effect.set(c[0], c[2])

## Drag a row by its name to move it. The data names the sequence, so a drop on another
## sequence's panel is refused rather than moving the effect between them.
func _row_drag(_at: Vector2, seq: JuiceeSequence, index: int, effect: JuiceeEffect) -> Variant:
	var preview := Label.new()
	preview.text = effect.get_display_name()
	preview.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	var base := EditorInterface.get_base_control()
	if base.get_viewport().gui_is_dragging():
		base.set_drag_preview(preview)
	else:
		preview.free()
	return {"type": "juicee_effect_row", "sequence": seq, "index": index}

func _row_can_drop(at: Vector2, data: Variant, seq: JuiceeSequence, panel: Control) -> bool:
	var ok: bool = typeof(data) == TYPE_DICTIONARY and data.get("type", "") == "juicee_effect_row" \
			and data.get("sequence") == seq
	if ok:
		_show_drop_line(panel, at.y > panel.size.y * 0.5)
	return ok

func _row_drop(at: Vector2, data: Variant, seq: JuiceeSequence, index: int, rebuild: Callable) -> void:
	_hide_drop_line()
	var from: int = int(data["index"])
	var panel := _drop_panel
	var to := index + (1 if is_instance_valid(panel) and at.y > panel.size.y * 0.5 else 0)
	if to > from:
		to -= 1
	if to == from or from < 0 or from >= seq.effects.size():
		return
	var before := _snapshot(seq)
	var after := _snapshot(seq)
	var moved: JuiceeEffect = after[from]
	after.remove_at(from)
	after.insert(clampi(to, 0, after.size()), moved)
	_apply_with_undo(seq, before, after, "Juicee: Reorder effects")
	rebuild.call()

## A line above or below the row a drag would land on.
var _drop_line: ColorRect = null
var _drop_panel: Control = null

func _show_drop_line(panel: Control, below: bool) -> void:
	if not is_instance_valid(_drop_line):
		_drop_line = ColorRect.new()
		_drop_line.color = COL_ACCENT
		_drop_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_drop_line.custom_minimum_size = Vector2(0, 2) * JuiceeEditorUtil.EDSCALE
	if _drop_line.get_parent() != panel:
		if _drop_line.get_parent():
			_drop_line.get_parent().remove_child(_drop_line)
		panel.add_child(_drop_line)
		_drop_line.set_as_top_level(true)
		if not panel.mouse_exited.is_connected(_hide_drop_line):
			panel.mouse_exited.connect(_hide_drop_line)
	_drop_panel = panel
	var r := panel.get_global_rect()
	_drop_line.global_position = Vector2(r.position.x, r.end.y - 1.0 if below else r.position.y - 1.0)
	_drop_line.size = Vector2(r.size.x, 2.0 * JuiceeEditorUtil.EDSCALE)
	_drop_line.visible = true

func _hide_drop_line() -> void:
	if is_instance_valid(_drop_line):
		_drop_line.visible = false

func _build_add_button(seq: JuiceeSequence, rebuild: Callable) -> Control:
	var btn := Button.new()
	btn.text = "+ Add Effect"
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 20) * JuiceeEditorUtil.EDSCALE
	btn.tooltip_text = "Search all effects by name or category"
	btn.pressed.connect(func() -> void:
		_open_effect_picker(seq, rebuild, btn))
	return btn

## Searchable effect picker. With 117 effects a nested submenu means hunting through
## eight categories; typing two letters is faster, so the list filters live and the
## keyboard drives it (Up/Down to move, Enter to add, Escape to close).
func _open_effect_picker(seq: JuiceeSequence, rebuild: Callable, anchor: Control) -> void:
	var popup := PopupPanel.new()
	popup.size = Vector2(400, 460) * JuiceeEditorUtil.EDSCALE
	anchor.add_child(popup)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(4 * JuiceeEditorUtil.EDSCALE))
	popup.add_child(box)

	var search := LineEdit.new()
	search.placeholder_text = "Search effects..."
	search.clear_button_enabled = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(search)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", int(1 * JuiceeEditorUtil.EDSCALE))
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var hint := Label.new()
	hint.text = JuiceeEditorUtil.PICKER_KEY_HINT
	hint.add_theme_color_override("font_color", COL_TEXT_DIM)
	box.add_child(hint)

	# Mutable state the lambdas share. GDScript lambdas capture by value, so whatever
	# they write to has to live in a container that is dereferenced when they run.
	var rows: Array = []          # {btn, wrap, entry, category, display}
	var headers: Array = []       # {btn, category}
	var nav: Array = []           # the rows the keyboard currently walks
	var order: Array = []         # every child in build order, for restoring after a search
	var cursor := [0]
	var expanded := {}

	var sel_sb := StyleBoxFlat.new()
	sel_sb.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.30)
	sel_sb.corner_radius_top_left = 3
	sel_sb.corner_radius_top_right = 3
	sel_sb.corner_radius_bottom_left = 3
	sel_sb.corner_radius_bottom_right = 3

	var paint := func() -> void:
		for i in nav.size():
			var btn: Button = nav[i]["btn"]
			if i == cursor[0]:
				btn.add_theme_stylebox_override("normal", sel_sb)
				# Keeps the highlight on screen while arrowing through a long list.
				scroll.ensure_control_visible(nav[i]["wrap"])
			else:
				btn.remove_theme_stylebox_override("normal")

	# What the keyboard walks: the visible rows, in the order they are laid out.
	var renav := func() -> void:
		nav.clear()
		for entry in rows:
			if (entry["wrap"] as Control).visible:
				nav.append(entry)
		cursor[0] = clampi(cursor[0], 0, maxi(0, nav.size() - 1))
		paint.call()

	var entries := _picker_entries()
	var by_cat := {}
	for e in entries:
		var c := String(e["category"])
		if not by_cat.has(c):
			by_cat[c] = []
		(by_cat[c] as Array).append(e)

	# Same section order as the graph's popup, with anything unexpected after it.
	var cats: Array = []
	for c in JuiceeEffectCatalog.CATEGORY_ORDER:
		if by_cat.has(c):
			cats.append(c)
	for c in by_cat:
		if not cats.has(c):
			cats.append(c)

	var refold := func() -> void:
		for h in headers:
			var cat := String(h["category"])
			var open: bool = bool(expanded.get(cat, false))
			(h["btn"] as Button).text = JuiceeEditorUtil.picker_header_text(
				cat, open, (by_cat[cat] as Array).size())
		for entry in rows:
			(entry["wrap"] as Control).visible = bool(expanded.get(String(entry["category"]), false))

	for cat in cats:
		expanded[cat] = false
		var head := Button.new()
		head.flat = true
		head.focus_mode = Control.FOCUS_NONE
		head.alignment = HORIZONTAL_ALIGNMENT_LEFT
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.tooltip_text = JuiceeEditorUtil.PICKER_HEADER_TIP
		var head_font := JuiceeEditorUtil.editor_font("bold")
		if head_font:
			head.add_theme_font_override("font", head_font)
		list.add_child(head)
		order.append(head)
		headers.append({"btn": head, "category": cat})
		var this_cat := String(cat)
		head.pressed.connect(func() -> void:
			expanded[this_cat] = not bool(expanded.get(this_cat, false))
			refold.call()
			renav.call())

		for e in by_cat[cat]:
			var row := _picker_row(e, String(cat), rows, seq, rebuild, popup,
				cursor, nav, paint)
			list.add_child(row)
			order.append(row)

	# Search ranks with the graph popup's scoring, so both lists agree on what counts
	# as a close match instead of each growing its own idea of it.
	var apply_query := func(text: String) -> void:
		var q := text.strip_edges().to_lower()
		if q.is_empty():
			for i in order.size():
				list.move_child(order[i], i)
			for h in headers:
				(h["btn"] as Control).visible = true
			for entry in rows:
				(entry["btn"].get_meta("rtl") as RichTextLabel).text = String(entry["display"])
			refold.call()
			renav.call()
			return

		# Headers make no sense over a ranked list that cuts across categories.
		for h in headers:
			(h["btn"] as Control).visible = false
		var scored: Array = []
		for entry in rows:
			var btn: Button = entry["btn"]
			var score := JuiceeGraphEditor._match_score(q,
				String(btn.get_meta("label")), String(btn.get_meta("search_text")))
			(entry["wrap"] as Control).visible = score > 0
			if score > 0:
				scored.append([score, entry])
				(btn.get_meta("rtl") as RichTextLabel).text = \
					JuiceeGraphEditor._highlight_bbcode(String(entry["display"]), q)
		scored.sort_custom(func(a, b) -> bool: return a[0] > b[0])
		for i in scored.size():
			list.move_child(scored[i][1]["wrap"], i)
		cursor[0] = 0
		renav.call()

	var commit := func() -> void:
		if cursor[0] >= nav.size():
			return
		_add_effect_from_script(seq, nav[cursor[0]]["entry"]["script"])
		popup.hide()
		rebuild.call()

	search.text_changed.connect(func(t: String) -> void: apply_query.call(t))
	search.text_submitted.connect(func(_t: String) -> void: commit.call())

	search.gui_input.connect(func(event: InputEvent) -> void:
		var key := event as InputEventKey
		if not key or not key.pressed:
			return
		if key.keycode == KEY_DOWN or key.keycode == KEY_UP:
			if nav.is_empty():
				return
			cursor[0] = clampi(cursor[0] + (1 if key.keycode == KEY_DOWN else -1),
				0, nav.size() - 1)
			paint.call()
			search.accept_event()
		elif key.keycode == KEY_ESCAPE:
			popup.hide())

	popup.popup_hide.connect(func() -> void: popup.queue_free())

	# Opens with the first category unfolded, so the popup never reads as an empty box.
	if not cats.is_empty():
		expanded[String(cats[0])] = true
	refold.call()
	renav.call()

	var origin := anchor.get_screen_position() + Vector2(0, anchor.size.y)
	popup.popup(Rect2i(Vector2i(origin), Vector2i(popup.size)))
	search.grab_focus()

## One pickable row: a colour stripe for the category, and a flat button whose label is
## drawn by a RichTextLabel so the matched characters can be bolded in place.
func _picker_row(e: Dictionary, cat: String, rows: Array, seq: JuiceeSequence,
		rebuild: Callable, popup: PopupPanel, cursor: Array, nav: Array,
		paint: Callable) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", int(6 * JuiceeEditorUtil.EDSCALE))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var stripe := ColorRect.new()
	stripe.color = e["color"]
	stripe.custom_minimum_size = Vector2(5, 18) * JuiceeEditorUtil.EDSCALE
	stripe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(stripe)

	var label := String(e["label"])
	var btn := Button.new()
	btn.text = ""  # drawn by the RichTextLabel below, so matches can be bolded
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 24) * JuiceeEditorUtil.EDSCALE
	btn.set_meta("label", label.to_lower())
	# Searched text spans the name, the description and the category, so "impact",
	# "camera" or "shake" all lead somewhere.
	btn.set_meta("search_text",
		(label + " " + String(e["tooltip"]) + " " + cat).to_lower())
	if not String(e["tooltip"]).is_empty():
		btn.tooltip_text = "%s\n\n%s" % [label, e["tooltip"]]
	box.add_child(btn)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.scroll_active = false
	rtl.fit_content = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The editor theme gives RichTextLabel a filled "normal" stylebox for doc panels;
	# clear it or every row draws inside a box.
	rtl.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	rtl.set_anchors_preset(Control.PRESET_FULL_RECT)
	rtl.offset_left = 4 * JuiceeEditorUtil.EDSCALE
	rtl.offset_top = 4 * JuiceeEditorUtil.EDSCALE
	rtl.text = label
	btn.add_child(rtl)
	btn.set_meta("rtl", rtl)

	# The same 2D / 3D tags as the graph's popup, so both pickers say which effects are restricted.
	for dim in e.get("dims", []):
		var icon_rect := JuiceeGraphEditor.dimension_tag_icon(dim, cat, 18)
		if icon_rect:
			box.add_child(icon_rect)

	var entry := {"btn": btn, "wrap": box, "entry": e, "category": cat, "display": label}
	rows.append(entry)

	btn.pressed.connect(func() -> void:
		_add_effect_from_script(seq, e["script"])
		popup.hide()
		rebuild.call())
	# Mouse and keyboard share one cursor, so hovering a row moves the highlight to it.
	btn.mouse_entered.connect(func() -> void:
		var i := nav.find(entry)
		if i >= 0:
			cursor[0] = i
			paint.call())
	return box

## Every effect script as a pickable row, sorted by category then name so the
## unfiltered list still reads in a sensible order.
func _picker_entries() -> Array:
	var out: Array = []
	for script: Script in _scan_effect_scripts():
		var inst = script.new()
		if not inst or not (inst is JuiceeEffect):
			continue
		var eff := inst as JuiceeEffect
		var basename: String = (script.resource_path as String).get_file().get_basename()
		var cat: String = eff.get_category_name()
		if cat.is_empty():
			cat = JuiceeEffectCatalog.EFFECT_CATEGORIES.get(basename, "Misc")
		var desc := eff.get_description()
		if desc.is_empty():
			desc = JuiceeEffectCatalog.EFFECT_DESCRIPTIONS.get(basename, "")
		out.append({
			"label": eff.get_display_name(),
			"category": cat,
			"color": eff.get_category_color(),
			"tooltip": desc,
			"script": script,
			"dims": JuiceeEffectCatalog.restrictive_dims(basename),
		})
	out.sort_custom(func(a, b) -> bool:
		if a["category"] == b["category"]:
			return String(a["label"]) < String(b["label"])
		return String(a["category"]) < String(b["category"]))
	return out

# --- Inline mini-editor -------------------------------------------------------

## Builds the effect's editable properties as compact rows under the card, one native widget
## per type; the kinds it cannot draw are a button that opens them in the Inspector.
func _build_effect_editor(effect: JuiceeEffect, actions: Control = null, seq: JuiceeSequence = null) -> Control:
	var docs: Dictionary = JuiceeEditorUtil.property_docs(effect.get_script() as Script)
	var body := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.16)
	sb.border_color = effect.get_category_color().darkened(0.2)
	sb.border_width_left = maxi(2, int(2 * JuiceeEditorUtil.EDSCALE))
	sb.content_margin_left = 12 * JuiceeEditorUtil.EDSCALE
	sb.content_margin_right = 6 * JuiceeEditorUtil.EDSCALE
	sb.content_margin_top = 3 * JuiceeEditorUtil.EDSCALE
	sb.content_margin_bottom = 6 * JuiceeEditorUtil.EDSCALE
	body.add_theme_stylebox_override("panel", sb)

	# Everything stacks in one column so the actions sit above the fields.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(3 * JuiceeEditorUtil.EDSCALE))
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(col)
	if actions:
		col.add_child(actions)
		col.add_child(HSeparator.new())

	# Sections follow the groups the effect declares (Advanced, Randomization,
	# Cooldown). Flattening them, which is what this did before, ran an effect's own
	# parameters straight into chance and cooldown with nothing marking the seam.
	var shown := 0
	var grid: GridContainer = null
	var group := ""

	for p in effect.get_property_list():
		var usage: int = p["usage"]
		# A category starts a fresh scope: the base class's properties are not part of
		# whatever group the effect's own list ended on.
		if usage & PROPERTY_USAGE_CATEGORY:
			group = ""
			grid = null
			continue
		if usage & PROPERTY_USAGE_GROUP:
			group = String(p["name"])
			grid = null
			continue
		if usage & PROPERTY_USAGE_SUBGROUP:
			continue
		if not (usage & PROPERTY_USAGE_EDITOR):
			continue
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var pname: String = p["name"]
		# graph_position is where the graph editor parks the node - not a gameplay knob.
		# enabled is the mute button in the bar above; a second control for it here
		# would be the same switch twice.
		if pname == "graph_position" or pname == "script" or pname == "enabled":
			continue
		var field := _make_field(effect, p, seq)
		if field == null:
			# A curve, an array, a sub-resource or a Variant: shown for what it holds, and
			# opened in the Inspector at that field, where Godot's own editors do them.
			field = JuiceeEditorUtil.inspector_field_button(effect, pname)
		shown += 1

		# Sections open on their first real property, so a group whose properties are
		# all hidden or unrenderable leaves no stray header behind.
		if grid == null:
			if group != "" and group != "Resource":
				col.add_child(_section_header(group))
			grid = GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", int(6 * JuiceeEditorUtil.EDSCALE))
			grid.add_theme_constant_override("v_separation", int(4 * JuiceeEditorUtil.EDSCALE))
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(grid)

		var key := Label.new()
		key.text = String(pname).capitalize()
		# Ellipsis alone drops a Label's minimum width to 1px, and a GridContainer sizes
		# a column to the largest minimum in it - so trimming every name collapses the
		# whole name column and the fields eat the row. It needs a floor of its own, and
		# room to expand so a wide dock still shows names in full.
		key.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		key.custom_minimum_size = Vector2(72, 0) * JuiceeEditorUtil.EDSCALE
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# What the parameter does, from its docstring, without opening the effect on its own.
		var doc := String(docs.get(pname, ""))
		key.tooltip_text = key.text + ("\n\n" + doc if not doc.is_empty() else "")
		key.mouse_filter = Control.MOUSE_FILTER_PASS
		key.add_theme_color_override("font_color", COL_TEXT_DIM)
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(key)

		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(field)

	if shown == 0:
		var note := Label.new()
		note.text = "Nothing to set on this effect."
		note.add_theme_color_override("font_color", COL_TEXT_DIM)
		col.add_child(note)

	return body

## A group heading inside the inline editor. Dim, spaced above, and set apart from the
## property names below it so the eye can skip a whole section.
func _section_header(text: String) -> Control:
	var box := MarginContainer.new()
	box.add_theme_constant_override("margin_top", int(6 * JuiceeEditorUtil.EDSCALE))
	var l := Label.new()
	l.text = text.to_upper()
	# Dim, not accent-coloured: a heading is structure, and structure is carried by the
	# spacing above it and by being upper-case. Colour here would be one more hue in a
	# panel whose whole problem was competing hues.
	l.add_theme_color_override("font_color", COL_TEXT_DIM)
	box.add_child(l)
	return box

## Picks a native editor widget for one property, or null for a type we don't
## render inline. Sets the current value BEFORE wiring the signal so the initial
## assignment doesn't fire a spurious (and self-cancelling) commit.
func _make_field(effect: JuiceeEffect, p: Dictionary, seq: JuiceeSequence = null) -> Control:
	var pname: String = p["name"]
	var ptype: int = p["type"]
	var hint: int = int(p.get("hint", 0))
	var hint_string: String = String(p.get("hint_string", ""))

	# Enum int -> dropdown. Items carry the enum's values as ids, which need not be 0, 1, 2.
	if ptype == TYPE_INT and hint == PROPERTY_HINT_ENUM:
		var ob := OptionButton.new()
		# Sized by the field, not by its longest item, or the dropdown takes the name column.
		ob.fit_to_longest_item = false
		ob.clip_text = true
		for entry in JuiceeEditorUtil.enum_entries(hint_string):
			ob.add_item(entry[0], entry[1])
		var at := ob.get_item_index(int(effect.get(pname)))
		ob.selected = maxi(at, 0)
		ob.item_selected.connect(func(sel: int) -> void: _commit_prop(effect, pname, ob.get_item_id(sel)))
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
				_commit_prop(effect, pname, ((int(round(v)) as Variant) if is_int else (v as Variant))))
			return spin
		TYPE_COLOR:
			var cpb := ColorPickerButton.new()
			cpb.custom_minimum_size = Vector2(0, 18) * JuiceeEditorUtil.EDSCALE
			cpb.color = effect.get(pname)
			cpb.color_changed.connect(func(c: Color) -> void: _commit_prop(effect, pname, c))
			return cpb
		TYPE_VECTOR2:
			return _make_vector_field(effect, pname, hint, hint_string, 2)
		TYPE_VECTOR3:
			return _make_vector_field(effect, pname, hint, hint_string, 3)
		TYPE_STRING, TYPE_STRING_NAME:
			# A string carrying an enum hint is a fixed set of choices - an audio bus,
			# say - so offer the list instead of a field to mistype into.
			if hint == PROPERTY_HINT_ENUM:
				return _make_string_enum(effect, pname, hint_string,
					ptype == TYPE_STRING_NAME)
			if hint == PROPERTY_HINT_MULTILINE_TEXT:
				var box := TextEdit.new()
				box.text = String(effect.get(pname))
				box.custom_minimum_size = Vector2(72, 48) * JuiceeEditorUtil.EDSCALE
				box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
				box.focus_exited.connect(func() -> void: _commit_prop(effect, pname, box.text))
				return box
			var le := LineEdit.new()
			le.text = String(effect.get(pname))
			le.custom_minimum_size = Vector2(72, 0) * JuiceeEditorUtil.EDSCALE
			var as_name := ptype == TYPE_STRING_NAME
			le.text_submitted.connect(func(t: String) -> void:
				_commit_prop(effect, pname, ((StringName(t) as Variant) if as_name else (t as Variant))))
			le.focus_exited.connect(func() -> void:
				_commit_prop(effect, pname, ((StringName(le.text) as Variant) if as_name else (le.text as Variant))))
			return le
		TYPE_NODE_PATH:
			# Drop a node from the Scene dock, or type. A dropped path is written relative to
			# the node the effect plays on, which is what it resolves against.
			var np := JuiceeNodePathField.new()
			np.text = String(effect.get(pname))
			np.placeholder_text = "drag a node here"
			np.custom_minimum_size = Vector2(72, 0) * JuiceeEditorUtil.EDSCALE
			np.base_node = _preview_context(seq) if seq else null
			for t in hint_string.split(",", false):
				if ClassDB.class_exists(t.strip_edges()):
					np.accepted_types.append(t.strip_edges())
			np.path_changed.connect(func(path: NodePath) -> void: _commit_prop(effect, pname, path))
			return np
	# A curve, a sub-resource, an array or a Variant: the caller shows it as a button.
	return null

## Dropdown for a string property with an enum hint. The item text is only a label:
## the value written back is the hint entry, so a blank entry (meaning "none") can be
## shown as something readable without storing that text.
func _make_string_enum(effect: JuiceeEffect, pname: String, hint_string: String,
		as_name: bool) -> OptionButton:
	var ob := OptionButton.new()
	var opts := hint_string.split(",")
	var current := String(effect.get(pname))
	var sel := -1
	for i in opts.size():
		ob.add_item("(none)" if opts[i].is_empty() else opts[i], i)
		if opts[i] == current:
			sel = i
	if sel < 0:
		# The stored value is gone from the list - a bus that was renamed or deleted.
		# Keep it as its own entry rather than silently snapping to the first bus, which
		# would rewrite the effect just for opening the foldout.
		ob.add_item("%s (missing)" % current, opts.size())
		sel = opts.size()
	ob.selected = sel
	ob.item_selected.connect(func(i: int) -> void:
		if i >= opts.size():
			return
		_commit_prop(effect, pname, ((StringName(opts[i]) as Variant) if as_name else (opts[i] as Variant))))
	return ob

## One numeric editor configured from a PROPERTY_HINT_RANGE "min,max,step" string.
## EditorSpinSlider (the native inspector slider) can only be built inside the editor;
## outside it - a headless test - fall back to a plain SpinBox. Both extend Range, so
## the caller wires `value` / `value_changed` the same either way.
func _make_spin(hint: int, hint_string: String, is_int: bool) -> Range:
	var spin: Range = (EditorSpinSlider.new() as Range) if Engine.is_editor_hint() else (SpinBox.new() as Range)
	spin.custom_minimum_size = Vector2(72, 0) * JuiceeEditorUtil.EDSCALE
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
	row.add_theme_constant_override("separation", int(4 * JuiceeEditorUtil.EDSCALE))
	for a in dims:
		var spin := _make_spin(hint, hint_string, false)
		# Room for "0.5" in each of three, in a dock of ordinary width.
		spin.custom_minimum_size = Vector2(50, 0) * JuiceeEditorUtil.EDSCALE
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
	_push_live(effect, pname, new_value)

## Mirrors a parameter change into a running game, so the change can be felt without
## relaunching. Every inline field commits through _commit_prop, so hooking it here
## covers the whole editor rather than each widget type separately.
##
## The effect's own resource_path is the address: an effect saved inside a sequence
## carries a sub-resource path, and load() on that path in the running game returns the
## very instance that is about to fire. An effect built in code has no path and simply
## is not tunable, which is why this returns quietly rather than warning.
func _push_live(effect: JuiceeEffect, pname: String, value: Variant) -> void:
	if not debugger_plugin or not is_instance_valid(effect):
		return
	if effect.resource_path.is_empty():
		return
	debugger_plugin.call("send_to_game", "juicee_tune:set", [effect.resource_path, pname, value])

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

## Flips an effect's mute state through the undo stack, so Ctrl+Z restores it.
func _toggle_mute(effect: JuiceeEffect) -> void:
	if not effect:
		return
	var was: bool = effect.enabled
	if undo_redo:
		undo_redo.create_action("Juicee: %s effect" % ("Unmute" if was == false else "Mute"))
		undo_redo.add_do_property(effect, "enabled", not was)
		undo_redo.add_undo_property(effect, "enabled", was)
		undo_redo.commit_action()
	else:
		effect.enabled = not was

## Duplicates one effect and drops the copy directly under the original, which is how
## you build a layered hit (two shakes at different strengths) without starting over.
func _duplicate_effect(seq: JuiceeSequence, index: int) -> void:
	if not seq or index < 0 or index >= seq.effects.size():
		return
	var src: JuiceeEffect = seq.effects[index]
	if not src:
		return
	# Deep copy so the clone owns its own values instead of aliasing the original.
	var copy: JuiceeEffect = src.duplicate(true)
	var before := _snapshot(seq)
	var after := _snapshot(seq)
	after.insert(index + 1, copy)
	_apply_with_undo(seq, before, after, "Juicee: Duplicate Effect")

## How long the sequence takes end to end. Sequential runs await each effect in turn, so
## that is the sum; parallel fires them together offset by stagger_delay, so it is the
## latest finish. Muted effects are skipped either way, matching what play() does.
func _sequence_duration(seq: JuiceeSequence) -> float:
	var total := 0.0
	var index := 0
	for e in seq.effects:
		if not e or not e.enabled:
			continue
		var d := JuiceeEditorUtil.play_length(e)
		if "delay" in e:
			d += float(e.delay)
		if seq.parallel:
			# Each effect starts one stagger step after the previous one.
			total = maxf(total, float(index) * seq.stagger_delay + d)
		else:
			total += d
		index += 1
	return total

## Typed, because `effects` is an Array[JuiceeEffect]: assigning a plain Array to it is
## silently ignored, and an undo built on one would look like it did nothing.
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
	return JuiceeEditorUtil.effect_scripts(EFFECTS_DIR, BASE_EFFECT_FILE)

## A row: the card's background, and a thin stripe in the category colour, darkened so it
## reads as an accent rather than a lit strip. Washes of colour across the row are kept for
## state: the pulse when a step fires, the warning flash.
func _card_stylebox(color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG_CARD
	if color.a > 0.0:
		sb.border_color = color.darkened(0.2)
		sb.border_width_left = maxi(2, int(2 * JuiceeEditorUtil.EDSCALE))
	else:
		sb.border_color = _ed_base.darkened(0.25)
		sb.border_width_left = 0
	sb.border_width_right = 0
	sb.border_width_top = 0
	sb.border_width_bottom = 0
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.content_margin_left = 8 * JuiceeEditorUtil.EDSCALE
	sb.content_margin_right = 6 * JuiceeEditorUtil.EDSCALE
	sb.content_margin_top = 1 * JuiceeEditorUtil.EDSCALE
	sb.content_margin_bottom = 1 * JuiceeEditorUtil.EDSCALE
	return sb

## Marks an effect that only works in one dimension. Tinted text rather than a filled
## pill: it is metadata sitting next to the name, and a solid block of colour on every
## row out-shouts the names, which are the only thing anyone is actually reading.
func _make_dim_badge(dim: String) -> Control:
	var l := Label.new()
	l.text = dim.to_upper() + " only"
	l.add_theme_color_override("font_color",
		(DIM_2D_COLOR if dim == "2d" else DIM_3D_COLOR).darkened(0.25))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.tooltip_text = "This effect only works on %s nodes." % dim.to_upper()
	return l

## Marks that a game is running and edits are being mirrored into it. A status light,
## not a headline: as a filled green pill it was the brightest thing in the panel,
## louder than the effect names it sits above.
func _make_live_badge() -> Control:
	var l := Label.new()
	l.text = "live"
	l.add_theme_color_override("font_color", Color(0.42, 0.72, 0.50))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.tooltip_text = "A game is running. Values you change here are pushed to it live."
	return l

## The effect's length for its row, from the same function as the graph block; "" when it has none.
func _effect_duration(effect: JuiceeEffect) -> String:
	return JuiceeEditorUtil.play_length_text(effect)

func _icon_button(glyph: String, tooltip: String, editor_icon: String = "") -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(18, 16) * JuiceeEditorUtil.EDSCALE
	btn.focus_mode = Control.FOCUS_NONE
	# Prefer the editor's own icon so the row matches Godot's native array controls;
	# fall back to the text glyph if the theme doesn't have it.
	var tex := JuiceeEditorUtil.editor_icon(editor_icon)
	if tex:
		btn.icon = tex
	else:
		btn.text = glyph
	return btn

