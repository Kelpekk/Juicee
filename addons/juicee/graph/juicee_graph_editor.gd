@tool
class_name JuiceeGraphEditor
extends Control

## Editor display scale (HiDPI). Every hardcoded pixel size multiplies by this
## so the UI matches the editor at 150%/200% display scale. 1.0 = no-op.
static var EDSCALE: float = (EditorInterface.get_editor_scale() if Engine.is_editor_hint() else 1.0)

const EFFECTS_DIR := "res://addons/juicee/effects/"
const BASE_EFFECT_FILE := "juicee_effect.gd"

# ─── Category & description registry ─────────────────────────────────────────
# Maps effect script basename → (category, description) for the popup search list.
# Effects that override get_category_name()/get_description() take precedence over this.
# Order of CATEGORY_ORDER controls section display order.
const CATEGORY_ORDER := ["Screen", "Camera", "Object", "Text", "Time", "Audio", "Physics", "Flow", "Misc"]

const EFFECT_CATEGORIES := {
	# Screen FX shaders + overlays
	"chromatic_effect":     "Screen",
	"vignette_effect":      "Screen",
	"blur_effect":          "Screen",
	"pixelate_effect":      "Screen",
	"glitch_effect":        "Screen",
	"color_grade_effect":   "Screen",
	"screen_tint_effect":   "Screen",
	"screen_wipe_effect":   "Screen",
	"bloom_effect":         "Screen",
	"tonemap_effect":       "Screen",
	"shockwave_effect":        "Screen",
	"cinematic_bars_effect":   "Screen",
	"scan_lines_effect":       "Screen",
	"film_grain_effect":       "Screen",
	"radial_blur_effect":      "Screen",
	# Camera
	"shake_effect":              "Camera",
	"shake_3d_effect":           "Camera",
	"zoom_effect":               "Camera",
	"fov_3d_effect":             "Camera",
	"camera_follow_effect":      "Camera",
	"directional_shake_effect":  "Camera",
	"camera_bob_effect":         "Camera",
	"zoom_pulse_effect":         "Camera",
	# Object (per-target transforms / particles / light)
	"flash_effect":         "Object",
	"modulate_effect":      "Object",
	"bounce_effect":        "Object",
	"jiggle_physics_effect":"Object",
	"position_effect":      "Object",
	"position_3d_effect":   "Object",
	"rotation_effect":      "Object",
	"rotation_3d_effect":   "Object",
	"trail_effect":         "Object",
	"burst_effect":         "Object",
	"confetti_effect":      "Object",
	"light_flash_effect":   "Object",
	"spring_effect":        "Object",
	# Text / UI
	"damage_number_effect": "Text",
	"floating_text_effect": "Text",
	"button_punch_effect":  "Text",
	"typewriter_effect":    "Text",
	"number_count_effect":  "Text",
	"text_wobble_effect":   "Text",
	# Time
	"hit_stop_effect":      "Time",
	"time_scale_ramp_effect":"Time",
	"delay_effect":         "Time",
	# Audio / haptics
	"sound_effect":         "Audio",
	"music_duck_effect":    "Audio",
	"rumble_effect":        "Audio",
	"reverb_effect":        "Audio",
	"pitch_shift_effect":   "Audio",
	# Physics
	"impulse_effect":       "Physics",
	# ULTIMATE — Object
	"ambient_flash_effect": "Object",
	"strobe_light_effect":  "Object",
	"recoil_effect":        "Object",
	"outline_effect":       "Object",
	"color_cycle_effect":   "Object",
	"spin_effect":          "Object",
	"wiggle_effect":        "Object",
	"sprite_bob_effect":    "Object",
	"pop_in_effect":        "Object",
	"shake_control_effect": "Object",
	"pulse_effect":         "Object",
	# ULTIMATE — Flow
	"animation_player_effect": "Flow",
	"set_active_effect":    "Flow",
	"chain_effect":         "Flow",
	"beat_sync_effect":     "Flow",
	"wait_for_input_effect":"Flow",
	# Time
	"freeze_frame_effect":  "Time",
	# Composition / generic
	"sequence_effect":      "Flow",
	"property_tween_effect":"Flow",
	# Batch 3 — Screen
	"lens_distortion_effect":  "Screen",
	"depth_of_field_effect":   "Screen",
	# Batch 3 — Camera
	"camera_rotation_effect":  "Camera",
	# Batch 3 — Object
	"shader_parameter_effect": "Object",
	"flicker_effect":          "Object",
	"scale_effect":            "Object",
	"particle_effect":         "Object",
	"light_3d_effect":         "Object",
	"material_3d_effect":      "Object",
	# Batch 3 — Audio
	"audio_source_3d_effect":  "Audio",
	# Batch 3 — Physics
	"add_force_effect":        "Physics",
	# Batch 3 — Flow
	"emit_signal_effect":      "Flow",
	"debug_log_effect":        "Flow",
	"animation_tree_effect":   "Flow",
	"set_property_effect":     "Flow",
	# Batch 4 — missing fundamentals
	"fade_effect":             "Object",
	"flip_effect":             "Object",
	"instantiate_effect":      "Object",
	"size_delta_effect":       "Object",
	"auto_destruct_effect":    "Flow",
}

const EFFECT_DESCRIPTIONS := {
	"chromatic_effect":     "RGB channel split full-screen.\nUse for damage hits or glitch moments.",
	"vignette_effect":      "Edge-darkening overlay with color tint.\nGreat for damage red or atmospheric mood.",
	"blur_effect":          "Full-screen gaussian blur.\nUse for pause menus or dream sequences.",
	"pixelate_effect":      "Full-screen pixelation.\nRetro flashes, damage hits, glitch moments.",
	"glitch_effect":        "Horizontal tear + chromatic split.\nDamage, hacking, broken-system vibe.",
	"color_grade_effect":   "Saturation / contrast / brightness / tint shift.\nDesaturate on damage, boost on level-up.",
	"screen_tint_effect":   "Colored full-screen overlay (red damage, gold level-up).",
	"screen_wipe_effect":   "Colored bar slides across screen for transitions.",
	"bloom_effect":         "Pulses WorldEnvironment glow (built-in Godot post-process).\nBoss intros, level-ups, power-ups. Native performance, 2D + 3D.",
	"tonemap_effect":       "Punch tonemap exposure for flashbang / overload feel.\nExplosions, teleports, dimension shifts.",
	"shockwave_effect":     "Expanding radial distortion ring from the context node's position.\nExplosions, teleport arrivals, spell impacts, landing slams.",
	"cinematic_bars_effect":"Letterbox bars slide in / hold / slide out for cutscene feel.\nBoss intros, dialogue sequences, dramatic slow-mo moments.",
	"shake_effect":         "Shakes the active Camera2D with Perlin noise + decay.\nThe absolute king of game feel.",
	"shake_3d_effect":      "Camera3D shake with per-axis scaling (Y=0 for horizontal-only).",
	"zoom_effect":          "Camera2D zoom punch in/out with overshoot.",
	"fov_3d_effect":        "Camera3D field-of-view punch (positive = zoom out).",
	"camera_follow_effect": "Smoothly lerps Camera2D to follow a target then returns.\nAttention shift for boss intros.",
	"flash_effect":         "Blinks `modulate` on a CanvasItem N times.\nUse for hit acknowledgment on sprites.",
	"modulate_effect":      "Smooth color shift (unlike Flash which blinks).",
	"bounce_effect":        "Squash & stretch scale punch on a Node2D.",
	"jiggle_physics_effect":"Spring-based jelly jiggle (real physics, not preset).",
	"position_effect":      "Move Node2D by offset, then return.",
	"position_3d_effect":   "Same as Position but for Node3D.",
	"rotation_effect":      "Rotate Node2D by angle, then return.",
	"rotation_3d_effect":   "Same as Rotation but for Node3D (quaternion-based).",
	"trail_effect":         "Sprite2D ghost trail behind a moving target.",
	"burst_effect":         "One-shot CPUParticles2D burst at target position.",
	"confetti_effect":      "Multi-color particle burst for celebrations / level-ups.",
	"light_flash_effect":   "Flash a Light2D's energy and color briefly.",
	"spring_effect":        "Harmonic-oscillator spring on a Vector2 property.\nBouncy menus, squash on hit, panel-into-view oscillation.",
	"damage_number_effect": "Floating damage numbers above a target.\nPass {\"damage\": 42, \"is_crit\": true} via play() for live values.",
	"floating_text_effect": "Generic floating text (Level Up!, pickup names, status messages).\nPass {\"text\": \"Hello!\"} via play() for dynamic content.",
	"button_punch_effect":  "Scale-punch for Control nodes (Button, Label, Panel).\nThe bouncy UI feel of polished menus.",
	"typewriter_effect":    "Char-by-char text reveal on a Label with optional click sounds.\nDialog, intros, terminal vibes.",
	"number_count_effect":  "Tween a Label's number from X to Y.\nScore rollups, money displays, XP gains. Pass {\"from\":1200,\"to\":2000}.",
	"text_wobble_effect":   "Sine-wave wobble on a Control's position with decay.\nDrama text: GAME OVER, WAVE COMPLETE, BOSS APPROACHING.",
	"hit_stop_effect":      "Instant Engine.time_scale freeze for impact moments.\n~50-100ms is the sweet spot.",
	"time_scale_ramp_effect":"Smooth slow-mo with ramp-in / hold / ramp-out.",
	"delay_effect":         "Wait N seconds. Useful for sequencing.",
	"sound_effect":         "Plays a random AudioStream with pitch variance.",
	"music_duck_effect":    "Temporarily lowers an audio bus volume.",
	"rumble_effect":        "Gamepad vibration via Input.start_joy_vibration.",
	"reverb_effect":        "Inject a temporary AudioEffectReverb on a bus with wet ramp.\nBoss intros, dimension shifts, low-health states.",
	"pitch_shift_effect":   "Animate a temporary AudioEffectPitchShift on a bus.\nUnderwater, slow-mo audio, demon transformations.",
	"impulse_effect":       "Applies an impulse to a RigidBody2D (knockback).",
	"ambient_flash_effect": "Repeating modulate flash for sustained states.\nLow-health siren, boss enrage, alarm pulsing.",
	"strobe_light_effect":  "Square-wave Light2D strobe.\nLightning flashes, flashbangs, emergency sirens.",
	"recoil_effect":        "Directional position kick on Node2D with spring-back.\nGun recoil, hit absorption, stiff-arm impact.",
	"outline_effect":       "Animate a colored sprite outline via shader uniform.\nSelection ring, status glow, lock-on indicator.",
	"color_cycle_effect":   "Cycle modulate through the HSV hue wheel.\nRainbow powerup, party mode, boss phase shift.",
	"animation_player_effect": "Trigger AnimationPlayer.play() as a sequence step.\nFEEL parity — blend existing animations into Juicee sequences.",
	"set_active_effect":    "Show/hide a node for N seconds then restore.\nMuzzle flash, hit spark, tutorial highlight.",
	"chain_effect":         "Compose N child effects as one reusable block.\nBuild signature combos as single .tres assets.",
	"sequence_effect":      "Embeds another JuiceeSequence as one step.\nFor composable presets.",
	"property_tween_effect":"Tween ANY property on ANY node.\nUniversal escape hatch.",
	# New batch
	"scan_lines_effect":       "CRT scanline overlay with scroll.\nRetro monitors, broken screens, hacker aesthetic.",
	"film_grain_effect":       "Analog film grain noise overlay.\nCinematic grit, horror atmosphere, film emulation.",
	"radial_blur_effect":      "Radial motion blur from a screen point.\nSpeed lines, warp drives, dash impacts.",
	"directional_shake_effect":"Kick-recoil shake in a specific direction with perpendicular noise.\nGun fire, punches, directional hits.",
	"camera_bob_effect":       "Rhythmic sine-wave camera bob (walk cycle, breathing idle).\nSin envelope — smooth start and stop.",
	"zoom_pulse_effect":       "BPM-synced zoom pulse on Camera2D.\nBeat-drop, music-reactive, bass rumble feel.",
	"spin_effect":             "Full 360° rotation tween on Node2D.\nCoin pickups, death spin, victory twirl.",
	"wiggle_effect":           "Random position jitter at frequency Hz with optional decay.\nAnxiety, confusion, low-health tremor.",
	"sprite_bob_effect":       "Sine-wave bob along an axis (idle float, hover loop).\nPickups, UI icons, floating enemies.",
	"pop_in_effect":           "SPRING overshoot scale-in from 0 (or custom from_scale).\nThe most satisfying UI pop-in possible.",
	"shake_control_effect":    "Horizontal shake on Control nodes (Button, Panel, Label).\nWrong-password UI, invalid action feedback.",
	"pulse_effect":            "Repeating scale pulse (EXPO in+out).\nOngoing heartbeat, charge meter, selected state.",
	"freeze_frame_effect":     "Engine.time_scale = 0 for N ms then restore.\nImpact pause — feels heavier than hit_stop.",
	"wait_for_input_effect":   "Pause sequence until player presses an action.\nDialog advancement, tutorial checkpoints, cutscene pacing.",
	"beat_sync_effect":        "Fire a child effect on every N beats (BPM-synced or JuiceeBeatClock).\nMusic-reactive juiciness, rhythm-game impacts.",
	# Batch 3
	"lens_distortion_effect":  "Barrel or pincushion lens distortion full-screen.\nPositive = fisheye, negative = telephoto. Scope zoom-in, portal, impact.",
	"depth_of_field_effect":   "Animate Camera3D depth-of-field blur (CameraAttributes).\nFocus pull, sniper scope, dialogue close-up, death blur.",
	"camera_rotation_effect":  "Dutch tilt — rotate Camera2D to angle then spring back.\nSuspense, horror reveal, gravity shift, off-kilter dream.",
	"shader_parameter_effect": "Tween any uniform on any ShaderMaterial.\nAnimate dissolves, hit-flash, charge-up glow, forcefield intensity.",
	"flicker_effect":          "Organic random visibility flicker on a CanvasItem.\nBroken lights, haunted objects, EMP, damaged HUD.",
	"scale_effect":            "General scale tween to target and optionally back.\nGrow on buff, shrink on nerf, scale-in from 0, death scale-out.",
	"particle_effect":         "Control an existing CPUParticles2D / GPUParticles2D node.\nEmit, stop, or restart a pre-configured particle system.",
	"light_3d_effect":         "Flash a Light3D energy and color (OmniLight3D, SpotLight3D).\n3D muzzle flash, explosion light, lightning strike, magical impact.",
	"material_3d_effect":      "Animate a MeshInstance3D material property (albedo, emission, etc.).\nHit flash, damage glow, dissolve, ghost transparency.",
	"audio_source_3d_effect":  "Spatial 3D AudioStreamPlayer3D at context's world position.\nFootsteps, gunshots, explosions with proper 3D attenuation.",
	"add_force_effect":        "Apply impulse or continuous force to RigidBody2D / RigidBody3D.\nExplosion push, wind gust, magnetic pull, knock-back.",
	"emit_signal_effect":      "Emit a signal on the context node mid-sequence.\nBridge Juicee timing to game logic: spawn enemy, open door, start dialogue.",
	"debug_log_effect":        "Print a debug message when this sequence step fires.\nTrace branch choices, confirm timing, integration debugging.",
	"animation_tree_effect":   "Travel to an AnimationTree state or set a parameter.\nTrigger 'Attack', blend run/walk, reset one-shot animations.",
	"set_property_effect":     "Instantly set any property on any node, optionally restore after delay.\nToggle bool flags, snap positions, change labels, set collision layers.",
	"fade_effect":             "Fade a CanvasItem's alpha to a target value over time.\nFade out on death, fade in on spawn, cutscene transitions, stealth state.",
	"flip_effect":             "Set flip_h / flip_v on a Sprite2D or AnimatedSprite2D.\nDirectional facing, hit reaction mirror, coin flip reveal.",
	"instantiate_effect":      "Spawn a PackedScene at the context node's position.\nBlood splats, hit sparks, VFX, spawn enemies / pickups / projectiles.",
	"size_delta_effect":       "Tween a Control's size or custom_minimum_size to a target value.\nHealth bar grow/shrink, animated panel expand/collapse, progress fill.",
	"auto_destruct_effect":    "Queue-free the context node (or a target) after an optional delay.\nClean up temporary VFX, hit sparks, spawned floating text, corpses.",
}


## Maps effect basename → ["2d"] / ["3d"] / ["2d","3d"].
## Used in the popup search list and graph block titlebars as small tag icons.
const EFFECT_DIMENSIONS: Dictionary = {
	# Screen overlays — full-screen shaders work in both 2D and 3D viewports.
	"chromatic_effect":        ["2d","3d"],
	"vignette_effect":         ["2d","3d"],
	"blur_effect":             ["2d","3d"],
	"pixelate_effect":         ["2d","3d"],
	"glitch_effect":           ["2d","3d"],
	"color_grade_effect":      ["2d","3d"],
	"screen_tint_effect":      ["2d","3d"],
	"screen_wipe_effect":      ["2d","3d"],
	"bloom_effect":            ["2d","3d"],
	"tonemap_effect":          ["2d","3d"],
	"shockwave_effect":        ["2d","3d"],
	"cinematic_bars_effect":   ["2d","3d"],
	# Camera
	"shake_effect":            ["2d"],
	"zoom_effect":             ["2d"],
	"camera_follow_effect":    ["2d"],
	"shake_3d_effect":         ["3d"],
	"fov_3d_effect":           ["3d"],
	# Object — 2D (Node2D / CanvasItem / Light2D)
	"flash_effect":            ["2d"],
	"modulate_effect":         ["2d"],
	"bounce_effect":           ["2d"],
	"jiggle_physics_effect":   ["2d"],
	"position_effect":         ["2d"],
	"rotation_effect":         ["2d"],
	"trail_effect":            ["2d"],
	"burst_effect":            ["2d"],
	"confetti_effect":         ["2d"],
	"light_flash_effect":      ["2d"],
	"spring_effect":           ["2d"],
	"ambient_flash_effect":    ["2d"],
	"strobe_light_effect":     ["2d"],
	"recoil_effect":           ["2d"],
	"outline_effect":          ["2d"],
	"color_cycle_effect":      ["2d"],
	# Object — 3D
	"position_3d_effect":      ["3d"],
	"rotation_3d_effect":      ["3d"],
	# Text / UI — Control nodes are 2D only.
	"damage_number_effect":    ["2d"],
	"floating_text_effect":    ["2d"],
	"button_punch_effect":     ["2d"],
	"typewriter_effect":       ["2d"],
	"number_count_effect":     ["2d"],
	"text_wobble_effect":      ["2d"],
	# Time — engine-level, works in any scene.
	"hit_stop_effect":         ["2d","3d"],
	"time_scale_ramp_effect":  ["2d","3d"],
	"delay_effect":            ["2d","3d"],
	# Audio / haptics — bus-level, scene-independent.
	"sound_effect":            ["2d","3d"],
	"music_duck_effect":       ["2d","3d"],
	"rumble_effect":           ["2d","3d"],
	"reverb_effect":           ["2d","3d"],
	"pitch_shift_effect":      ["2d","3d"],
	# Physics
	"impulse_effect":          ["2d"],
	# Flow — generic composition.
	"animation_player_effect": ["2d","3d"],
	"set_active_effect":       ["2d","3d"],
	"chain_effect":            ["2d","3d"],
	"sequence_effect":         ["2d","3d"],
	"property_tween_effect":   ["2d","3d"],
	# New batch — Screen
	"scan_lines_effect":       ["2d","3d"],
	"film_grain_effect":       ["2d","3d"],
	"radial_blur_effect":      ["2d","3d"],
	# New batch — Camera
	"directional_shake_effect":["2d"],
	"camera_bob_effect":       ["2d"],
	"zoom_pulse_effect":       ["2d"],
	# New batch — Object
	"spin_effect":             ["2d"],
	"wiggle_effect":           ["2d"],
	"sprite_bob_effect":       ["2d"],
	"pop_in_effect":           ["2d"],
	"shake_control_effect":    ["2d"],
	"pulse_effect":            ["2d"],
	# New batch — Time / Flow
	"freeze_frame_effect":     ["2d","3d"],
	"wait_for_input_effect":   ["2d","3d"],
	"beat_sync_effect":        ["2d","3d"],
	# Batch 3
	"lens_distortion_effect":  ["2d","3d"],
	"depth_of_field_effect":   ["3d"],
	"camera_rotation_effect":  ["2d"],
	"shader_parameter_effect": ["2d","3d"],
	"flicker_effect":          ["2d"],
	"scale_effect":            ["2d"],
	"particle_effect":         ["2d"],
	"light_3d_effect":         ["3d"],
	"material_3d_effect":      ["3d"],
	"audio_source_3d_effect":  ["3d"],
	"add_force_effect":        ["2d","3d"],
	"emit_signal_effect":      ["2d","3d"],
	"debug_log_effect":        ["2d","3d"],
	"animation_tree_effect":   ["2d","3d"],
	"set_property_effect":     ["2d","3d"],
	"fade_effect":             ["2d"],
	"flip_effect":             ["2d"],
	"instantiate_effect":      ["2d","3d"],
	"size_delta_effect":       ["2d"],
	"auto_destruct_effect":    ["2d","3d"],
}

const ICON_2D: Texture2D = preload("res://addons/juicee/icons/2dtag.svg")
const ICON_3D: Texture2D = preload("res://addons/juicee/icons/3dtag.svg")

## Set by JuiceePlugin on startup so graph operations register with Ctrl+Z / Ctrl+Y.
var undo_redo: EditorUndoRedoManager = null

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
var _pan_mode: bool = false
var _is_panning: bool = false
var _file_dialog: EditorFileDialog
var _selected_block: JuiceeGraphBlock = null
var _hovered_block:  JuiceeGraphBlock = null

## Shared hover info-panel. Set by plugin.gd after both objects are created.
var hover_panel: Control = null

# id_in_popup → effect Script (or null for builtins)
var _popup_items: Dictionary = {}
var _effect_scripts: Array[Script] = []

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_scan_effects()
	_build_ui()
	_new_graph()

func _scan_effects() -> void:
	_effect_scripts.clear()
	var dir := DirAccess.open(EFFECTS_DIR)
	if not dir:
		push_warning("JuiceeGraphEditor: cannot open " + EFFECTS_DIR)
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".gd") and f != BASE_EFFECT_FILE:
			var path := EFFECTS_DIR + f
			var script := load(path) as Script
			if script and script.can_instantiate():
				_effect_scripts.append(script)
			elif script:
				push_warning("JuiceeGraphEditor: skipping %s (cannot instantiate — parse error?)" % f)
		f = dir.get_next()
	dir.list_dir_end()

func _build_ui() -> void:
	# No background ColorRect — the host EditorPlugin bottom panel paints its own
	# (matches Animation / Shader Editor docks).
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", int(0 * EDSCALE))
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
	_graph.minimap_enabled = true
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
	# focus (rare in a bottom panel), so the real handling is in _input below —
	# these connections are just a harmless fallback for the focused case.
	_graph.copy_nodes_request.connect(_on_copy_nodes_request)
	_graph.paste_nodes_request.connect(_on_paste_nodes_request)
	_graph.duplicate_nodes_request.connect(_on_duplicate_nodes_request)
	set_process_input(true)  # ensure _input fires for the Ctrl+C/V/D shortcuts
	# Dismiss the hover panel the instant a block starts moving — during a drag the
	# block stays under the cursor so `unhovered` never fires, leaving the panel
	# stranded at the block's old spot.
	_graph.begin_node_move.connect(_on_graph_node_move_begin)
	_style_graph()
	hsplit.add_child(_graph)

	hsplit.add_child(_build_props_panel())

	_popup = PopupPanel.new()
	_popup.size = Vector2i(int(260 * EDSCALE), int(360 * EDSCALE))
	# Popup uses the editor's native PopupPanel stylebox.

	var popup_vbox := VBoxContainer.new()
	popup_vbox.add_theme_constant_override("separation", int(6 * EDSCALE))
	_popup.add_child(popup_vbox)

	_popup_search = LineEdit.new()
	_popup_search.placeholder_text = "Search effects…   (↑↓ to move, Enter to add)"
	_popup_search.clear_button_enabled = true
	_popup_search.text_changed.connect(_on_popup_search_changed)
	_popup_search.gui_input.connect(_on_popup_search_gui_input)
	popup_vbox.add_child(_popup_search)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(240, 300) * EDSCALE
	popup_vbox.add_child(scroll)
	_popup_scroll = scroll

	_popup_list = VBoxContainer.new()
	_popup_list.add_theme_constant_override("separation", int(3 * EDSCALE))
	_popup_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_popup_list)

	_build_popup()
	_popup.popup_hide.connect(_on_popup_hide)
	add_child(_popup)

	_file_dialog = EditorFileDialog.new()
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_file_dialog.add_filter("*.tres", "Juicee Graph / Sequence Resource")
	add_child(_file_dialog)

func _style_graph() -> void:
	# Slim, antialiased connection lines (these are GraphEdit PROPERTIES in Godot 4;
	# default thickness 4.0 reads chunky). The in-progress drag preview is rendered
	# by the engine and isn't separately controllable from here.
	_graph.connection_lines_thickness = 3.0 * EDSCALE
	_graph.connection_lines_antialiased = true

func _build_popup() -> void:
	_popup_items.clear()
	for c in _popup_list.get_children():
		c.queue_free()

	# Flow control built-ins (graph topology, not effects).
	_add_popup_section_label("Flow control")
	_add_popup_item("Trigger",   Color(0.22, 0.88, 0.48), "res://addons/juicee/icons/trigger.svg", "builtin:trigger",   "The entry point. Every graph needs exactly one — execution starts here when play() is called.")
	_add_popup_item("Split",     Color(0.95, 0.85, 0.20), "res://addons/juicee/icons/split.svg",   "builtin:split",     "Fan-out. All connected outputs fire at the same time and run independently.")
	_add_popup_item("Loop",      Color(1.00, 0.55, 0.15), "res://addons/juicee/icons/loop.svg",    "builtin:loop",      "Repeat the next chain N times in a row (sequential).")
	_add_popup_item("Random",    Color(0.95, 0.85, 0.20), "res://addons/juicee/icons/random.svg",  "builtin:random",    "Pick exactly one connected output at random (weighted) and run only that branch.")
	_add_popup_item("Condition", Color(0.50, 0.85, 1.00), "",                                      "builtin:condition", "Evaluates a GDScript expression against 'context'.\nPort 0 = True  ·  Port 1 = False.\nExamples: context.health < 20  |  context.visible")
	_add_popup_item("Comment",  Color(0.88, 0.75, 0.22), "",                                      "builtin:comment",   "Visual annotation — no ports, never executes.\nDocument sections or leave notes for teammates.")

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
			category = EFFECT_CATEGORIES.get(basename, "Misc")
		var description: String = eff.get_description()
		if description.is_empty():
			description = EFFECT_DESCRIPTIONS.get(basename, "")
		entries.append({
			"script": script,
			"name": eff.get_display_name(),
			"color": eff.get_category_color(),
			"icon": eff.get_icon_path(),
			"category": category,
			"description": description,
			"dims": EFFECT_DIMENSIONS.get(basename, []),
		})

	# Sort by (category index in CATEGORY_ORDER, then name).
	entries.sort_custom(func(a, b) -> bool:
		var ai: int = CATEGORY_ORDER.find(a["category"])
		var bi: int = CATEGORY_ORDER.find(b["category"])
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

	# Remember the grouped order so clearing the search box can restore it.
	_popup_build_order = _popup_list.get_children()

func _add_popup_section_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_font_size_override("font_size", int(10 * EDSCALE))
	lbl.modulate = Color(1, 1, 1, 0.6)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(4 * EDSCALE))
	m.add_theme_constant_override("margin_top", int(4 * EDSCALE))
	m.add_child(lbl)
	_popup_list.add_child(m)

func _add_popup_item(label: String, color: Color, _icon_path: String, entry: Variant, tooltip: String = "", dims: Array = [], category: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(6 * EDSCALE))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_list.add_child(row)

	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(3, 16) * EDSCALE
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)

	var btn := Button.new()
	btn.text = ""  # text is drawn by the RichTextLabel overlay so matches can be bolded
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 26) * EDSCALE
	btn.set_meta("entry", entry)
	btn.set_meta("label", label.to_lower())
	btn.set_meta("display", label)
	# Combined text searched when the user types in the popup — includes label,
	# description, and category so "screen", "camera", "impact" etc. all work.
	btn.set_meta("search_text", (label + " " + tooltip + " " + category).to_lower())
	if not tooltip.is_empty():
		btn.tooltip_text = "%s\n\n%s" % [label, tooltip]
	btn.pressed.connect(func() -> void: _on_popup_choice(entry))
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
	# (it's used for doc panels) — clear it so list items don't render in boxes.
	rtl.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	rtl.set_anchors_preset(Control.PRESET_FULL_RECT)
	rtl.offset_left = 4 * EDSCALE
	rtl.offset_top = 5 * EDSCALE  # vertically centers the single line in the 26px row
	rtl.text = label
	btn.add_child(rtl)
	btn.set_meta("rtl", rtl)

	# 2D / 3D tag icons — right-aligned after the label.
	for dim in dims:
		var tex: Texture2D = ICON_2D if dim == "2d" else (ICON_3D if dim == "3d" else null)
		if not tex:
			continue
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(18, 18) * EDSCALE
		tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.modulate = Color(1, 1, 1, 0.9)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)

func _on_popup_search_changed(text: String) -> void:
	var q := text.strip_edges().to_lower()

	# Empty query → restore the category-grouped layout, show everything, and
	# clear any match-bolding from a previous search.
	if q.is_empty():
		_restore_popup_order()
		for c in _popup_list.get_children():
			c.visible = true
			var btn := _row_button(c)
			if btn and btn.has_meta("rtl"):
				(btn.get_meta("rtl") as RichTextLabel).text = str(btn.get_meta("display", ""))
		_rebuild_popup_nav()
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
			c.visible = false  # category header — hidden during a ranked search

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
## "ani-m-a-tio-n" or "film gr-a-i-n" — only genuinely close matches survive.
func _match_score(q: String, label: String, search_text: String) -> int:
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
## "permanent") without rejecting mid-name matches like "lash" → "Flash".
func _word_start_find(text: String, q: String) -> int:
	var from := 0
	while from <= text.length() - q.length():
		var idx := text.find(q, from)
		if idx < 0:
			return -1
		if idx == 0 or not _is_word_char(text.unicode_at(idx - 1)):
			return idx
		from = idx + 1
	return -1

func _is_word_char(c: int) -> bool:
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57)

## Span of a greedy subsequence match of `q` in `text` (last index − first + 1),
## or -1 if `q` is not a subsequence. A small span means the letters are adjacent.
func _subsequence_span(q: String, text: String) -> int:
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
func _highlight_bbcode(display: String, q: String) -> String:
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
func _rebuild_popup_nav() -> void:
	_popup_nav_buttons.clear()
	for c in _popup_list.get_children():
		if c is HBoxContainer and c.visible:
			var btn := _row_button(c)
			if btn:
				_popup_nav_buttons.append(btn)
	_popup_nav_index = 0 if not _popup_nav_buttons.is_empty() else -1
	_apply_popup_highlight()

func _apply_popup_highlight() -> void:
	for i in _popup_nav_buttons.size():
		var btn := _popup_nav_buttons[i]
		if i == _popup_nav_index:
			btn.flat = false
			btn.add_theme_stylebox_override("normal", _popup_highlight_box())
			btn.add_theme_stylebox_override("hover", _popup_highlight_box())
			if is_instance_valid(_popup_scroll):
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
		_popup_hl_box.set_corner_radius_all(int(3 * EDSCALE))
		_popup_hl_box.content_margin_left = 4 * EDSCALE
		_popup_hl_box.content_margin_right = 4 * EDSCALE
		_popup_hl_box.content_margin_top = 2 * EDSCALE
		_popup_hl_box.content_margin_bottom = 2 * EDSCALE
	return _popup_hl_box

func _move_popup_nav(delta: int) -> void:
	if _popup_nav_buttons.is_empty():
		return
	_popup_nav_index = wrapi(_popup_nav_index + delta, 0, _popup_nav_buttons.size())
	_apply_popup_highlight()

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
	# Snapshot drag-connect state BEFORE hiding — _on_popup_hide will clear it.
	var pending_from := _pending_connect_from
	var pending_port := _pending_connect_from_port
	_popup.hide()

	var pos: Vector2 = _popup_pos if _popup_pos != Vector2.ZERO else (_graph.scroll_offset + _graph.size * 0.5)
	var new_id := ""
	if entry is String and (entry as String).begins_with("builtin:"):
		var type := (entry as String).substr("builtin:".length())
		new_id = _add_builtin(type, pos)
	elif entry is Script:
		new_id = _add_effect(entry as Script, pos)

	if not pending_from.is_empty() and not new_id.is_empty():
		_graph.connect_node(pending_from, pending_port, new_id, 0)
		_resource.add_connection(pending_from, pending_port, new_id, 0)
		_mark_dirty()

func _build_toolbar() -> Control:
	# Toolbar uses Godot's native bottom-panel toolbar look — a thin HBox with
	# small margin, no custom background. Matches the Animation / Shader Editor
	# tabs row.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(4 * EDSCALE))
	margin.add_theme_constant_override("margin_right", int(4 * EDSCALE))
	margin.add_theme_constant_override("margin_top", int(4 * EDSCALE))
	margin.add_theme_constant_override("margin_bottom", int(4 * EDSCALE))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(4 * EDSCALE))
	margin.add_child(bar)

	bar.add_child(_toolbar_btn("New",  _new_graph))
	bar.add_child(_toolbar_btn("Open", _open_dialog))
	bar.add_child(_toolbar_btn("Save", _save))
	bar.add_child(_vsep())
	var btn_test := _toolbar_btn("▶ Test", _test_sequence)
	btn_test.tooltip_text = "Play the full sequence on the currently edited scene.\nBlocks light up as they execute.\n\nNote: full-screen shader effects (Blur, Chromatic, Glitch,\nVignette, Pixelate, Color Grade) preview at the editor's\nviewport size only. Run the project (F5/F6) to see them\nat their true full-screen extent."
	bar.add_child(btn_test)
	var btn_export := _toolbar_btn("⤓ Export Sequence", _export_sequence)
	btn_export.tooltip_text = "Export current graph as a JuiceeSequence .tres for use with JuiceePlayer"
	bar.add_child(btn_export)
	bar.add_child(_vsep())
	var btn_fit := _toolbar_btn("⊡ Fit", _zoom_to_fit)
	btn_fit.tooltip_text = "Zoom and center the graph to fit all nodes"
	bar.add_child(btn_fit)

	_pan_btn = _toolbar_btn("", _toggle_pan_mode)
	_pan_btn.toggle_mode = true
	_pan_btn.tooltip_text = "Hand tool — drag with LMB to pan\n(MMB drag always pans regardless of this toggle)"
	var pan_icon := _editor_icon("ToolPan")
	if pan_icon:
		_pan_btn.icon = pan_icon
	else:
		_pan_btn.text = "✋"
	bar.add_child(_pan_btn)
	var btn_rescan := _toolbar_btn("⟳ Rescan", _rescan_effects)
	btn_rescan.tooltip_text = "Rescan effects/ folder for new effect scripts"
	bar.add_child(btn_rescan)
	var btn_update := _toolbar_btn("↑ Update", _check_for_updates)
	btn_update.tooltip_text = "Check GitHub for a newer release of Juicee\n(current: v%s)" % JuiceeUpdater.get_current_version()
	bar.add_child(btn_update)
	bar.add_child(_vsep())

	_file_label = Label.new()
	_file_label.text = "untitled"
	_file_label.modulate = Color(1, 1, 1, 0.65)
	_file_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_file_label)

	return margin

func _vsep() -> VSeparator:
	var s := VSeparator.new()
	s.add_theme_constant_override("separation", int(8 * EDSCALE))
	return s

func _build_props_panel() -> Control:
	# No custom bg — let the editor theme's panel style apply. Matches inspector
	# sidebars in built-in panels (Animation params, Shader editor sidebars).
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 260 * EDSCALE

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   int(10 * EDSCALE))
	m.add_theme_constant_override("margin_right",  int(10 * EDSCALE))
	m.add_theme_constant_override("margin_top",    int(10 * EDSCALE))
	m.add_theme_constant_override("margin_bottom", int(10 * EDSCALE))
	panel.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(8 * EDSCALE))
	m.add_child(vbox)

	_props_title = Label.new()
	_props_title.text = "Properties"
	vbox.add_child(_props_title)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_props_content = VBoxContainer.new()
	_props_content.add_theme_constant_override("separation", int(10 * EDSCALE))
	_props_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_props_content)

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
		block.position_offset = pos
	_mark_dirty()

func _ur_add_connection(from_id: String, from_port: int, to_id: String, to_port: int) -> void:
	_resource.add_connection(from_id, from_port, to_id, to_port)
	_graph.connect_node(from_id, from_port, to_id, to_port)
	_mark_dirty()

func _ur_remove_connection(from_id: String, from_port: int, to_id: String, to_port: int) -> void:
	_resource.remove_connection(from_id, from_port, to_id, to_port)
	_graph.disconnect_node(from_id, from_port, to_id, to_port)
	_mark_dirty()

func _ur_set_effect_property(effect: JuiceeEffect, prop_name: String, value: Variant) -> void:
	effect.set(prop_name, value)
	_mark_dirty()
	if _selected_block and _selected_block.node_data.effect == effect:
		_show_props(_selected_block)

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

## Public API: convert a JuiceeSequence into a fresh linear graph (Trigger → effect → effect …)
## and load it into the editor. Used by the JuiceePlayer inspector "Edit in Graph" button.
func load_from_sequence(seq: JuiceeSequence, source_label: String = "from sequence") -> void:
	if not seq:
		push_warning("JuiceeGraphEditor: load_from_sequence got null")
		return
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
		data.effect = effect
		effect.graph_position = data.graph_position
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
	for child in _graph.get_children():
		if child is GraphNode:
			child.queue_free()
	_graph.clear_connections()
	_selected_block = null
	_clear_props()

	if not _resource:
		return

	for data in _resource.nodes:
		var block := JuiceeGraphBlock.create(data)
		_graph.add_child(block)
		block.dragged.connect(_on_block_dragged.bind(block))
		block.preview_requested.connect(_on_block_preview_requested.bind(block))
		block.ports_changed.connect(_on_block_ports_changed.bind(block))
		block.hovered.connect(_on_block_hovered.bind(block))
		block.unhovered.connect(_on_block_unhovered.bind(block))

	await get_tree().process_frame

	for conn in _resource.connections:
		var p := conn.split(":")
		if p.size() == 4:
			_graph.connect_node(p[0], int(p[1]), p[2], int(p[3]))

func _add_builtin(type: String, at_position: Vector2) -> String:
	var data := JuiceeGraphNodeData.create_for_builtin(type, at_position)
	_resource.add_node(data)
	var block := JuiceeGraphBlock.create(data)
	_graph.add_child(block)
	block.dragged.connect(_on_block_dragged.bind(block))
	block.preview_requested.connect(_on_block_preview_requested.bind(block))
	block.ports_changed.connect(_on_block_ports_changed.bind(block))
	block.hovered.connect(_on_block_hovered.bind(block))
	block.unhovered.connect(_on_block_unhovered.bind(block))
	_mark_dirty()
	if undo_redo:
		undo_redo.create_action("Add %s Node" % data.type.capitalize())
		undo_redo.add_do_method(self, "_ur_add_node", data)
		undo_redo.add_undo_method(self, "_ur_remove_node", data.id)
		undo_redo.commit_action(false)
	return data.id

func _add_effect(script: Script, at_position: Vector2) -> String:
	var data := JuiceeGraphNodeData.create_for_effect(script, at_position)
	_resource.add_node(data)
	var block := JuiceeGraphBlock.create(data)
	_graph.add_child(block)
	block.dragged.connect(_on_block_dragged.bind(block))
	block.preview_requested.connect(_on_block_preview_requested.bind(block))
	block.ports_changed.connect(_on_block_ports_changed.bind(block))
	block.hovered.connect(_on_block_hovered.bind(block))
	block.unhovered.connect(_on_block_unhovered.bind(block))
	_mark_dirty()
	if undo_redo:
		var label := data.effect.get_display_name() if data.effect else script.resource_path.get_file().get_basename()
		undo_redo.create_action("Add %s" % label)
		undo_redo.add_do_method(self, "_ur_add_node", data)
		undo_redo.add_undo_method(self, "_ur_remove_node", data.id)
		undo_redo.commit_action(false)
	return data.id

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
	var data := block.node_data
	var connections_before := _resource.connections.duplicate()
	_resource.remove_node(data.id)
	_graph.clear_connections()
	block.queue_free()
	await get_tree().process_frame
	for conn in _resource.connections:
		var p := conn.split(":")
		if p.size() == 4:
			_graph.connect_node(p[0], int(p[1]), p[2], int(p[3]))
	if _selected_block == block:
		_selected_block = null
		_clear_props()
	_mark_dirty()
	if undo_redo:
		var label := data.effect.get_display_name() if data.effect else data.type.capitalize()
		undo_redo.create_action("Delete %s" % label)
		undo_redo.add_do_method(self, "_ur_remove_node", data.id)
		undo_redo.add_undo_method(self, "_ur_add_node_with_connections", data, connections_before)
		undo_redo.commit_action(false)

# ─── Properties panel (auto-built from JuiceeEffect's @export properties) ─────

func _show_props(block: JuiceeGraphBlock) -> void:
	_clear_props()
	_selected_block = block
	var data := block.node_data

	var title_color := Color.WHITE
	if data.type == "effect" and data.effect:
		_props_title.text = data.effect.get_display_name()
		title_color = data.effect.get_category_color()
		_build_props_for_effect(data.effect)
	else:
		_props_title.text = data.type.capitalize()
		var meta: Dictionary = JuiceeGraphBlock.BUILTIN_META.get(data.type, {})
		if meta.has("color"):
			title_color = meta["color"]
		_build_props_for_builtin(data)
	# Tint title with category color — matches Godot's inspector header tint.
	_props_title.modulate = title_color

	_props_content.add_child(HSeparator.new())
	var del_btn := Button.new()
	del_btn.text = "Delete Node"
	del_btn.pressed.connect(func() -> void: _delete_block(block))
	_props_content.add_child(del_btn)

func _show_props_placeholder() -> void:
	_clear_props()
	var lbl := Label.new()
	lbl.text = "Select a node to edit its properties"
	lbl.modulate = Color(1, 1, 1, 0.6)
	lbl.add_theme_font_size_override("font_size", int(11 * EDSCALE))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_props_content.add_child(lbl)

func _build_props_for_builtin(data: JuiceeGraphNodeData) -> void:
	match data.type:
		"loop":
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", int(2 * EDSCALE))
			_props_content.add_child(row)
			var lbl := Label.new()
			lbl.text = "Iteration Count"
			lbl.add_theme_font_size_override("font_size", int(11 * EDSCALE))
			row.add_child(lbl)
			var spin := SpinBox.new()
			spin.min_value = 1
			spin.max_value = 100
			spin.step = 1
			spin.value = int(data.properties.get("count", 3))
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.value_changed.connect(func(v: float) -> void:
				data.properties["count"] = int(v)
				_mark_dirty()
				var block := _graph.get_node_or_null(NodePath(data.id)) as JuiceeGraphBlock
				if block:
					block.refresh_subtitle()
			)
			row.add_child(spin)
		"random":
			_build_random_weights_editor(data)
		"condition":
			_build_condition_editor(data)
		_:
			var lbl := Label.new()
			lbl.text = "No properties"
			lbl.modulate = Color(1, 1, 1, 0.6)
			_props_content.add_child(lbl)

# Per-output-port weight editor for Random nodes. Each Option N has a SpinBox
# bound to data.properties.weights[N-1] plus a live percentage label that
# shows the normalized probability — updates as the user drags.
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
	header.add_theme_font_size_override("font_size", int(12 * EDSCALE))
	_props_content.add_child(header)

	var desc := Label.new()
	desc.text = "Relative probability each output is picked. Set 0 to disable that branch entirely."
	desc.modulate = Color(1, 1, 1, 0.58)
	desc.add_theme_font_size_override("font_size", int(10 * EDSCALE))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_props_content.add_child(desc)

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
				pct_labels[j].text = "—"

	for i in port_count:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(8 * EDSCALE))
		_props_content.add_child(row)

		var lbl := Label.new()
		lbl.text = "Option %d" % (i + 1)
		lbl.custom_minimum_size.x = 70 * EDSCALE
		row.add_child(lbl)

		var spin := SpinBox.new()
		spin.min_value = 0.0
		spin.max_value = 100.0
		spin.step = 0.1
		spin.value = float(weights[i])
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spin)

		var pct_lbl := Label.new()
		pct_lbl.custom_minimum_size.x = 44 * EDSCALE
		pct_lbl.modulate = Color(1, 1, 1, 0.55)
		pct_lbl.add_theme_font_size_override("font_size", int(10 * EDSCALE))
		pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pct_lbl)
		pct_labels.append(pct_lbl)

		var idx := i
		spin.value_changed.connect(func(v: float) -> void:
			weights[idx] = v
			data.properties["weights"] = weights
			refresh_pcts.call()
			_mark_dirty()
		)

	refresh_pcts.call()

func _build_condition_editor(data: JuiceeGraphNodeData) -> void:
	var header := Label.new()
	header.text = "Expression"
	header.add_theme_font_size_override("font_size", int(12 * EDSCALE))
	_props_content.add_child(header)

	var hint := Label.new()
	hint.text = "GDScript expression evaluated against 'context'.\nPort 0 fires when True, port 1 when False.\n\nExamples:\n  context.health < 20\n  context.is_in_group(\"enemy\")\n  context.visible\n  true"
	hint.modulate = Color(1, 1, 1, 0.58)
	hint.add_theme_font_size_override("font_size", int(10 * EDSCALE))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_props_content.add_child(hint)

	var edit := LineEdit.new()
	edit.text = data.properties.get("expression", "true")
	edit.placeholder_text = "e.g. context.health < 20"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var commit := func() -> void:
		data.properties["expression"] = edit.text
		_mark_dirty()
	edit.text_submitted.connect(func(_t: String) -> void: commit.call())
	edit.focus_exited.connect(commit)
	_props_content.add_child(edit)

func _build_props_for_effect(effect: JuiceeEffect) -> void:
	# Pull all ## docstrings from the effect's source code so we can attach them as tooltips.
	var docs: Dictionary = _get_property_docs(effect.get_script() as Script)
	for prop in effect.get_property_list():
		var usage: int = prop["usage"]
		if not (usage & PROPERTY_USAGE_EDITOR):
			continue
		if not (usage & PROPERTY_USAGE_STORAGE):
			continue
		var name: String = prop["name"]
		if name == "graph_position" or name == "resource_local_to_scene" or name == "resource_name" or name == "resource_path" or name == "script":
			continue
		_add_prop_editor(effect, prop, docs.get(name, ""))

func _add_prop_editor(effect: JuiceeEffect, prop: Dictionary, doc: String = "") -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", int(3 * EDSCALE))
	_props_content.add_child(row)

	var name: String = prop["name"]
	var type: int = prop["type"]
	var hint: int = prop.get("hint", PROPERTY_HINT_NONE)
	var hint_string: String = prop.get("hint_string", "")
	var has_range := hint == PROPERTY_HINT_RANGE and not hint_string.is_empty()

	# Property name — main header.
	var lbl := Label.new()
	lbl.text = name.capitalize()
	lbl.add_theme_font_size_override("font_size", int(12 * EDSCALE))
	row.add_child(lbl)

	# Inline docstring — what does this do? Always visible (not buried in tooltip).
	if not doc.is_empty():
		var doc_lbl := Label.new()
		doc_lbl.text = doc
		doc_lbl.modulate = Color(1, 1, 1, 0.58)
		doc_lbl.add_theme_font_size_override("font_size", int(10 * EDSCALE))
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
			cb.text = "enabled"
			cb.button_pressed = effect.get(name)
			cb.toggled.connect(func(p: bool) -> void:
				effect.set(name, p)
				_mark_dirty()
			)
			row.add_child(cb)
		TYPE_COLOR:
			row.add_child(_build_color_widget(effect, name))
		TYPE_STRING:
			var edit := LineEdit.new()
			edit.text = str(effect.get(name))
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.add_theme_font_size_override("font_size", int(11 * EDSCALE))
			var commit_s := func() -> void:
				effect.set(name, edit.text)
				_mark_dirty()
			edit.text_submitted.connect(func(_t: String) -> void: commit_s.call())
			edit.focus_exited.connect(commit_s)
			row.add_child(edit)
		TYPE_VECTOR2:
			row.add_child(_build_vec2_widget(effect, name))
		TYPE_STRING_NAME:
			var edit := LineEdit.new()
			edit.text = String(effect.get(name))
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.add_theme_font_size_override("font_size", int(11 * EDSCALE))
			var commit_sn := func() -> void:
				effect.set(name, StringName(edit.text))
				_mark_dirty()
			edit.text_submitted.connect(func(_t: String) -> void: commit_sn.call())
			edit.focus_exited.connect(commit_sn)
			row.add_child(edit)
		TYPE_NODE_PATH:
			var edit := LineEdit.new()
			edit.placeholder_text = "node/path (optional)"
			edit.text = String(effect.get(name))
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.add_theme_font_size_override("font_size", int(11 * EDSCALE))
			var commit_np := func() -> void:
				effect.set(name, NodePath(edit.text))
				_mark_dirty()
			edit.text_submitted.connect(func(_t: String) -> void: commit_np.call())
			edit.focus_exited.connect(commit_np)
			row.add_child(edit)
		TYPE_OBJECT:
			# Resources (PackedScene, Curve, AudioStream, etc.) need full inspector.
			var current_val := effect.get(name)
			var info := Label.new()
			if current_val != null:
				var res := current_val as Resource
				var type_name := hint_string if not hint_string.is_empty() else "Resource"
				info.text = "[%s set]  →  use ✎ to edit" % type_name
				info.modulate = Color(0.7, 1.0, 0.7, 0.8)
			else:
				var type_name := hint_string if not hint_string.is_empty() else "Resource"
				info.text = "[no %s]  →  use ✎ to edit" % type_name
				info.modulate = Color(1, 1, 1, 0.45)
			info.add_theme_font_size_override("font_size", int(10 * EDSCALE))
			row.add_child(info)
		_:
			var info := Label.new()
			info.text = "(type %d unsupported)" % type
			info.modulate = Color(1, 1, 1, 0.5)
			row.add_child(info)

# Slider + numeric readout + min/max endpoints. Used for ranged numeric props
# so the user can see WHERE the current value sits in the valid range at a glance.
func _build_slider_widget(effect: JuiceeEffect, name: String, type: int, hint_string: String) -> Control:
	var parts := hint_string.split(",")
	var minv := float(parts[0]) if parts.size() >= 1 else 0.0
	var maxv := float(parts[1]) if parts.size() >= 2 else 1.0
	var step := float(parts[2]) if parts.size() >= 3 else (1.0 if type == TYPE_INT else 0.01)

	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", int(1 * EDSCALE))

	var slider_row := HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", int(8 * EDSCALE))
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(slider_row)

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
	value_lbl.custom_minimum_size.x = 42 * EDSCALE
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_lbl.add_theme_font_size_override("font_size", int(11 * EDSCALE))
	slider_row.add_child(value_lbl)

	# Endpoint hints — small, dim, under the slider.
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", int(0 * EDSCALE))
	wrap.add_child(hint_row)

	var min_lbl := Label.new()
	min_lbl.text = _format_value(minv, type, step)
	min_lbl.modulate = Color(1, 1, 1, 0.4)
	min_lbl.add_theme_font_size_override("font_size", int(9 * EDSCALE))
	min_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_row.add_child(min_lbl)

	var max_lbl := Label.new()
	max_lbl.text = _format_value(maxv, type, step)
	max_lbl.modulate = Color(1, 1, 1, 0.4)
	max_lbl.add_theme_font_size_override("font_size", int(9 * EDSCALE))
	max_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_row.add_child(max_lbl)

	var _slider_old_value: Variant = effect.get(name)
	slider.drag_started.connect(func() -> void:
		_slider_old_value = effect.get(name)
	)
	slider.drag_ended.connect(func(value_changed_flag: bool) -> void:
		if not value_changed_flag or not undo_redo:
			return
		var new_val: Variant = effect.get(name)
		undo_redo.create_action("Change " + name.capitalize())
		undo_redo.add_do_method(self, "_ur_set_effect_property", effect, name, new_val)
		undo_redo.add_undo_method(self, "_ur_set_effect_property", effect, name, _slider_old_value)
		undo_redo.commit_action(false)
	)
	slider.value_changed.connect(func(v: float) -> void:
		value_lbl.text = _format_value(v, type, step)
		if type == TYPE_INT:
			effect.set(name, int(v))
		else:
			effect.set(name, v)
		_mark_dirty()
	)
	return wrap

func _build_spin_widget(effect: JuiceeEffect, name: String, type: int) -> Control:
	var spin := SpinBox.new()
	spin.min_value = -99999.0
	spin.max_value = 99999.0
	spin.step = 1.0 if type == TYPE_INT else 0.01
	spin.value = effect.get(name)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _spin_old_value: Variant = effect.get(name)
	spin.get_line_edit().focus_entered.connect(func() -> void:
		_spin_old_value = effect.get(name)
	)
	spin.value_changed.connect(func(v: float) -> void:
		var new_val: Variant = int(v) if type == TYPE_INT else v
		effect.set(name, new_val)
		if undo_redo:
			undo_redo.create_action("Change " + name.capitalize(), UndoRedo.MERGE_ENDS, effect)
			undo_redo.add_do_method(self, "_ur_set_effect_property", effect, name, new_val)
			undo_redo.add_undo_method(self, "_ur_set_effect_property", effect, name, _spin_old_value)
			undo_redo.commit_action(false)
		_mark_dirty()
	)
	return spin

func _build_vec2_widget(effect: JuiceeEffect, prop_name: String) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(4 * EDSCALE))
	var val: Vector2 = effect.get(prop_name)

	var lbl_x := Label.new()
	lbl_x.text = "x:"
	lbl_x.add_theme_font_size_override("font_size", int(11 * EDSCALE))
	hbox.add_child(lbl_x)
	var spin_x := SpinBox.new()
	spin_x.min_value = -99999.0; spin_x.max_value = 99999.0; spin_x.step = 1.0; spin_x.value = val.x
	spin_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_x.value_changed.connect(func(v: float) -> void:
		effect.set(prop_name, Vector2(v, (effect.get(prop_name) as Vector2).y))
		_mark_dirty()
	)
	hbox.add_child(spin_x)

	var lbl_y := Label.new()
	lbl_y.text = "y:"
	lbl_y.add_theme_font_size_override("font_size", int(11 * EDSCALE))
	hbox.add_child(lbl_y)
	var spin_y := SpinBox.new()
	spin_y.min_value = -99999.0; spin_y.max_value = 99999.0; spin_y.step = 1.0; spin_y.value = val.y
	spin_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_y.value_changed.connect(func(v: float) -> void:
		effect.set(prop_name, Vector2((effect.get(prop_name) as Vector2).x, v))
		_mark_dirty()
	)
	hbox.add_child(spin_y)

	return hbox

# OptionButton for enum-typed @export properties (e.g. ScreenWipe.wipe_from).
# Godot serializes enums as TYPE_INT with PROPERTY_HINT_ENUM and a hint string
# of comma-separated labels (optionally "Label:value").
func _build_enum_widget(effect: JuiceeEffect, name: String, hint_string: String) -> Control:
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_value: int = int(effect.get(name))
	var entries := hint_string.split(",")
	for i in entries.size():
		var label := entries[i].strip_edges()
		var value := i
		var split := label.split(":")
		if split.size() > 1:
			label = split[0].strip_edges()
			value = int(split[1])
		# Pretty-print: "WIPE_LEFT" / "TopRight" → "Wipe Left" / "Top Right".
		ob.add_item(label.capitalize(), value)
		if value == current_value:
			ob.select(ob.item_count - 1)
	ob.item_selected.connect(func(idx: int) -> void:
		var old_val: Variant = effect.get(name)
		var new_val: int = ob.get_item_id(idx)
		effect.set(name, new_val)
		if undo_redo and old_val != new_val:
			undo_redo.create_action("Change " + name.capitalize())
			undo_redo.add_do_method(self, "_ur_set_effect_property", effect, name, new_val)
			undo_redo.add_undo_method(self, "_ur_set_effect_property", effect, name, old_val)
			undo_redo.commit_action(false)
		_mark_dirty()
	)
	return ob

# ColorPickerButton wrapper — explicit minimum size + sync after picking so
# the visible swatch always reflects the current value.
func _build_color_widget(effect: JuiceeEffect, name: String) -> Control:
	var cp := ColorPickerButton.new()
	cp.color = effect.get(name)
	cp.edit_alpha = true
	cp.custom_minimum_size = Vector2(0, 28) * EDSCALE
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _color_old_value: Color = effect.get(name)
	cp.popup_closed.connect(func() -> void:
		var new_col: Color = cp.color
		if undo_redo and new_col != _color_old_value:
			undo_redo.create_action("Change " + name.capitalize())
			undo_redo.add_do_method(self, "_ur_set_effect_property", effect, name, new_col)
			undo_redo.add_undo_method(self, "_ur_set_effect_property", effect, name, _color_old_value)
			undo_redo.commit_action(false)
		_color_old_value = new_col
	)
	cp.color_changed.connect(func(c: Color) -> void:
		cp.color = c
		effect.set(name, c)
		_mark_dirty()
	)
	return cp

# Format a numeric value for display — int → "5", float → "0.25" or "1.0" using
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


func _clear_props() -> void:
	for child in _props_content.get_children():
		child.queue_free()
	_props_title.text = "Properties"
	_props_title.modulate = Color.WHITE

# ─── File I/O ─────────────────────────────────────────────────────────────────

func _save() -> void:
	if _resource_path.is_empty():
		_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		_file_dialog.popup_centered_ratio(0.6)
		_file_dialog.file_selected.connect(_on_save_path_selected, CONNECT_ONE_SHOT)
	else:
		_do_save(_resource_path)

func _on_save_path_selected(path: String) -> void:
	_do_save(path)

func _do_save(path: String) -> void:
	_resource_path = path
	ResourceSaver.save(_resource, path)
	_dirty = false
	_file_label.text = path.get_file()

func _open_dialog() -> void:
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.popup_centered_ratio(0.6)
	_file_dialog.file_selected.connect(_on_open_path_selected, CONNECT_ONE_SHOT)

func _on_open_path_selected(path: String) -> void:
	var res := load(path)
	if res is JuiceeGraphResource:
		_resource = res
		_resource_path = path
		_dirty = false
		_file_label.text = path.get_file()
		_rebuild_graph()
	elif res is JuiceeSequence:
		# A JuiceeSequence is converted to a fresh linear graph (Trigger → effect → effect …).
		# It loads as "untitled" since we'd need to re-export to keep the sequence in sync.
		load_from_sequence(res as JuiceeSequence, path.get_file())
	else:
		push_error("JuiceeGraphEditor: file is neither a JuiceeGraphResource nor a JuiceeSequence: " + path)

func _export_sequence() -> void:
	if not _resource:
		return
	var seq := _resource.to_sequence()
	var dlg := EditorFileDialog.new()
	dlg.access = EditorFileDialog.ACCESS_RESOURCES
	dlg.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dlg.add_filter("*.tres", "JuiceeSequence")
	add_child(dlg)
	dlg.popup_centered_ratio(0.6)
	dlg.file_selected.connect(func(path: String) -> void:
		ResourceSaver.save(seq, path)
		dlg.queue_free()
	, CONNECT_ONE_SHOT)

func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		_file_label.text = ("* " + _file_label.text) if not _file_label.text.begins_with("* ") else _file_label.text

# ─── Signal handlers ──────────────────────────────────────────────────────────

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if not _is_valid_connection(str(from_node), str(to_node)):
		return  # self-loop or cycle — rejected (with a toast)
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

## Adding from_id → to_id closes a cycle iff to_id can ALREADY reach from_id by
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
		sb.set_corner_radius_all(int(4 * EDSCALE))
		sb.content_margin_left = 10 * EDSCALE
		sb.content_margin_right = 10 * EDSCALE
		sb.content_margin_top = 5 * EDSCALE
		sb.content_margin_bottom = 5 * EDSCALE
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
	_toast.position = Vector2((_graph.size.x - _toast.size.x) * 0.5, 12 * EDSCALE)
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
	for node_name in nodes:
		var block := _graph.get_node_or_null(NodePath(str(node_name))) as JuiceeGraphBlock
		if block:
			await _delete_block(block)

func _on_block_dragged(from: Vector2, to: Vector2, block: JuiceeGraphBlock) -> void:
	block.node_data.graph_position = to
	if block.node_data.effect:
		block.node_data.effect.graph_position = to
	_mark_dirty()
	if undo_redo and from.distance_squared_to(to) > 1.0:
		undo_redo.create_action("Move Node")
		undo_redo.add_do_method(self, "_ur_move_node", block.node_data.id, to)
		undo_redo.add_undo_method(self, "_ur_move_node", block.node_data.id, from)
		undo_redo.commit_action(false)

# ─── Copy / Paste / Duplicate ─────────────────────────────────────────────────

## Ctrl+C — snapshot the selected nodes (deep-copied) plus the connections that
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

## Ctrl+V — instantiate the clipboard with fresh ids, cascading the offset on each
## consecutive paste so copies don't stack exactly on top of one another.
func _on_paste_nodes_request() -> void:
	if _clipboard_nodes.is_empty():
		return
	_clipboard_paste_count += 1
	var offset := Vector2(30, 30) * _clipboard_paste_count
	_commit_paste(_clipboard_nodes, _clipboard_connections, offset, "Paste Nodes")

## Ctrl+X — copy the selection to the clipboard, then delete it.
func _on_cut_nodes_request() -> void:
	var blocks := _selected_blocks()
	if blocks.is_empty():
		return
	_on_copy_nodes_request()
	for b in blocks:
		await _delete_block(b)

## Ctrl+A — select every block in the graph.
func _select_all_blocks() -> void:
	var first: JuiceeGraphBlock = null
	for c in _graph.get_children():
		if c is JuiceeGraphBlock:
			(c as JuiceeGraphBlock).selected = true
			if first == null:
				first = c
	if first:
		_show_props(first)

## Escape — clear the selection and the props panel.
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

## Ctrl+D — copy the current selection and re-insert it at a small offset in one
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
	# Apply immediately, then register undo with execute=false — exactly how the
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
	for s in src_nodes:
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

func _toolbar_btn(label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(callback)
	return btn

func _test_sequence() -> void:
	if not _resource:
		return
	var ctx: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	if not ctx:
		push_warning("JuiceeGraphEditor: open a scene to test the sequence against")
		return
	var trigger := _resource.find_trigger()
	if not trigger:
		push_warning("JuiceeGraphEditor: add a Trigger node before testing")
		return
	# Walk the graph ourselves with pulse-highlighting at each step.
	await _debug_walk(trigger, _resource, ctx)

func _debug_walk(data: JuiceeGraphNodeData, resource: JuiceeGraphResource, context: Node) -> void:
	var block := _find_block_for(data)
	if data.effect:
		# Visual feedback during effect playback:
		# - delay_started → progress bar fills over the delay duration
		# - started      → pulse highlight at the moment work actually begins
		var delay_cb := func(seconds: float) -> void:
			if is_instance_valid(block):
				block.show_delay_progress(seconds)
		var start_cb := func() -> void:
			if is_instance_valid(block):
				block.pulse_highlight()
		data.effect.delay_started.connect(delay_cb)
		data.effect.started.connect(start_cb)
		await data.effect.apply(context)
		if data.effect.delay_started.is_connected(delay_cb):
			data.effect.delay_started.disconnect(delay_cb)
		if data.effect.started.is_connected(start_cb):
			data.effect.started.disconnect(start_cb)
	else:
		# Flow control node — pulse instantly so the user can see traversal.
		if is_instance_valid(block):
			block.pulse_highlight()
	var nexts := resource.get_next(data.id)
	if nexts.is_empty():
		return

	match data.type:
		"split":
			for next in nexts:
				_debug_walk(next, resource, context)
		"random":
			# Honor the weights so Test reflects what runtime will do.
			var weights: Array = data.properties.get("weights", [])
			var idx := JuiceeGraphPlayer._weighted_random_index(weights, nexts.size())
			await _debug_walk(nexts[idx], resource, context)
		"loop":
			var count: int = int(data.properties.get("count", 1))
			for i in count:
				await _debug_walk(nexts[0], resource, context)
		"condition":
			var expr_str: String = data.properties.get("expression", "true")
			var expr := Expression.new()
			var result: bool = true
			if expr.parse(expr_str, ["context"]) == OK:
				var val := expr.execute([context], context)
				if not expr.has_execute_failed():
					result = bool(val)
			var port := 0 if result else 1
			if nexts.size() > port:
				await _debug_walk(nexts[port], resource, context)
		_:
			await _debug_walk(nexts[0], resource, context)

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
		push_warning("JuiceeGraphEditor: open a scene to preview effects against")
		return
	# Same visual feedback as the toolbar Test: bar during delay, pulse on start.
	# Spam-clicking is now safe — JuiceeEffect's generation counter supersedes the
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

# ─── Property docstring extraction ───────────────────────────────────────────
# Reads ## comments from the script's source and maps them to @export property names.
# Cached per script so we don't re-parse on every property panel rebuild.

var _property_doc_cache: Dictionary = {}

func _get_property_docs(script: Script) -> Dictionary:
	if not script:
		return {}
	var key: String = script.resource_path
	if _property_doc_cache.has(key):
		return _property_doc_cache[key]

	var docs: Dictionary = {}
	if not script.has_method("get_source_code"):
		_property_doc_cache[key] = docs
		return docs

	var source: String = script.get_source_code()
	if source.is_empty():
		_property_doc_cache[key] = docs
		return docs

	var pending_doc: String = ""
	for raw_line in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("##"):
			# Strip leading "##" and one optional space.
			var doc_text: String = line.substr(2)
			if doc_text.begins_with(" "):
				doc_text = doc_text.substr(1)
			if pending_doc.is_empty():
				pending_doc = doc_text
			else:
				pending_doc += "\n" + doc_text
		elif line.begins_with("@export"):
			# Try to extract the property name after `var `.
			var var_pos: int = line.find("var ")
			if var_pos >= 0 and not pending_doc.is_empty():
				var after_var: String = line.substr(var_pos + 4)
				# Property name ends at first colon, space, or equals sign.
				var end: int = after_var.length()
				for ch in [":", " ", "="]:
					var p: int = after_var.find(ch)
					if p >= 0 and p < end:
						end = p
				var prop_name: String = after_var.substr(0, end).strip_edges()
				if not prop_name.is_empty():
					docs[prop_name] = pending_doc
			# Always reset after an @export line (even @export_group with no var).
			pending_doc = ""
		elif line.is_empty():
			pending_doc = ""
		else:
			# Any other code line breaks the docstring chain.
			pending_doc = ""

	_property_doc_cache[key] = docs
	return docs

func _editor_icon(icon_name: String) -> Texture2D:
	if not Engine.is_editor_hint():
		return null
	var theme := EditorInterface.get_editor_theme()
	if theme and theme.has_icon(icon_name, "EditorIcons"):
		return theme.get_icon(icon_name, "EditorIcons")
	return null

func _toggle_pan_mode() -> void:
	_pan_mode = _pan_btn.button_pressed
	if _pan_mode:
		_graph.mouse_default_cursor_shape = Control.CURSOR_DRAG
	else:
		_graph.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_is_panning = false

## Keyboard shortcuts for the graph panel, handled in _input (runs before the
## editor's global shortcuts):
##   • Alt+G          — toggle the JuiceeGraph bottom panel (works while hidden)
##   • Ctrl/Cmd+C/V/D — copy / paste / duplicate the selected blocks
## GraphEdit only emits its own copy/paste signals while it holds keyboard focus,
## which is rare in a bottom panel, so we drive them ourselves.
func _input(event: InputEvent) -> void:
	# Right-click a block → context menu. Handled here (not via the block's own
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
	# Alt+G toggles the panel — must work even while the graph is hidden, so it is
	# deliberately NOT gated by _graph_is_active().
	if k.keycode == KEY_G and k.alt_pressed and not k.is_command_or_control_pressed() and not k.shift_pressed:
		_toggle_panel()
		get_viewport().set_input_as_handled()
		return
	# Escape — deselect everything (let an open popup consume its own Escape first).
	if k.keycode == KEY_ESCAPE and not k.is_command_or_control_pressed() and not k.alt_pressed and not k.shift_pressed:
		if is_instance_valid(_popup) and _popup.visible:
			return
		if _graph_is_active():
			_deselect_all_blocks()
			get_viewport().set_input_as_handled()
		return
	# Ctrl/Cmd shortcuts — only while actually working in the graph.
	if not k.is_command_or_control_pressed() or k.shift_pressed or k.alt_pressed:
		return
	if not _graph_is_active():
		return
	match k.keycode:
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
	var owner: Control = (vp.gui_get_focus_owner() if vp else null)
	var owner_in_graph := owner != null and (owner == _graph or _graph.is_ancestor_of(owner))
	# Typing in a text field outside the graph → leave the shortcut alone.
	if (owner is LineEdit or owner is TextEdit) and not owner_in_graph:
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
	var padding := Vector2(80, 80) * EDSCALE
	var available: Vector2 = _graph.size - padding * 2.0
	if available.x <= 0 or available.y <= 0:
		return
	var zoom := min(available.x / bounds.x, available.y / bounds.y, 1.0)
	_graph.zoom = zoom
	var center := (min_p + max_p) * 0.5
	_graph.scroll_offset = center * zoom - _graph.size * 0.5

# ─── Update checker ──────────────────────────────────────────────────────────
# Godot has no built-in addon updater, so we ask the GitHub releases API and
# download/extract the latest tagged archive on confirmation.

var _updater: JuiceeUpdater
var _update_dialog: ConfirmationDialog
var _checking_label: Label

func _ensure_updater() -> void:
	if _updater:
		return
	_updater = JuiceeUpdater.new()
	add_child(_updater)
	_updater.check_completed.connect(_on_update_check_completed)
	_updater.check_failed.connect(_on_update_check_failed)
	_updater.install_completed.connect(_on_update_install_completed)
	_updater.install_failed.connect(_on_update_install_failed)

func _check_for_updates() -> void:
	_ensure_updater()
	_show_update_status("Checking GitHub for updates…")
	_updater.check_for_updates()

func _show_update_status(message: String) -> void:
	if not _update_dialog:
		_update_dialog = ConfirmationDialog.new()
		_update_dialog.title = "Juicee Updater"
		add_child(_update_dialog)
		_checking_label = Label.new()
		_checking_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_checking_label.custom_minimum_size = Vector2(420, 0) * EDSCALE
		_update_dialog.add_child(_checking_label)
	_checking_label.text = message
	# Reset any previous confirmation handlers — fresh dialog each time.
	for sig_dict in _update_dialog.confirmed.get_connections():
		_update_dialog.confirmed.disconnect(sig_dict.callable)
	_update_dialog.ok_button_text = "OK"
	_update_dialog.get_cancel_button().visible = false
	_update_dialog.popup_centered()

func _on_update_check_completed(latest: String, current: String, release_data: Dictionary) -> void:
	var cmp := JuiceeUpdater.compare_versions(latest, current)
	if cmp == 0:
		_show_update_status("You're up to date.\n\nInstalled: v%s\nLatest:    v%s" % [current, latest])
		return
	if cmp < 0:
		# Installed version is AHEAD of the latest published release (dev build).
		# Don't claim "up to date" — that reads as broken when Latest < Installed.
		_show_update_status("You're ahead of the latest release (development build).\n\nInstalled: v%s\nLatest:    v%s" % [current, latest])
		return
	# Newer version is out — offer to install.
	var notes := str(release_data.get("body", "")).strip_edges()
	if notes.length() > 600:
		notes = notes.substr(0, 600) + "…"
	var text := "Update available: v%s → v%s\n\n%s\n\nDownload and install now?\nRestart the editor afterwards." % [current, latest, notes]
	_checking_label.text = text
	for sig_dict in _update_dialog.confirmed.get_connections():
		_update_dialog.confirmed.disconnect(sig_dict.callable)
	_update_dialog.ok_button_text = "Update Now"
	_update_dialog.get_cancel_button().visible = true
	_update_dialog.confirmed.connect(_updater.download_and_install.bind(release_data), CONNECT_ONE_SHOT)
	_update_dialog.popup_centered()

func _on_update_check_failed(message: String) -> void:
	_show_update_status("Could not check for updates.\n\n%s" % message)

func _on_update_install_completed() -> void:
	_show_update_status("Update installed.\n\nRestart the editor (or disable + re-enable the plugin) for changes to take effect.")

func _on_update_install_failed(message: String) -> void:
	_show_update_status("Update failed.\n\n%s" % message)

# ─── Block hover handlers ─────────────────────────────────────────────────────

func _on_block_hovered(block: JuiceeGraphBlock) -> void:
	_hovered_block = block
	if not is_instance_valid(hover_panel):
		return
	var data := block.node_data
	var rect  := block.get_global_rect()
	if data.type == "effect" and data.effect:
		hover_panel.call("show_for_effect", data.effect, rect)
	else:
		var meta: Dictionary = JuiceeGraphBlock.BUILTIN_META.get(
			data.type, {"title": data.type, "sub": "", "color": Color.WHITE, "tip": ""})
		hover_panel.call("show_for_builtin",
			meta.get("title", data.type),
			meta.get("sub", ""),
			meta.get("tip", ""),
			meta.get("color", Color.WHITE),
			rect)

func _on_block_unhovered(block: JuiceeGraphBlock) -> void:
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
			hover_panel.call("add_log_entry", "● Running…")

func _debugger_on_block_end(resource_path: String, node_id: String) -> void:
	if not _resource or _resource.resource_path != resource_path:
		return
	var block := _graph.get_node_or_null(NodePath(node_id)) as JuiceeGraphBlock
	if block:
		block.set_debug_active(false)
		if is_instance_valid(hover_panel) and block == _hovered_block:
			hover_panel.call("add_log_entry", "✓ Done")
