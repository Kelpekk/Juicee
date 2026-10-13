class_name JuiceeEffectCatalog
## What each effect is: its category, its one-line description, and which
## dimensions it works in. Plus the colour that category resolves to.
##
## This lived inside JuiceeGraphEditor, which made the runtime depend on the
## editor: JuiceeEffect.get_category_color() reached into a 3300-line Control to
## read a dictionary, and because GDScript resolves class names at parse time,
## every exported game loaded the whole graph editor to do it. None of this is
## about editing a graph, so it does not belong behind one.
##
## Pure data and pure functions. Nothing here touches a Node.

# ─── Category & description registry ─────────────────────────────────────────
# Maps effect script basename -> (category, description) for the popup search list.
# Effects that override get_category_name()/get_description() take precedence over this.
# Order of CATEGORY_ORDER controls section display order.
## What kind of node each effect needs, so a play on the wrong one can be moved to the right
## one instead of warning and doing nothing (see JuiceeEffect._retarget). A class name, several
## separated by commas, or "property:name" for the effects that drive anything carrying that
## property. Effects that work on any node (screen shaders, camera, audio, time, flow) are absent.
const EFFECT_TARGETS := {
	"add_force_effect":                   "RigidBody2D,RigidBody3D",
	"afterimage_effect":                  "Node2D",
	"ambient_flash_effect":               "CanvasItem",
	"animation_player_effect":            "AnimationPlayer",
	"animation_tree_effect":              "AnimationTree",
	"audio_source_3d_effect":             "Node3D,Node2D",
	"bounce_effect":                      "Node2D",
	"breathe_effect":                     "Node2D",
	"burst_effect":                       "Node2D",
	"button_punch_effect":                "Control",
	"camera_follow_effect":               "Node2D",
	"color_cycle_effect":                 "CanvasItem",
	"confetti_effect":                    "Node2D",
	"crack_effect":                       "Node2D",
	"damage_number_effect":               "Node2D",
	"explosion_push_effect":              "Node2D",
	"fade_effect":                        "CanvasItem",
	"flash_effect":                       "CanvasItem",
	"flicker_effect":                     "CanvasItem",
	"flip_effect":                        "Sprite2D,AnimatedSprite2D",
	"floating_text_effect":               "Node2D",
	"glow_pulse_effect":                  "CanvasItem",
	"gravity_shift_effect":               "RigidBody2D",
	"heartbeat_effect":                   "Node2D",
	"hit_spark_effect":                   "Node2D",
	"hop_effect":                         "Node2D",
	"impact_ring_effect":                 "Node2D",
	"impulse_effect":                     "RigidBody2D",
	"instantiate_effect":                 "Node2D,Node3D",
	"jelly_wobble_effect":                "Node2D",
	"jiggle_physics_effect":              "Node2D",
	"knockback_effect":                   "RigidBody2D",
	"light_3d_effect":                    "Light3D",
	"light_flash_effect":                 "Light2D",
	"material_3d_effect":                 "MeshInstance3D",
	"modulate_effect":                    "CanvasItem",
	"number_count_effect":                "property:text",
	"outline_effect":                     "Sprite2D,AnimatedSprite2D,TextureRect,TextureButton,NinePatchRect",
	"particle_effect":                    "CPUParticles2D,GPUParticles2D,CPUParticles3D,GPUParticles3D",
	"pop_in_effect":                      "Node2D,Control",
	"position_effect":                    "Node2D",
	"position_3d_effect":                 "Node3D",
	"pulse_effect":                       "Node2D,Control",
	"recoil_effect":                      "Node2D",
	"rich_text_emphasis_effect":          "RichTextLabel",
	"rotation_effect":                    "Node2D",
	"rotation_3d_effect":                 "Node3D",
	"scale_effect":                       "Node2D,Control",
	"scale_3d_effect":                    "Node3D",
	"set_active_effect":                  "property:visible",
	"shake_control_effect":               "Control",
	"size_delta_effect":                  "Control",
	"slash_arc_effect":                   "Node2D",
	"sparkle_effect":                     "Node2D",
	"spin_effect":                        "Node2D",
	"sprite_bob_effect":                  "Node2D",
	"squash_land_effect":                 "Node2D",
	"stretch_effect":                     "Node2D",
	"strobe_light_effect":                "Light2D",
	"sway_effect":                        "Node2D,Control",
	"text_scramble_effect":               "property:text",
	"text_wobble_effect":                 "Control",
	"trail_effect":                       "Node2D",
	"typewriter_effect":                  "property:visible_ratio",
	"wiggle_effect":                      "Node2D",
	"wobble_rotation_effect":             "Node2D",
}

## The node classes an effect can work on, empty when it takes any node.
static func required_nodes(basename: String) -> PackedStringArray:
	var want: String = EFFECT_TARGETS.get(basename, "")
	return PackedStringArray() if want.is_empty() else PackedStringArray(want.split(","))
## The one parameter an effect cannot do anything without, for the warnings JuiceePlayer shows
## in the Scene dock. Only the cases the effect itself refuses to run on: a Sound with no
## streams, an Animation Player with no clip named. Everything else has a working default.
const REQUIRED_PARAMS := {
	"animation_player_effect":  "animation_name",
	"animation_tree_effect":    "parameter",
	"audio_source_3d_effect":   "streams",
	"beat_sync_effect":         "effect",
	"emit_signal_effect":       "signal_name",
	"instantiate_effect":       "scene",
	"property_tween_effect":    "property",
	"set_property_effect":      "property_name",
	"shader_parameter_effect":  "parameter_name",
	"sound_effect":             "streams",
}

## The parameter this effect needs filled in, or "" when it has none.
static func required_param(basename: String) -> String:
	return str(REQUIRED_PARAMS.get(basename, ""))

const CATEGORY_ORDER := ["Screen", "Camera", "Object", "Text", "Time", "Audio", "Physics", "Flow", "Misc"]

## One colour per category, in one place. Effects don't pick their own any more:
## the base class reads this, so a new effect is coloured correctly for free and
## the palette can be changed here without touching a hundred files.
##
## Colour means category. The 2D / 3D badge on the titlebar means dimension. They
## used to fight over the same signal, which is why Screen and Camera were both
## purple while Object was three different blues.
## Hues are spread around the wheel and checked against each other perceptually
## (CIE Lab deltaE), not by eye. The closest pair sits at dE 28, comfortably past
## the ~20 where two colours stop being tellable apart at a glance. The old palette
## had amber and yellow almost on top of each other, and indigo indistinguishable
## from blue. Trigger's green is part of this budget: it shares the canvas.
const CATEGORY_COLORS := {
	"Screen":  Color(0.76, 0.30, 0.95),   # violet
	"Camera":  Color(0.22, 0.44, 0.98),   # blue
	"Object":  Color(0.13, 0.66, 0.88),   # cyan
	"Physics": Color(0.09, 0.62, 0.46),   # deep teal
	"Audio":   Color(0.98, 0.95, 0.10),   # yellow
	"Time":    Color(0.98, 0.48, 0.05),   # orange
	"Text":    Color(0.92, 0.23, 0.32),   # red
	"Flow":    Color(0.55, 0.60, 0.70),   # slate, it wires things rather than doing them
	"Misc":    Color(0.60, 0.62, 0.68),
}

## The alternative: colour by what the effect targets, using the engine's own 2D
## blue and 3D red, so a graph mixing both dimensions reads at a glance.
const DIMENSION_COLORS := {
	"2d":   Color(0.45, 0.62, 0.99),   # the blue Godot paints Node2D with
	"3d":   Color(0.99, 0.45, 0.45),   # the red it paints Node3D with
	# Works in both, so it is literally the two mixed. Must not be the slate that
	# flow control uses, or an engine-level effect and a Loop block look the same.
	"both": Color(0.76, 0.45, 0.95),
}

## Project Settings > Juicee > Graph > Effect Color Mode. 0 = Category, 1 = Dimension.
const COLOR_MODE_SETTING := "juicee/graph/effect_color_mode"

enum ColorMode { CATEGORY, DIMENSION }

static func color_mode() -> int:
	return int(ProjectSettings.get_setting(COLOR_MODE_SETTING, ColorMode.CATEGORY))

## The colour for a category, falling back to Object's blue for anything unmapped.
static func category_color(category: String) -> Color:
	return CATEGORY_COLORS.get(category, CATEGORY_COLORS["Object"])

## An effect's titlebar / card colour, honouring the project's chosen mode.
## `dims` comes from EFFECT_DIMENSIONS: ["2d"], ["3d"], or both.
static func effect_color(category: String, dims: Array = []) -> Color:
	if color_mode() == ColorMode.DIMENSION:
		var has_2d: bool = dims.has("2d")
		var has_3d: bool = dims.has("3d")
		if has_2d and has_3d:
			return DIMENSION_COLORS["both"]
		if has_3d:
			return DIMENSION_COLORS["3d"]
		if has_2d:
			return DIMENSION_COLORS["2d"]
		return DIMENSION_COLORS["both"]
	return category_color(category)

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
	"speed_lines_effect":      "Screen",
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
	"scale_3d_effect":   "Object",
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
	"low_pass_effect":      "Audio",
	# Physics
	"impulse_effect":       "Physics",
	# Object, the second batch
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
	# Flow, the second batch
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
	# Batch 3 - Screen
	"lens_distortion_effect":  "Screen",
	"depth_of_field_effect":   "Screen",
	# Batch 3 - Camera
	"camera_rotation_effect":  "Camera",
	# Batch 3 - Object
	"shader_parameter_effect": "Object",
	"flicker_effect":          "Object",
	"scale_effect":            "Object",
	"particle_effect":         "Object",
	"light_3d_effect":         "Object",
	"material_3d_effect":      "Object",
	# Batch 3 - Audio
	"audio_source_3d_effect":  "Audio",
	# Batch 3 - Physics
	"add_force_effect":        "Physics",
	# Batch 3 - Flow
	"emit_signal_effect":      "Flow",
	"debug_log_effect":        "Flow",
	"animation_tree_effect":   "Flow",
	"set_property_effect":     "Flow",
	# Batch 4 - missing fundamentals
	"fade_effect":             "Object",
	"flip_effect":             "Object",
	"instantiate_effect":      "Object",
	"size_delta_effect":       "Object",
	"auto_destruct_effect":    "Flow",
}

const EFFECT_DESCRIPTIONS := {
	"chromatic_effect":     "RGB channel split full-screen.\nUse for damage hits or glitch moments.",
	"vignette_effect":      "Edge-darkening overlay with color tint.\nGreat for damage red or atmospheric mood.",
	"blur_effect":          "Full-screen blur.\nUse for pause menus or dream sequences.",
	"pixelate_effect":      "Full-screen pixelation.\nRetro flashes, damage hits, glitch moments.",
	"glitch_effect":        "Horizontal tear + chromatic split.\nDamage, hacking, broken-system vibe.",
	"color_grade_effect":   "Saturation / contrast / brightness / tint shift.\nDesaturate on damage, boost on level-up.",
	"screen_tint_effect":   "Colored full-screen overlay (red damage, gold level-up).",
	"screen_wipe_effect":   "Colored bar slides across screen for transitions.",
	"bloom_effect":         "Pulses WorldEnvironment glow (built-in Godot post-process).\nBoss intros, level-ups, power-ups. Needs a WorldEnvironment, 2D or 3D.",
	"tonemap_effect":       "Punch tonemap exposure for flashbang / overload feel.\nExplosions, teleports, dimension shifts.",
	"shockwave_effect":     "Expanding radial distortion ring from the context node's position.\nExplosions, teleport arrivals, spell impacts, landing slams.",
	"cinematic_bars_effect":"Letterbox bars slide in / hold / slide out for cutscene feel.\nBoss intros, dialogue sequences, dramatic slow-mo moments.",
	"shake_effect":         "Shakes the active Camera2D with Perlin noise + decay.\nHits, explosions, landings, anything with weight.",
	"shake_3d_effect":      "Camera3D shake that mostly turns the camera rather than sliding it.",
	"zoom_effect":          "Camera2D zoom punch in/out with overshoot.",
	"fov_3d_effect":        "Camera3D field-of-view punch (positive = zoom out).",
	"camera_follow_effect": "Smoothly lerps Camera2D to follow a target then returns.\nAttention shift for boss intros.",
	"flash_effect":         "Blinks modulate on a CanvasItem N times.\nUse for hit acknowledgment on sprites.",
	"modulate_effect":      "Smooth color shift (unlike Flash which blinks).",
	"bounce_effect":        "Uniform scale punch on a Node2D that springs back.",
	"jiggle_physics_effect":"Spring-based jelly jiggle (real physics, not preset).",
	"position_effect":      "Move Node2D by offset, then return.",
	"position_3d_effect":   "Same as Position but for Node3D.",
	"rotation_effect":      "Rotate Node2D by angle, then return.",
	"rotation_3d_effect":   "Same as Rotation but for Node3D (quaternion-based).",
	"scale_3d_effect": "Scale a Node3D to a target and optionally back.\nGrow on buff, shrink on nerf, scale-in from 0, death scale-out.",
	"trail_effect":         "Sprite2D or AnimatedSprite2D ghost trail behind a moving target.",
	"burst_effect":         "One-shot CPUParticles2D burst at target position.",
	"confetti_effect":      "Multi-color particle burst for celebrations / level-ups.",
	"light_flash_effect":   "Flash a Light2D's energy and color briefly.",
	"spring_effect":        "Harmonic-oscillator spring on a Vector2 or float property.\nBouncy menus, squash on hit, panel-into-view oscillation.",
	"damage_number_effect": "Floating damage numbers above a target.\nPass {\"damage\": 42, \"is_crit\": true} via play() for live values.",
	"floating_text_effect": "Generic floating text (Level Up!, pickup names, status messages).\nPass {\"text\": \"Hello!\"} via play() for dynamic content.",
	"button_punch_effect":  "Scale-punch for Control nodes (Button, Label, Panel).\nButton presses, menu picks, confirmations.",
	"typewriter_effect":    "Char-by-char text reveal on a Label with optional click sounds.\nDialog, intros, terminal vibes.",
	"number_count_effect":  "Tween a Label's number from X to Y.\nScore rollups, money displays, XP gains. Pass {\"from\":1200,\"to\":2000}.",
	"text_wobble_effect":   "Sine-wave wobble on a Control's position with decay.\nDrama text: GAME OVER, WAVE COMPLETE, BOSS APPROACHING.",
	"hit_stop_effect":      "Instant Engine.time_scale freeze for impact moments.\n~50-100ms is the sweet spot.",
	"time_scale_ramp_effect":"Smooth slow-mo with ramp-in / hold / ramp-out.",
	"delay_effect":         "Wait N seconds. Useful for sequencing.",
	"sound_effect":         "Plays a random AudioStream with pitch variance.",
	"music_duck_effect":    "Temporarily lowers an audio bus volume.",
	"rumble_effect":        "Gamepad vibration through Juicee's mixer.\nOverlapping rumbles combine instead of cancelling.",
	"reverb_effect":        "Inject a temporary AudioEffectReverb on a bus with wet ramp.\nBoss intros, dimension shifts, low-health states.",
	"pitch_shift_effect":   "Animate a temporary AudioEffectPitchShift on a bus.\nUnderwater, slow-mo audio, demon transformations.",
	"low_pass_effect":      "Ramp a temporary AudioEffectLowPassFilter on a bus.\nMuffled-on-hit, underwater, stunned, behind-a-wall.",
	"impulse_effect":       "Applies a fixed impulse to a RigidBody2D.\nFor a push along hit_direction, use Knockback.",
	"ambient_flash_effect": "Repeating modulate flash for sustained states.\nLow-health siren, boss enrage, alarm pulsing.",
	"strobe_light_effect":  "Square-wave Light2D strobe.\nLightning flashes, flashbangs, emergency sirens.",
	"recoil_effect":        "Directional position kick on Node2D with spring-back.\nGun recoil, hit absorption, stiff-arm impact.",
	"outline_effect":       "Animate a colored sprite outline via shader uniform.\nSelection ring, status glow, lock-on indicator.",
	"color_cycle_effect":   "Cycle modulate through the hue wheel or your own colours.\nRainbow powerup, party mode, boss phase shift.",
	"animation_player_effect": "Trigger AnimationPlayer.play() as a sequence step.\nRun a clip you already have in time with the other effects.",
	"set_active_effect":    "Show/hide a node for N seconds then restore.\nMuzzle flash, hit spark, tutorial highlight.",
	"chain_effect":         "Compose N child effects as one reusable block.\nBuild signature combos as single .tres assets.",
	"sequence_effect":      "Embeds another JuiceeSequence as one step.\nFor composable presets.",
	"property_tween_effect":"Tween ANY property on ANY node.\nUniversal escape hatch.",
	# New batch
	"scan_lines_effect":       "CRT scanline overlay with scroll.\nRetro monitors, broken screens, hacker aesthetic.",
	"speed_lines_effect":      "Anime radial speed lines converging on centre.\nDashes, bursts of speed, focus and shock moments.",
	"film_grain_effect":       "Analog film grain noise overlay.\nCinematic grit, horror atmosphere, film emulation.",
	"radial_blur_effect":      "Radial motion blur from a screen point.\nSpeed lines, warp drives, dash impacts.",
	"directional_shake_effect":"Kick-recoil shake in a specific direction with perpendicular noise.\nGun fire, punches, directional hits.",
	"camera_bob_effect":       "Rhythmic sine-wave camera bob (walk cycle, breathing idle).\nEases in and out, or loops for as long as you walk.",
	"zoom_pulse_effect":       "BPM-synced zoom pulse on Camera2D.\nBeat-drop, music-reactive, bass rumble feel.",
	"spin_effect":             "Spin a Node2D for a set time.\nCoin pickups, death spin, victory twirl.",
	"wiggle_effect":           "Random position jitter at frequency Hz with optional decay.\nAnxiety, confusion, low-health tremor.",
	"sprite_bob_effect":       "Sine-wave bob along an axis (idle float, hover loop).\nPickups, UI icons, floating enemies.",
	"pop_in_effect":           "Spring overshoot scale-in from 0 (or custom from_scale).\nMenus opening, pickups spawning, icons appearing.",
	"shake_control_effect":    "Horizontal shake on Control nodes (Button, Panel, Label).\nWrong-password UI, invalid action feedback.",
	"pulse_effect":            "Repeating scale pulse (EXPO in+out).\nOngoing heartbeat, charge meter, selected state.",
	"freeze_frame_effect":     "A time freeze with a full-screen flash you can turn off.\nFinishing blows, super moves, headshots. Hit Stop is the pause alone.",
	"wait_for_input_effect":   "Pause sequence until player presses an action.\nDialog advancement, tutorial checkpoints, cutscene pacing.",
	"beat_sync_effect":        "Fire a child effect on every N beats (BPM-synced or JuiceeBeatClock).\nMusic-reactive juiciness, rhythm-game impacts.",
	# Batch 3
	"lens_distortion_effect":  "Barrel or pincushion lens distortion full-screen.\nPositive = fisheye, negative = telephoto. Scope zoom-in, portal, impact.",
	"depth_of_field_effect":   "Animate Camera3D depth-of-field blur (CameraAttributes).\nFocus pull, sniper scope, dialogue close-up, death blur.",
	"camera_rotation_effect":  "Dutch tilt - rotate Camera2D to angle then spring back.\nSuspense, horror reveal, gravity shift, off-kilter dream.",
	"shader_parameter_effect": "Tween any uniform on any ShaderMaterial.\nAnimate dissolves, hit-flash, charge-up glow, forcefield intensity.",
	"flicker_effect":          "Organic random visibility flicker on a CanvasItem.\nBroken lights, haunted objects, EMP, damaged HUD.",
	"scale_effect":            "General scale tween to target and optionally back.\nGrow on buff, shrink on nerf, scale-in from 0, death scale-out.",
	"particle_effect":         "Control an existing particle node, 2D or 3D.\nEmit, stop, or restart a pre-configured particle system.",
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


## Maps effect basename -> ["2d"] / ["3d"] / ["2d","3d"].
## Used in the popup search list and graph block titlebars as small tag icons.
const EFFECT_DIMENSIONS: Dictionary = {
	# Screen overlays - full-screen shaders work in both 2D and 3D viewports.
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
	# Object - 2D (Node2D / CanvasItem / Light2D)
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
	# Object - 3D
	"position_3d_effect":      ["3d"],
	"rotation_3d_effect":      ["3d"],
	"scale_3d_effect": ["3d"],
	# Text / UI - Control nodes are 2D only.
	"damage_number_effect":    ["2d"],
	"floating_text_effect":    ["2d"],
	"button_punch_effect":     ["2d"],
	"typewriter_effect":       ["2d"],
	"number_count_effect":     ["2d"],
	"text_wobble_effect":      ["2d"],
	"text_scramble_effect":    ["2d"],
	# Time - engine-level, works in any scene.
	"hit_stop_effect":         ["2d","3d"],
	"time_scale_ramp_effect":  ["2d","3d"],
	"stutter_effect":          ["2d","3d"],
	"delay_effect":            ["2d","3d"],
	# Audio / haptics - bus-level, scene-independent.
	"sound_effect":            ["2d","3d"],
	"music_duck_effect":       ["2d","3d"],
	"rumble_effect":           ["2d","3d"],
	"reverb_effect":           ["2d","3d"],
	"pitch_shift_effect":      ["2d","3d"],
	"low_pass_effect":         ["2d","3d"],
	"distortion_effect":       ["2d","3d"],
	# Physics
	"impulse_effect":          ["2d"],
	"knockback_effect":        ["2d"],
	# Flow - generic composition.
	"animation_player_effect": ["2d","3d"],
	"set_active_effect":       ["2d","3d"],
	"chain_effect":            ["2d","3d"],
	"sequence_effect":         ["2d","3d"],
	"property_tween_effect":   ["2d","3d"],
	# New batch - Screen
	"scan_lines_effect":       ["2d","3d"],
	"speed_lines_effect":      ["2d","3d"],
	"film_grain_effect":       ["2d","3d"],
	"radial_blur_effect":      ["2d","3d"],
	# New batch - Camera
	"directional_shake_effect":["2d"],
	"camera_bob_effect":       ["2d"],
	"zoom_pulse_effect":       ["2d"],
	# New batch - Object
	"spin_effect":             ["2d"],
	"wiggle_effect":           ["2d"],
	"sprite_bob_effect":       ["2d"],
	"pop_in_effect":           ["2d"],
	"shake_control_effect":    ["2d"],
	"pulse_effect":            ["2d"],
	# New batch - Time / Flow
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
	# 1.5 - ported from the 2.0 line. All 2D (Node2D / CanvasItem / RigidBody2D /
	# Control); only tremolo is bus-level audio, so it rides in both like the rest.
	"afterimage_effect":         ["2d"],
	"breathe_effect":            ["2d"],
	"crack_effect":              ["2d"],
	"explosion_push_effect":     ["2d"],
	"glow_pulse_effect":         ["2d"],
	"gravity_shift_effect":      ["2d"],
	"heartbeat_effect":          ["2d"],
	"hit_spark_effect":          ["2d"],
	"hop_effect":                ["2d"],
	"jelly_wobble_effect":       ["2d"],
	"rich_text_emphasis_effect": ["2d"],
	"slash_arc_effect":          ["2d"],
	"sparkle_effect":            ["2d"],
	"squash_land_effect":        ["2d"],
	"stretch_effect":            ["2d"],
	"wobble_rotation_effect":    ["2d"],
	"tremolo_effect":            ["2d","3d"],
}

## An effect's dimensions, but only when it is limited to one. 45 of the 117 work
## in both, so handing back the full list tagged nearly every block and the tag
## stopped carrying information. Empty means "works either way, nothing to say",
## which leaves a tag meaning "this one is limited" wherever it does appear.
static func restrictive_dims(basename: String) -> Array:
	var dims: Array = EFFECT_DIMENSIONS.get(basename, [])
	return dims if dims.size() == 1 else []

## Effects that write a captured property directly from a manual loop, one value per
## iteration, instead of handing it to a tween.
##
## The two do not share a property peacefully, and the loop side is the one that loses.
## A tween writes later in the frame and overwrites whatever the loop just set, so the
## loop's contribution never survives to be drawn: measured, a Wiggle with a 6 px
## amplitude running under a Position tween moved its node 0.000 px. Two tweens hand
## over smoothly (0.055 of movement at the handover against 0.079 for one effect's own
## return), so only the loop side is worth flagging. Loops that move a property by an offset
## add up with each other (JuiceeEffect._write_offset()), so those meeting is not flagged either.
##
## Read off the sources rather than guessed at, and `temp/test_stacking.gd` re-derives
## it and fails if this list and the code have drifted apart. Time Scale writers are
## deliberately absent: Hit Stop and Freeze Frame contend over `Engine.time_scale` by
## design and are ref-counted for it.
const LOOP_WRITERS: Dictionary = {
	"ambient_flash_effect": true,
	"breathe_effect": true,
	"camera_bob_effect": true,
	"color_cycle_effect": true,
	"directional_shake_effect": true,
	"flicker_effect": true,
	"jelly_wobble_effect": true,
	"shake_3d_effect": true,
	"shake_control_effect": true,
	"shake_effect": true,
	"spring_effect": true,
	"sprite_bob_effect": true,
	"sway_effect": true,
	"text_scramble_effect": true,
	"text_wobble_effect": true,
	"tremolo_effect": true,
	"wiggle_effect": true,
	"wobble_rotation_effect": true,
}

## Whether this effect drives its target from a manual loop. See LOOP_WRITERS.
static func writes_in_loop(basename: String) -> bool:
	return LOOP_WRITERS.has(basename)
