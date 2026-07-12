# Juicee Singleton API Reference

The `Juicee` autoload singleton is available from any script without setup.

```gdscript
extends Node   # or any script
func _input(event):
    if event.is_action_pressed("shoot"):
        Juicee.shake_camera(self, 12.0, 0.3)
        Juicee.flash(my_sprite, Color.RED)
```

All methods are fire-and-forget — they create a temporary effect resource, call `apply()`, and return. For stoppable, stacking, or configurable effects use `JuiceePlayer` + `JuiceeSequence` instead.

---

## Accessibility

```gdscript
var accessibility: JuiceeAccessibility
```

Global accessibility object. Set flags from your settings screen — all effects read this automatically.

```gdscript
Juicee.accessibility.reduced_motion = true    # halves all intensities
Juicee.accessibility.no_flash       = true    # silences Flash/Strobe/AmbientFlash
Juicee.accessibility.no_screenshake = true    # silences camera shake
Juicee.accessibility.no_chromatic   = true    # silences Chromatic/Glitch
Juicee.accessibility.intensity_scale = 0.5   # master multiplier (0–1)

# Save/load:
save_data["a11y"] = Juicee.accessibility.to_dict()
Juicee.accessibility.from_dict(save_data["a11y"])
```

---

## Camera

```gdscript
func shake_camera(
    context: Node,
    intensity: float = 8.0,
    duration: float = 0.3,
    frequency: float = 15.0
) -> void
```
Shake the active Camera2D via Perlin noise. `context` provides the viewport — any node in the scene works. Pass `{"hit_direction": Vector2}` via `JuiceePlayer.play()` for directional bias.

```gdscript
func shake_camera_3d(
    context: Node,
    intensity: float = 0.1,
    duration: float = 0.3
) -> void
```
Camera3D shake with per-axis scaling.

```gdscript
func zoom_camera(
    context: Node,
    zoom_factor: float = 1.2,
    duration: float = 0.4
) -> void
```
Camera2D zoom punch. `zoom_factor > 1` = zoom in, `< 1` = zoom out.

```gdscript
func camera_follow(
    target: Node2D,
    duration: float = 1.5,
    follow_speed: float = 5.0
) -> void
```
Smoothly lerp Camera2D toward `target` for `duration` seconds, then return.

```gdscript
func directional_shake(
    context: Node,
    direction: Vector2 = Vector2(0,-1),
    kick_distance: float = 12.0,
    duration: float = 0.35
) -> void
```
Directional kick shake. Camera snaps toward `direction`, then oscillates back.

```gdscript
func camera_bob(
    context: Node,
    amplitude: Vector2 = Vector2(0.0, 3.0),
    frequency: float = 2.0,
    duration: float = 2.0
) -> void
```
Rhythmic sine-wave bob on Camera2D offset. Walk cycle, breathing idle.

```gdscript
func zoom_pulse(
    context: Node,
    bpm: float = 120.0,
    zoom_boost: float = 0.08,
    duration: float = 4.0
) -> void
```
BPM-synced Camera2D zoom pulse. Each beat pulses 8% zoom in then decays.

---

## Time

```gdscript
func hit_stop(
    context: Node,
    freeze_duration: float = 0.08,
    time_scale_during: float = 0.0
) -> void
```
Instant time freeze. `0.05–0.1s` is the sweet spot for melee combat.

```gdscript
func slow_mo(
    context: Node,
    target_scale: float = 0.2,
    hold: float = 0.4
) -> void
```
Smooth slow-motion ramp. Uses default ramp_in=0.3, ramp_out=0.4.

```gdscript
func freeze_frame(
    context: Node,
    freeze_duration: float = 0.1,
    white_flash: bool = true
) -> void
```
Full `Engine.time_scale = 0.0` freeze with optional white flash. Heavier than `hit_stop` — use for finishing blows and super moves.

---

## Object feedback

```gdscript
func flash(
    target: CanvasItem,
    flash_color: Color = Color.WHITE,
    duration: float = 0.15,
    count: int = 1
) -> void
```
Blink modulate N times. Target is the sprite or control to flash.

```gdscript
func bounce(
    target: Node2D,
    scale_factor: float = 1.3,
    duration: float = 0.3
) -> void
```
Squash & stretch scale punch.

```gdscript
func punch_position(
    target: Node2D,
    offset: Vector2,
    duration: float = 0.3,
    return_to_original: bool = true,
    relative: bool = true
) -> void
```
Displace and return. With `relative = false`, `offset` is the exact position to land on rather than a nudge from where the node already is.

```gdscript
func punch_rotation(
    target: Node2D,
    angle_degrees: float = 15.0,
    duration: float = 0.3,
    return_to_original: bool = true,
    relative: bool = true
) -> void
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
) -> void
```
Scale punch on a Node3D, with an optional spring back. The 3D counterpart of `scale_to`.

```gdscript
func jiggle(
    target: Node2D,
    impulse: Vector2 = Vector2(0.4, -0.4),
    stiffness: float = 8.0
) -> void
```
Spring-mass jelly jiggle on scale.

```gdscript
func modulate_to(
    target: CanvasItem,
    color: Color,
    duration: float = 0.4
) -> void
```
Smooth color shift (unlike flash which blinks).

```gdscript
func light_flash(
    target: Light2D,
    peak_energy: float = 3.0,
    color: Color = Color.WHITE,
    duration: float = 0.3
) -> void
```
Flash a Light2D's energy and color.

```gdscript
func spring(
    target: Node,
    property_name: String,
    kick: Vector2,
    stiffness: float = 200.0,
    damping: float = 10.0
) -> void
```
Harmonic spring on any Vector2 property. Example: `Juicee.spring(my_button, "scale", Vector2(0.4, 0.4))`.

```gdscript
func spin(
    target: Node2D,
    speed_deg_per_sec: float = 360.0,
    duration: float = 0.6,
    restore: bool = false
) -> void
```
Full 360° spin. `restore=true` snaps back to original rotation at the end.

```gdscript
func wiggle(
    target: Node2D,
    amplitude: float = 4.0,
    frequency: float = 12.0,
    duration: float = 0.5
) -> void
```
Random position jitter at Hz frequency.

```gdscript
func sprite_bob(
    target: Node2D,
    amplitude_px: float = 6.0,
    bob_freq: float = 1.5,
    duration: float = 3.0,
    axis: Vector2 = Vector2(0, 1)
) -> void
```
Sine-wave bob. Default axis = vertical.

```gdscript
func pop_in(
    target: Node,
    from_scale: float = 0.0
) -> void
```
SPRING overshoot scale-in. Works on Node2D and Control.

```gdscript
func shake_control(
    target: Control,
    amplitude: float = 8.0,
    duration: float = 0.4,
    frequency: float = 18.0
) -> void
```
Horizontal shake for UI elements. Wrong-password, invalid-action feedback.

```gdscript
func pulse(
    target: Node,
    scale_factor: float = 1.15,
    interval: float = 0.5,
    count: int = 0,
    duration: float = 3.0
) -> void
```
Repeating scale pulse. `count=0` + `duration>0` = time-limited.

```gdscript
func recoil(
    target: Node2D,
    direction: Vector2 = Vector2(-1, 0),
    kick_distance: float = 12.0,
    return_duration: float = 0.18
) -> void
```
Directional position kick with spring-back. Gun recoil, hit absorption.

```gdscript
func outline(
    target: CanvasItem,
    outline_color: Color = Color(1.0, 0.85, 0.20, 1.0),
    outline_width: float = 2.0,
    duration: float = 0.8
) -> void
```
Animated colored outline via shader uniform.

```gdscript
func color_cycle(
    target: CanvasItem,
    cycles: float = 2.0,
    duration: float = 1.5,
    saturation: float = 1.0,
    loop: bool = false
) -> void
```
Hue cycle on modulate. Rainbow powerup, party mode. `loop = true` runs until `stop()` (persistent RAINBOW MODE).

```gdscript
func impact_ring(
    target: Node2D,
    color: Color = Color(1.0, 0.85, 0.3),
    spikes: int = 8,
    radius: float = 42.0
) -> void
```
Expanding ring + radiating "POW" spikes drawn on the node (Line2D, no shaders). Crits, parries, explosions.

```gdscript
func sway(
    target: Node,
    angle: float = 6.0,
    period: float = 1.2,
    cycles: float = 0.0
) -> void
```
Smooth pendulum rotation sway. `cycles = 0` sways forever (until `stop()`). Idle UI, hanging signs, breathing titles.

```gdscript
func ambient_flash(
    target: CanvasItem,
    flash_color: Color = Color(1.0, 0.2, 0.2, 0.5),
    duration: float = 3.0,
    frequency: float = 1.5
) -> void
```
Repeating flash for sustained states. Low-health siren, boss enrage.

```gdscript
func strobe_light(
    target: Light2D,
    pulse_count: int = 6,
    duration: float = 0.5,
    peak_energy: float = 3.0
) -> void
```
Square-wave Light2D strobe.

---

## Particles

```gdscript
func burst(
    target: Node2D,
    amount: int = 12,
    color: Color = Color(1.0, 0.8, 0.3),
    spread: float = 120.0
) -> void
```
One-shot CPUParticles2D burst.

```gdscript
func confetti(
    target: Node2D,
    amount: int = 40
) -> void
```
Multi-color confetti burst.

---

## Screen FX

```gdscript
func chromatic(
    context: Node,
    intensity: float = 5.0,
    duration: float = 0.2
) -> void
```
RGB channel split.

```gdscript
func vignette(
    context: Node,
    intensity: float = 0.6,
    duration: float = 0.8,
    color: Color = Color.BLACK
) -> void
```
Edge-darkening overlay.

```gdscript
func blur(
    context: Node,
    blur_amount: float = 4.0,
    duration: float = 0.6
) -> void
```
Full-screen Gaussian blur.

```gdscript
func glitch(
    context: Node,
    strength: float = 0.5,
    duration: float = 0.3
) -> void
```
Horizontal tear + chromatic split.

```gdscript
func screen_tint(
    context: Node,
    tint_color: Color,
    duration: float = 0.4
) -> void
```
Full-screen colored overlay.

```gdscript
func color_grade(
    context: Node,
    saturation: float = 0.5,
    contrast: float = 1.2,
    tint: Color = Color.WHITE,
    duration: float = 0.8
) -> void
```
Saturation / contrast / tint shift.

```gdscript
func pixelate(
    context: Node,
    pixel_size: float = 8.0,
    duration: float = 0.5
) -> void
```
Full-screen pixelation.

```gdscript
func screen_wipe(
    context: Node,
    from_side: int = 0,
    color: Color = Color.BLACK,
    duration: float = 0.6
) -> void
```
Transition wipe. `from_side`: 0=left, 1=right, 2=top, 3=bottom.

```gdscript
func shockwave(
    context: Node,
    max_radius: float = 0.6,
    strength: float = 0.025,
    duration: float = 0.5
) -> void
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
Letterbox bars. Returns the effect instance so you can call `stop()` to trigger the slide-out manually.

```gdscript
func scan_lines(
    context: Node,
    line_count: float = 300.0,
    strength: float = 0.25,
    duration: float = 1.0,
    scroll_speed: float = 0.0
) -> void
```
CRT scanline overlay.

```gdscript
func speed_lines(
    context: Node,
    strength: float = 0.5,
    duration: float = 0.4,
    color: Color = Color.WHITE,
    density: float = 140.0
) -> void
```
Anime radial speed-lines overlay (dashes, speed bursts, focus/shock moments).

```gdscript
func film_grain(
    context: Node,
    grain_strength: float = 0.12,
    grain_speed: float = 30.0,
    duration: float = 1.0
) -> void
```
Analog film grain noise.

```gdscript
func radial_blur(
    context: Node,
    blur_strength: float = 0.015,
    duration: float = 0.4,
    center: Vector2 = Vector2(0.5, 0.5)
) -> void
```
Radial motion blur from a screen point.

---

## WorldEnvironment

```gdscript
func bloom(
    context: Node,
    intensity_boost: float = 1.5,
    duration: float = 0.6
) -> void
```
Pulse WorldEnvironment glow.

```gdscript
func tonemap_punch(
    context: Node,
    exposure_boost: float = 3.0,
    duration: float = 0.4
) -> void
```
Punch tonemap exposure.

---

## Audio / Hardware

```gdscript
func play_sound(
    context: Node,
    streams: Array[AudioStream],
    pitch_min: float = 0.9,
    pitch_max: float = 1.1
) -> void
```
Play a random stream with pitch variance.

```gdscript
func rumble(
    context: Node,
    weak: float = 0.5,
    strong: float = 0.5,
    duration: float = 0.2,
    device: int = 0
) -> void
```
Gamepad vibration.

```gdscript
func reverb(
    context: Node,
    bus: String = "Master",
    peak_wet: float = 0.45,
    duration: float = 1.5
) -> void
```
Temporary reverb on an audio bus.

```gdscript
func pitch_shift(
    context: Node,
    target_pitch: float = 0.7,
    bus: String = "Master",
    duration: float = 1.0
) -> void
```
Temporary pitch shift on an audio bus.

```gdscript
func low_pass(
    context: Node,
    target_cutoff: float = 500.0,
    bus: String = "Master",
    duration: float = 0.6
) -> void
```
Temporary low-pass ("muffle") on an audio bus — muffled-on-hit, underwater, stunned.

```gdscript
func distortion(
    context: Node,
    bus_name: String = "Master",
    peak_drive: float = 0.5,
    duration: float = 0.8
) -> void
```
Ramp a temporary distortion on an audio bus and back. Blown speakers, radio, damage.

```gdscript
func stutter(
    context: Node,
    count: int = 5,
    freeze_time: float = 0.03,
    gap_time: float = 0.03
) -> void
```
A rapid burst of micro-freezes (machine-gun hit-stop). Hit flurries, glitches.

```gdscript
func knockback(
    body: Node2D,
    direction: Vector2 = Vector2.RIGHT,
    force: float = 400.0
) -> void
```
Shove a RigidBody2D along a direction. Aimed hit reactions.

---

## Text / UI

```gdscript
func damage_number(
    target: Node2D,
    damage: int,
    is_crit: bool = false
) -> void
```
Floating damage number above target.

```gdscript
func floating_text(
    target: Node2D,
    text: String,
    text_color: Color = Color.WHITE
) -> void
```
Generic floating text label.

```gdscript
func button_punch(
    target: Control,
    scale_factor: float = 1.15,
    duration: float = 0.25
) -> void
```
Scale punch on a Control node.

```gdscript
func typewriter(
    target: Label,
    text: String,
    chars_per_second: float = 30.0
) -> void
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
) -> void
```
Tween a Label's number.

```gdscript
func text_wobble(
    target: Control,
    amplitude: float = 4.0,
    duration: float = 0.5
) -> void
```
Sine wobble on a Control.

```gdscript
func text_scramble(
    label: Label,
    text: String = "",
    duration: float = 0.8
) -> void
```
Reveal a Label's text by locking in scrambling characters. Decoding, reveals.

---

## Flow / Sequencing

```gdscript
func chain(
    context: Node,
    chain_effects: Array[JuiceeEffect],
    parallel: bool = false,
    step_delay: float = 0.0
) -> void
```
Run an ad-hoc array of effects in sequence or parallel.

```gdscript
func animation_player(
    context: Node,
    player_path: NodePath,
    animation_name: String,
    speed: float = 1.0,
    wait_for_finish: bool = true
) -> void
```
Trigger an AnimationPlayer as a sequence step.

```gdscript
func set_active(
    context: Node,
    target_path: NodePath,
    duration: float = 0.5,
    action: JuiceeSetActiveEffect.Action = JuiceeSetActiveEffect.Action.SHOW
) -> void
```
Show/hide a node for duration then restore.

```gdscript
func wait_for_input(
    context: Node,
    action: String = "ui_accept",
    timeout: float = 0.0
) -> void
```
Pause until the player presses an action.

```gdscript
func beat_sync(
    context: Node,
    child_effect: JuiceeEffect,
    bpm: float = 120.0,
    duration: float = 8.0,
    beats_per_trigger: int = 1,
    clock_path: NodePath = NodePath()
) -> void
```
Fire a child effect on every beat.

```gdscript
func play_sequence(
    sequence: JuiceeSequence,
    context: Node,
    params: Dictionary = {}
) -> void
```
Play a pre-built `JuiceeSequence` resource.

---

## Built-in presets

One-line drop-in game-feel sequences. No `.tres` lookup — built inline.

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
Slow-mo + persistent blur + pixelate + grayscale + glitch. Stays up until scene reload.

```gdscript
func preset_explosion(context: Node, burst_color: Color = Color(1.0,0.6,0.2)) -> void
```
`hit_stop` + burst + heavy shake + chromatic.

```gdscript
func preset_combo(context: Node) -> void
```
3× escalating hit-stops + chromatic + burst. Combo finisher.

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
Zoom + vignette + shake + ominous red tint + rumble.

```gdscript
func preset_low_health_pulse(target: CanvasItem, duration: float = 10.0) -> JuiceeAmbientFlashEffect
```
Sustained red ambient flash. **Returns the effect** — call `effect.stop()` to cancel.

```gdscript
func preset_victory(context: Node) -> void
```
Confetti + zoom + color cycle + warm tint + rumble.
