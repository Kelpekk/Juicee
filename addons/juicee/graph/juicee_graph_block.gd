@tool
class_name JuiceeGraphBlock
extends GraphNode

## Editor display scale (HiDPI). Every hardcoded pixel size multiplies by this
## so the UI matches the editor at 150%/200% display scale. 1.0 = no-op.
static var EDSCALE: float = (EditorInterface.get_editor_scale() if Engine.is_editor_hint() else 1.0)

const MIN_PORTS := 2
const MAX_PORTS := 8

signal ports_changed(new_count: int)
signal hovered
signal unhovered

const BUILTIN_META := {
	"trigger":   {"title": "Trigger",   "sub": "Graph starts here",     "color": Color(0.22, 0.88, 0.48), "icon": "res://addons/juicee/icons/trigger.svg",  "tip": "Entry point. Execution begins here when JuiceeGraphPlayer.play(graph) is called. Each graph needs exactly one Trigger."},
	"split":     {"title": "Split",     "sub": "Run all paths at once", "color": Color(0.95, 0.85, 0.20), "icon": "res://addons/juicee/icons/split.svg",    "tip": "Fan-out. All connected outputs fire at the same time and run in parallel. Use for hits (Shake + Flash + Chromatic all at once)."},
	"loop":      {"title": "Loop",      "sub": "Repeat the next chain", "color": Color(1.00, 0.55, 0.15), "icon": "res://addons/juicee/icons/loop.svg",     "tip": "Repeats the connected output chain N times sequentially. Each iteration waits for the previous one to finish."},
	"random":    {"title": "Random",    "sub": "Pick one path",         "color": Color(0.95, 0.85, 0.20), "icon": "res://addons/juicee/icons/random.svg",   "tip": "Picks one connected output at random (weighted) and runs only that branch. Use for varied juicy responses."},
	"condition": {"title": "Condition", "sub": "if / else branch",      "color": Color(0.50, 0.85, 1.00), "icon": "",                                        "tip": "Evaluates a GDScript expression against 'context'.\nPort 0 = True branch  ·  Port 1 = False branch.\nExamples:\n  context.health < 20\n  context.is_in_group(\"player\")\n  context.visible"},
	"comment":   {"title": "Comment",   "sub": "",                       "color": Color(0.88, 0.75, 0.22), "icon": "",                                        "tip": "Visual annotation — no ports, never executes.\nUse to document graph sections or leave notes for teammates."},
}

var node_data: JuiceeGraphNodeData

static func create(data: JuiceeGraphNodeData) -> JuiceeGraphBlock:
	var block := JuiceeGraphBlock.new()
	block.node_data = data
	block.name = data.id
	block.position_offset = data.graph_position

	var title_text: String
	var subtitle_text: String
	var icon_path: String
	var color: Color
	var has_input: bool
	var out_ports: int = 1
	var tooltip: String = ""

	if data.type == "effect" and data.effect:
		title_text = data.effect.get_display_name()
		# Show the effect's category ("Camera", "Screen", "Object" …) instead of the
		# generic word "Effect" — the user can tell at a glance what scope it affects.
		# Prefer the effect's own override, fall back to editor's central category map.
		var script_path: String = (data.effect.get_script() as Script).resource_path
		var basename: String = script_path.get_file().get_basename()
		var category := data.effect.get_category_name()
		if category.is_empty():
			category = JuiceeGraphEditor.EFFECT_CATEGORIES.get(basename, "")
		subtitle_text = category if not category.is_empty() else "Effect"
		# Tooltip falls back to the editor's central description map.
		tooltip = data.effect.get_description()
		if tooltip.is_empty():
			tooltip = JuiceeGraphEditor.EFFECT_DESCRIPTIONS.get(basename, "")
		icon_path = data.effect.get_icon_path()
		color = data.effect.get_category_color()
		has_input = true
	else:
		var meta: Dictionary = BUILTIN_META.get(data.type, {"title": data.type, "sub": "", "color": Color.WHITE, "icon": "", "tip": ""})
		title_text = meta["title"]
		subtitle_text = meta["sub"]
		icon_path = meta.get("icon", "")
		color = meta["color"]
		tooltip = meta.get("tip", "")
		has_input = data.type != "trigger" and data.type != "comment"
		if data.type == "split" or data.type == "random":
			out_ports = clampi(int(data.properties.get("port_count", 3)), MIN_PORTS, MAX_PORTS)
		elif data.type == "condition":
			out_ports = 2
		elif data.type == "comment":
			out_ports = 0
		# Loop shows its repeat count live — "Repeat × 3".
		if data.type == "loop":
			var count: int = int(data.properties.get("count", 3))
			subtitle_text = "Repeat × %d" % count

	block.title = title_text
	block.custom_minimum_size = (Vector2(200, 0) if data.type != "comment" else Vector2(220, 0)) * EDSCALE
	# tooltip_text intentionally left empty — JuiceeHoverPanel handles descriptions.
	block._apply_theme(color)
	block._apply_titlebar_icon(icon_path)
	if data.type == "effect" and data.effect:
		var _script_path: String = (data.effect.get_script() as Script).resource_path
		var _basename: String = _script_path.get_file().get_basename()
		block._apply_dimension_tags(JuiceeGraphEditor.EFFECT_DIMENSIONS.get(_basename, []))
		block._add_titlebar_preview_button()

	# Build body children FIRST — set_slot must reference existing rows or
	# Godot's port_cache stays at size 0 and complains every frame.
	if data.type == "comment":
		# Comment blocks have no ports — just a free-form text area.
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_top", int(4 * EDSCALE))
		m.add_theme_constant_override("margin_bottom", int(6 * EDSCALE))
		m.add_theme_constant_override("margin_left", int(6 * EDSCALE))
		m.add_theme_constant_override("margin_right", int(6 * EDSCALE))
		block.add_child(m)
		var text_edit := TextEdit.new()
		text_edit.text = data.properties.get("text", "Comment")
		text_edit.custom_minimum_size = Vector2(0, 60) * EDSCALE
		text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		text_edit.scroll_fit_content_height = true
		text_edit.text_changed.connect(func() -> void:
			block.node_data.properties["text"] = text_edit.text
		)
		m.add_child(text_edit)
	elif data.type == "condition":
		# Fixed 2-port: True (0) / False (1) — no +/− controls.
		_add_port_row(block, "True")
		_add_port_row(block, "False")
	elif out_ports > 1:
		# Flow nodes with multiple outputs (split/random): one labeled row per port,
		# then the +/− controls row (which has no port assigned).
		var port_prefix := "Path " if data.type == "split" else "Option "
		for i in out_ports:
			_add_port_row(block, port_prefix + str(i + 1))
		block._add_port_controls_row(out_ports, color)
	elif not subtitle_text.is_empty():
		var sub_wrap := MarginContainer.new()
		sub_wrap.add_theme_constant_override("margin_top", int(0 * EDSCALE))
		sub_wrap.add_theme_constant_override("margin_bottom", int(0 * EDSCALE))
		block.add_child(sub_wrap)

		var sub := Label.new()
		sub.name = &"_juicee_subtitle"
		sub.text = subtitle_text
		sub.modulate = Color(1, 1, 1, 0.62)
		sub.add_theme_font_size_override("font_size", int(10 * EDSCALE))
		sub_wrap.add_child(sub)

	# Now the children exist — assign one input/output slot per port row.
	# Comment nodes have no ports so this loop is a no-op for them.
	for i in out_ports:
		var left_on: bool = has_input and i == 0
		if not left_on and i == 0:
			# Godot 4.7 queries the input port of EVERY slot (new accessibility pass),
			# and errors every frame on a right-only slot whose left-port cache is empty
			# (e.g. the Trigger). Register a transparent left port: present in the cache
			# (no error spam) but invisible. It's harmless if something connects to it —
			# the sequence walk always starts AT the Trigger and ignores inbound edges.
			block.set_slot(i, true, 0, Color(0, 0, 0, 0), true, 0, color)
		else:
			block.set_slot(i, left_on, 0, color, true, 0, color)

	block.mouse_entered.connect(block.hovered.emit)
	block.mouse_exited.connect(block.unhovered.emit)

	return block

## Called by the live debugger when this node's effect fires.
## Emits a bright flash that decays back to normal within ~350 ms.
func flash_debug() -> void:
	# Kill any in-flight flash tween so rapid fires don't compound infinitely.
	if _debug_flash_tween and _debug_flash_tween.is_valid():
		_debug_flash_tween.kill()
	modulate = Color(1, 1, 1, 1)  # reset before tweening
	_debug_flash_tween = create_tween()
	_debug_flash_tween.tween_property(self, "modulate", Color(2.4, 2.2, 1.0, 1.0), 0.04)\
		.set_trans(Tween.TRANS_LINEAR)
	_debug_flash_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.38)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

## Show a persistent "active" glow while an effect is running.
func set_debug_active(active: bool) -> void:
	if _debug_flash_tween and _debug_flash_tween.is_valid():
		_debug_flash_tween.kill()
	if active:
		modulate = Color(1.5, 1.4, 0.7, 1.0)
	else:
		_debug_flash_tween = create_tween()
		_debug_flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

var _debug_flash_tween: Tween = null

## Re-reads node_data and refreshes any dynamic subtitle (e.g. Loop's "Repeat × N").
## Called by the props panel when properties change so the block stays in sync.
func refresh_subtitle() -> void:
	var label := find_child("_juicee_subtitle", true, false) as Label
	if not label:
		return
	if node_data.type == "loop":
		var count: int = int(node_data.properties.get("count", 3))
		label.text = "Repeat × %d" % count

## Adds a +/- control strip at the bottom of the block so the user can
## grow or shrink the number of output ports interactively.
func _add_port_controls_row(current_count: int, color: Color) -> void:
	var row := MarginContainer.new()
	row.add_theme_constant_override("margin_top", int(6 * EDSCALE))
	row.add_theme_constant_override("margin_bottom", int(2 * EDSCALE))
	row.add_theme_constant_override("margin_left", int(6 * EDSCALE))
	row.add_theme_constant_override("margin_right", int(6 * EDSCALE))
	add_child(row)
	# This row index has no port — set_slot is intentionally not called for it.

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", int(6 * EDSCALE))
	row.add_child(hbox)

	hbox.add_child(_make_pill_button("−", "Remove the last path", current_count <= MIN_PORTS, color,
		func() -> void: ports_changed.emit(maxi(MIN_PORTS, current_count - 1))))
	hbox.add_child(_make_pill_button("+", "Add another path", current_count >= MAX_PORTS, color,
		func() -> void: ports_changed.emit(mini(MAX_PORTS, current_count + 1))))

func _make_pill_button(text: String, tip: String, disabled: bool, _accent: Color, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(22, 20) * EDSCALE
	btn.tooltip_text = tip
	btn.disabled = disabled
	btn.pressed.connect(on_press)
	return btn

static func _add_port_row(block: JuiceeGraphBlock, text: String) -> void:
	var row := MarginContainer.new()
	row.add_theme_constant_override("margin_top", int(2 * EDSCALE))
	row.add_theme_constant_override("margin_bottom", int(2 * EDSCALE))
	row.add_theme_constant_override("margin_left", int(6 * EDSCALE))
	row.add_theme_constant_override("margin_right", int(6 * EDSCALE))
	block.add_child(row)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(label)

signal preview_requested

func _add_titlebar_preview_button() -> void:
	var titlebar := get_titlebar_hbox()
	if not titlebar:
		return
	var btn := Button.new()
	btn.text = "▶"
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(22, 20) * EDSCALE
	btn.tooltip_text = "Preview this effect on the currently edited scene.\n\nNote: full-screen shader effects (Blur, Chromatic, etc.)\npreview at the editor viewport size. Run the project (F5/F6)\nfor true full-screen rendering."
	btn.pressed.connect(func() -> void: preview_requested.emit())
	titlebar.add_child(btn)

func _apply_titlebar_icon(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	if not tex:
		return
	var titlebar := get_titlebar_hbox()
	if not titlebar:
		return
	titlebar.add_theme_constant_override("separation", int(4 * EDSCALE))
	var icon := TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(16, 16) * EDSCALE
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	titlebar.add_child(icon)
	titlebar.move_child(icon, 0)

func _apply_dimension_tags(dims: Array) -> void:
	if dims.is_empty():
		return
	var titlebar := get_titlebar_hbox()
	if not titlebar:
		return
	for dim in dims:
		var path := ""
		if dim == "2d":
			path = "res://addons/juicee/icons/2dtag.svg"
		elif dim == "3d":
			path = "res://addons/juicee/icons/3dtag.svg"
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if not tex:
			continue
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(20, 20) * EDSCALE
		tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.modulate = Color(1, 1, 1, 0.9)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		titlebar.add_child(tr)

func _apply_theme(c: Color) -> void:
	# Inherit Godot's editor GraphNode look (matches VisualShader / AnimationTree /
	# user's chosen editor theme — light, dark, custom) and only tint a 2-px
	# hairline at the top of the titlebar with our category color. Same trick
	# Godot itself uses in VisualShader to indicate input/output category.
	if not Engine.is_editor_hint():
		return
	var theme := EditorInterface.get_editor_theme()
	if not theme:
		return

	_tint_stylebox(theme, "titlebar", "GraphNode", c)
	_tint_stylebox(theme, "titlebar_selected", "GraphNode", c)

func _tint_stylebox(theme: Theme, name: String, type: String, c: Color) -> void:
	if not theme.has_stylebox(name, type):
		return
	var sb := theme.get_stylebox(name, type).duplicate() as StyleBoxFlat
	if not sb:
		return
	sb.border_color = c
	sb.border_width_top = maxi(sb.border_width_top, 2)
	add_theme_stylebox_override(name, sb)

func sync_position() -> void:
	node_data.graph_position = position_offset
	if node_data.effect:
		node_data.effect.graph_position = position_offset

## Visually pulses the block to indicate it just started executing.
## Used by the graph debugger after the effect's pre-delay has elapsed.
func pulse_highlight() -> void:
	_clear_delay_bar()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.4, 1.4, 1.4, 1.0), 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

# Filled portion of the delay-progress bar (0..1). Drawn directly via _draw()
# so it can't grow the block or push other content around.
var _delay_progress: float = 0.0

func _draw() -> void:
	if _delay_progress <= 0.0:
		return
	# Bar inset from rounded corners and sitting just above the bottom edge.
	const BAR_HEIGHT := 3.0
	const SIDE_INSET := 4.0
	const BOTTOM_INSET := 5.0
	var max_w := maxf(0.0, size.x - SIDE_INSET * 2.0)
	var w := max_w * clampf(_delay_progress, 0.0, 1.0)
	var rect := Rect2(SIDE_INSET, size.y - BAR_HEIGHT - BOTTOM_INSET, w, BAR_HEIGHT)
	# Faint background track behind the fill so the user sees the full extent.
	draw_rect(Rect2(SIDE_INSET, rect.position.y, max_w, BAR_HEIGHT),
		Color(1, 1, 1, 0.08), true)
	draw_rect(rect, _delay_bar_color(), true)

## Animates a fill bar at the bottom of the block over `duration` seconds —
## shown while an effect is in its pre-delay wait.
func show_delay_progress(duration: float) -> void:
	_clear_delay_bar()
	if duration <= 0.0:
		return

	# Faint glow hint that "something is waiting".
	modulate = Color(1.15, 1.15, 1.15, 1.0)
	var tween := create_tween()
	tween.tween_method(_set_delay_progress, 0.0, 1.0, duration)\
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(_clear_delay_bar)

func _set_delay_progress(v: float) -> void:
	_delay_progress = v
	queue_redraw()

func _clear_delay_bar() -> void:
	if _delay_progress != 0.0:
		_delay_progress = 0.0
		queue_redraw()

func _delay_bar_color() -> Color:
	# Match the category — fall back to a warm amber.
	if node_data and node_data.effect:
		var c := node_data.effect.get_category_color()
		c.a = 0.85
		return c
	if node_data and JuiceeGraphBlock.BUILTIN_META.has(node_data.type):
		var c2: Color = JuiceeGraphBlock.BUILTIN_META[node_data.type]["color"]
		c2.a = 0.85
		return c2
	return Color(1.0, 0.78, 0.30, 0.85)
