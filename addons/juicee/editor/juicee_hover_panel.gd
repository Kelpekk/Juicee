## Floating info panel that appears when hovering an effect block in the graph
## or an effect card in the sequence inspector.
##
## Shows: effect name + category, description, a live animated mini-preview
## (SubViewport running the actual effect on a demo node), and a log of recent
## debugger events for this effect during gameplay.
##
## Created by plugin.gd and added to EditorInterface.get_base_control() so it
## can float over the entire editor. Passed as `hover_panel` to both the graph
## editor and the inspector plugin.
@tool
class_name JuiceeHoverPanel
extends PanelContainer


const PANEL_WIDTH := 300
const PREVIEW_H   := 118
const LOG_MAX     := 6

## Project Settings > Juicee > Preview. This is the info panel that pops up when you
## hover an effect (name, description, live mini-preview, output log). One toggle hides
## the whole panel, the other just drops the description line.
const HOVER_PANEL_SETTING := "juicee/preview/hover_panel_visible"
const HOVER_DESCRIPTION_SETTING := "juicee/preview/hover_show_description"
## Extra canvas drawn past every edge of the preview so a Camera Follow pan scrolls
## across filled background and grid instead of sliding the transparent viewport edge in.
const PREVIEW_MARGIN := 120

# ─── Layout refs ──────────────────────────────────────────────────────────────
var _name_label:       Label
var _category_label:   Label
var _desc_label:       Label
var _preview_container: SubViewportContainer
var _preview_viewport:  SubViewport
var _preview_root:      Node2D
var _preview_subject:   Node2D
## The Godot icon as a Control, for the effects that need one (Shake Control, Size Delta).
var _preview_square:    TextureRect
## A copy of the look of the node the effect will play on, standing in for the square, and the
## line under the preview that names it.
## What Object effects play on: a copy of the selected player's sprite, else the Godot icon.
var _stand_in:          Sprite2D = null
var _stand_in_is_icon:  bool = false
var _preview_light:     PointLight2D
var _preview_particles: CPUParticles2D
var _preview_rich:      RichTextLabel
## The sweep that carries the subject across for Trail and Afterimage.
var _drive:             Tween
## The drawn part of each stand-in frame, by texture and frame rect, so a hover reads the image once.
var _content_rects:     Dictionary = {}
var _stand_in_label:    Label
var _preview_camera:    Camera2D
var _preview_text:      Label
var _no_preview_label:  Label
var _preview_sep:       Control
var _log_label:         RichTextLabel
## The Output section and the divider above it, hidden where nothing can log to it.
var _log_parts:         Array[Control] = []

# ─── Internal state ───────────────────────────────────────────────────────────
var _show_delay_timer: Timer   # fires after ~0.42s; shows + fades in the panel
var _hide_timer:       Timer   # fires after ~0.15s; kicks off the fade-out
var _anim_tween:       Tween = null
var _preview_gen:      int = 0
var _log_lines:        Array[String] = []

# Pending content - stored while show-delay timer is counting down.
var _pending_show: Callable = Callable()
var _pending_rect:  Rect2 = Rect2()
## Live source block - its rect is re-queried at show time so a scroll/zoom during
## the show-delay can never strand the panel at a stale (off-screen) position.
var _pending_node:  Control = null

const _NO_PREVIEW := ["Time", "Flow", "Physics", "Audio"]

# Effects whose real target can't exist in the 2D mini-preview (lights,
# WorldEnvironment, AnimationPlayer, external scenes/particles). Mapped to a
# short "needs X" hint shown in place of the preview instead of a dead square.
# 3D effects (name contains "_3d") are caught separately.
const _NO_VISUAL := {
	"bloom_effect": "a WorldEnvironment in your scene",
	"tonemap_effect": "a WorldEnvironment in your scene",
	"depth_of_field_effect": "a Camera3D in your scene",
	"animation_player_effect": "an AnimationPlayer of yours",
	"animation_tree_effect": "an AnimationTree of yours",
	"instantiate_effect": "a scene of yours to spawn",
	"set_property_effect": "a node of yours to change",
	"set_active_effect": "a node of yours to switch",
	"shader_parameter_effect": "a ShaderMaterial of yours",
}

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	JuiceeEditorUtil.english_only(self)
	custom_minimum_size.x = PANEL_WIDTH * JuiceeEditorUtil.EDSCALE
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100

	_setup_style()
	_build_layout()
	_build_preview_viewport()

	# Show-delay: wait before revealing so quick mouse passes don't flash the panel.
	_show_delay_timer = Timer.new()
	_show_delay_timer.wait_time = 0.42
	_show_delay_timer.one_shot = true
	_show_delay_timer.timeout.connect(_fire_show)
	add_child(_show_delay_timer)

	# Hide-delay: short buffer so moving from block->panel doesn't instantly close it.
	_hide_timer = Timer.new()
	_hide_timer.wait_time = 0.15
	_hide_timer.one_shot = true
	_hide_timer.timeout.connect(_fire_hide)
	add_child(_hide_timer)

	mouse_entered.connect(_cancel_hide)
	mouse_exited.connect(schedule_hide)

	modulate.a = 0.0
	hide()

func _setup_style() -> void:
	# Derive panel colors from the editor theme so we blend naturally on both
	# dark and light themes rather than forcing hard-coded near-black values.
	var base := Color(0.20, 0.20, 0.22)
	if Engine.is_editor_hint():
		var et := EditorInterface.get_editor_theme()
		if et and et.has_color("base_color", "Editor"):
			base = et.get_color("base_color", "Editor")

	var sb := StyleBoxFlat.new()
	# Slightly lighter than the editor base so the panel reads as a popup layer.
	sb.bg_color = Color(base.r + 0.04, base.g + 0.04, base.b + 0.06, 0.97)
	sb.border_color = Color(base.r + 0.14, base.g + 0.14, base.b + 0.22, 0.65)
	sb.set_border_width_all(maxi(1, int(1 * JuiceeEditorUtil.EDSCALE)))
	# Soft drop-shadow so the panel lifts off the canvas without a hard edge.
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = int(6 * JuiceeEditorUtil.EDSCALE)
	sb.shadow_offset = Vector2(0, 2)
	for corner in [0, 1, 2, 3]:
		sb.set_corner_radius(corner, int(6 * JuiceeEditorUtil.EDSCALE))
	add_theme_stylebox_override("panel", sb)

func _build_layout() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(0 * JuiceeEditorUtil.EDSCALE))
	add_child(vbox)

	# ── Header ────────────────────────────────────────────────────────────────
	var base2 := Color(0.20, 0.20, 0.22)
	if Engine.is_editor_hint():
		var et2 := EditorInterface.get_editor_theme()
		if et2 and et2.has_color("base_color", "Editor"):
			base2 = et2.get_color("base_color", "Editor")

	var header := PanelContainer.new()
	var hdr_sb := StyleBoxFlat.new()
	hdr_sb.bg_color = Color(base2.r + 0.01, base2.g + 0.01, base2.b + 0.02, 1.0)
	for corner in [0, 1]:  # top corners only
		hdr_sb.set_corner_radius(corner, int(6 * JuiceeEditorUtil.EDSCALE))
	hdr_sb.content_margin_left   = 10 * JuiceeEditorUtil.EDSCALE
	hdr_sb.content_margin_right  = 10 * JuiceeEditorUtil.EDSCALE
	hdr_sb.content_margin_top    = 7 * JuiceeEditorUtil.EDSCALE
	hdr_sb.content_margin_bottom = 7 * JuiceeEditorUtil.EDSCALE
	header.add_theme_stylebox_override("panel", hdr_sb)
	vbox.add_child(header)

	var hdr_row := HBoxContainer.new()
	header.add_child(hdr_row)

	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_row.add_child(_name_label)

	_category_label = Label.new()
	_category_label.add_theme_color_override("font_color", JuiceeEditorUtil.text_color(0.55))
	_category_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hdr_row.add_child(_category_label)

	# ── Description ───────────────────────────────────────────────────────────
	var desc_m := MarginContainer.new()
	desc_m.add_theme_constant_override("margin_left",   int(10 * JuiceeEditorUtil.EDSCALE))
	desc_m.add_theme_constant_override("margin_right",  int(10 * JuiceeEditorUtil.EDSCALE))
	desc_m.add_theme_constant_override("margin_top",     int(8 * JuiceeEditorUtil.EDSCALE))
	desc_m.add_theme_constant_override("margin_bottom",  int(8 * JuiceeEditorUtil.EDSCALE))
	vbox.add_child(desc_m)

	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A width to wrap at from the start, or the first layout wraps a word per line and the panel,
	# which never shrinks back, keeps that height.
	_desc_label.custom_minimum_size.x = (PANEL_WIDTH - 20) * JuiceeEditorUtil.EDSCALE
	_desc_label.add_theme_color_override("font_color", JuiceeEditorUtil.text_color(0.85))
	desc_m.add_child(_desc_label)

	# Separator above the preview. Kept as a field so flow-control blocks, which have
	# no preview, can drop it too and not leave a doubled divider next to the log's.
	_preview_sep = _hsep()
	vbox.add_child(_preview_sep)

	# ── Preview area ──────────────────────────────────────────────────────────
	_preview_container = SubViewportContainer.new()
	_preview_container.custom_minimum_size = Vector2(PANEL_WIDTH, PREVIEW_H) * JuiceeEditorUtil.EDSCALE
	_preview_container.stretch = true
	vbox.add_child(_preview_container)

	_no_preview_label = Label.new()
	_no_preview_label.custom_minimum_size = Vector2(PANEL_WIDTH, PREVIEW_H) * JuiceeEditorUtil.EDSCALE
	_no_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_preview_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_no_preview_label.add_theme_color_override("font_color", JuiceeEditorUtil.text_color(0.5))
	vbox.add_child(_no_preview_label)
	_no_preview_label.hide()

	var log_sep := _hsep()
	vbox.add_child(log_sep)

	# ── Log ───────────────────────────────────────────────────────────────────
	var log_hdr_m := MarginContainer.new()
	log_hdr_m.add_theme_constant_override("margin_left",   int(10 * JuiceeEditorUtil.EDSCALE))
	log_hdr_m.add_theme_constant_override("margin_right",  int(10 * JuiceeEditorUtil.EDSCALE))
	log_hdr_m.add_theme_constant_override("margin_top",     int(5 * JuiceeEditorUtil.EDSCALE))
	log_hdr_m.add_theme_constant_override("margin_bottom",  int(3 * JuiceeEditorUtil.EDSCALE))
	vbox.add_child(log_hdr_m)

	var log_title := Label.new()
	log_title.text = "Output"
	log_title.add_theme_color_override("font_color", Color(0.50, 0.54, 0.70, 0.9))
	log_hdr_m.add_child(log_title)

	var log_outer := MarginContainer.new()
	log_outer.add_theme_constant_override("margin_left",   int(8 * JuiceeEditorUtil.EDSCALE))
	log_outer.add_theme_constant_override("margin_right",  int(8 * JuiceeEditorUtil.EDSCALE))
	log_outer.add_theme_constant_override("margin_bottom", int(10 * JuiceeEditorUtil.EDSCALE))
	vbox.add_child(log_outer)

	var log_panel := PanelContainer.new()
	var log_sb := StyleBoxFlat.new()
	# Slightly darker inset than the panel body - keep the depth hint subtle.
	var base3 := Color(0.20, 0.20, 0.22)
	if Engine.is_editor_hint():
		var et3 := EditorInterface.get_editor_theme()
		if et3 and et3.has_color("base_color", "Editor"):
			base3 = et3.get_color("base_color", "Editor")
	log_sb.bg_color = Color(base3.r - 0.02, base3.g - 0.02, base3.b - 0.01, 1.0)
	for corner in [0, 1, 2, 3]:
		log_sb.set_corner_radius(corner, int(4 * JuiceeEditorUtil.EDSCALE))
	log_sb.content_margin_left   = 8 * JuiceeEditorUtil.EDSCALE
	log_sb.content_margin_right  = 8 * JuiceeEditorUtil.EDSCALE
	log_sb.content_margin_top    = 6 * JuiceeEditorUtil.EDSCALE
	log_sb.content_margin_bottom = 6 * JuiceeEditorUtil.EDSCALE
	log_panel.add_theme_stylebox_override("panel", log_sb)
	log_outer.add_child(log_panel)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.fit_content = true
	_log_label.scroll_active = false
	_log_label.custom_minimum_size.x = (PANEL_WIDTH - 32) * JuiceeEditorUtil.EDSCALE
	_log_label.text = "[color=#7c8094]No output yet. It fills when the running game plays this graph.[/color]"
	log_panel.add_child(_log_label)
	_log_parts = [log_sep, log_hdr_m, log_outer]

func _build_preview_viewport() -> void:
	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(int(PANEL_WIDTH * JuiceeEditorUtil.EDSCALE), int(PREVIEW_H * JuiceeEditorUtil.EDSCALE))
	_preview_viewport.transparent_bg = true
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_container.add_child(_preview_viewport)

	_preview_root = Node2D.new()
	_preview_root.name = &"_juicee_hover_root"
	_preview_root.set_meta("_juicee_hover_preview", true)
	_preview_viewport.add_child(_preview_root)

	# Mid-tone background. A near-black canvas hides any darkening screen effect
	# (cinematic bars, vignette, dark tint render black-on-black and look "dead");
	# this medium tone keeps the white subject contrasting while letting dark
	# overlays read clearly.
	var bg := ColorRect.new()
	bg.color = Color(0.17, 0.18, 0.22)
	bg.position = Vector2(-PREVIEW_MARGIN, -PREVIEW_MARGIN) * JuiceeEditorUtil.EDSCALE
	bg.size = Vector2(PANEL_WIDTH + 2 * PREVIEW_MARGIN, PREVIEW_H + 2 * PREVIEW_MARGIN) * JuiceeEditorUtil.EDSCALE
	bg.z_index = -10
	_preview_root.add_child(bg)

	# A faint grid over the whole canvas. Distortion effects (shockwave, lens
	# distortion, chromatic, blur) only show up where there are edges to bend, and a
	# flat frame made them read as barely doing anything. Lines everywhere means the warp
	# is visible wherever it lands, which is why there are no side panels any more: two
	# flat blocks beside the subject read as placeholders.
	var grid := Node2D.new()
	grid.z_index = -9
	grid.modulate = Color(1, 1, 1, 0.16)
	_preview_root.add_child(grid)
	var step := 14.0 * JuiceeEditorUtil.EDSCALE
	# Cover the oversized background so the grid keeps going when the camera pans.
	var gx0: float = -PREVIEW_MARGIN * JuiceeEditorUtil.EDSCALE
	var gx1: float = (PANEL_WIDTH + PREVIEW_MARGIN) * JuiceeEditorUtil.EDSCALE
	var gy0: float = -PREVIEW_MARGIN * JuiceeEditorUtil.EDSCALE
	var gy1: float = (PREVIEW_H + PREVIEW_MARGIN) * JuiceeEditorUtil.EDSCALE
	var x := gx0
	while x < gx1:
		var v := ColorRect.new()
		v.color = Color(0.62, 0.68, 0.85)
		v.position = Vector2(x, gy0)
		v.size = Vector2(maxf(1.0, JuiceeEditorUtil.EDSCALE), gy1 - gy0)
		grid.add_child(v)
		x += step
	var y := gy0
	while y < gy1:
		var hl := ColorRect.new()
		hl.color = Color(0.62, 0.68, 0.85)
		hl.position = Vector2(gx0, y)
		hl.size = Vector2(gx1 - gx0, maxf(1.0, JuiceeEditorUtil.EDSCALE))
		grid.add_child(hl)
		y += step

	# Camera - required so camera effects find a Camera2D in the SubViewport.
	_preview_camera = Camera2D.new()
	_preview_camera.position = Vector2(PANEL_WIDTH / 2.0, PREVIEW_H / 2.0) * JuiceeEditorUtil.EDSCALE
	_preview_camera.enabled = true
	_preview_root.add_child(_preview_camera)

	# The subject Object effects move, scale and tint. What it shows is the stand-in sprite (see
	# _set_stand_in), or the icon as a Control for the effects that need one.
	_preview_subject = Node2D.new()
	_preview_subject.position = Vector2(PANEL_WIDTH / 2.0, PREVIEW_H / 2.0) * JuiceeEditorUtil.EDSCALE
	_preview_root.add_child(_preview_subject)

	_preview_square = TextureRect.new()
	_preview_square.texture = _icon()
	_preview_square.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_square.stretch_mode = TextureRect.STRETCH_SCALE
	_preview_subject.add_child(_preview_square)
	_reset_square()

	# A light at rest for Light Flash and Strobe Light to find, dark until they raise it.
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.gradient = Gradient.new()
	glow.gradient.set_color(0, Color.WHITE)
	glow.gradient.set_color(1, Color(1, 1, 1, 0))
	_preview_light = PointLight2D.new()
	_preview_light.texture = glow
	_preview_light.energy = 0.0
	_preview_light.texture_scale = 2.0 * JuiceeEditorUtil.EDSCALE
	_preview_subject.add_child(_preview_light)

	# An emitter at rest for Particle to fire.
	_preview_particles = CPUParticles2D.new()
	_preview_particles.emitting = false
	_preview_particles.one_shot = true
	_preview_particles.amount = 24
	_preview_particles.lifetime = 0.6
	_preview_particles.explosiveness = 0.9
	_preview_particles.direction = Vector2.UP
	_preview_particles.spread = 180.0
	_preview_particles.initial_velocity_min = 50.0 * JuiceeEditorUtil.EDSCALE
	_preview_particles.initial_velocity_max = 100.0 * JuiceeEditorUtil.EDSCALE
	_preview_particles.gravity = Vector2(0, 160) * JuiceeEditorUtil.EDSCALE
	_preview_particles.scale_amount_min = 4.0 * JuiceeEditorUtil.EDSCALE
	_preview_particles.scale_amount_max = 6.0 * JuiceeEditorUtil.EDSCALE
	_preview_particles.color = Color(1.0, 0.82, 0.35)
	_preview_subject.add_child(_preview_particles)

	# Text label for Text-category effects (typewriter, number_count, etc.).
	_preview_text = Label.new()
	_preview_text.text = "100"
	_preview_text.position = Vector2(PANEL_WIDTH / 2.0 - 18, PREVIEW_H / 2.0 - 16) * JuiceeEditorUtil.EDSCALE
	_preview_text.add_theme_font_size_override("font_size", int(24 * JuiceeEditorUtil.EDSCALE))
	_preview_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	_preview_root.add_child(_preview_text)
	_preview_text.hide()

	# Rich Text Emphasis works on BBCode, which a Label does not have.
	_preview_rich = RichTextLabel.new()
	_preview_rich.bbcode_enabled = true
	_preview_rich.fit_content = true
	_preview_rich.scroll_active = false
	_preview_rich.autowrap_mode = TextServer.AUTOWRAP_OFF
	_preview_rich.text = "Juicee"
	_preview_rich.position = Vector2(PANEL_WIDTH / 2.0 - 44, PREVIEW_H / 2.0 - 18) * JuiceeEditorUtil.EDSCALE
	_preview_rich.size = Vector2(120, 40) * JuiceeEditorUtil.EDSCALE
	_preview_rich.add_theme_font_size_override("normal_font_size", int(24 * JuiceeEditorUtil.EDSCALE))
	_preview_rich.add_theme_color_override("default_color", Color(0.9, 0.9, 0.92))
	# The editor theme gives a RichTextLabel a dark panel; the preview's Label has none.
	_preview_rich.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_preview_rich.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_preview_root.add_child(_preview_rich)
	_preview_rich.hide()

	var caption_layer := CanvasLayer.new()
	_preview_viewport.add_child(caption_layer)
	_stand_in_label = Label.new()
	# Bottom-right, out of the subject's way.
	_stand_in_label.position = Vector2(PANEL_WIDTH - 156, PREVIEW_H - 17) * JuiceeEditorUtil.EDSCALE
	_stand_in_label.size = Vector2(150, 15) * JuiceeEditorUtil.EDSCALE
	_stand_in_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stand_in_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_stand_in_label.add_theme_font_size_override("font_size", int(11 * JuiceeEditorUtil.EDSCALE))
	_stand_in_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	caption_layer.add_child(_stand_in_label)
	_stand_in_label.hide()

func _hsep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_color_override("color", Color(0.28, 0.28, 0.40, 0.55))
	return s

# ─── Public API ───────────────────────────────────────────────────────────────

## Show the panel for a JuiceeEffect (graph block or inspector card). `target` is the node the
## effect will play on, when it is known: the preview then plays on a copy of its sprite.
## `live_log` keeps the Output section, which only a graph block's events reach.
func show_for_effect(effect: JuiceeEffect, src_node: Control, target: Node = null,
		live_log := true) -> void:
	# Project Settings > Juicee > Preview can turn the hover panel off entirely.
	if not bool(ProjectSettings.get_setting(HOVER_PANEL_SETTING, true)):
		return
	if not is_instance_valid(effect):
		return
	_clear_log()

	var script_path: String = (effect.get_script() as Script).resource_path
	var basename: String    = script_path.get_file().get_basename()
	var category := effect.get_category_name()
	if category.is_empty():
		category = JuiceeEffectCatalog.EFFECT_CATEGORIES.get(basename, "")
	var desc := effect.get_description()
	if desc.is_empty():
		desc = JuiceeEffectCatalog.EFFECT_DESCRIPTIONS.get(basename, "")

	# Count user-facing @export parameters (excludes base-class bookkeeping fields).
	var param_count := 0
	var _skip := ["graph_position","resource_local_to_scene","resource_name","resource_path","script",
		"enabled","chance","delay","intensity_min","intensity_max","cooldown"]
	for p in effect.get_property_list():
		if (p["usage"] & PROPERTY_USAGE_EDITOR) and (p["usage"] & PROPERTY_USAGE_STORAGE):
			if not (p["name"] in _skip):
				param_count += 1

	# Capture values for the pending closure (avoid lambda-capture-by-ref pitfalls).
	var eff   := effect
	var cat   := category
	var dsc   := desc
	var pcount := param_count
	var tgt   := target
	var logs  := live_log
	_pending_show = func() -> void:
		_show_log(logs)
		_name_label.text = eff.get_display_name()
		_name_label.add_theme_color_override("font_color", JuiceeEditorUtil.heading_color(eff.get_category_color()))
		var cat_text := cat
		if pcount > 0:
			cat_text += "  ·  %d param%s" % [pcount, "s" if pcount != 1 else ""]
		_category_label.text = cat_text
		_desc_label.text = dsc if not dsc.is_empty() else "(no description)"
		_preview_sep.show()
		_no_preview_label.hide()
		_preview_container.show()
		_start_preview(eff, cat, tgt)
	_pending_node = src_node
	_pending_rect = src_node.get_global_rect() if is_instance_valid(src_node) else Rect2()
	_arm_show()

## Show the panel for a built-in block (Trigger, Loop, Split, etc.).
func show_for_builtin(title: String, category: String, desc: String,
		accent: Color, src_node: Control) -> void:
	if not bool(ProjectSettings.get_setting(HOVER_PANEL_SETTING, true)):
		return
	_clear_log()
	var t := title; var c := category; var d := desc; var a := accent
	_pending_show = func() -> void:
		_show_log(true)
		_preview_gen += 1
		_name_label.text = t
		_name_label.add_theme_color_override("font_color", JuiceeEditorUtil.heading_color(a))
		_category_label.text = c
		_desc_label.text = d if not d.is_empty() else "(no description)"
		# Flow-control blocks have nothing to preview, so drop the whole area (and its
		# separator) instead of showing a placeholder that just eats vertical space.
		_preview_sep.hide()
		_preview_container.hide()
		_no_preview_label.hide()
	_pending_node = src_node
	_pending_rect = src_node.get_global_rect() if is_instance_valid(src_node) else Rect2()
	_arm_show()

## Always re-arm the show delay. If a panel is already up (moving between blocks),
## drop it first so it visibly disappears before reappearing on the new block -
## there's always a fresh timer, never an instant content swap.
func _arm_show() -> void:
	_hide_timer.stop()
	if visible:
		force_hide()
	_show_delay_timer.start()

## Add a timestamped entry to the Output log. Called by the graph editor when
## block_fire / block_start / block_end debugger events fire for this effect.
func add_log_entry(text: String) -> void:
	var msec := Time.get_ticks_msec()
	var entry := "[color=#5a5a88][%d.%03d][/color] %s" % [
		int(msec / 1000.0) % 1000, msec % 1000, text
	]
	_log_lines.append(entry)
	if _log_lines.size() > LOG_MAX:
		_log_lines = _log_lines.slice(_log_lines.size() - LOG_MAX)
	_log_label.text = "\n".join(_log_lines)

func schedule_hide() -> void:
	# Cancel any pending show - mouse left before the delay fired.
	_show_delay_timer.stop()
	if visible:
		_hide_timer.start()

## Hide immediately with no fade - used when a block starts being dragged, where
## a lingering fade-out would look stranded as the block moves away.
func force_hide() -> void:
	_show_delay_timer.stop()
	_hide_timer.stop()
	_stop_anim()
	_preview_gen += 1  # cancel any running preview loop
	modulate.a = 0.0
	hide()

# ─── Animation helpers ────────────────────────────────────────────────────────

func _fire_show() -> void:
	# show() BEFORE _pending_show: the preview loop bails while the panel is hidden,
	# so it must already be visible when _start_preview kicks it off - otherwise the
	# loop exits on its first check and the mini-preview never animates (it only ran
	# before if you re-hovered an already-visible panel). modulate stays 0 so it's
	# invisible until the fade-in.
	modulate.a = 0.0
	show()
	_pending_show.call()
	# Project Settings can drop just the description line while keeping the rest of the
	# panel. Done here (after _pending_show sets the text) so it covers both entry points
	# and the re-fit below accounts for the collapsed row.
	if is_instance_valid(_desc_label) and _desc_label.get_parent():
		_desc_label.get_parent().visible = bool(ProjectSettings.get_setting(HOVER_DESCRIPTION_SETTING, true))
	# A PanelContainer grows to fit content but won't shrink itself back, so moving from
	# a tall effect card to a short flow-control one would leave dead space. Force it to
	# re-fit the current content every time.
	reset_size()
	_position_near(_current_src_rect())
	_fade_in()
	_refit.call_deferred()

## Once the layout has run with the new text, fit the panel to it again: the first reset_size()
## measures before the labels have wrapped.
func _refit() -> void:
	if not visible:
		return
	reset_size()
	_position_near(_current_src_rect())

## The block's rect right now (not when the hover started) - survives a scroll/zoom
## during the show-delay. Falls back to the captured rect if the block is gone.
func _current_src_rect() -> Rect2:
	if is_instance_valid(_pending_node) and _pending_node.is_visible_in_tree():
		return _pending_node.get_global_rect()
	return _pending_rect

func _fire_hide() -> void:
	_stop_anim()
	_preview_gen += 1
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "modulate:a", 0.0, 0.16)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_anim_tween.tween_callback(hide)

func _fade_in() -> void:
	_stop_anim()
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "modulate:a", 1.0, 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _stop_anim() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null

# ─── Positioning ──────────────────────────────────────────────────────────────

func _position_near(src: Rect2) -> void:
	var vp := get_viewport_rect().size
	# Use the panel's real computed height (it varies - full preview vs. the
	# shorter "no preview" message) so the bottom-edge clamp keeps the WHOLE panel
	# on-screen instead of guessing a fixed height and overflowing.
	var panel_h := get_combined_minimum_size().y
	if panel_h < 120.0:
		panel_h = 340.0
	# Try right side first; flip to left if it overflows.
	var x := src.end.x + 10.0 * JuiceeEditorUtil.EDSCALE
	if x + PANEL_WIDTH * JuiceeEditorUtil.EDSCALE > vp.x - 6:
		x = src.position.x - PANEL_WIDTH * JuiceeEditorUtil.EDSCALE - 10.0 * JuiceeEditorUtil.EDSCALE
	x = clampf(x, 4, maxf(4.0, vp.x - PANEL_WIDTH * JuiceeEditorUtil.EDSCALE - 4))
	var y := src.position.y
	if y + panel_h > vp.y - 6:
		y = vp.y - panel_h - 6
	y = clampf(y, 4, maxf(4.0, vp.y - panel_h - 4))
	global_position = Vector2(x, y)

func _cancel_hide() -> void:
	_show_delay_timer.stop()
	_hide_timer.stop()
	# If we were fading out, smoothly fade back in from wherever we are.
	if visible and modulate.a < 0.99:
		_fade_in()

func _clear_log() -> void:
	_log_lines.clear()
	_log_label.text = "[color=#7c8094]No output yet. It fills when the running game plays this graph.[/color]"

## Only graph blocks hear from the running game, so an Inspector row has no Output section.
func _show_log(on: bool) -> void:
	for part in _log_parts:
		part.visible = on

# ─── Live preview ─────────────────────────────────────────────────────────────

func _start_preview(effect: JuiceeEffect, category: String, target: Node = null) -> void:
	_set_stand_in(target if category != "Text" else null)
	_preview_gen += 1
	var my_gen := _preview_gen

	if category in _NO_PREVIEW:
		_preview_container.hide()
		_no_preview_label.text = "%s effects have nothing\nto show in a picture" % category
		_no_preview_label.show()
		return

	# Effects whose real target can't exist in the 2D mini-preview - show a hint
	# instead of a misleading static square that never animates.
	var basename := ""
	var scr := effect.get_script() as Script
	if scr:
		basename = scr.resource_path.get_file().get_basename()
	if basename.contains("_3d") or _NO_VISUAL.has(basename):
		_preview_container.hide()
		_no_preview_label.text = "Needs %s,\nso there is nothing to preview" % String(_NO_VISUAL.get(basename, "a 3D node in your scene"))
		_no_preview_label.show()
		return

	# Effects that need a Control get the icon as one; the rest play on the sprite.
	var wants_control := String(JuiceeEffectCatalog.EFFECT_TARGETS.get(basename, "")) == "Control"
	if is_instance_valid(_stand_in):
		_stand_in.visible = not wants_control
	_preview_square.visible = wants_control

	_no_preview_label.hide()
	_preview_container.show()
	_reset_subject()
	_run_preview_loop(effect, category, my_gen)

func _reset_subject() -> void:
	if _drive:
		_drive.kill()
	_preview_subject.position = Vector2(PANEL_WIDTH / 2.0, PREVIEW_H / 2.0) * JuiceeEditorUtil.EDSCALE
	_preview_subject.scale    = Vector2.ONE
	_preview_subject.modulate = Color.WHITE
	_preview_subject.rotation = 0.0
	_reset_square()
	if is_instance_valid(_stand_in):
		_stand_in.flip_h = bool(_stand_in.get_meta("flip_h", false))
		_stand_in.flip_v = bool(_stand_in.get_meta("flip_v", false))
		_stand_in.modulate = Color.WHITE
		_stand_in.material = null
	_preview_light.energy = 0.0
	_preview_light.color = Color.WHITE
	_preview_light.texture_scale = 2.0 * JuiceeEditorUtil.EDSCALE
	_preview_particles.emitting = false
	_preview_rich.text = "Juicee"
	_preview_camera.position  = Vector2(PANEL_WIDTH / 2.0, PREVIEW_H / 2.0) * JuiceeEditorUtil.EDSCALE
	_preview_camera.offset    = Vector2.ZERO
	_preview_camera.zoom      = Vector2.ONE
	_preview_camera.rotation  = 0.0
	# Remove any screen-overlay CanvasLayers the previous effect may have added.
	for child in _preview_root.get_children() + _preview_subject.get_children():
		if child is CanvasLayer:
			child.queue_free()

## Effects that find a Control reach the square itself (Size Delta grows it), so it is put
## back too, or every preview after one of them plays on a stretched bar.
func _reset_square() -> void:
	_preview_square.size = Vector2(48, 48) * JuiceeEditorUtil.EDSCALE
	_preview_square.custom_minimum_size = Vector2.ZERO
	_preview_square.position = Vector2(-24, -24) * JuiceeEditorUtil.EDSCALE
	_preview_square.scale = Vector2.ONE
	_preview_square.rotation = 0.0
	_preview_square.modulate = Color.WHITE
	_preview_square.pivot_offset = Vector2.ZERO

## Trail and Afterimage leave copies of a sprite where it has been, so the preview moves it.
const _MOVES_SUBJECT := ["trail_effect", "afterimage_effect"]

static var _icon_padded: Texture2D

## The editor's own Godot icon, the one a new project gets as icon.svg. A plain square stands in
## on an editor without it. `padded` puts a clear border round it, so Outline has room to draw:
## the icon itself runs to within a few pixels of its edge.
static func _icon(padded := false) -> Texture2D:
	if padded and _icon_padded:
		return _icon_padded
	var tex: Texture2D = null
	if Engine.is_editor_hint():
		var ed_theme := EditorInterface.get_editor_theme()
		if ed_theme and ed_theme.has_icon("DefaultProjectIcon", "EditorIcons"):
			tex = ed_theme.get_icon("DefaultProjectIcon", "EditorIcons")
	var img: Image = tex.get_image() if tex else null
	if not img:
		img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.88, 0.88, 0.92))
		tex = ImageTexture.create_from_image(img)
	if not padded:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var border := int(img.get_width() / 8.0)
	var big := Image.create(img.get_width() + border * 2, img.get_height() + border * 2, false, Image.FORMAT_RGBA8)
	big.fill(Color(0, 0, 0, 0))
	big.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(border, border))
	_icon_padded = ImageTexture.create_from_image(big)
	return _icon_padded

## The sprite Object effects play on: a copy of `target`'s sprite when it has one (a
## Sprite2D or AnimatedSprite2D on it or a few levels down), else the Godot icon.
func _set_stand_in(target: Node) -> void:
	# Out of the tree now, not at the end of the frame: the preview starts in this frame, and an
	# effect looking for a sprite found the old copy first, played on it, and hung when it went.
	if is_instance_valid(_stand_in):
		_stand_in.get_parent().remove_child(_stand_in)
		_stand_in.queue_free()
	_stand_in = null
	if is_instance_valid(_stand_in_label):
		_stand_in_label.hide()
	var src := _find_sprite(target) if is_instance_valid(target) else null
	# A sprite with nothing to draw this frame is no better than none.
	if src is AnimatedSprite2D:
		var frames := (src as AnimatedSprite2D).sprite_frames
		if not frames or not frames.has_animation((src as AnimatedSprite2D).animation):
			src = null
	elif src is Sprite2D and not (src as Sprite2D).texture:
		src = null
	var s := Sprite2D.new()
	var frame_size := Vector2.ZERO
	if not src:
		s.texture = _icon(true)
	elif src is AnimatedSprite2D:
		var a := src as AnimatedSprite2D
		s.texture = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		s.flip_h = a.flip_h
		s.flip_v = a.flip_v
	else:
		var sp := src as Sprite2D
		s.texture = sp.texture
		s.hframes = sp.hframes
		s.vframes = sp.vframes
		s.frame = sp.frame
		s.region_enabled = sp.region_enabled
		s.region_rect = sp.region_rect
		s.flip_h = sp.flip_h
		s.flip_v = sp.flip_v
	if not s.texture:
		s.free()
		return
	# The frame's rect in the texture: the region (or the whole texture) cut into the frame grid.
	var base := s.region_rect if s.region_enabled else Rect2(Vector2.ZERO, s.texture.get_size())
	var cell := base.size / Vector2(maxi(1, s.hframes), maxi(1, s.vframes))
	var coords := Vector2(s.frame % maxi(1, s.hframes), floorf(float(s.frame) / maxi(1, s.hframes)))
	var frame_rect := Rect2i(Rect2(base.position + coords * cell, cell))
	frame_size = Vector2(frame_rect.size)
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		s.free()
		return
	var used := _content_rect(s.texture, frame_rect)
	var drawn := Vector2(used.size)
	var centre := Vector2(used.position) + drawn / 2.0
	if s.flip_h:
		centre.x = frame_size.x - centre.x
	if s.flip_v:
		centre.y = frame_size.y - centre.y
	s.centered = true
	s.offset = frame_size / 2.0 - centre
	if src:
		s.self_modulate = (src as CanvasItem).self_modulate
		s.texture_filter = _effective_filter(src)
	# Fitted to the preview: about half its height, a little less for the icon, whose dark tile
	# reads larger than a character does. Pixel art scales by a whole number, so its pixels stay
	# even.
	var share := 0.55 if src else 0.4
	var fit := minf(PREVIEW_H * share / drawn.y, PANEL_WIDTH * 0.4 / drawn.x) * JuiceeEditorUtil.EDSCALE
	if s.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and fit >= 1.0:
		fit = floorf(fit)
	s.scale = Vector2(fit, fit)
	s.set_meta("flip_h", s.flip_h)
	s.set_meta("flip_v", s.flip_v)
	_preview_subject.add_child(s)
	_stand_in = s
	_stand_in_is_icon = src == null
	if src and is_instance_valid(_stand_in_label):
		_stand_in_label.text = "on %s" % src.name
		_stand_in_label.show()

## The part of `frame_rect` that is drawn. Sheets pad every cell, often by half, and a stand-in
## fitted to the padded cell came out a small sprite in the middle of an empty preview. Falls back
## to the whole frame when the image cannot be read.
func _content_rect(tex: Texture2D, frame_rect: Rect2i) -> Rect2i:
	var key := "%d %s" % [tex.get_instance_id(), frame_rect]
	if _content_rects.has(key):
		return _content_rects[key]
	var used := Rect2i(Vector2i.ZERO, frame_rect.size)
	var img := tex.get_image()
	if img and (not img.is_compressed() or img.decompress() == OK):
		var r := frame_rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.has_area():
			var u := img.get_region(r).get_used_rect()
			if u.has_area():
				used = u
	_content_rects[key] = used
	return used

## The first visible Sprite2D or AnimatedSprite2D on `node` or below it, nearest first.
func _find_sprite(node: Node) -> CanvasItem:
	var queue: Array[Node] = [node]
	var i := 0
	while i < queue.size() and i < 64:
		var n := queue[i]
		i += 1
		if (n is Sprite2D or n is AnimatedSprite2D) and (n as CanvasItem).visible:
			return n as CanvasItem
		queue.append_array(n.get_children())
	return null

## The filter the node is drawn with, following "inherit" up to the project default, so pixel
## art stays sharp in the preview.
func _effective_filter(item: CanvasItem) -> CanvasItem.TextureFilter:
	var n: Node = item
	while n is CanvasItem:
		var f := (n as CanvasItem).texture_filter
		if f != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			return f
		n = n.get_parent()
	var project := int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", 1))
	return [CanvasItem.TEXTURE_FILTER_NEAREST, CanvasItem.TEXTURE_FILTER_LINEAR,
			CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS][clampi(project, 0, 3)]

## Text effects that spawn their own label float it off a Node2D, not off the preview's label.
const _SPAWNS_TEXT := ["damage_number_effect", "floating_text_effect"]
## Screen effects centred on the node they play on, which for the preview root is its corner.
const _CENTRED_ON_NODE := ["shockwave_effect"]

func _get_context(category: String, basename: String = "") -> Node:
	_preview_rich.hide()
	if basename == "rich_text_emphasis_effect":
		_preview_subject.hide()
		_preview_text.hide()
		_preview_rich.show()
		return _preview_rich
	# Outline draws round a texture, so it needs the sprite itself, not the node above it.
	if basename == "outline_effect" and is_instance_valid(_stand_in):
		_preview_subject.show()
		_preview_text.hide()
		return _stand_in
	if basename in _SPAWNS_TEXT or basename in _CENTRED_ON_NODE:
		_preview_subject.show()
		_preview_text.hide()
		return _preview_subject
	if category == "Screen":
		_preview_subject.show()
		_preview_text.hide()
		return _preview_root
	if category == "Text":
		_preview_subject.hide()
		_preview_text.show()
		return _preview_text
	_preview_subject.show()
	_preview_text.hide()
	return _preview_subject

# Coroutine - runs as a background task. Cancelled by bumping _preview_gen.
func _run_preview_loop(effect: JuiceeEffect, category: String, my_gen: int) -> void:
	# Default runtime params so param-driven Text effects (typewriter, number
	# count, damage number, floating text) actually render something. Effects only
	# read the keys they need, so extra keys are harmless.
	var preview_params := {
		"text": "Juicee", "damage": 42, "is_crit": false,
		"from": 0.0, "to": 100.0, "color": Color(1.0, 0.9, 0.4),
	}
	var scr := effect.get_script() as Script
	var basename: String = scr.resource_path.get_file().get_basename() if scr else ""
	while is_instance_valid(self) and is_visible_in_tree() and _preview_gen == my_gen:
		_reset_subject()

		var copy := effect.duplicate() as JuiceeEffect
		# Strip delay / cooldown / chance so preview is snappy and always fires.
		copy.delay         = 0.0
		copy.cooldown      = 0.0
		copy.chance        = 1.0
		copy.intensity_min = 1.0
		copy.intensity_max = 1.0
		# Clamp long durations so a 2-8 s effect doesn't drag out at full length
		# before the preview loops - keep it snappy and obviously animated.
		for p in copy.get_property_list():
			if p["type"] == TYPE_FLOAT:
				var pn: String = p["name"]
				if pn.ends_with("duration") or pn == "hold":
					if float(copy.get(pn)) > 0.6:
						copy.set(pn, 0.6)

		# Screen-overlay effects that clear their centre (Speed Lines) draw thin lines
		# only near the edges - in the tiny wide preview that reads as "nothing".
		# Fill the whole preview and strengthen so the mini-demo is actually visible.
		if copy.get("center_clear") != null:
			copy.set("center_clear", 0.0)
			if copy.get("strength") != null:
				copy.set("strength", maxf(float(copy.get("strength")), 0.85))

		# Dutch tilt defaults to a subtle 5°, which barely reads at preview size. Boost
		# it so the tilt is obvious (it still eases back to level on its own).
		if basename == "camera_rotation_effect":
			copy.angle_degrees = 20.0
		# The same goes for the rest of what a full screen shows plainly and a 300 px preview
		# shrinks to a few pixels: a floor under each, never a cut.
		match basename:
			"shake_effect":
				copy.set("intensity", maxf(float(copy.get("intensity")), 14.0))
			"camera_bob_effect":
				var amp: Vector2 = copy.get("amplitude")
				if amp.length() > 0.0 and amp.length() < 8.0:
					copy.set("amplitude", amp.normalized() * 8.0)
			"chromatic_effect":
				copy.set("intensity", maxf(float(copy.get("intensity")), 10.0))
			"glitch_effect":
				copy.set("intensity", maxf(float(copy.get("intensity")), 0.8))
			"breathe_effect":
				copy.set("amount", maxf(float(copy.get("amount")), 0.1))
			"sway_effect":
				copy.set("angle", maxf(float(copy.get("angle")), 12.0))
			"shockwave_effect":
				copy.set("strength", maxf(float(copy.get("strength")), 0.1))
				copy.set("ring_width", maxf(float(copy.get("ring_width")), 0.08))
			"outline_effect":
				# Its width is in texture pixels, and the icon's texture is drawn at about a
				# third of its size: at least 3 pixels on screen.
				if is_instance_valid(_stand_in) and _stand_in.scale.x > 0.0:
					copy.set("outline_width", clampf(maxf(float(copy.get("outline_width")),
							3.0 / _stand_in.scale.x), 0.0, 16.0))
			"flip_effect":
				# The icon is symmetric, so a plain mirror would show nothing on it.
				if _stand_in_is_icon:
					copy.set("animate", true)

		var context := _get_context(category, basename)
		# Camera Follow lerps the camera toward the context node. Everything else sits
		# dead-centre under the camera, so without an offset target the camera has
		# nowhere to travel and the preview looks frozen. Push the follow target aside
		# and it pans across (the oversized canvas keeps the edge from showing through).
		if basename == "camera_follow_effect":
			_preview_subject.position = Vector2(PANEL_WIDTH / 2.0 + 78, PREVIEW_H / 2.0) * JuiceeEditorUtil.EDSCALE
		# Damage numbers and floating text rise from above the node; from the middle of a 118 px
		# preview they left it at once.
		if basename in _SPAWNS_TEXT:
			_preview_subject.position.y = PREVIEW_H * 0.8 * JuiceeEditorUtil.EDSCALE
		if basename in _MOVES_SUBJECT:
			_preview_subject.position.x = (PANEL_WIDTH / 2.0 - 80) * JuiceeEditorUtil.EDSCALE
			_drive = _preview_subject.create_tween()
			_drive.tween_property(_preview_subject, "position:x",
					(PANEL_WIDTH / 2.0 + 80) * JuiceeEditorUtil.EDSCALE, 0.6) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if context.is_inside_tree():
			await copy.apply(context, preview_params)

		if _preview_gen != my_gen:
			break

		await get_tree().create_timer(0.5, true, false, false).timeout

	if _preview_gen == my_gen:
		_reset_subject()
