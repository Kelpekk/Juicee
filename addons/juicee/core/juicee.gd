## Global convenience API for game juicee effects.
##
## Auto-registered as the `Juicee` autoload singleton — accessible from any script.
##
## Quick fire-and-forget effects with one line of code, no setup required:
## [codeblock]
## Juicee.shake_camera(self, 15.0, 0.3)
## Juicee.hit_stop(self, 0.08)
## Juicee.flash(my_sprite, Color.RED)
## Juicee.burst(self, 12, Color.YELLOW)
## [/codeblock]
##
## For repeated, sequenced, or designer-tweakable effects, use `JuiceePlayer` nodes
## and `JuiceeSequence` resources instead — they're configurable in the Inspector.
extends Node

## Global accessibility settings. Change these from your game's settings screen.
## All effects read these flags automatically via JuiceeEffect.accessibility.
## [codeblock]
## Juicee.accessibility.reduced_motion = true   # silences shake/wobble
## Juicee.accessibility.no_flash       = true   # disables flash/strobe
## Juicee.accessibility.no_screenshake = true   # disables camera shake only
## [/codeblock]
var accessibility: JuiceeAccessibility = JuiceeAccessibility.new()

## When true, the built-in presets (preset_hit, preset_pickup, preset_explosion, …)
## also play a procedurally-synthesized sfxr sound — zero audio assets required.
## Opt-in (default false) so existing projects keep their current silent presets.
## [codeblock]
## Juicee.sfx_enabled = true
## Juicee.preset_hit(enemy)   # now also makes a hit sound
## [/codeblock]
## @experimental: Procedural SFX is an experimental prototyping aid; the API may change.
var sfx_enabled: bool = false

func _ready() -> void:
	JuiceeEffect.accessibility = accessibility

# ─── Camera ─────────────────────────────────────────────────────────────────

## Shake the active Camera2D found via context.get_viewport().
func shake_camera(context: Node, intensity: float = 8.0, duration: float = 0.3, frequency: float = 15.0) -> void:
	var effect := JuiceeShakeEffect.new()
	effect.intensity = intensity
	effect.duration = duration
	effect.frequency = frequency
	effect.apply(context)

## 3D camera shake.
func shake_camera_3d(context: Node, intensity: float = 0.1, duration: float = 0.3) -> void:
	var effect := JuiceeShake3DEffect.new()
	effect.intensity = intensity
	effect.duration = duration
	effect.apply(context)

## Camera2D zoom punch.
func zoom_camera(context: Node, zoom_factor: float = 1.2, duration: float = 0.4) -> void:
	var effect := JuiceeZoomEffect.new()
	effect.zoom_factor = zoom_factor
	effect.duration = duration
	effect.apply(context)

# ─── Time ───────────────────────────────────────────────────────────────────

## Instant Engine.time_scale freeze for impact moments.
func hit_stop(context: Node, freeze_duration: float = 0.08, time_scale_during: float = 0.0) -> void:
	var effect := JuiceeHitStopEffect.new()
	effect.freeze_duration = freeze_duration
	effect.time_scale_during = time_scale_during
	effect.apply(context)

## Smooth slow-motion ramp.
func slow_mo(context: Node, target_scale: float = 0.2, hold: float = 0.4) -> void:
	var effect := JuiceeTimeScaleRampEffect.new()
	effect.target_scale = target_scale
	effect.hold = hold
	effect.apply(context)

## Engine.time_scale = 0 for N seconds (feels heavier than hit_stop — true freeze).
func freeze_frame(context: Node, freeze_duration: float = 0.1,
		white_flash: bool = true) -> void:
	var effect := JuiceeFreezeFrameEffect.new()
	effect.duration = freeze_duration
	effect.use_flash = white_flash
	effect.apply(context)

## Simple pause for `duration` seconds — stalls a sequence without any visual change.
## Use in sequences between steps: `Juicee.wait(self, 0.5)`.
func wait(context: Node, duration: float = 0.5) -> void:
	var effect := JuiceeDelayEffect.new()
	effect.duration = duration
	effect.apply(context)

# ─── Object feedback ─────────────────────────────────────────────────────────

## Flash a CanvasItem's modulate. Target = the node to flash (sprite, control, etc.).
func flash(target: CanvasItem, flash_color: Color = Color.WHITE, duration: float = 0.15, count: int = 1) -> void:
	var effect := JuiceeFlashEffect.new()
	effect.flash_color = flash_color
	effect.duration = duration
	effect.flash_count = count
	effect.apply(target)

## Squash & stretch scale punch on a Node2D.
func bounce(target: Node2D, scale_factor: float = 1.3, duration: float = 0.3) -> void:
	var effect := JuiceeBounceEffect.new()
	effect.scale_factor = scale_factor
	effect.duration = duration
	effect.apply(target)

## Position punch with return.
func punch_position(target: Node2D, offset: Vector2, duration: float = 0.3) -> void:
	var effect := JuiceePositionEffect.new()
	effect.offset = offset
	effect.duration = duration
	effect.apply(target)

## Rotation punch with return.
func punch_rotation(target: Node2D, angle_degrees: float = 15.0, duration: float = 0.3) -> void:
	var effect := JuiceeRotationEffect.new()
	effect.angle_degrees = angle_degrees
	effect.duration = duration
	effect.apply(target)

## 3D position punch — move Node3D by offset (in world units) then return.
func punch_position_3d(target: Node3D, offset: Vector3 = Vector3(0, 0.5, 0),
		duration: float = 0.3) -> void:
	var effect := JuiceePosition3DEffect.new()
	effect.offset = offset
	effect.duration = duration
	effect.apply(target)

## 3D rotation punch — rotate Node3D around axis by angle_degrees then return.
func punch_rotation_3d(target: Node3D, angle_degrees: float = 15.0,
		axis: Vector3 = Vector3.UP, duration: float = 0.3) -> void:
	var effect := JuiceeRotation3DEffect.new()
	effect.angle_degrees = angle_degrees
	effect.axis = axis
	effect.duration = duration
	effect.apply(target)

## Full 360° rotation tween on Node2D (coin pickups, death spin, victory twirl).
func spin(target: Node2D, speed_deg_per_sec: float = 360.0, duration: float = 0.6,
		restore: bool = false) -> void:
	var effect := JuiceeSpinEffect.new()
	effect.degrees_per_second = speed_deg_per_sec
	effect.duration = duration
	effect.restore_on_end = restore
	effect.apply(target)

## Random position jitter at Hz frequency with optional decay (anxiety, confusion).
func wiggle(target: Node2D, amplitude: float = 4.0, frequency: float = 12.0,
		duration: float = 0.5) -> void:
	var effect := JuiceeWiggleEffect.new()
	effect.amplitude = amplitude
	effect.frequency = frequency
	effect.duration = duration
	effect.apply(target)

## Sine-wave bob along an axis (floating pickups, hover loop, idle animation).
func sprite_bob(target: Node2D, amplitude_px: float = 6.0, bob_freq: float = 1.5,
		duration: float = 3.0, axis: Vector2 = Vector2(0, 1)) -> void:
	var effect := JuiceeSpriteBobEffect.new()
	effect.amplitude = amplitude_px
	effect.frequency = bob_freq
	effect.duration = duration
	effect.bob_axis = axis
	effect.apply(target)

## SPRING overshoot scale-in from zero (the most satisfying pop-in possible).
func pop_in(target: Node, from_scale: float = 0.0) -> void:
	var effect := JuiceePopInEffect.new()
	effect.from_scale = from_scale
	effect.apply(target)

## Horizontal shake on a Control node (wrong-password, invalid-action feedback).
func shake_control(target: Control, amplitude: float = 8.0, duration: float = 0.4,
		frequency: float = 18.0) -> void:
	var effect := JuiceeShakeControlEffect.new()
	effect.intensity = amplitude
	effect.duration = duration
	effect.frequency = frequency
	effect.apply(target)

## Fade a CanvasItem's alpha to target_alpha over duration.
## Use restore_on_end = true for fade-out-then-back-in patterns.
func fade(target: CanvasItem, target_alpha: float = 0.0, duration: float = 0.5,
		restore_on_end: bool = false, restore_duration: float = 0.4) -> void:
	var effect := JuiceeFadeEffect.new()
	effect.target_alpha = target_alpha
	effect.duration = duration
	effect.restore_on_end = restore_on_end
	effect.restore_duration = restore_duration
	effect.apply(target)

## Flip a Sprite2D or AnimatedSprite2D horizontally (toggle by default).
func flip(target: Node, flip_h_mode: JuiceeFlipEffect.Mode = JuiceeFlipEffect.Mode.TOGGLE,
		flip_v_mode: JuiceeFlipEffect.Mode = JuiceeFlipEffect.Mode.SET_FALSE,
		restore_on_end: bool = false, hold_duration: float = 0.0) -> void:
	var effect := JuiceeFlipEffect.new()
	effect.flip_h_mode = flip_h_mode
	effect.flip_v_mode = flip_v_mode
	effect.restore_on_end = restore_on_end
	effect.hold_duration = hold_duration
	effect.apply(target)

## Spawn a PackedScene at the context node's position. Auto-freed after `lifetime` seconds.
func instantiate_scene(context: Node, scene: PackedScene, lifetime: float = 2.0,
		offset: Vector2 = Vector2.ZERO) -> void:
	var effect := JuiceeInstantiateEffect.new()
	effect.scene = scene
	effect.lifetime = lifetime
	effect.position_offset = offset
	effect.apply(context)

## Queue-free the context node (or target) after `delay` seconds.
func auto_destruct(context: Node, delay: float = 0.0,
		target_path: NodePath = NodePath()) -> void:
	var effect := JuiceeAutoDestructEffect.new()
	effect.destruct_delay = delay
	effect.target_path = target_path
	effect.apply(context)

## Tween a Control's custom_minimum_size to target_size over duration.
func resize_control(target: Control, target_size: Vector2,
		duration: float = 0.3, restore_on_end: bool = false) -> void:
	var effect := JuiceeSizeDeltaEffect.new()
	effect.target_size = target_size
	effect.duration = duration
	effect.restore_on_end = restore_on_end
	effect.apply(target)

## Repeating scale pulse on a Node2D/Control (heartbeat, charge meter, selected state).
## count=0 + duration>0 = time-limited; count>0 = fixed repetitions.
func pulse(target: Node, scale_factor: float = 1.15, interval: float = 0.5,
		count: int = 0, duration: float = 3.0) -> void:
	var effect := JuiceePulseEffect.new()
	effect.scale_amount = scale_factor
	effect.pulse_interval = interval
	effect.count = count
	effect.duration = duration
	effect.apply(target)

## Tween any ShaderMaterial uniform from `from_value` to `to_value` over `duration`.
func shader_parameter(target: Node, param_name: String, from_value: Variant,
		to_value: Variant, duration: float = 0.5, restore_on_end: bool = false,
		surface_index: int = 0) -> void:
	var effect := JuiceeShaderParameterEffect.new()
	effect.parameter_name = param_name
	effect.from_value = from_value
	effect.to_value = to_value
	effect.duration = duration
	effect.restore_on_end = restore_on_end
	effect.surface_index = surface_index
	effect.apply(target)

## Organic random modulate flicker on a CanvasItem (torches, broken lights, ghosts).
## duration = 0 runs forever until stop() is called.
func flicker(target: CanvasItem, duration: float = 1.5,
		off_color: Color = Color(0, 0, 0, 0), off_chance: float = 0.3) -> void:
	var effect := JuiceeFlickerEffect.new()
	effect.duration = duration
	effect.off_color = off_color
	effect.off_chance = off_chance
	effect.apply(target)

## General scale tween to `target_scale` with optional spring back.
func scale_to(target: Node, target_scale: Vector2 = Vector2(1.5, 1.5),
		duration: float = 0.3, return_to_original: bool = true,
		return_duration: float = 0.2) -> void:
	var effect := JuiceeScaleEffect.new()
	effect.target_scale = target_scale
	effect.duration = duration
	effect.return_to_original = return_to_original
	effect.return_duration = return_duration
	effect.apply(target)

## Control an existing CPUParticles2D or GPUParticles2D by path.
func particle_emit(context: Node, particle_path: NodePath,
		action: JuiceeParticleEffect.Action = JuiceeParticleEffect.Action.EMIT,
		wait_for_finish: bool = false) -> void:
	var effect := JuiceeParticleEffect.new()
	effect.particle_path = particle_path
	effect.action = action
	effect.wait_for_finish = wait_for_finish
	effect.apply(context)

## Flash a Light3D's energy and color (muzzle flash, explosion light, magic pulse).
func light_3d_flash(target: Node, peak_energy: float = 5.0,
		flash_color: Color = Color.WHITE, duration: float = 0.25,
		light_path: NodePath = NodePath()) -> void:
	var effect := JuiceeLight3DEffect.new()
	effect.peak_energy = peak_energy
	effect.flash_color = flash_color
	effect.duration = duration
	if not light_path.is_empty():
		effect.light_path = light_path
	effect.apply(target)

## Animate a MeshInstance3D material property (dissolve, emission, fresnel).
func material_3d(target: Node, property_name: String, from_value: Variant,
		to_value: Variant, duration: float = 0.5, restore_on_end: bool = false,
		surface_index: int = 0) -> void:
	var effect := JuiceeMaterial3DEffect.new()
	effect.property_name = property_name
	effect.from_value = from_value
	effect.to_value = to_value
	effect.duration = duration
	effect.restore_on_end = restore_on_end
	effect.surface_index = surface_index
	effect.apply(target)

# ─── Particles ──────────────────────────────────────────────────────────────

## One-shot particle burst at the target's position.
func burst(target: Node2D, amount: int = 12, color: Color = Color(1.0, 0.8, 0.3), spread: float = 120.0) -> void:
	var effect := JuiceeBurstEffect.new()
	effect.amount = amount
	effect.color = color
	effect.spread = spread
	effect.apply(target)

## Multi-color confetti burst for celebrations.
func confetti(target: Node2D, amount: int = 40) -> void:
	var effect := JuiceeConfettiEffect.new()
	effect.amount = amount
	effect.apply(target)

# ─── Screen FX ──────────────────────────────────────────────────────────────

## Chromatic aberration (RGB split) full-screen.
func chromatic(context: Node, intensity: float = 5.0, duration: float = 0.2) -> void:
	var effect := JuiceeChromaticEffect.new()
	effect.intensity = intensity
	effect.duration = duration
	effect.apply(context)

## Edge-darkening vignette with color tint.
func vignette(context: Node, intensity: float = 0.6, duration: float = 0.8, color: Color = Color.BLACK) -> void:
	var effect := JuiceeVignetteEffect.new()
	effect.intensity = intensity
	effect.duration = duration
	effect.vignette_color = color
	effect.apply(context)

## Full-screen blur.
func blur(context: Node, blur_amount: float = 4.0, duration: float = 0.6) -> void:
	var effect := JuiceeBlurEffect.new()
	effect.intensity = blur_amount
	effect.duration = duration
	effect.apply(context)

## Digital glitch tear + chromatic split.
func glitch(context: Node, strength: float = 0.5, duration: float = 0.3) -> void:
	var effect := JuiceeGlitchEffect.new()
	effect.intensity = strength
	effect.duration = duration
	effect.apply(context)

## Colored full-screen flash (damage red, level-up gold, etc.).
func screen_tint(context: Node, tint_color: Color, duration: float = 0.4) -> void:
	var effect := JuiceeScreenTintEffect.new()
	effect.tint_color = tint_color
	effect.duration = duration
	effect.apply(context)

## Smooth modulate color shift on a CanvasItem (unlike flash which blinks).
func modulate_to(target: CanvasItem, color: Color, duration: float = 0.4) -> void:
	var effect := JuiceeModulateEffect.new()
	effect.target_color = color
	effect.duration = duration
	effect.apply(target)

## Spring-based jiggle on a Node2D's scale (jelly cube feel).
func jiggle(target: Node2D, impulse: Vector2 = Vector2(0.4, -0.4), stiffness: float = 8.0) -> void:
	var effect := JuiceeJigglePhysicsEffect.new()
	effect.impulse = impulse
	effect.stiffness = stiffness
	effect.apply(target)

## Full-screen color grading shift (saturation, contrast, brightness, tint).
func color_grade(context: Node, saturation: float = 0.5, contrast: float = 1.2, tint: Color = Color.WHITE, duration: float = 0.8) -> void:
	var effect := JuiceeColorGradeEffect.new()
	effect.saturation = saturation
	effect.contrast = contrast
	effect.tint = tint
	effect.duration = duration
	effect.apply(context)

## Full-screen pixelation effect.
func pixelate(context: Node, pixel_size: float = 8.0, duration: float = 0.5) -> void:
	var effect := JuiceePixelateEffect.new()
	effect.pixel_size = pixel_size
	effect.duration = duration
	effect.apply(context)

## Light2D energy/color flash.
func light_flash(target: Light2D, peak_energy: float = 3.0, color: Color = Color.WHITE, duration: float = 0.3) -> void:
	var effect := JuiceeLightFlashEffect.new()
	effect.peak_energy = peak_energy
	effect.flash_color = color
	effect.duration = duration
	effect.apply(target)

## Full-screen wipe transition (colored bar slides across).
func screen_wipe(context: Node, from_side: int = 0, color: Color = Color.BLACK, duration: float = 0.6) -> void:
	var effect := JuiceeScreenWipeEffect.new()
	effect.wipe_from = from_side
	effect.wipe_color = color
	effect.duration = duration
	effect.apply(context)

## Expanding radial shockwave distortion ring from the context node's screen position.
## Use for explosions, teleport arrivals, spell impacts, landing slams.
func shockwave(context: Node, max_radius: float = 0.6, strength: float = 0.025, duration: float = 0.5) -> void:
	var effect := JuiceeShockwaveEffect.new()
	effect.max_radius = max_radius
	effect.strength = strength
	effect.duration = duration
	effect.apply(context)

## Cinematic letterbox bars: slide in, hold, slide out.
## hold_duration=0 keeps bars up until you call stop() on the returned effect.
func cinematic_bars(context: Node, bar_height: float = 0.1, enter_duration: float = 0.3,
		hold_duration: float = 2.0, exit_duration: float = 0.3) -> JuiceeCinematicBarsEffect:
	var effect := JuiceeCinematicBarsEffect.new()
	effect.bar_height = bar_height
	effect.enter_duration = enter_duration
	effect.hold_duration = hold_duration
	effect.exit_duration = exit_duration
	effect.apply(context)
	return effect

## Dutch tilt — rotate Camera2D by angle_degrees then spring back.
func camera_rotation(context: Node, angle_degrees: float = 5.0, tilt_duration: float = 0.3,
		hold_duration: float = 0.0, return_duration: float = 0.4) -> void:
	var effect := JuiceeCameraRotationEffect.new()
	effect.angle_degrees = angle_degrees
	effect.tilt_duration = tilt_duration
	effect.hold_duration = hold_duration
	effect.return_duration = return_duration
	effect.apply(context)

## Temporary Camera2D lerp to follow a target Node2D (attention shift).
func camera_follow(target: Node2D, duration: float = 1.5, follow_speed: float = 5.0) -> void:
	var effect := JuiceeCameraFollowEffect.new()
	effect.duration = duration
	effect.follow_speed = follow_speed
	effect.apply(target)

## CRT scanline overlay (retro monitors, broken screens).
func scan_lines(context: Node, line_count: float = 300.0, strength: float = 0.25,
		duration: float = 1.0, scroll_speed: float = 0.0) -> void:
	var effect := JuiceeScanLinesEffect.new()
	effect.line_count = line_count
	effect.strength = strength
	effect.scroll_speed = scroll_speed
	effect.duration = duration
	effect.apply(context)

## Analog film grain overlay (cinematic grit, horror atmosphere).
func film_grain(context: Node, grain_strength: float = 0.12, grain_speed: float = 30.0,
		duration: float = 1.0) -> void:
	var effect := JuiceeFilmGrainEffect.new()
	effect.strength = grain_strength
	effect.speed = grain_speed
	effect.duration = duration
	effect.apply(context)

## Radial motion blur from a screen point (speed lines, warp drives, dash impacts).
func radial_blur(context: Node, blur_strength: float = 0.015, duration: float = 0.4,
		center: Vector2 = Vector2(0.5, 0.5)) -> void:
	var effect := JuiceeRadialBlurEffect.new()
	effect.strength = blur_strength
	effect.duration = duration
	effect.center_uv = center
	effect.apply(context)

## Barrel or pincushion lens distortion (fisheye, scope zoom, warp portals).
## strength > 0 = barrel (outward), strength < 0 = pincushion (inward).
func lens_distortion(context: Node, strength: float = 0.25, duration: float = 0.5,
		fade_out: bool = true) -> void:
	var effect := JuiceeLensDistortionEffect.new()
	effect.strength = strength
	effect.duration = duration
	effect.fade_out = fade_out
	effect.apply(context)

## Camera3D depth-of-field blur (sharp focus pull, cinematic transitions).
func depth_of_field(context: Node, far_distance: float = 10.0, duration: float = 1.0,
		blur_far: bool = true, fade_out: bool = true,
		camera_path: NodePath = NodePath()) -> void:
	var effect := JuiceeDepthOfFieldEffect.new()
	effect.far_distance = far_distance
	effect.duration = duration
	effect.blur_far = blur_far
	effect.fade_out = fade_out
	if not camera_path.is_empty():
		effect.camera_path = camera_path
	effect.apply(context)

## Directional kick shake (gun fire, punches, directional hits).
func directional_shake(context: Node, direction: Vector2 = Vector2(0, -1),
		kick_distance: float = 12.0, duration: float = 0.35) -> void:
	var effect := JuiceeDirectionalShakeEffect.new()
	effect.direction = direction
	effect.kick_distance = kick_distance
	effect.duration = duration
	effect.apply(context)

## Rhythmic sine-wave camera bob (walk cycle, breathing idle).
func camera_bob(context: Node, amplitude: Vector2 = Vector2(0.0, 3.0),
		frequency: float = 2.0, duration: float = 2.0) -> void:
	var effect := JuiceeCameraBobEffect.new()
	effect.amplitude = amplitude
	effect.frequency = frequency
	effect.duration = duration
	effect.apply(context)

## BPM-synced Camera2D zoom pulse (beat-drops, music-reactive moments).
func zoom_pulse(context: Node, bpm: float = 120.0, zoom_boost: float = 0.08,
		duration: float = 4.0) -> void:
	var effect := JuiceeZoomPulseEffect.new()
	effect.bpm = bpm
	effect.pulse_amount = zoom_boost
	effect.duration = duration
	effect.apply(context)

# ─── Audio / Hardware ───────────────────────────────────────────────────────

## Play a random AudioStream with pitch variance.
func play_sound(context: Node, streams: Array[AudioStream], pitch_min: float = 0.9, pitch_max: float = 1.1) -> void:
	var effect := JuiceeSoundEffect.new()
	effect.streams = streams
	effect.pitch_min = pitch_min
	effect.pitch_max = pitch_max
	effect.apply(context)

## Gamepad vibration.
func rumble(context: Node, weak: float = 0.5, strong: float = 0.5, duration: float = 0.2, device: int = 0) -> void:
	var effect := JuiceeRumbleEffect.new()
	effect.weak_magnitude = weak
	effect.strong_magnitude = strong
	effect.duration = duration
	effect.device = device
	effect.apply(context)

## Synthesize and play a retro game sound at runtime — ZERO audio assets needed.
## `seed = 0` gives a fresh random variation each call; any fixed seed reproduces
## the exact same sound. Categories: PICKUP_COIN, LASER_SHOOT, EXPLOSION, POWERUP,
## HIT_HURT, JUMP, BLIP_SELECT, RANDOM.
## [codeblock]
## Juicee.sfx(self, JuiceeSfxr.Category.PICKUP_COIN)
## [/codeblock]
## @experimental: Procedural SFX is an experimental prototyping aid; the API may change.
func sfx(context: Node, category: JuiceeSfxr.Category, sound_seed: int = 0,
		volume_db: float = 0.0, pitch_min: float = 1.0, pitch_max: float = 1.0,
		bus: StringName = &"Master") -> void:
	var effect := JuiceeProcSoundEffect.new()
	effect.category = category
	effect.sound_seed = sound_seed
	effect.volume_db = volume_db
	effect.pitch_min = pitch_min
	effect.pitch_max = pitch_max
	effect.bus = bus
	effect.apply(context)

## Internal: plays a preset's signature sfxr sound, but only when sfx_enabled is on.
func _preset_sfx(context: Node, category: JuiceeSfxr.Category) -> void:
	if sfx_enabled:
		sfx(context, category)

## Spawn a temporary AudioStreamPlayer3D at the context's world position.
func audio_3d(context: Node, streams: Array[AudioStream], volume_db: float = 0.0,
		pitch_min: float = 0.9, pitch_max: float = 1.1, bus: String = "Master",
		max_distance: float = 20.0) -> void:
	var effect := JuiceeAudioSource3DEffect.new()
	effect.streams = streams
	effect.volume_db = volume_db
	effect.pitch_min = pitch_min
	effect.pitch_max = pitch_max
	effect.bus = bus
	effect.max_distance = max_distance
	effect.apply(context)

# ─── Physics ────────────────────────────────────────────────────────────────

## Apply an impulse or constant force to a RigidBody2D or RigidBody3D.
func add_force(target: Node, force: Vector2 = Vector2(0, -300),
		mode: JuiceeAddForceEffect.Mode = JuiceeAddForceEffect.Mode.IMPULSE,
		force_3d: Vector3 = Vector3.ZERO, duration: float = 0.3) -> void:
	var effect := JuiceeAddForceEffect.new()
	effect.force = force
	effect.force_3d = force_3d if force_3d != Vector3.ZERO else Vector3(force.x, -force.y, 0.0) * 0.01
	effect.mode = mode
	effect.duration = duration
	effect.apply(target)

# ─── Text / UI ──────────────────────────────────────────────────────────────

## Floating damage number above a target Node2D. Crit support via the flag.
func damage_number(target: Node2D, damage: int, is_crit: bool = false) -> void:
	var effect := JuiceeDamageNumberEffect.new()
	effect.apply(target, {"damage": damage, "is_crit": is_crit})

## Generic floating text above a target Node2D (Level Up!, pickup names, status).
func floating_text(target: Node2D, text: String, text_color: Color = Color.WHITE) -> void:
	var effect := JuiceeFloatingTextEffect.new()
	effect.apply(target, {"text": text, "color": text_color})

## Scale-punch a UI Control (Button click feedback, menu item highlight).
func button_punch(target: Control, scale_factor: float = 1.15, duration: float = 0.25) -> void:
	var effect := JuiceeButtonPunchEffect.new()
	effect.scale_factor = scale_factor
	effect.duration = duration
	effect.apply(target)

## Reveal a Label's text char-by-char (dialog, intros, terminal vibes).
func typewriter(target: Label, text: String, chars_per_second: float = 30.0) -> void:
	var effect := JuiceeTypewriterEffect.new()
	effect.chars_per_second = chars_per_second
	effect.apply(target, {"text": text})

## Tween a Label's number from a value to another (score rollups, money displays).
func count_to(target: Label, from_val: float, to_val: float, duration: float = 1.0,
		number_format: String = "%d", prefix: String = "", suffix: String = "") -> void:
	var effect := JuiceeNumberCountEffect.new()
	effect.duration = duration
	effect.number_format = number_format
	effect.prefix = prefix
	effect.suffix = suffix
	effect.apply(target, {"from": from_val, "to": to_val})

## Sine-wave wobble on a Control with decay (drama text: GAME OVER, BOSS APPROACHING).
func text_wobble(target: Control, amplitude: float = 4.0, duration: float = 0.5) -> void:
	var effect := JuiceeTextWobbleEffect.new()
	effect.amplitude = amplitude
	effect.duration = duration
	effect.apply(target)

# ─── WorldEnvironment ──────────────────────────────────────────────────────

## Pulse the active WorldEnvironment glow (bloom). Native Godot post-process.
func bloom(context: Node, intensity_boost: float = 1.5, duration: float = 0.6) -> void:
	var effect := JuiceeBloomEffect.new()
	effect.intensity_boost = intensity_boost
	effect.duration = duration
	effect.apply(context)

## Punch the active WorldEnvironment tonemap exposure (flashbang effect).
func tonemap_punch(context: Node, exposure_boost: float = 3.0, duration: float = 0.4) -> void:
	var effect := JuiceeTonemapEffect.new()
	effect.exposure_boost = exposure_boost
	effect.duration = duration
	effect.apply(context)

# ─── Spring physics ────────────────────────────────────────────────────────

## Spring-bounce a Vector2 property on the target node (universal animator).
## Use for buttons, menus, sprites, anything bouncy.
## Example: Juicee.spring(my_button, "scale", Vector2(0.4, 0.4))
func spring(target: Node, property_name: String, kick: Vector2,
		stiffness: float = 200.0, damping: float = 10.0) -> void:
	var effect := JuiceeSpringEffect.new()
	effect.target_path = NodePath(".")  # apply uses context = target directly
	effect.property = property_name
	effect.impulse = kick
	effect.stiffness = stiffness
	effect.damping = damping
	effect.apply(target)

# ─── Audio bus FX ──────────────────────────────────────────────────────────

## Temporarily add reverb to an audio bus with wet ramp in/out.
func reverb(context: Node, bus: String = "Master", peak_wet: float = 0.45, duration: float = 1.5) -> void:
	var effect := JuiceeReverbEffect.new()
	effect.bus_name = bus
	effect.peak_wet = peak_wet
	effect.duration = duration
	effect.apply(context)

## Temporarily pitch-shift an audio bus (slow-mo audio, underwater feel).
func pitch_shift(context: Node, target_pitch: float = 0.7, bus: String = "Master",
		duration: float = 1.0) -> void:
	var effect := JuiceePitchShiftEffect.new()
	effect.bus_name = bus
	effect.target_pitch = target_pitch
	effect.duration = duration
	effect.apply(context)

# ─── Built-in presets ──────────────────────────────────────────────────────
# Drop-in game-feel sequences. Each is a one-line call from your game code.
# These build the sequence INLINE — no .tres file needed, no resource lookup.

## Light hit reaction: brief shake + flash. Use for non-crit melee/projectile hits.
func preset_hit(context: Node, hit_color: Color = Color.WHITE) -> void:
	_preset_sfx(context, JuiceeSfxr.Category.HIT_HURT)
	var seq := JuiceeSequence.new()
	seq.parallel = true
	var shake := JuiceeShakeEffect.new()
	shake.intensity = 6.0
	shake.duration = 0.18
	shake.frequency = 18.0
	seq.effects.append(shake)
	if context is CanvasItem:
		var flash := JuiceeFlashEffect.new()
		flash.flash_color = hit_color
		flash.duration = 0.1
		flash.flash_count = 1
		seq.effects.append(flash)
	seq.play(context)

## Critical hit reaction: hit_stop + bigger shake + chromatic + bright flash.
func preset_hit_crit(context: Node) -> void:
	_preset_sfx(context, JuiceeSfxr.Category.HIT_HURT)
	var seq := JuiceeSequence.new()
	seq.parallel = true
	var hs := JuiceeHitStopEffect.new()
	hs.freeze_duration = 0.06
	hs.time_scale_during = 0.05
	seq.effects.append(hs)
	var shake := JuiceeShakeEffect.new()
	shake.intensity = 14.0
	shake.duration = 0.35
	shake.frequency = 22.0
	seq.effects.append(shake)
	var chrom := JuiceeChromaticEffect.new()
	chrom.intensity = 8.0
	chrom.duration = 0.25
	seq.effects.append(chrom)
	if context is CanvasItem:
		var flash := JuiceeFlashEffect.new()
		flash.flash_color = Color(1.4, 1.2, 0.4, 1.0)
		flash.duration = 0.18
		flash.flash_count = 2
		seq.effects.append(flash)
	seq.play(context)

## Level-up celebration: shake + zoom + bounce + confetti + warm tint.
func preset_level_up(context: Node) -> void:
	_preset_sfx(context, JuiceeSfxr.Category.POWERUP)
	var seq := JuiceeSequence.new()
	seq.parallel = true
	var shake := JuiceeShakeEffect.new()
	shake.intensity = 10.0
	shake.frequency = 16.0
	seq.effects.append(shake)
	var zoom := JuiceeZoomEffect.new()
	zoom.zoom_factor = 1.12
	zoom.duration = 0.5
	seq.effects.append(zoom)
	if context is Node2D:
		var bnc := JuiceeBounceEffect.new()
		bnc.scale_factor = 1.5
		bnc.duration = 0.4
		seq.effects.append(bnc)
		var conf := JuiceeConfettiEffect.new()
		conf.amount = 60
		conf.speed = 220.0
		conf.spread = 360.0
		seq.effects.append(conf)
	var tint := JuiceeScreenTintEffect.new()
	tint.tint_color = Color(1.0, 0.85, 0.3, 0.35)
	tint.duration = 0.7
	seq.effects.append(tint)
	seq.play(context)

## Player damage taken: hit_stop + big shake + red tint + red vignette + rumble.
func preset_damage_taken(context: Node) -> void:
	_preset_sfx(context, JuiceeSfxr.Category.HIT_HURT)
	var seq := JuiceeSequence.new()
	seq.parallel = true
	var hs := JuiceeHitStopEffect.new()
	seq.effects.append(hs)
	var shake := JuiceeShakeEffect.new()
	shake.intensity = 18.0
	shake.duration = 0.4
	shake.frequency = 22.0
	shake.decay = 0.6
	seq.effects.append(shake)
	var tint := JuiceeScreenTintEffect.new()
	tint.tint_color = Color(1.0, 0.2, 0.2, 0.4)
	tint.duration = 0.5
	seq.effects.append(tint)
	var vig := JuiceeVignetteEffect.new()
	vig.intensity = 0.65
	vig.vignette_color = Color(0.6, 0.0, 0.0, 1.0)
	vig.duration = 0.6
	seq.effects.append(vig)
	var rumble := JuiceeRumbleEffect.new()
	rumble.strong_magnitude = 0.7
	rumble.duration = 0.25
	seq.effects.append(rumble)
	seq.play(context)

## Player death: slow-mo + persistent blur + pixelate + grayscale + glitch.
## Effects with fade_out=false stay on screen until you trigger a respawn.
func preset_death(context: Node) -> void:
	_preset_sfx(context, JuiceeSfxr.Category.EXPLOSION)
	var seq := JuiceeSequence.new()
	seq.parallel = true
	var slowmo := JuiceeTimeScaleRampEffect.new()
	slowmo.target_scale = 0.15
	slowmo.hold = 1.0
	slowmo.ramp_out = 0.5
	seq.effects.append(slowmo)
	var blur := JuiceeBlurEffect.new()
	blur.duration = 1.5
	blur.fade_out = false
	seq.effects.append(blur)
	var pix := JuiceePixelateEffect.new()
	pix.pixel_size = 10.0
	pix.duration = 1.2
	pix.fade_out = false
	seq.effects.append(pix)
	var grade := JuiceeColorGradeEffect.new()
	grade.saturation = 0.0
	grade.contrast = 1.3
	grade.tint = Color(0.7, 0.7, 0.9, 1.0)
	grade.duration = 1.5
	grade.fade_out = false
	seq.effects.append(grade)
	var glitch := JuiceeGlitchEffect.new()
	glitch.intensity = 0.6
	glitch.duration = 0.5
	seq.effects.append(glitch)
	seq.play(context)

## Explosion impact: hit_stop + burst + shake + chromatic.
func preset_explosion(context: Node, burst_color: Color = Color(1.0, 0.6, 0.2, 1.0)) -> void:
	_preset_sfx(context, JuiceeSfxr.Category.EXPLOSION)
	var seq := JuiceeSequence.new()
	seq.parallel = true
	var hs := JuiceeHitStopEffect.new()
	seq.effects.append(hs)
	if context is Node2D:
		var b := JuiceeBurstEffect.new()
		b.amount = 30
		b.speed = 250.0
		b.spread = 360.0
		b.lifetime = 0.7
		b.color = burst_color
		seq.effects.append(b)
	var shake := JuiceeShakeEffect.new()
	shake.intensity = 16.0
	shake.duration = 0.4
	shake.frequency = 20.0
	seq.effects.append(shake)
	var chrom := JuiceeChromaticEffect.new()
	chrom.intensity = 6.0
	chrom.duration = 0.3
	seq.effects.append(chrom)
	seq.play(context)

# ─── Composition ────────────────────────────────────────────────────────────

## Trigger an AnimationPlayer animation as a sequence step.
## Set wait_for_finish = true to stall the caller until the animation ends.
func animation_player(context: Node, player_path: NodePath, animation_name: String,
		speed: float = 1.0, wait_for_finish: bool = true) -> void:
	var effect := JuiceeAnimationPlayerEffect.new()
	effect.player_path = player_path
	effect.animation_name = animation_name
	effect.speed = speed
	effect.wait_for_finish = wait_for_finish
	effect.apply(context)

## Show/hide a node for `duration` seconds then restore it.
func set_active(context: Node, target_path: NodePath, duration: float = 0.5,
		action: JuiceeSetActiveEffect.Action = JuiceeSetActiveEffect.Action.SHOW) -> void:
	var effect := JuiceeSetActiveEffect.new()
	effect.target_path = target_path
	effect.duration = duration
	effect.action = action
	effect.apply(context)

## Repeating modulate flash for sustained danger states (siren, low-health pulse).
func ambient_flash(target: CanvasItem, flash_color: Color = Color(1.0, 0.2, 0.2, 0.5),
		duration: float = 3.0, frequency: float = 1.5) -> void:
	var effect := JuiceeAmbientFlashEffect.new()
	effect.flash_color = flash_color
	effect.duration = duration
	effect.frequency = frequency
	effect.apply(target)

## Square-wave strobe a Light2D (lightning, flashbang, emergency siren).
func strobe_light(target: Light2D, pulse_count: int = 6, duration: float = 0.5,
		peak_energy: float = 3.0) -> void:
	var effect := JuiceeStrobeLightEffect.new()
	effect.pulse_count = pulse_count
	effect.duration = duration
	effect.peak_energy = peak_energy
	effect.apply(target)

## Directional position kick (gun recoil, absorbing a hit). Direction gets normalized.
func recoil(target: Node2D, direction: Vector2 = Vector2(-1, 0),
		kick_distance: float = 12.0, return_duration: float = 0.18) -> void:
	var effect := JuiceeRecoilEffect.new()
	effect.direction = direction
	effect.kick_distance = kick_distance
	effect.return_duration = return_duration
	effect.apply(target)

## Animate a colored outline on a CanvasItem (selection ring, status glow).
func outline(target: CanvasItem, outline_color: Color = Color(1.0, 0.85, 0.20, 1.0),
		outline_width: float = 2.0, duration: float = 0.8) -> void:
	var effect := JuiceeOutlineEffect.new()
	effect.outline_color = outline_color
	effect.outline_width = outline_width
	effect.duration = duration
	effect.apply(target)

## Cycle a CanvasItem's modulate through the hue wheel (powerup rainbow, party mode).
func color_cycle(target: CanvasItem, cycles: float = 2.0, duration: float = 1.5,
		saturation: float = 1.0) -> void:
	var effect := JuiceeColorCycleEffect.new()
	effect.cycles = cycles
	effect.duration = duration
	effect.saturation = saturation
	effect.apply(target)

## Run an array of effects in sequence (or parallel). Convenience wrapper for JuiceeChainEffect.
func chain(context: Node, chain_effects: Array[JuiceeEffect], parallel: bool = false,
		step_delay: float = 0.0) -> void:
	var effect := JuiceeChainEffect.new()
	effect.effects = chain_effects
	effect.parallel = parallel
	effect.step_delay = step_delay
	effect.apply(context)

# ─── ULTIMATE Presets ───────────────────────────────────────────────────────

## Multi-hit combo finisher: 3× rapid hit_stops + escalating shakes + burst + chromatic.
func preset_combo(context: Node) -> void:
	_preset_sfx(context, JuiceeSfxr.Category.HIT_HURT)
	var seq := JuiceeSequence.new()
	seq.parallel = false
	for i in 3:
		var hs := JuiceeHitStopEffect.new()
		hs.freeze_duration = 0.04 + i * 0.02
		hs.time_scale_during = 0.05
		seq.effects.append(hs)
		var shake := JuiceeShakeEffect.new()
		shake.intensity = 6.0 + i * 4.0
		shake.duration = 0.1
		shake.frequency = 20.0
		seq.effects.append(shake)
	var chrom := JuiceeChromaticEffect.new()
	chrom.intensity = 7.0
	chrom.duration = 0.25
	seq.effects.append(chrom)
	if context is Node2D:
		var b := JuiceeBurstEffect.new()
		b.amount = 20
		b.color = Color(1.0, 0.7, 0.2)
		seq.effects.append(b)
	seq.play(context)

## Quick-dodge dash: chromatic + motion-blur afterimage + zoom punch.
func preset_dash(context: Node, direction: Vector2 = Vector2.RIGHT) -> void:
	_preset_sfx(context, JuiceeSfxr.Category.LASER_SHOOT)
	var seq := JuiceeSequence.new()
	seq.parallel = true
	var chrom := JuiceeChromaticEffect.new()
	chrom.intensity = 6.0
	chrom.duration = 0.18
	seq.effects.append(chrom)
	var blur := JuiceeBlurEffect.new()
	blur.intensity = 3.0
	blur.duration = 0.22
	seq.effects.append(blur)
	var zoom := JuiceeZoomEffect.new()
	zoom.zoom_factor = 1.06
	zoom.duration = 0.22
	seq.effects.append(zoom)
	if context is Node2D:
		var pos := JuiceePositionEffect.new()
		pos.offset = direction.normalized() * 14.0
		pos.duration = 0.18
		seq.effects.append(pos)
	seq.play(context)

## Item / coin pickup: scale bounce + flash + burst confetti + float text.
func preset_pickup(target: Node2D, label_text: String = "+1") -> void:
	_preset_sfx(target, JuiceeSfxr.Category.PICKUP_COIN)
	var seq := JuiceeSequence.new()
	seq.parallel = true
	var bnc := JuiceeBounceEffect.new()
	bnc.scale_factor = 1.35
	bnc.duration = 0.28
	seq.effects.append(bnc)
	if target is CanvasItem:
		var flash := JuiceeFlashEffect.new()
		flash.flash_color = Color(1.0, 1.0, 0.6, 1.0)
		flash.duration = 0.12
		seq.effects.append(flash)
	var conf := JuiceeConfettiEffect.new()
	conf.amount = 18
	conf.speed = 140.0
	conf.spread = 140.0
	seq.effects.append(conf)
	seq.play(target)
	floating_text(target, label_text, Color(1.0, 0.95, 0.4))

## Boss entrance: camera-lock zoom + vignette + heavy shake + rumble + ominous tint.
func preset_boss_intro(context: Node) -> void:
	_preset_sfx(context, JuiceeSfxr.Category.POWERUP)
	var seq := JuiceeSequence.new()
	seq.parallel = true
	var zoom := JuiceeZoomEffect.new()
	zoom.zoom_factor = 1.25
	zoom.duration = 0.8
	seq.effects.append(zoom)
	var vig := JuiceeVignetteEffect.new()
	vig.intensity = 0.75
	vig.vignette_color = Color(0.6, 0.0, 0.0, 1.0)
	vig.duration = 1.5
	vig.fade_out = false
	seq.effects.append(vig)
	var shake := JuiceeShakeEffect.new()
	shake.intensity = 8.0
	shake.duration = 0.6
	shake.frequency = 10.0
	seq.effects.append(shake)
	var tint := JuiceeScreenTintEffect.new()
	tint.tint_color = Color(0.5, 0.0, 0.0, 0.3)
	tint.duration = 1.0
	tint.fade_out = false
	seq.effects.append(tint)
	var rumble := JuiceeRumbleEffect.new()
	rumble.strong_magnitude = 0.6
	rumble.duration = 0.5
	seq.effects.append(rumble)
	seq.play(context)

## Low-health pulse loop: repeating red ambient flash + subtle vignette.
## Stop it manually: effect.stop() — store the returned effect reference.
func preset_low_health_pulse(target: CanvasItem, duration: float = 10.0) -> JuiceeAmbientFlashEffect:
	var effect := JuiceeAmbientFlashEffect.new()
	effect.flash_color = Color(1.0, 0.15, 0.15, 0.55)
	effect.duration = duration
	effect.frequency = 1.2
	effect.apply(target)
	return effect

## Victory: confetti + zoom + color cycle + warm screen tint + fanfare rumble.
func preset_victory(context: Node) -> void:
	_preset_sfx(context, JuiceeSfxr.Category.POWERUP)
	var seq := JuiceeSequence.new()
	seq.parallel = true
	var conf := JuiceeConfettiEffect.new()
	conf.amount = 80
	conf.speed = 300.0
	conf.spread = 360.0
	seq.effects.append(conf)
	var zoom := JuiceeZoomEffect.new()
	zoom.zoom_factor = 1.15
	zoom.duration = 0.6
	seq.effects.append(zoom)
	var tint := JuiceeScreenTintEffect.new()
	tint.tint_color = Color(1.0, 0.9, 0.4, 0.3)
	tint.duration = 1.2
	seq.effects.append(tint)
	var rumble := JuiceeRumbleEffect.new()
	rumble.weak_magnitude = 0.3
	rumble.strong_magnitude = 0.3
	rumble.duration = 0.8
	seq.effects.append(rumble)
	seq.play(context)
	if context is CanvasItem:
		color_cycle(context, 3.0, 2.0, 0.9)

# ─── Composition ────────────────────────────────────────────────────────────

## Play a pre-built JuiceeSequence resource. Optional `params` dict is forwarded
## to all effects for runtime customization (e.g., {"hit_direction": Vector2.LEFT}).
func play_sequence(sequence: JuiceeSequence, context: Node, params: Dictionary = {}) -> void:
	if not sequence:
		return
	sequence.play(context, params)

# ─── Flow / Sequencing ─────────────────────────────────────────────────────

## Pause sequence until the player presses `action` (or `timeout` seconds elapses).
## timeout = 0 waits indefinitely.
func wait_for_input(context: Node, action: String = "ui_accept",
		timeout: float = 0.0) -> void:
	var effect := JuiceeWaitForInputEffect.new()
	effect.action = action
	effect.timeout = timeout
	effect.apply(context)

## Fire a child effect synchronized to a BPM beat for `duration` seconds.
## If clock_path points to a JuiceeBeatClock in the scene, it uses that for tight sync.
func beat_sync(context: Node, child_effect: JuiceeEffect, bpm: float = 120.0,
		duration: float = 8.0, beats_per_trigger: int = 1,
		clock_path: NodePath = NodePath()) -> void:
	var effect := JuiceeBeatSyncEffect.new()
	effect.effect = child_effect
	effect.bpm = bpm
	effect.duration = duration
	effect.beats_per_trigger = beats_per_trigger
	effect.clock_path = clock_path
	effect.apply(context)

## Emit a signal by name on the context node (bridge between sequences and game signals).
func emit_signal_on(context: Node, signal_name: String, argument: Variant = null) -> void:
	var effect := JuiceeEmitSignalEffect.new()
	effect.signal_name = signal_name
	effect.argument = argument
	effect.apply(context)

## Print/warn/error a message from a sequence step (debug helper).
func debug_log(context: Node, message: String,
		level: JuiceeDebugLogEffect.Level = JuiceeDebugLogEffect.Level.PRINT) -> void:
	var effect := JuiceeDebugLogEffect.new()
	effect.message = message
	effect.level = level
	effect.apply(context)

## Travel to an AnimationTree state or set a parameter.
func animation_tree_travel(context: Node, state_or_param: String,
		mode: JuiceeAnimationTreeEffect.Mode = JuiceeAnimationTreeEffect.Mode.TRAVEL,
		value: Variant = true, tree_path: NodePath = NodePath()) -> void:
	var effect := JuiceeAnimationTreeEffect.new()
	effect.parameter = state_or_param
	effect.mode = mode
	effect.value = value
	if not tree_path.is_empty():
		effect.tree_path = tree_path
	effect.apply(context)

## Instantly set any property, optionally restore after restore_delay seconds.
## restore_delay = -1 (never restore), 0 (restore immediately), >0 (restore after delay).
func set_property(context: Node, property_name: String, value: Variant,
		restore_delay: float = -1.0, target_path: NodePath = NodePath()) -> void:
	var effect := JuiceeSetPropertyEffect.new()
	effect.property_name = property_name
	effect.value = value
	effect.restore_delay = restore_delay
	if not target_path.is_empty():
		effect.target_path = target_path
	effect.apply(context)
