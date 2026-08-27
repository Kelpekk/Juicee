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

## Editor display scale (HiDPI). Every hardcoded pixel size multiplies by this
## so the UI matches the editor at 150%/200% display scale. 1.0 = no-op.
static var EDSCALE: float = (EditorInterface.get_editor_scale() if Engine.is_editor_hint() else 1.0)

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
var _preview_camera:    Camera2D
var _preview_text:      Label
var _no_preview_label:  Label
var _preview_sep:       Control
var _log_label:         RichTextLabel

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
	"bloom_effect": "a WorldEnvironment",
	"tonemap_effect": "a WorldEnvironment",
	"light_flash_effect": "a Light2D",
	"strobe_light_effect": "a Light2D",
	"depth_of_field_effect": "a Camera3D",
	"animation_player_effect": "an AnimationPlayer",
	"animation_tree_effect": "an AnimationTree",
	"particle_effect": "a particle node",
	"instantiate_effect": "a PackedScene",
	"set_property_effect": "a target node",
	"set_active_effect": "a target node",
}

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	custom_minimum_size.x = PANEL_WIDTH * EDSCALE
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
	sb.set_border_width_all(maxi(1, int(1 * EDSCALE)))
	# Soft drop-shadow so the panel lifts off the canvas without a hard edge.
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = int(6 * EDSCALE)
	sb.shadow_offset = Vector2(0, 2)
	for corner in [0, 1, 2, 3]:
		sb.set_corner_radius(corner, int(6 * EDSCALE))
	add_theme_stylebox_override("panel", sb)

func _build_layout() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(0 * EDSCALE))
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
		hdr_sb.set_corner_radius(corner, int(6 * EDSCALE))
	hdr_sb.content_margin_left   = 10 * EDSCALE
	hdr_sb.content_margin_right  = 10 * EDSCALE
	hdr_sb.content_margin_top    = 7 * EDSCALE
	hdr_sb.content_margin_bottom = 7 * EDSCALE
	header.add_theme_stylebox_override("panel", hdr_sb)
	vbox.add_child(header)

	var hdr_row := HBoxContainer.new()
	header.add_child(hdr_row)

	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_row.add_child(_name_label)

	_category_label = Label.new()
	_category_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.44))
	_category_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hdr_row.add_child(_category_label)

	# ── Description ───────────────────────────────────────────────────────────
	var desc_m := MarginContainer.new()
	desc_m.add_theme_constant_override("margin_left",   int(10 * EDSCALE))
	desc_m.add_theme_constant_override("margin_right",  int(10 * EDSCALE))
	desc_m.add_theme_constant_override("margin_top",     int(8 * EDSCALE))
	desc_m.add_theme_constant_override("margin_bottom",  int(8 * EDSCALE))
	vbox.add_child(desc_m)

	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_color_override("font_color", Color(0.80, 0.82, 0.88, 0.86))
	desc_m.add_child(_desc_label)

	# Separator above the preview. Kept as a field so flow-control blocks, which have
	# no preview, can drop it too and not leave a doubled divider next to the log's.
	_preview_sep = _hsep()
	vbox.add_child(_preview_sep)

	# ── Preview area ──────────────────────────────────────────────────────────
	_preview_container = SubViewportContainer.new()
	_preview_container.custom_minimum_size = Vector2(PANEL_WIDTH, PREVIEW_H) * EDSCALE
	_preview_container.stretch = true
	vbox.add_child(_preview_container)

	_no_preview_label = Label.new()
	_no_preview_label.custom_minimum_size = Vector2(PANEL_WIDTH, PREVIEW_H) * EDSCALE
	_no_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_preview_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_no_preview_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.42))
	vbox.add_child(_no_preview_label)
	_no_preview_label.hide()

	vbox.add_child(_hsep())

	# ── Log ───────────────────────────────────────────────────────────────────
	var log_hdr_m := MarginContainer.new()
	log_hdr_m.add_theme_constant_override("margin_left",   int(10 * EDSCALE))
	log_hdr_m.add_theme_constant_override("margin_right",  int(10 * EDSCALE))
	log_hdr_m.add_theme_constant_override("margin_top",     int(5 * EDSCALE))
	log_hdr_m.add_theme_constant_override("margin_bottom",  int(3 * EDSCALE))
	vbox.add_child(log_hdr_m)

	var log_title := Label.new()
	log_title.text = "Output"
	log_title.add_theme_color_override("font_color", Color(0.50, 0.54, 0.70, 0.9))
	log_hdr_m.add_child(log_title)

	var log_outer := MarginContainer.new()
	log_outer.add_theme_constant_override("margin_left",   int(8 * EDSCALE))
	log_outer.add_theme_constant_override("margin_right",  int(8 * EDSCALE))
	log_outer.add_theme_constant_override("margin_bottom", int(10 * EDSCALE))
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
		log_sb.set_corner_radius(corner, int(4 * EDSCALE))
	log_sb.content_margin_left   = 8 * EDSCALE
	log_sb.content_margin_right  = 8 * EDSCALE
	log_sb.content_margin_top    = 6 * EDSCALE
	log_sb.content_margin_bottom = 6 * EDSCALE
	log_panel.add_theme_stylebox_override("panel", log_sb)
	log_outer.add_child(log_panel)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.fit_content = true
	_log_label.scroll_active = false
	_log_label.custom_minimum_size.x = (PANEL_WIDTH - 32) * EDSCALE
	_log_label.text = "[color=#383850]No output yet - run the game to see live events[/color]"
	log_panel.add_child(_log_label)

func _build_preview_viewport() -> void:
	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(int(PANEL_WIDTH * EDSCALE), int(PREVIEW_H * EDSCALE))
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
	bg.position = Vector2(-PREVIEW_MARGIN, -PREVIEW_MARGIN) * EDSCALE
	bg.size = Vector2(PANEL_WIDTH + 2 * PREVIEW_MARGIN, PREVIEW_H + 2 * PREVIEW_MARGIN) * EDSCALE
	bg.z_index = -10
	_preview_root.add_child(bg)

	# A faint grid over the whole canvas. Distortion effects (shockwave, lens
	# distortion, chromatic, blur) only show up where there are edges to bend, and
	# two accent panels left most of the frame flat, so they read as barely doing
	# anything. Lines everywhere means the warp is visible wherever it lands.
	var grid := Node2D.new()
	grid.z_index = -9
	grid.modulate = Color(1, 1, 1, 0.16)
	_preview_root.add_child(grid)
	var step := 14.0 * EDSCALE
	# Cover the oversized background so the grid keeps going when the camera pans.
	var gx0: float = -PREVIEW_MARGIN * EDSCALE
	var gx1: float = (PANEL_WIDTH + PREVIEW_MARGIN) * EDSCALE
	var gy0: float = -PREVIEW_MARGIN * EDSCALE
	var gy1: float = (PREVIEW_H + PREVIEW_MARGIN) * EDSCALE
	var x := gx0
	while x < gx1:
		var v := ColorRect.new()
		v.color = Color(0.62, 0.68, 0.85)
		v.position = Vector2(x, gy0)
		v.size = Vector2(maxf(1.0, EDSCALE), gy1 - gy0)
		grid.add_child(v)
		x += step
	var y := gy0
	while y < gy1:
		var hl := ColorRect.new()
		hl.color = Color(0.62, 0.68, 0.85)
		hl.position = Vector2(gx0, y)
		hl.size = Vector2(gx1 - gx0, maxf(1.0, EDSCALE))
		grid.add_child(hl)
		y += step

	# Static side panels so screen effects have actual content to act on - a flat
	# fill shows nothing under chromatic/blur/glitch/distortion. Positioned at the
	# edges so they frame (never cover) the center subject that Object effects animate.
	var accents := [
		[Color(0.28, 0.40, 0.60), Vector2(16, 14), Vector2(56, 90)],
		[Color(0.62, 0.45, 0.30), Vector2(228, 22), Vector2(56, 74)],
	]
	for a in accents:
		var panel := ColorRect.new()
		panel.color = a[0]
		panel.position = a[1] * EDSCALE
		panel.size = a[2] * EDSCALE
		panel.z_index = -9
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview_root.add_child(panel)

	# Camera - required so camera effects find a Camera2D in the SubViewport.
	_preview_camera = Camera2D.new()
	_preview_camera.position = Vector2(PANEL_WIDTH / 2.0, PREVIEW_H / 2.0) * EDSCALE
	_preview_camera.enabled = true
	_preview_root.add_child(_preview_camera)

	# Demo subject - a small Node2D (extends CanvasItem) with a white square child.
	# Object effects manipulate position/scale/rotation/modulate on this.
	_preview_subject = Node2D.new()
	_preview_subject.position = Vector2(PANEL_WIDTH / 2.0, PREVIEW_H / 2.0) * EDSCALE
	_preview_root.add_child(_preview_subject)

	var square := ColorRect.new()
	square.color = Color(0.88, 0.88, 0.92)
	square.size = Vector2(38, 38) * EDSCALE
	square.position = Vector2(-19, -19) * EDSCALE
	_preview_subject.add_child(square)

	# Text label for Text-category effects (typewriter, number_count, etc.).
	_preview_text = Label.new()
	_preview_text.text = "100"
	_preview_text.position = Vector2(PANEL_WIDTH / 2.0 - 18, PREVIEW_H / 2.0 - 16) * EDSCALE
	_preview_text.add_theme_font_size_override("font_size", int(24 * EDSCALE))
	_preview_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	_preview_root.add_child(_preview_text)
	_preview_text.hide()

func _hsep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_color_override("color", Color(0.28, 0.28, 0.40, 0.55))
	return s

# ─── Public API ───────────────────────────────────────────────────────────────

## Show the panel for a JuiceeEffect (graph block or inspector card).
func show_for_effect(effect: JuiceeEffect, src_node: Control) -> void:
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
		category = JuiceeGraphEditor.EFFECT_CATEGORIES.get(basename, "")
	var desc := effect.get_description()
	if desc.is_empty():
		desc = JuiceeGraphEditor.EFFECT_DESCRIPTIONS.get(basename, "")

	# Count user-facing @export parameters (excludes base-class bookkeeping fields).
	var param_count := 0
	var _skip := ["graph_position","resource_local_to_scene","resource_name","resource_path","script",
		"chance","delay","intensity_min","intensity_max","cooldown"]
	for p in effect.get_property_list():
		if (p["usage"] & PROPERTY_USAGE_EDITOR) and (p["usage"] & PROPERTY_USAGE_STORAGE):
			if not (p["name"] in _skip):
				param_count += 1

	# Capture values for the pending closure (avoid lambda-capture-by-ref pitfalls).
	var eff   := effect
	var cat   := category
	var dsc   := desc
	var pcount := param_count
	_pending_show = func() -> void:
		_name_label.text = eff.get_display_name()
		_name_label.add_theme_color_override("font_color", eff.get_category_color().lightened(0.22))
		var cat_text := cat
		if pcount > 0:
			cat_text += "  ·  %d param%s" % [pcount, "s" if pcount != 1 else ""]
		_category_label.text = cat_text
		_desc_label.text = dsc if not dsc.is_empty() else "(no description)"
		_preview_sep.show()
		_no_preview_label.hide()
		_preview_container.show()
		_start_preview(eff, cat)
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
		_preview_gen += 1
		_name_label.text = t
		_name_label.add_theme_color_override("font_color", a.lightened(0.18))
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
		(msec / 1000) % 1000, msec % 1000, text
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
	var x := src.end.x + 10.0 * EDSCALE
	if x + PANEL_WIDTH * EDSCALE > vp.x - 6:
		x = src.position.x - PANEL_WIDTH * EDSCALE - 10.0 * EDSCALE
	x = clampf(x, 4, maxf(4.0, vp.x - PANEL_WIDTH * EDSCALE - 4))
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
	_log_label.text = "[color=#383850]No output yet - run the game to see live events[/color]"

# ─── Live preview ─────────────────────────────────────────────────────────────

func _start_preview(effect: JuiceeEffect, category: String) -> void:
	_preview_gen += 1
	var my_gen := _preview_gen

	if category in _NO_PREVIEW:
		_preview_container.hide()
		_no_preview_label.text = "%s effect - no visual preview" % category
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
		_no_preview_label.text = "Needs %s in your scene\n- no live preview here" % String(_NO_VISUAL.get(basename, "a 3D node"))
		_no_preview_label.show()
		return

	_no_preview_label.hide()
	_preview_container.show()
	_reset_subject()
	_run_preview_loop(effect, category, my_gen)

func _reset_subject() -> void:
	_preview_subject.position = Vector2(PANEL_WIDTH / 2.0, PREVIEW_H / 2.0) * EDSCALE
	_preview_subject.scale    = Vector2.ONE
	_preview_subject.modulate = Color.WHITE
	_preview_subject.rotation = 0.0
	_preview_camera.position  = Vector2(PANEL_WIDTH / 2.0, PREVIEW_H / 2.0) * EDSCALE
	_preview_camera.offset    = Vector2.ZERO
	_preview_camera.zoom      = Vector2.ONE
	_preview_camera.rotation  = 0.0
	# Remove any screen-overlay CanvasLayers the previous effect may have added.
	for child in _preview_root.get_children():
		if child is CanvasLayer:
			child.queue_free()

func _get_context(category: String) -> Node:
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

		var context := _get_context(category)
		# Camera Follow lerps the camera toward the context node. Everything else sits
		# dead-centre under the camera, so without an offset target the camera has
		# nowhere to travel and the preview looks frozen. Push the follow target aside
		# and it pans across (the oversized canvas keeps the edge from showing through).
		if basename == "camera_follow_effect":
			_preview_subject.position = Vector2(PANEL_WIDTH / 2.0 + 78, PREVIEW_H / 2.0) * EDSCALE
		if context.is_inside_tree():
			await copy.apply(context, preview_params)

		if _preview_gen != my_gen:
			break

		await get_tree().create_timer(0.5, true, false, false).timeout

	if _preview_gen == my_gen:
		_reset_subject()
