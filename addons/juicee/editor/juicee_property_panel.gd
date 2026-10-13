@tool
class_name JuiceePropertyPanel
## Builds the parameter editors on the right-hand side of the graph, straight from
## an effect's @export list: sliders, spin boxes, colour pickers, enums, vectors.
##
## Six hundred and seventy-five lines of widget building that had nothing to do
## with editing a graph, inside the file that edits graphs. It reached back into
## the host for a handful of things, so those are signals now rather than calls, and
## the panel owns no editor state beyond the containers it fills.
extends RefCounted

## An edit happened and the graph should be marked unsaved.
signal changed
## The Delete button on a block's parameter panel was pressed.
signal delete_requested(block: JuiceeGraphBlock)
## An effect parameter was written. The graph editor mirrors it into a running game,
## the same way the Inspector does.
signal property_committed(effect: JuiceeEffect, property: String, value: Variant)
## An undo or redo rewrote a parameter, so the widgets showing it are stale.
signal rebuild_requested(effect: JuiceeEffect)

## Set by the graph editor. Undo entries register against the editor's own manager,
## so Ctrl+Z covers a slider drag the same as it covers moving a block.
var undo_redo: EditorUndoRedoManager = null
## The container the editors are built into, and the header above it.
var content: VBoxContainer = null
var title: Label = null
## Needed to look a block up by id when a builtin node edits another one.
var graph: GraphEdit = null


## Every widget writes a parameter through here. There were fourteen scattered
## effect.set() calls before, with nowhere common to hook, which is why live tuning
## reached the Inspector but never the graph.
func _commit(effect: JuiceeEffect, property: String, value: Variant) -> void:
	effect.set(property, value)
	changed.emit()
	property_committed.emit(effect, property, value)

## A write that Ctrl+Z can take back. Consecutive edits to one property merge into one step,
## so dragging a vector field is one undo rather than one per frame.
func _commit_undoable(effect: JuiceeEffect, property: String, value: Variant) -> void:
	var old: Variant = effect.get(property)
	_commit(effect, property, value)
	if undo_redo and old != value:
		undo_redo.create_action("Change " + property.capitalize(), UndoRedo.MERGE_ENDS, effect)
		undo_redo.add_do_method(self, "_ur_set_effect_property", effect, property, value)
		undo_redo.add_undo_method(self, "_ur_set_effect_property", effect, property, old)
		undo_redo.commit_action(false)

## Undo entries name this object as their target, so the write itself has to live
## here. Redrawing is left to the graph editor, which is the side that knows which
## block is on screen.
func _ur_set_effect_property(effect: JuiceeEffect, prop_name: String, value: Variant) -> void:
	_commit(effect, prop_name, value)
	rebuild_requested.emit(effect)


func show_for(block: JuiceeGraphBlock) -> void:
	clear()
	var data := block.node_data

	var title_color := Color.WHITE
	if data.type == "effect" and data.effect:
		title.text = data.effect.get_display_name()
		title_color = data.effect.get_category_color()
		_build_props_for_effect(data.effect)
	else:
		title.text = data.type.capitalize()
		var meta: Dictionary = JuiceeGraphBlock.BUILTIN_META.get(data.type, {})
		if meta.has("color"):
			title_color = meta["color"]
		_build_props_for_builtin(data)
	# Tint title with category color - matches Godot's inspector header tint.
	title.modulate = title_color

	content.add_child(HSeparator.new())
	var del_btn := Button.new()
	del_btn.text = "Delete Node"
	del_btn.pressed.connect(func() -> void: delete_requested.emit(block))
	content.add_child(del_btn)

func show_placeholder() -> void:
	clear()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(8 * JuiceeEditorUtil.EDSCALE))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A little top room so the hint sits down from the header, not jammed against it.
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 36) * JuiceeEditorUtil.EDSCALE
	box.add_child(pad)
	var icon_tex := JuiceeEditorUtil.editor_icon("GraphEdit")
	if not icon_tex:
		icon_tex = JuiceeEditorUtil.editor_icon("Edit")
	if icon_tex:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.custom_minimum_size = Vector2(28, 28) * JuiceeEditorUtil.EDSCALE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.modulate = Color(1, 1, 1, 0.3)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon_rect)
	var lbl := Label.new()
	lbl.text = "Select a node to edit its properties"
	lbl.modulate = Color(1, 1, 1, 0.5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(lbl)
	content.add_child(box)

func _build_props_for_builtin(data: JuiceeGraphNodeData) -> void:
	match data.type:
		"loop":
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", int(2 * JuiceeEditorUtil.EDSCALE))
			content.add_child(row)
			var infinite := bool(data.properties.get("infinite", false))
			var inf_cb := CheckBox.new()
			inf_cb.text = "Loop forever"
			inf_cb.button_pressed = infinite
			inf_cb.tooltip_text = "Repeat until the scene changes or the node is freed. The count is ignored."
			row.add_child(inf_cb)
			var lbl := Label.new()
			lbl.text = "Iteration Count"
			row.add_child(lbl)
			var spin := SpinBox.new()
			spin.min_value = 1
			spin.max_value = 100
			spin.step = 1
			spin.value = int(data.properties.get("count", 3))
			spin.editable = not infinite
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.value_changed.connect(func(v: float) -> void:
				data.properties["count"] = int(v)
				changed.emit()
				var block := graph.get_node_or_null(NodePath(data.id)) as JuiceeGraphBlock
				if block:
					block.refresh_subtitle()
			)
			row.add_child(spin)
			inf_cb.toggled.connect(func(pressed: bool) -> void:
				data.properties["infinite"] = pressed
				spin.editable = not pressed
				changed.emit()
				var block := graph.get_node_or_null(NodePath(data.id)) as JuiceeGraphBlock
				if block:
					block.refresh_subtitle()
			)
		"random":
			_build_random_weights_editor(data)
		"condition":
			_build_condition_editor(data)
		_:
			var lbl := Label.new()
			lbl.text = "No properties"
			lbl.modulate = Color(1, 1, 1, 0.6)
			content.add_child(lbl)

# Per-output-port weight editor for Random nodes. Each Option N has a SpinBox
# bound to data.properties.weights[N-1] plus a live percentage label that
# shows the normalized probability - updates as the user drags.
func _build_random_weights_editor(data: JuiceeGraphNodeData) -> void:
	var port_count: int = clampi(int(data.properties.get("port_count", 3)), 2, 8)
	var weights: Array = data.properties.get("weights", [])
	# Keep array in sync with port_count.
	while weights.size() < port_count:
		weights.append(1.0)
	if weights.size() > port_count:
		weights.resize(port_count)
	data.properties["weights"] = weights

	var header := Label.new()
	header.text = "Branch weights"
	JuiceeEditorUtil.bold_label(header)
	content.add_child(header)

	var desc := Label.new()
	desc.text = "Relative probability each output is picked. Set 0 to disable that branch entirely."
	desc.modulate = Color(1, 1, 1, 0.58)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc)

	var pct_labels: Array[Label] = []

	var refresh_pcts := func() -> void:
		var total := 0.0
		for w in weights:
			total += maxf(0.0, float(w))
		for j in pct_labels.size():
			var w: float = maxf(0.0, float(weights[j]))
			if total > 0.0:
				pct_labels[j].text = "%.0f%%" % (w / total * 100.0)
			else:
				pct_labels[j].text = "-"

	for i in port_count:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(8 * JuiceeEditorUtil.EDSCALE))
		content.add_child(row)

		var lbl := Label.new()
		lbl.text = "Option %d" % (i + 1)
		lbl.custom_minimum_size.x = 70 * JuiceeEditorUtil.EDSCALE
		row.add_child(lbl)

		var spin := SpinBox.new()
		spin.min_value = 0.0
		spin.max_value = 100.0
		spin.step = 0.1
		spin.value = float(weights[i])
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spin)

		var pct_lbl := Label.new()
		pct_lbl.custom_minimum_size.x = 44 * JuiceeEditorUtil.EDSCALE
		pct_lbl.modulate = Color(1, 1, 1, 0.55)
		pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pct_lbl)
		pct_labels.append(pct_lbl)

		var idx := i
		spin.value_changed.connect(func(v: float) -> void:
			weights[idx] = v
			data.properties["weights"] = weights
			refresh_pcts.call()
			changed.emit()
		)

	refresh_pcts.call()

func _build_condition_editor(data: JuiceeGraphNodeData) -> void:
	var header := Label.new()
	header.text = "Expression"
	JuiceeEditorUtil.bold_label(header)
	content.add_child(header)

	var hint := Label.new()
	hint.text = "GDScript expression evaluated against 'context'.\nPort 0 fires when True, port 1 when False.\n\nExamples:\n  context.health < 20\n  context.is_in_group(\"enemy\")\n  context.visible\n  true"
	hint.modulate = Color(1, 1, 1, 0.58)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)

	var edit := LineEdit.new()
	edit.text = data.properties.get("expression", "true")
	edit.placeholder_text = "e.g. context.health < 20"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var commit := func() -> void:
		data.properties["expression"] = edit.text
		changed.emit()
	edit.text_submitted.connect(func(_t: String) -> void: commit.call())
	edit.focus_exited.connect(commit)
	content.add_child(edit)

func _build_props_for_effect(effect: JuiceeEffect) -> void:
	# Pull all ## docstrings from the effect's source code so we can attach them as tooltips.
	var docs: Dictionary = JuiceeEditorUtil.property_docs(effect.get_script() as Script)
	# Follow the groups the effect declares (Advanced, Randomization, Cooldown) instead
	# of running its own parameters straight into chance and cooldown unmarked. The
	# header waits for a real property, so a group with nothing visible in it leaves
	# no stray heading behind.
	var pending := ""
	for prop in effect.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_CATEGORY:
			# A category starts a fresh scope; the base class's properties do not belong
			# to whatever group the effect's own list ended on.
			pending = ""
			continue
		if usage & PROPERTY_USAGE_GROUP:
			var g := String(prop["name"])
			pending = "" if g == "Resource" else g
			continue
		if usage & PROPERTY_USAGE_SUBGROUP:
			continue
		if not (usage & PROPERTY_USAGE_EDITOR):
			continue
		if not (usage & PROPERTY_USAGE_STORAGE):
			continue
		var name: String = prop["name"]
		if name == "graph_position" or name == "resource_local_to_scene" or name == "resource_name" or name == "resource_path" or name == "script":
			continue
		if not pending.is_empty():
			_add_props_section_header(pending)
			pending = ""
		_add_prop_editor(effect, prop, docs.get(name, ""))

## A group heading in the properties panel. Bold through the editor font, matching how
## the add-node popup marks its categories.
func _add_props_section_header(text: String) -> void:
	content.add_child(HSeparator.new())
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.modulate = Color(1, 1, 1, 0.75)
	var f := JuiceeEditorUtil.editor_font("bold")
	if f:
		lbl.add_theme_font_override("font", f)
	content.add_child(lbl)

func _add_prop_editor(effect: JuiceeEffect, prop: Dictionary, doc: String = "") -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", int(3 * JuiceeEditorUtil.EDSCALE))
	content.add_child(row)

	var name: String = prop["name"]
	var type: int = prop["type"]
	var hint: int = prop.get("hint", PROPERTY_HINT_NONE)
	var hint_string: String = prop.get("hint_string", "")
	var has_range := hint == PROPERTY_HINT_RANGE and not hint_string.is_empty()

	# Property name - main header.
	var lbl := Label.new()
	lbl.text = name.capitalize()
	row.add_child(lbl)

	# Inline docstring - what does this do? Always visible (not buried in tooltip).
	if not doc.is_empty():
		var doc_lbl := Label.new()
		doc_lbl.text = doc
		doc_lbl.modulate = Color(1, 1, 1, 0.58)
		doc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(doc_lbl)

	match type:
		TYPE_FLOAT, TYPE_INT:
			if hint == PROPERTY_HINT_ENUM and not hint_string.is_empty():
				row.add_child(_build_enum_widget(effect, name, hint_string))
			elif has_range:
				row.add_child(_build_slider_widget(effect, name, type, hint_string))
			else:
				row.add_child(_build_spin_widget(effect, name, type))
		TYPE_BOOL:
			var cb := CheckBox.new()
			cb.text = "On"
			cb.button_pressed = effect.get(name)
			cb.toggled.connect(func(p: bool) -> void:
				_commit_undoable(effect, name, p)
			)
			row.add_child(cb)
		TYPE_COLOR:
			row.add_child(_build_color_widget(effect, name))
		TYPE_PACKED_COLOR_ARRAY:
			row.add_child(_build_color_array_widget(effect, name))
		TYPE_STRING:
			# An enum hint on a string means a fixed set of choices (an audio bus), so
			# it gets the list rather than a field to mistype into.
			if hint == PROPERTY_HINT_ENUM and not hint_string.is_empty():
				row.add_child(_build_string_enum_widget(effect, name, hint_string, false))
				return
			if hint == PROPERTY_HINT_MULTILINE_TEXT:
				var box := TextEdit.new()
				box.text = str(effect.get(name))
				box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				box.custom_minimum_size = Vector2(0, 64) * JuiceeEditorUtil.EDSCALE
				box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
				box.focus_exited.connect(func() -> void: _commit_undoable(effect, name, box.text))
				row.add_child(box)
				return
			var edit := LineEdit.new()
			edit.text = str(effect.get(name))
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var commit_s := func() -> void:
				_commit_undoable(effect, name, edit.text)
			edit.text_submitted.connect(func(_t: String) -> void: commit_s.call())
			edit.focus_exited.connect(commit_s)
			row.add_child(edit)
		TYPE_VECTOR2:
			row.add_child(_build_vector_widget(effect, name, 2))
		TYPE_VECTOR3:
			row.add_child(_build_vector_widget(effect, name, 3))
		TYPE_STRING_NAME:
			if hint == PROPERTY_HINT_ENUM and not hint_string.is_empty():
				row.add_child(_build_string_enum_widget(effect, name, hint_string, true))
				return
			var edit := LineEdit.new()
			edit.text = String(effect.get(name))
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var commit_sn := func() -> void:
				_commit_undoable(effect, name, StringName(edit.text))
			edit.text_submitted.connect(func(_t: String) -> void: commit_sn.call())
			edit.focus_exited.connect(commit_sn)
			row.add_child(edit)
		TYPE_NODE_PATH:
			var edit := JuiceeNodePathField.new()
			edit.text = String(effect.get(name))
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# The effect's @export_node_path("Light3D") hint tells us what it can
			# actually use, so the field rejects a drop of anything else.
			edit.accepted_types = _node_path_types(hint_string)
			if not edit.accepted_types.is_empty():
				edit.placeholder_text = "drag a %s here" % ", ".join(edit.accepted_types)
			edit.path_changed.connect(func(p: NodePath) -> void:
				_commit_undoable(effect, name, p)
			)
			row.add_child(edit)
		_:
			# A curve, a sub-resource, an array or a Variant: Godot's own editors in the
			# Inspector do these, so the panel shows what is there and opens it at the field.
			row.add_child(JuiceeEditorUtil.inspector_field_button(effect, name))

# Slider + numeric readout + min/max endpoints. Used for ranged numeric props
# so the user can see WHERE the current value sits in the valid range at a glance.
func _build_slider_widget(effect: JuiceeEffect, name: String, type: int, hint_string: String) -> Control:
	var parts := hint_string.split(",")
	var minv := float(parts[0]) if parts.size() >= 1 else 0.0
	var maxv := float(parts[1]) if parts.size() >= 2 else 1.0
	var step := float(parts[2]) if parts.size() >= 3 else (1.0 if type == TYPE_INT else 0.01)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(1 * JuiceeEditorUtil.EDSCALE))

	var slider_row := HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", int(8 * JuiceeEditorUtil.EDSCALE))
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(slider_row)

	var slider := HSlider.new()
	slider.min_value = minv
	slider.max_value = maxv
	slider.step = step
	slider.value = effect.get(name)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider_row.add_child(slider)

	var value_lbl := Label.new()
	value_lbl.text = _format_value(slider.value, type, step)
	value_lbl.custom_minimum_size.x = 42 * JuiceeEditorUtil.EDSCALE
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider_row.add_child(value_lbl)

	# Endpoint hints - small, dim, under the slider.
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", int(0 * JuiceeEditorUtil.EDSCALE))
	box.add_child(hint_row)

	var min_lbl := Label.new()
	min_lbl.text = _format_value(minv, type, step)
	min_lbl.modulate = Color(1, 1, 1, 0.4)
	min_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_row.add_child(min_lbl)

	var max_lbl := Label.new()
	max_lbl.text = _format_value(maxv, type, step)
	max_lbl.modulate = Color(1, 1, 1, 0.4)
	max_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_row.add_child(max_lbl)

	# Every change through undo, merged per property: a wheel turn, an arrow key or a click on
	# the track moves a slider without a drag.
	slider.value_changed.connect(func(v: float) -> void:
		value_lbl.text = _format_value(v, type, step)
		_commit_undoable(effect, name, (int(v) as Variant) if type == TYPE_INT else (v as Variant))
	)
	return box

func _build_spin_widget(effect: JuiceeEffect, name: String, type: int) -> Control:
	var spin := SpinBox.new()
	spin.min_value = -99999.0
	spin.max_value = 99999.0
	spin.step = 1.0 if type == TYPE_INT else 0.01
	spin.value = effect.get(name)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# In an array, so the focus handler's update reaches the undo below: a lambda gets its own
	# copy of a captured variable back on every call.
	var spin_old: Array = [effect.get(name)]
	spin.get_line_edit().focus_entered.connect(func() -> void:
		spin_old[0] = effect.get(name)
	)
	spin.value_changed.connect(func(v: float) -> void:
		var new_val: Variant = v
		if type == TYPE_INT:
			new_val = int(v)
		_commit(effect, name, new_val)
		if undo_redo:
			undo_redo.create_action("Change " + name.capitalize(), UndoRedo.MERGE_ENDS, effect)
			undo_redo.add_do_method(self, "_ur_set_effect_property", effect, name, new_val)
			undo_redo.add_undo_method(self, "_ur_set_effect_property", effect, name, spin_old[0])
			undo_redo.commit_action(false)
	)
	return spin

## `@export_node_path("Light3D", "OmniLight3D")` arrives as a hint string of
## comma-separated class names. Plain `@export var p: NodePath` has no hint, and
## then any node is fair game.
func _node_path_types(hint_string: String) -> PackedStringArray:
	var out := PackedStringArray()
	for part in hint_string.split(",", false):
		var t := part.strip_edges()
		if not t.is_empty() and ClassDB.class_exists(t):
			out.append(t)
	return out

## One spin box per component, for Vector2 and Vector3 alike.
const VECTOR_AXES := ["x", "y", "z"]

func _build_vector_widget(effect: JuiceeEffect, prop_name: String, components: int) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(4 * JuiceeEditorUtil.EDSCALE))
	for i in components:
		var axis := i
		var lbl := Label.new()
		lbl.text = VECTOR_AXES[axis] + ":"
		hbox.add_child(lbl)
		var spin := SpinBox.new()
		# step 0.01, not 1.0: scale-like vectors need decimals (issue #6)
		spin.min_value = -99999.0
		spin.max_value = 99999.0
		spin.step = 0.01
		spin.value = _vector_component(effect.get(prop_name), axis)
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Read the current value back on every edit rather than closing over it, so two
		# components edited in turn do not overwrite each other.
		spin.value_changed.connect(func(v: float) -> void:
			_commit_undoable(effect, prop_name, _vector_with(effect.get(prop_name), axis, v)))
		hbox.add_child(spin)
	return hbox

func _vector_component(value: Variant, axis: int) -> float:
	if value is Vector3:
		return (value as Vector3)[axis]
	return (value as Vector2)[axis]

func _vector_with(value: Variant, axis: int, component: float) -> Variant:
	if value is Vector3:
		var out3 := value as Vector3
		out3[axis] = component
		return out3
	var out2 := value as Vector2
	out2[axis] = component
	return out2

# OptionButton for enum-typed @export properties (e.g. ScreenWipe.wipe_from).
# Godot serializes enums as TYPE_INT with PROPERTY_HINT_ENUM and a hint string
# of comma-separated labels (optionally "Label:value").
## Dropdown for a string property carrying an enum hint. Item text is a label only:
## the value written back is the hint entry, so a blank entry meaning "none" can read
## as something sensible without storing that word.
func _build_string_enum_widget(effect: JuiceeEffect, name: String, hint_string: String,
		as_name: bool) -> OptionButton:
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var opts := hint_string.split(",")
	var current := String(effect.get(name))
	var sel := -1
	for i in opts.size():
		ob.add_item("(none)" if opts[i].is_empty() else opts[i], i)
		if opts[i] == current:
			sel = i
	if sel < 0:
		# A bus that was renamed or deleted. Keep it rather than snapping to the first
		# entry, which would rewrite the effect just for opening the panel.
		ob.add_item("%s (missing)" % current, opts.size())
		sel = opts.size()
	ob.selected = sel
	ob.item_selected.connect(func(i: int) -> void:
		if i >= opts.size():
			return
		_commit_undoable(effect, name, (StringName(opts[i]) as Variant) if as_name else (opts[i] as Variant)))
	return ob

func _build_enum_widget(effect: JuiceeEffect, name: String, hint_string: String) -> Control:
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_value: int = int(effect.get(name))
	for entry in JuiceeEditorUtil.enum_entries(hint_string):
		ob.add_item(entry[0], entry[1])
		if entry[1] == current_value:
			ob.select(ob.item_count - 1)
	ob.item_selected.connect(func(idx: int) -> void:
		var old_val: Variant = effect.get(name)
		var new_val: int = ob.get_item_id(idx)
		_commit(effect, name, new_val)
		if undo_redo and old_val != new_val:
			undo_redo.create_action("Change " + name.capitalize())
			undo_redo.add_do_method(self, "_ur_set_effect_property", effect, name, new_val)
			undo_redo.add_undo_method(self, "_ur_set_effect_property", effect, name, old_val)
			undo_redo.commit_action(false)
	)
	return ob

# ColorPickerButton wrapper - explicit minimum size + sync after picking so
# the visible swatch always reflects the current value.
func _build_color_widget(effect: JuiceeEffect, name: String) -> Control:
	var cp := ColorPickerButton.new()
	cp.color = effect.get(name)
	cp.edit_alpha = true
	cp.custom_minimum_size = Vector2(0, 28) * JuiceeEditorUtil.EDSCALE
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# In an array, so each finished edit's colour is the next one's undo (see spin_old above).
	var color_old: Array = [effect.get(name)]
	cp.popup_closed.connect(func() -> void:
		var new_col: Color = cp.color
		if undo_redo and new_col != color_old[0]:
			undo_redo.create_action("Change " + name.capitalize())
			undo_redo.add_do_method(self, "_ur_set_effect_property", effect, name, new_col)
			undo_redo.add_undo_method(self, "_ur_set_effect_property", effect, name, color_old[0])
			undo_redo.commit_action(false)
		color_old[0] = new_col
	)
	cp.color_changed.connect(func(c: Color) -> void:
		cp.color = c
		_commit(effect, name, c)
	)
	return cp

# Inline editor for a PackedColorArray: a wrapping row of colour swatches with add and
# remove buttons. Godot's graph panel has no built-in array editor, and Color Cycle's
# optional palette has to be editable right here in the graph, not only in the Inspector.
func _build_color_array_widget(effect: JuiceeEffect, name: String) -> Control:
	var box := HFlowContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var holder := {}
	# Add / remove change the array's shape, so they go through undo and let
	# _ur_set_effect_property rebuild the whole panel (which recreates this widget).
	holder["structural"] = func(new_arr: PackedColorArray, old_arr: PackedColorArray) -> void:
		if undo_redo:
			undo_redo.create_action("Change " + name.capitalize())
			undo_redo.add_do_method(self, "_ur_set_effect_property", effect, name, new_arr)
			undo_redo.add_undo_method(self, "_ur_set_effect_property", effect, name, old_arr)
			undo_redo.commit_action()
		else:
			_commit(effect, name, new_arr)
			holder["rebuild"].call()

	holder["rebuild"] = func() -> void:
		for ch in box.get_children():
			ch.queue_free()
		var cols: PackedColorArray = effect.get(name)
		for i in cols.size():
			var idx := i
			# In an array for the same reason as spin_old above.
			var before: Array = [cols[idx]]
			var cell := HBoxContainer.new()
			cell.add_theme_constant_override("separation", int(1 * JuiceeEditorUtil.EDSCALE))
			var pick := ColorPickerButton.new()
			pick.color = before[0]
			pick.edit_alpha = true
			pick.custom_minimum_size = Vector2(30, 22) * JuiceeEditorUtil.EDSCALE
			# Live while dragging (keeps the popup open); one undo entry per finished edit.
			pick.color_changed.connect(func(c: Color) -> void:
				var arr: PackedColorArray = effect.get(name)
				if idx < arr.size():
					arr[idx] = c
					_commit(effect, name, arr))
			pick.popup_closed.connect(func() -> void:
				var now: PackedColorArray = effect.get(name)
				if undo_redo and idx < now.size() and now[idx] != before[0]:
					var restored := now.duplicate()
					restored[idx] = before[0]
					undo_redo.create_action("Change " + name.capitalize())
					undo_redo.add_do_method(self, "_ur_set_effect_property", effect, name, now.duplicate())
					undo_redo.add_undo_method(self, "_ur_set_effect_property", effect, name, restored)
					undo_redo.commit_action(false)
					before[0] = now[idx])
			cell.add_child(pick)
			var del := Button.new()
			del.text = "×"
			del.tooltip_text = "Remove this colour"
			del.custom_minimum_size = Vector2(16, 22) * JuiceeEditorUtil.EDSCALE
			del.pressed.connect(func() -> void:
				var old_arr: PackedColorArray = effect.get(name)
				if idx >= old_arr.size():
					return
				var new_arr := old_arr.duplicate()
				new_arr.remove_at(idx)
				holder["structural"].call(new_arr, old_arr))
			cell.add_child(del)
			box.add_child(cell)

		var add_btn := Button.new()
		add_btn.text = "+"
		add_btn.tooltip_text = "Add a colour (leave empty for the rainbow)"
		add_btn.custom_minimum_size = Vector2(24, 22) * JuiceeEditorUtil.EDSCALE
		add_btn.pressed.connect(func() -> void:
			var old_arr: PackedColorArray = effect.get(name)
			var new_arr := old_arr.duplicate()
			new_arr.append(old_arr[old_arr.size() - 1] if not old_arr.is_empty() else Color(1, 1, 1))
			holder["structural"].call(new_arr, old_arr))
		box.add_child(add_btn)

	holder["rebuild"].call()
	return box

# Format a numeric value for display - int -> "5", float -> "0.25" or "1.0" using
# step to decide decimal precision.
func _format_value(v: float, type: int, step: float) -> String:
	if type == TYPE_INT:
		return str(int(v))
	if step >= 1.0:
		return "%.0f" % v
	if step >= 0.1:
		return "%.1f" % v
	if step >= 0.01:
		return "%.2f" % v
	return "%.3f" % v


func clear() -> void:
	for child in content.get_children():
		child.queue_free()
	title.text = "Properties"
	title.modulate = Color.WHITE

