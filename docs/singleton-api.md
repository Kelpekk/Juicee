# Singleton API

[Juicee](../README.md) / [Docs](../README.md#docs)

The `Juicee` autoload singleton is available from any script without setup.

Sections: [Accessibility](#accessibility), [Startup](#startup), [Camera](#camera), [Time](#time), [Object feedback](#object-feedback), [Particles](#particles), [Screen FX](#screen-fx), [WorldEnvironment](#worldenvironment), [Audio / Hardware](#audio--hardware), [Physics](#physics), [Text / UI](#text--ui), [Flow / Sequencing](#flow--sequencing), [Built-in presets](#built-in-presets).

```gdscript
extends Node   # or any script
func _input(event):
    if event.is_action_pressed("shoot"):
        Juicee.shake_camera(self, 12.0, 0.3)
        Juicee.flash(my_sprite, Color.RED)
```

Every method creates a temporary effect resource, calls `apply()`, and hands the effect back, so you can fire and forget or keep the handle:

```gdscript
var shake = Juicee.shake_camera(self, 12.0, 2.0)
shake.stop()                  # cut it short
if shake.is_playing(): pass  # or just ask
```

The handle is for controlling an effect that is already running. `apply()` has been called by the time you get it, so setting properties on it afterwards will not change the run in progress. To reach parameters a one-liner does not take, including the advanced ones (see [advanced-properties.md](advanced-properties.md)), build the effect yourself:

```gdscript
var shake := JuiceeShakeEffect.new()
shake.preset = JuiceeShakeEffect.Preset.HANDHELD
shake.apply(self)
```

For sequences that stack and replay, use `JuiceePlayer` + `JuiceeSequence` instead.

---

## Accessibility

```gdscript
var accessibility: JuiceeAccessibility
```

Global accessibility object. Set flags from your settings screen - all effects read this automatically.

```gdscript
Juicee.accessibility.reduced_motion = true    # plays effects at a quarter of their strength
Juicee.accessibility.no_flash       = true    # silences flashing effects, Screen Tint included
Juicee.accessibility.no_screenshake = true    # silences camera shake
Juicee.accessibility.no_chromatic   = true    # silences Chromatic/Glitch
Juicee.accessibility.no_haptics     = true    # silences gamepad rumble
Juicee.accessibility.intensity_scale = 0.5   # master multiplier (0-1)

# Save/load:
save_data["a11y"] = Juicee.accessibility.to_dict()
Juicee.accessibility.from_dict(save_data["a11y"])
```

```gdscript
func set_quality(level: JuiceeAccessibility.Quality) -> void
```

How much the particle-heavy effects spawn. `LOW` gives Burst, Confetti, Hit Spark and Sparkle four
pieces in ten, `MEDIUM` seven, `HIGH` all of them; every other effect plays the same either way,
and the same plays still happen. Saved and loaded with the rest of the accessibility state.

```gdscript
Juicee.set_quality(JuiceeAccessibility.Quality.LOW)   # phones, or a player who asked for it
```

There is a ready-made settings panel for all of the above: instance
`addons/juicee/ui/accessibility_settings.tscn` in your options menu and it builds the toggles, the
intensity slider and the quality dropdown, wired live.

---

## Startup

```gdscript
func warmup() -> void
```
Compiles every full-screen shader ahead of time, so the first effect to use one does
not stall the frame it fires on. Godot compiles a shader the first time its material is
drawn rather than when it is loaded, so without this the cost lands mid-game, on the
frame of the first big hit, which is the worst moment available. Measured on a GL
Compatibility build: firing eleven shader effects cold costs 114 ms and 4 ms once they
are compiled.

Call it from a loading screen or a splash and await it:

```gdscript
await Juicee.warmup()
```

Safe to call more than once - only the first does the work. Does nothing when there is
no rendering device, so headless tools and dedicated servers skip it.

```gdscript
func is_warmed_up() -> bool
```
Whether `warmup()` has been called. It is true from the moment the call starts, while the shaders are still compiling; await `warmup()` itself to wait for them.

---

## Camera


```gdscript
func fov_punch(
    context: Node,
    fov_delta: float = 10.0,
    duration: float = 0.4
) -> JuiceeFOV3DEffect
```
Punch the current Camera3D's field of view and let it come back: a sprint, a dash, an impact.
Widening reads as speed, narrowing as focus.

```gdscript
func shake_camera(
    context: Node,
    intensity: float = 8.0,
    duration: float = 0.3,
    frequency: float = 15.0
) -> JuiceeShakeEffect
```
Shake the active Camera2D via Perlin noise. `context` provides the viewport - any node in the scene works. Pass `{"hit_direction": Vector2}` via `JuiceePlayer.play()` for directional bias.

```gdscript
func shake_camera_3d(
    context: Node,
    intensity: float = 0.1,
    duration: float = 0.3
) -> JuiceeShake3DEffect
```
Camera3D shake. It mostly turns the camera rather than sliding it, which reads as the hit instead of the world moving.

```gdscript
func zoom_camera(
    context: Node,
    zoom_factor: float = 1.2,
    duration: float = 0.4
) -> JuiceeZoomEffect
```
Camera2D zoom punch. `zoom_factor > 1` = zoom in, `< 1` = zoom out.

```gdscript
func camera_follow(
    target: Node2D,
    duration: float = 1.5,
    follow_speed: float = 5.0
) -> JuiceeCameraFollowEffect
```
Smoothly lerp Camera2D toward `target` for `duration` seconds, then return.

```gdscript
func directional_shake(
    context: Node,
    direction: Vector2 = Vector2(0,-1),
    kick_distance: float = 12.0,
    duration: float = 0.35
) -> JuiceeDirectionalShakeEffect
```
Directional kick shake. The camera is kicked away from `direction` (hit from the right, it moves left) and eases back, with a little sideways shake on top.

```gdscript
func camera_bob(
    context: Node,
    amplitude: Vector2 = Vector2(0.0, 3.0),
    frequency: float = 2.0,
    duration: float = 2.0
) -> JuiceeCameraBobEffect
```
Rhythmic sine-wave bob on Camera2D offset. Walk cycle, breathing idle.

```gdscript
func zoom_pulse(
    context: Node,
    bpm: float = 120.0,
    zoom_boost: float = 0.08,
    duration: float = 4.0
) -> JuiceeZoomPulseEffect
```
BPM-synced Camera2D zoom pulse. Each beat pulses 8% zoom in then decays.

```gdscript
func camera_rotation(
    context: Node,
    angle_degrees: float = 5.0,
    tilt_duration: float = 0.3,
    hold_duration: float = 0.0,
    return_duration: float = 0.4
) -> JuiceeCameraRotationEffect
```
Dutch tilt - rotate Camera2D by angle_degrees then spring back.

```gdscript
func depth_of_field(
    context: Node,
    far_distance: float = 10.0,
    duration: float = 1.0,
    blur_far: bool = true,
    fade_out: bool = true,
    camera_path: NodePath = NodePath()
) -> JuiceeDepthOfFieldEffect
```
Camera3D depth-of-field blur (sharp focus pull, cinematic transitions).


---

## Time

```gdscript
func hit_stop(
    context: Node,
    freeze_duration: float = 0.08,
    time_scale_during: float = 0.0
) -> JuiceeHitStopEffect
```
Instant time freeze. `0.05-0.1s` is the sweet spot for melee combat.

```gdscript
func slow_mo(
    context: Node,
    target_scale: float = 0.2,
    hold: float = 0.4
) -> JuiceeTimeScaleRampEffect
```
Smooth slow-motion ramp. Uses default ramp_in=0.15, ramp_out=0.3.

```gdscript
func freeze_frame(
    context: Node,
    freeze_duration: float = 0.1,
    white_flash: bool = true
) -> JuiceeFreezeFrameEffect
```
Full `Engine.time_scale = 0.0` freeze with optional white flash. Heavier than `hit_stop` - use for finishing blows and super moves.

```gdscript
func wait(
    context: Node,
    duration: float = 0.5
) -> JuiceeDelayEffect
```
Simple pause for `duration` seconds - stalls a sequence without any visual change. Use in sequences between steps: `Juicee.wait(self, 0.5)`.


---

## Object feedback

```gdscript
func afterimage(
    target: Node2D,
    duration: float = 0.3,
    ghost_lifetime: float = 0.35,
    color: Color = Color(0.6, 0.9, 1.0, 0.6)
) -> JuiceeAfterimageEffect
```
Fading copies left behind as the node moves: dashes, dodges, fast attacks. The ghosts copy the
sprite frame by frame, so an AnimatedSprite2D leaves the frame it was on.

```gdscript
func breathe(
    target: Node2D,
    amount: float = 0.05,
    period: float = 2.0,
    cycles: int = 3
) -> JuiceeBreatheEffect
```
Slow idle swell, for a character standing still. `period` is one breath in and out.

```gdscript
func heartbeat(
    target: Node2D,
    amount: float = 0.18,
    bpm: float = 70.0,
    duration: float = 2.0
) -> JuiceeHeartbeatEffect
```
Two-beat pulse at a heart rate: low health, tension, a charging attack.

```gdscript
func glow_pulse(
    target: CanvasItem,
    peak: float = 1.8,
    duration: float = 0.5,
    count: int = 1,
    tint: Color = Color.WHITE
) -> JuiceeGlowPulseEffect
```
Pulse a CanvasItem brighter and back, without a Light2D. A node already drawing at full white
needs glow on the WorldEnvironment to read as brighter; a `tint` pulses either way.

```gdscript
func wobble_rotation(
    target: Node2D,
    amount_degrees: float = 18.0,
    frequency: float = 5.0,
    duration: float = 0.6
) -> JuiceeWobbleRotationEffect
```
Rotation wobble that decays, like a sign left swinging.

```gdscript
func flash(
    target: CanvasItem,
    flash_color: Color = Color.WHITE,
    duration: float = 0.15,
    count: int = 1
) -> JuiceeFlashEffect
```
Blink modulate N times. Target is the sprite or control to flash.

```gdscript
func bounce(
    target: Node2D,
    scale_factor: float = 1.3,
    duration: float = 0.3
) -> JuiceeBounceEffect
```
Uniform scale punch that springs back.

```gdscript
func punch_position(
    target: Node2D,
    offset: Vector2,
    duration: float = 0.3,
    return_to_original: bool = true,
    relative: bool = true
) -> JuiceePositionEffect
```
Displace and return. With `relative = false`, `offset` is the exact position to land on rather than a nudge from where the node already is.

```gdscript
func punch_rotation(
    target: Node2D,
    angle_degrees: float = 15.0,
    duration: float = 0.3,
    return_to_original: bool = true,
    relative: bool = true
) -> JuiceeRotationEffect
```
Rotation punch and return. With `relative = false`, `angle_degrees` is the exact angle to turn to.

```gdscript
func scale_to_3d(
    target: Node,
    target_scale: Vector3 = Vector3(1.5, 1.5, 1.5),
    duration: float = 0.3,
    return_to_original: bool = true,
    return_duration: float = 0.2,
    relative: bool = true
) -> JuiceeScale3DEffect
```
Scale punch on a Node3D that can ease back to the original scale. The 3D counterpart of `scale_to`.

```gdscript
func jiggle(
    target: Node2D,
    impulse: Vector2 = Vector2(0.4, -0.4),
    stiffness: float = 8.0
) -> JuiceeJigglePhysicsEffect
```
Spring-mass jelly jiggle on scale.

```gdscript
func modulate_to(
    target: CanvasItem,
    color: Color,
    duration: float = 0.4
) -> JuiceeModulateEffect
```
Smooth color shift (unlike flash which blinks).

```gdscript
func light_flash(
    target: Light2D,
    peak_energy: float = 3.0,
    color: Color = Color.WHITE,
    duration: float = 0.3
) -> JuiceeLightFlashEffect
```
Flash a Light2D's energy and color.

```gdscript
func spring(
    target: Node,
    property_name: String,
    kick: Vector2,
    stiffness: float = 200.0,
    damping: float = 10.0
) -> JuiceeSpringEffect
```
Harmonic spring on any Vector2 property. Example: `Juicee.spring(my_button, "scale", Vector2(0.4, 0.4))`.

```gdscript
func spin(
    target: Node2D,
    speed_deg_per_sec: float = 360.0,
    duration: float = 0.6,
    restore: bool = false
) -> JuiceeSpinEffect
```
Spins at `speed_deg_per_sec` for `duration`, so the defaults turn 216 degrees, not a full turn. `restore=true` turns it back to its original rotation at the end.

```gdscript
func wiggle(
    target: Node2D,
    amplitude: float = 4.0,
    frequency: float = 12.0,
    duration: float = 0.5
) -> JuiceeWiggleEffect
```
Random position jitter at Hz frequency.

```gdscript
func sprite_bob(
    target: Node2D,
    amplitude_px: float = 6.0,
    bob_freq: float = 1.5,
    duration: float = 3.0,
    axis: Vector2 = Vector2(0, 1)
) -> JuiceeSpriteBobEffect
```
Sine-wave bob. Default axis = vertical.

```gdscript
func pop_in(
    target: Node,
    from_scale: float = 0.0
) -> JuiceePopInEffect
```
SPRING overshoot scale-in. Works on Node2D and Control.

```gdscript
func shake_control(
    target: Control,
    amplitude: float = 8.0,
    duration: float = 0.4,
    frequency: float = 18.0
) -> JuiceeShakeControlEffect
```
Horizontal shake for UI elements. Wrong-password, invalid-action feedback.

```gdscript
func pulse(
    target: Node,
    scale_factor: float = 1.15,
    interval: float = 0.5,
    count: int = 0,
    duration: float = 3.0
) -> JuiceePulseEffect
```
Repeating scale pulse. `count=0` + `duration>0` = time-limited.

```gdscript
func recoil(
    target: Node2D,
    direction: Vector2 = Vector2(-1, 0),
    kick_distance: float = 12.0,
    return_duration: float = 0.18
) -> JuiceeRecoilEffect
```
Directional position kick with spring-back. Gun recoil, hit absorption.

```gdscript
func outline(
    target: CanvasItem,
    outline_color: Color = Color(1.0, 0.85, 0.20, 1.0),
    outline_width: float = 2.0,
    duration: float = 0.8
) -> JuiceeOutlineEffect
```
Animated colored outline via shader uniform, around a sprite or a `TextureRect` (a node above one finds it).

```gdscript
func color_cycle(
    target: CanvasItem,
    cycles: float = 2.0,
    duration: float = 1.5,
    saturation: float = 1.0,
    loop: bool = false
) -> JuiceeColorCycleEffect
```
Hue cycle on modulate. Rainbow powerup, party mode. `loop = true` runs until `stop()` (persistent RAINBOW MODE).

```gdscript
func impact_ring(
    target: Node2D,
    color: Color = Color(1.0, 0.85, 0.3),
    spikes: int = 8,
    radius: float = 42.0
) -> JuiceeImpactRingEffect
```
Expanding ring + radiating "POW" spikes drawn on the node (Line2D, no shaders). Crits, parries, explosions.

```gdscript
func sway(
    target: Node,
    angle: float = 6.0,
    period: float = 1.2,
    cycles: float = 0.0
) -> JuiceeSwayEffect
```
Smooth pendulum rotation sway. `cycles = 0` sways forever (until `stop()`). Idle UI, hanging signs, breathing titles.

```gdscript
func ambient_flash(
    target: CanvasItem,
    flash_color: Color = Color(1.0, 0.2, 0.2, 0.5),
    duration: float = 3.0,
    frequency: float = 1.5
) -> JuiceeAmbientFlashEffect
```
Repeating flash for sustained states. Low-health siren, boss enrage.

```gdscript
func strobe_light(
    target: Light2D,
    pulse_count: int = 6,
    duration: float = 0.5,
    peak_energy: float = 3.0
) -> JuiceeStrobeLightEffect
```
Square-wave Light2D strobe.

```gdscript
func hop(
    target: Node2D,
    height: float = 24.0,
    duration: float = 0.4
) -> JuiceeHopEffect
```
Hop: a quick jump arc up and back down (pickups, coins, an idle "notice me").

```gdscript
func squash_land(
    target: Node2D,
    squash_amount: float = 0.4,
    duration: float = 0.35,
    bounce_back: float = 0.5
) -> JuiceeSquashLandEffect
```
Landing squash: flatten on impact, then spring back (platformer landings, jelly hops).

```gdscript
func jelly_wobble(
    target: Node2D,
    amount: float = 0.25,
    frequency: float = 4.0,
    duration: float = 0.6,
    decay: float = 3.0
) -> JuiceeJellyWobbleEffect
```
Jelly wobble: a springy squash-stretch scale oscillation that decays (slimes, gel, bouncy UI).

```gdscript
func stretch(
    target: Node2D,
    direction: Vector2 = Vector2.RIGHT,
    amount: float = 0.5
) -> JuiceeStretchEffect
```
Stretch/smear: stretch along `direction` then snap back (dashes, jumps, thrown objects).

```gdscript
func flip(
    target: Node,
    flip_h_mode: JuiceeFlipEffect.Mode = JuiceeFlipEffect.Mode.TOGGLE,
    flip_v_mode: JuiceeFlipEffect.Mode = JuiceeFlipEffect.Mode.SET_FALSE,
    restore_on_end: bool = false,
    hold_duration: float = 0.0
) -> JuiceeFlipEffect
```
Flip a Sprite2D or AnimatedSprite2D horizontally (toggle by default).

```gdscript
func fade(
    target: CanvasItem,
    target_alpha: float = 0.0,
    duration: float = 0.5,
    restore_on_end: bool = false,
    restore_duration: float = 0.4
) -> JuiceeFadeEffect
```
Fade a CanvasItem's alpha to target_alpha over duration. Use restore_on_end = true for fade-out-then-back-in patterns.

```gdscript
func flicker(
    target: CanvasItem,
    duration: float = 1.5,
    off_color: Color = Color(0, 0, 0, 0),
    off_chance: float = 0.3
) -> JuiceeFlickerEffect
```
Organic random modulate flicker on a CanvasItem (torches, broken lights, ghosts). duration = 0 runs forever until stop() is called.

```gdscript
func scale_to(
    target: Node,
    target_scale: Vector2 = Vector2(1.5, 1.5),
    duration: float = 0.3,
    return_to_original: bool = true,
    return_duration: float = 0.2,
    relative: bool = true
) -> JuiceeScaleEffect
```
General scale tween to `target_scale` with optional spring back.

```gdscript
func punch_position_3d(
    target: Node3D,
    offset: Vector3 = Vector3(0, 0.5, 0),
    duration: float = 0.3,
    return_to_original: bool = true,
    relative: bool = true
) -> JuiceePosition3DEffect
```
3D position punch - move Node3D by offset (in world units) then return.

```gdscript
func punch_rotation_3d(
    target: Node3D,
    angle_degrees: float = 15.0,
    axis: Vector3 = Vector3.UP,
    duration: float = 0.3,
    return_to_original: bool = true,
    relative: bool = true
) -> JuiceeRotation3DEffect
```
3D rotation punch - rotate Node3D around axis by angle_degrees then return.

```gdscript
func light_3d_flash(
    target: Node,
    peak_energy: float = 5.0,
    flash_color: Color = Color.WHITE,
    duration: float = 0.25,
    light_path: NodePath = NodePath()
) -> JuiceeLight3DEffect
```
Flash a Light3D's energy and color (muzzle flash, explosion light, magic pulse).

```gdscript
func material_3d(
    target: Node,
    property_name: String,
    from_value: Variant,
    to_value: Variant,
    duration: float = 0.5,
    restore_on_end: bool = false,
    surface_index: int = 0
) -> JuiceeMaterial3DEffect
```
Animate a MeshInstance3D material property (dissolve, emission, fresnel).

```gdscript
func shader_parameter(
    target: Node,
    param_name: String,
    from_value: Variant,
    to_value: Variant,
    duration: float = 0.5,
    restore_on_end: bool = false,
    surface_index: int = 0
) -> JuiceeShaderParameterEffect
```
Tween any ShaderMaterial uniform from `from_value` to `to_value` over `duration`.

```gdscript
func resize_control(
    target: Control,
    target_size: Vector2,
    duration: float = 0.3,
    restore_on_end: bool = false
) -> JuiceeSizeDeltaEffect
```
Tween a Control's custom_minimum_size to target_size over duration.


---

## Particles

```gdscript
func burst(
    target: Node2D,
    amount: int = 12,
    color: Color = Color(1.0, 0.8, 0.3),
    spread: float = 120.0
) -> JuiceeBurstEffect
```
One-shot CPUParticles2D burst.

```gdscript
func confetti(
    target: Node2D,
    amount: int = 40
) -> JuiceeConfettiEffect
```
Multi-color confetti burst.

```gdscript
func trail(
    target: Node2D,
    duration: float = 0.6,
    max_ghosts: int = 8
) -> JuiceeTrailEffect
```
Ghost trail: fading copies left behind as a Sprite2D or AnimatedSprite2D moves (dashes, dodges, jumps).

```gdscript
func sparkle(
    target: Node2D,
    count: int = 6,
    spread: float = 36.0,
    star_scale: float = 1.0
) -> JuiceeSparkleEffect
```
Sparkle: a scatter of little star pops around the node (pickups, level-ups, UI shine).

```gdscript
func particle_emit(
    context: Node,
    particle_path: NodePath,
    action: JuiceeParticleEffect.Action = JuiceeParticleEffect.Action.EMIT,
    wait_for_finish: bool = false
) -> JuiceeParticleEffect
```
Control an existing particle node by path, 2D or 3D.

```gdscript
func instantiate_scene(
    context: Node,
    scene: PackedScene,
    lifetime: float = 2.0,
    offset: Vector2 = Vector2.ZERO
) -> JuiceeInstantiateEffect
```
Spawn a PackedScene at the context node's position. Auto-freed after `lifetime` seconds; `lifetime = 0` keeps it.


```gdscript
func hit_spark(
    target: Node2D,
    direction: Vector2 = Vector2.RIGHT,
    amount: int = 10,
    speed: float = 420.0,
    cone: float = 24.0
) -> JuiceeHitSparkEffect
```
Directional spark spray off a hit point. `direction` is where the sparks fly; `cone` is how wide
the spray is either side of it.

```gdscript
func slash_arc(
    target: Node2D,
    angle_degrees: float = 0.0,
    radius: float = 60.0,
    arc_degrees: float = 140.0,
    duration: float = 0.26
) -> JuiceeSlashArcEffect
```
Crescent melee swoosh drawn through the node: sword swings, claws, dash attacks. `angle_degrees`
turns the arc, 0 facing right.

```gdscript
func crack(
    target: Node2D,
    count: int = 5,
    length: float = 70.0,
    thickness: float = 5.0,
    duration: float = 0.5
) -> JuiceeCrackEffect
```
Jagged fracture lines radiating from the node: impacts, heavy landings, broken glass.

---

## Screen FX

```gdscript
func chromatic(
    context: Node,
    intensity: float = 5.0,
    duration: float = 0.2
) -> JuiceeChromaticEffect
```
RGB channel split.

```gdscript
func vignette(
    context: Node,
    intensity: float = 0.6,
    duration: float = 0.8,
    color: Color = Color.BLACK
) -> JuiceeVignetteEffect
```
Edge-darkening overlay.

```gdscript
func blur(
    context: Node,
    blur_amount: float = 4.0,
    duration: float = 0.6
) -> JuiceeBlurEffect
```
Full-screen blur.

```gdscript
func glitch(
    context: Node,
    strength: float = 0.5,
    duration: float = 0.3
) -> JuiceeGlitchEffect
```
Horizontal tear + chromatic split.

```gdscript
func screen_tint(
    context: Node,
    tint_color: Color,
    duration: float = 0.4
) -> JuiceeScreenTintEffect
```
Full-screen colored overlay.

```gdscript
func color_grade(
    context: Node,
    saturation: float = 0.5,
    contrast: float = 1.2,
    tint: Color = Color.WHITE,
    duration: float = 0.8
) -> JuiceeColorGradeEffect
```
Saturation / contrast / tint shift.

```gdscript
func pixelate(
    context: Node,
    pixel_size: float = 8.0,
    duration: float = 0.5
) -> JuiceePixelateEffect
```
Full-screen pixelation.

```gdscript
func screen_wipe(
    context: Node,
    from_side: int = 0,
    color: Color = Color.BLACK,
    duration: float = 0.6
) -> JuiceeScreenWipeEffect
```
Transition wipe. `from_side`: 0=left, 1=right, 2=top, 3=bottom.

```gdscript
func shockwave(
    context: Node,
    max_radius: float = 0.6,
    strength: float = 0.025,
    duration: float = 0.5
) -> JuiceeShockwaveEffect
```
Expanding radial distortion ring.

```gdscript
func cinematic_bars(
    context: Node,
    bar_height: float = 0.1,
    enter_duration: float = 0.3,
    hold_duration: float = 2.0,
    exit_duration: float = 0.3
) -> JuiceeCinematicBarsEffect
```
Letterbox bars: slide in, hold for `hold_duration`, slide out. With `hold_duration = 0` they stay until you call `stop()` on the returned effect.

```gdscript
func scan_lines(
    context: Node,
    line_count: float = 300.0,
    strength: float = 0.25,
    duration: float = 1.0,
    scroll_speed: float = 0.0
) -> JuiceeScanLinesEffect
```
CRT scanline overlay.

```gdscript
func speed_lines(
    context: Node,
    strength: float = 0.5,
    duration: float = 0.4,
    color: Color = Color.WHITE,
    density: float = 140.0
) -> JuiceeSpeedLinesEffect
```
Anime radial speed-lines overlay (dashes, speed bursts, focus/shock moments).

```gdscript
func film_grain(
    context: Node,
    grain_strength: float = 0.12,
    grain_speed: float = 30.0,
    duration: float = 1.0
) -> JuiceeFilmGrainEffect
```
Analog film grain noise.

```gdscript
func radial_blur(
    context: Node,
    blur_strength: float = 0.015,
    duration: float = 0.4,
    center: Vector2 = Vector2(0.5, 0.5)
) -> JuiceeRadialBlurEffect
```
Radial motion blur. When `context` is a Node2D it centres on that node's screen position and `center` is ignored; otherwise it uses `center`, in screen UV.

```gdscript
func lens_distortion(
    context: Node,
    strength: float = 0.25,
    duration: float = 0.5,
    fade_out: bool = true
) -> JuiceeLensDistortionEffect
```
Barrel or pincushion lens distortion (fisheye, scope zoom, warp portals). strength > 0 = barrel (outward), strength < 0 = pincushion (inward).


---

## WorldEnvironment

```gdscript
func bloom(
    context: Node,
    intensity_boost: float = 1.5,
    duration: float = 0.6
) -> JuiceeBloomEffect
```
Pulse WorldEnvironment glow. Needs a WorldEnvironment in the scene; glow is switched on for the play if it was off. Without one it warns and does nothing.

```gdscript
func tonemap_punch(
    context: Node,
    exposure_boost: float = 3.0,
    duration: float = 0.4
) -> JuiceeTonemapEffect
```
Punch tonemap exposure. Needs a WorldEnvironment in the scene; without one it warns and does nothing.

---

## Audio / Hardware

```gdscript
func play_sound(
    context: Node,
    streams: Array[AudioStream],
    pitch_min: float = 0.9,
    pitch_max: float = 1.1
) -> JuiceeSoundEffect
```
Play a random stream with pitch variance.

```gdscript
func rumble(
    context: Node,
    weak: float = 0.5,
    strong: float = 0.5,
    duration: float = 0.2,
    device: int = 0
) -> JuiceeRumbleEffect
```
Gamepad vibration.

```gdscript
func reverb(
    context: Node,
    bus: String = "Master",
    peak_wet: float = 0.45,
    duration: float = 1.5
) -> JuiceeReverbEffect
```
Temporary reverb on an audio bus.

```gdscript
func pitch_shift(
    context: Node,
    target_pitch: float = 0.7,
    bus: String = "Master",
    duration: float = 1.0
) -> JuiceePitchShiftEffect
```
Temporary pitch shift on an audio bus.

```gdscript
func low_pass(
    context: Node,
    target_cutoff: float = 500.0,
    bus: String = "Master",
    duration: float = 0.6
) -> JuiceeLowPassEffect
```
Temporary low-pass ("muffle") on an audio bus - muffled-on-hit, underwater, stunned.

```gdscript
func distortion(
    context: Node,
    bus_name: String = "Master",
    peak_drive: float = 0.5,
    duration: float = 0.8
) -> JuiceeDistortionEffect
```
Ramp a temporary distortion on an audio bus and back. Blown speakers, radio, damage.

```gdscript
func stutter(
    context: Node,
    count: int = 5,
    freeze_time: float = 0.03,
    gap_time: float = 0.03
) -> JuiceeStutterEffect
```
A rapid burst of micro-freezes (machine-gun hit-stop). Hit flurries, glitches.

```gdscript
func knockback(
    body: Node2D,
    direction: Vector2 = Vector2.RIGHT,
    force: float = 400.0
) -> JuiceeKnockbackEffect
```
Shove a RigidBody2D along a direction. Aimed hit reactions.

```gdscript
func sfx(
    context: Node,
    category: JuiceeSfxr.Category,
    sound_seed: int = 0,
    volume_db: float = 0.0,
    pitch_min: float = 1.0,
    pitch_max: float = 1.0,
    bus: StringName = &"Master"
) -> JuiceeProcSoundEffect
```
Synthesize and play a retro game sound at runtime - ZERO audio assets needed. `sound_seed = 0` gives one of eight random variations of the category; any fixed seed reproduces the exact same sound. Categories: PICKUP_COIN, LASER_SHOOT, EXPLOSION, POWERUP, HIT_HURT, JUMP, BLIP_SELECT, RANDOM.

```gdscript
Juicee.sfx(self, JuiceeSfxr.Category.PICKUP_COIN)
```

Experimental: procedural SFX is a prototyping aid, and its API may change.

```gdscript
func audio_3d(
    context: Node,
    streams: Array[AudioStream],
    volume_db: float = 0.0,
    pitch_min: float = 0.9,
    pitch_max: float = 1.1,
    bus: String = "Master",
    max_distance: float = 20.0
) -> JuiceeAudioSource3DEffect
```
Spawn a temporary AudioStreamPlayer3D at the context's world position.

```gdscript
func music_duck(
    context: Node,
    bus: String = "Master",
    duck_db: float = -15.0,
    hold: float = 1.0
) -> JuiceeMusicDuckEffect
```
Duck a bus while something louder happens, then bring it back: dialogue over music, a boss roar,
a menu opening.

```gdscript
func tremolo(
    context: Node,
    bus: String = "Master",
    depth_db: float = -12.0,
    rate: float = 6.0,
    duration: float = 1.5
) -> JuiceeTremoloEffect
```
Wobble a bus's volume up and down: a damage hum, a dying engine, an unstable machine.


---

## Physics

```gdscript
func add_force(
    target: Node,
    force: Vector2 = Vector2(0, -300),
    mode: JuiceeAddForceEffect.Mode = JuiceeAddForceEffect.Mode.IMPULSE,
    force_3d: Vector3 = Vector3.ZERO,
    duration: float = 0.3
) -> JuiceeAddForceEffect
```
Apply an impulse or constant force to a RigidBody2D or RigidBody3D. `duration` only applies to CONSTANT_FORCE. On a RigidBody3D, leaving `force_3d` at zero uses `force` with y flipped, scaled by 0.01.

```gdscript
func impulse(
    body: Node,
    impulse_force: Vector2 = Vector2(200, -100),
    random_cone_degrees: float = 0.0
) -> JuiceeImpulseEffect
```
One push on a RigidBody2D. `random_cone_degrees` spreads repeated pushes apart so a pile of
debris does not fly in formation.

```gdscript
func explosion_push(
    origin: Node2D,
    radius: float = 200.0,
    force: float = 600.0
) -> JuiceeExplosionPushEffect
```
Push every RigidBody2D within `radius` away from `origin`, falling off with distance. The
whole-blast version of `impulse`.

```gdscript
func gravity_shift(
    body: Node,
    gravity_scale: float = 0.0,
    duration: float = 1.0,
    blend_time: float = 0.15
) -> JuiceeGravityShiftEffect
```
Change a RigidBody2D's gravity for a while, then hand it back: floaty jumps, low gravity rooms,
a stasis field. 0 is weightless, negative falls upward.

---

## Text / UI

```gdscript
func damage_number(
    target: Node2D,
    damage: int,
    is_crit: bool = false
) -> JuiceeDamageNumberEffect
```
Floating damage number above target.

```gdscript
func floating_text(
    target: Node2D,
    text: String,
    text_color: Color = Color.WHITE
) -> JuiceeFloatingTextEffect
```
Generic floating text label.

```gdscript
func button_punch(
    target: Control,
    scale_factor: float = 1.15,
    duration: float = 0.25
) -> JuiceeButtonPunchEffect
```
Scale punch on a Control node.

```gdscript
func typewriter(
    target: Label,
    text: String,
    chars_per_second: float = 30.0
) -> JuiceeTypewriterEffect
```
Char-by-char text reveal.

```gdscript
func count_to(
    target: Label,
    from_val: float,
    to_val: float,
    duration: float = 1.0,
    number_format: String = "%d",
    prefix: String = "",
    suffix: String = ""
) -> JuiceeNumberCountEffect
```
Tween a Label's number.

```gdscript
func text_wobble(
    target: Control,
    amplitude: float = 4.0,
    duration: float = 0.5
) -> JuiceeTextWobbleEffect
```
Sine wobble of a Control's position that dies away over `duration`.

```gdscript
func text_scramble(
    label: Label,
    text: String = "",
    duration: float = 0.8
) -> JuiceeTextScrambleEffect
```
Reveal a Label's text by locking in scrambling characters. Decoding, reveals. With `text` left empty it reveals "DECODING", the effect's default, not the label's current text.
```gdscript
func rich_text_emphasis(
    label: Node,
    mode: int = 0,
    phrase: String = "",
    duration: float = 1.5
) -> JuiceeRichTextEmphasisEffect
```
Wave, shake, rainbow or tornado on a RichTextLabel (mode 0 to 3). An empty `phrase` treats the
whole text; otherwise only that phrase moves.


---

## Flow / Sequencing


```gdscript
func tween_property(
    target: Node,
    property: String,
    to_value: Variant,
    duration: float = 0.5,
    return_to_original: bool = true
) -> JuiceePropertyTweenEffect
```
Tween any property on any node, for what has no effect of its own. `property` takes Godot's
indexed paths, so `"modulate:a"` and `"position:x"` work.

```gdscript
func chain(
    context: Node,
    chain_effects: Array[JuiceeEffect],
    parallel: bool = false,
    step_delay: float = 0.0
) -> JuiceeChainEffect
```
Run an ad-hoc array of effects in sequence or parallel.

```gdscript
func animation_player(
    context: Node,
    player_path: NodePath,
    animation_name: String,
    speed: float = 1.0,
    wait_for_finish: bool = true
) -> JuiceeAnimationPlayerEffect
```
Trigger an AnimationPlayer as a sequence step.

```gdscript
func set_active(
    context: Node,
    target_path: NodePath,
    duration: float = 0.5,
    action: JuiceeSetActiveEffect.Action = JuiceeSetActiveEffect.Action.SHOW
) -> JuiceeSetActiveEffect
```
Show/hide a node for duration then restore.

```gdscript
func wait_for_input(
    context: Node,
    action: String = "ui_accept",
    timeout: float = 0.0
) -> JuiceeWaitForInputEffect
```
Pause until the player presses `action`, or until `timeout` seconds pass. `timeout = 0` waits for as long as it takes.

```gdscript
func beat_sync(
    context: Node,
    child_effect: JuiceeEffect,
    bpm: float = 120.0,
    duration: float = 8.0,
    beats_per_trigger: int = 1,
    clock_path: NodePath = NodePath()
) -> JuiceeBeatSyncEffect
```
Fire a child effect every `beats_per_trigger` beats at `bpm`, for `duration` seconds. With `clock_path` set to a JuiceeBeatClock it follows that clock instead.

```gdscript
func play_sequence(
    sequence: JuiceeSequence,
    context: Node,
    params: Dictionary = {}
) -> void
```
Play a pre-built `JuiceeSequence` resource.

```gdscript
func set_property(
    context: Node,
    property_name: String,
    value: Variant,
    restore_delay: float = -1.0,
    target_path: NodePath = NodePath()
) -> JuiceeSetPropertyEffect
```
Instantly set any property, optionally restore after restore_delay seconds. restore_delay = -1 (never restore), 0 (restore immediately), >0 (restore after delay).

```gdscript
func emit_signal_on(
    context: Node,
    signal_name: String,
    argument: Variant = null
) -> JuiceeEmitSignalEffect
```
Emit a signal by name on the context node (bridge between sequences and game signals).

```gdscript
func debug_log(
    context: Node,
    message: String,
    level: JuiceeDebugLogEffect.Level = JuiceeDebugLogEffect.Level.PRINT
) -> JuiceeDebugLogEffect
```
Print/warn/error a message from a sequence step (debug helper).

```gdscript
func auto_destruct(
    context: Node,
    delay: float = 0.0,
    target_path: NodePath = NodePath()
) -> JuiceeAutoDestructEffect
```
Queue-free the context node (or target) after `delay` seconds.

```gdscript
func animation_tree_travel(
    context: Node,
    state_or_param: String,
    mode: JuiceeAnimationTreeEffect.Mode = JuiceeAnimationTreeEffect.Mode.TRAVEL,
    value: Variant = true,
    tree_path: NodePath = NodePath()
) -> JuiceeAnimationTreeEffect
```
Travel to an AnimationTree state or set a parameter.


---

## Built-in presets

One-line drop-in game-feel sequences. No `.tres` lookup - built inline.

With `Juicee.sfx_enabled = true`, every preset except `preset_low_health_pulse` also plays a matching procedural sound. It is off by default.

```gdscript
func preset_hit(context: Node, hit_color: Color = Color.WHITE) -> void
```
Light shake + modulate flash. Non-crit melee/projectile hits.

```gdscript
func preset_hit_crit(context: Node) -> void
```
`hit_stop` + heavy shake + chromatic + bright double-flash. Critical hits.

```gdscript
func preset_level_up(context: Node) -> void
```
Shake + zoom + bounce + confetti + warm gold tint.

```gdscript
func preset_damage_taken(context: Node) -> void
```
`hit_stop` + heavy shake + red tint + red vignette + rumble.

```gdscript
func preset_death(context: Node) -> void
```
Slow-mo + blur + pixelate + grayscale + glitch. The blur, pixelate and grayscale stay on screen: they are children of `context`, so they go when that node is freed.

```gdscript
func preset_explosion(context: Node, burst_color: Color = Color(1.0, 0.6, 0.2, 1.0)) -> void
```
`hit_stop` + burst + heavy shake + chromatic.

```gdscript
func preset_combo(context: Node) -> void
```
Three escalating hit-stops, each with a harder shake, then chromatic + burst. Combo finisher.

```gdscript
func preset_dash(context: Node, direction: Vector2 = Vector2.RIGHT) -> void
```
Chromatic + blur + zoom + position kick. Dodge/dash feel.

```gdscript
func preset_pickup(target: Node2D, label_text: String = "+1") -> void
```
Bounce + flash + confetti + floating text.

```gdscript
func preset_boss_intro(context: Node) -> void
```
Zoom + vignette + shake + ominous red tint + rumble. The vignette and tint stay on until `context` is freed.

```gdscript
func preset_low_health_pulse(target: CanvasItem, duration: float = 10.0) -> JuiceeAmbientFlashEffect
```
Sustained red ambient flash. **Returns the effect** - call `effect.stop()` to cancel.

```gdscript
func preset_victory(context: Node) -> void
```
Confetti + zoom + color cycle + warm tint + rumble.
