# Juicee - Effects Reference (117 effects)

All 99 effects organized by category. Every `@export` parameter is documented. For base-class params (`chance`, `delay`, `intensity_min/max`, `cooldown`) see [api-reference.md](api-reference.md).

**Accessibility tags** are noted where relevant - see `JuiceeAccessibility` in [api-reference.md](api-reference.md).

---

## Screen (18 effects)

Screen effects render on a `CanvasLayer` above everything else. Shader-based effects use `SCREEN_TEXTURE` and require **Forward Plus or Mobile renderer**. The Compatibility renderer does not support `hint_screen_texture`.

> **Editor preview note:** In the Inspector ▶ Preview and JuiceeGraph ▶ Test flows, screen effects render inside the editor's preview viewport (smaller than the window). An amber outline marks the preview area. Run the project (F5/F6) for true full-screen rendering.

---

### JuiceeChromaticEffect

RGB channel split full-screen. Splits the screen into R, G, B samples offset by `intensity` pixels in opposite directions. Classic damage hit / glitch vibe.

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity` | `float` | `5.0` | Max pixel offset per channel. Higher = more extreme split. |
| `duration` | `float` | `0.2` | Total effect time in seconds. |
| `fade_out` | `bool` | `true` | Fade the effect out over the last 50% of duration. |

**Accessibility tag:** `TAG_CHROMATIC`  
**Shader:** `addons/juicee/shaders/chromatic.gdshader`

---

### JuiceeVignetteEffect

Edge-darkening overlay with color tint. Useful for damage indicators, atmospheric mood, horror tunnels.

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity` | `float` | `0.6` | Vignette strength (0-1). `1.0` = full black edges. |
| `duration` | `float` | `0.8` | Duration in seconds. |
| `fade_out` | `bool` | `true` | Fade out at the end. Set to `false` for persistent vignette. |
| `vignette_color` | `Color` | `Color.BLACK` | Tint color of the vignette - try `Color(0.6,0,0,1)` for a red damage vignette. |

**Shader:** `addons/juicee/shaders/vignette.gdshader`

---

### JuiceeBlurEffect

Full-screen Gaussian blur. Use for pause menus, dream sequences, or death overlays.

| Property | Type | Default | Description |
|---|---|---|---|
| `blur_amount` | `float` | `4.0` | Blur radius in pixels. |
| `duration` | `float` | `0.6` | Duration in seconds. |
| `fade_out` | `bool` | `true` | Fade blur to zero at the end. `false` = stays blurred. |

**Shader:** `addons/juicee/shaders/blur.gdshader`

---

### JuiceePixelateEffect

Full-screen pixelation. Retro hit flashes, damage moments, glitch sequences.

| Property | Type | Default | Description |
|---|---|---|---|
| `pixel_size` | `float` | `8.0` | Pixel size in screen pixels. |
| `duration` | `float` | `0.5` | Duration in seconds. |
| `fade_out` | `bool` | `true` | Smooth pixel_size back to 1 at the end. |

**Shader:** `addons/juicee/shaders/pixelate.gdshader`

---

### JuiceeGlitchEffect

Horizontal screen tear with chromatic split. Hacking aesthetic, broken systems, damage states.

| Property | Type | Default | Description |
|---|---|---|---|
| `strength` | `float` | `0.5` | Tear intensity (0-1). |
| `intensity` | `float` | `5.0` | Chromatic split width in pixels. |
| `duration` | `float` | `0.3` | Duration in seconds. |
| `fade_out` | `bool` | `true` | Fade out at the end. |

**Accessibility tag:** `TAG_CHROMATIC`  
**Shader:** `addons/juicee/shaders/glitch.gdshader`

---

### JuiceeColorGradeEffect

Saturation / contrast / brightness / tint shift on the full screen. Desaturate on damage, boost on level-up, go green for night vision.

| Property | Type | Default | Description |
|---|---|---|---|
| `saturation` | `float` | `0.5` | Target saturation (0=gray, 1=original, >1=hyper-saturated). |
| `contrast` | `float` | `1.2` | Target contrast multiplier. |
| `brightness` | `float` | `1.0` | Target brightness multiplier. |
| `tint` | `Color` | `Color.WHITE` | Multiplicative color tint. |
| `duration` | `float` | `0.8` | Duration. |
| `fade_out` | `bool` | `true` | Restore all values at the end. |

**Accessibility tag:** `TAG_CHROMATIC`  
**Shader:** `addons/juicee/shaders/color_grade.gdshader`

---

### JuiceeScreenTintEffect

Solid colored full-screen overlay (RGBA `ColorRect` on a `CanvasLayer`). Fastest screen effect - no shader needed. Red flash for damage, gold for level-up, white for explosion.

| Property | Type | Default | Description |
|---|---|---|---|
| `tint_color` | `Color` | `Color(1,0,0,0.35)` | Overlay color. Alpha controls opacity. |
| `duration` | `float` | `0.4` | Duration. |
| `fade_out` | `bool` | `true` | Fade alpha to 0 at the end. |

**Accessibility tag:** `TAG_FLASH`  
**No shader** - solid `ColorRect` overlay.

---

### JuiceeScreenWipeEffect

Colored bar slides across the screen. Use for scene transitions.

| Property | Type | Default | Description |
|---|---|---|---|
| `wipe_from` | `int` | `0` | Edge the bar enters from: `0`=left, `1`=right, `2`=top, `3`=bottom. |
| `wipe_color` | `Color` | `Color.BLACK` | Wipe bar color. |
| `duration` | `float` | `0.6` | Duration of the slide. |

---

### JuiceeBloomEffect

Pulses the active `WorldEnvironment` glow parameters. **No custom shader** - animates Godot's built-in post-process. Zero performance overhead. Works in 2D and 3D.

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity_boost` | `float` | `1.5` | How much to add to `glow_intensity` at the peak. |
| `duration` | `float` | `0.6` | Duration. |
| `strength_boost` | `float` | `0.5` | How much to add to `glow_strength` at peak. |

Requires a `WorldEnvironment` node in the scene with glow enabled.

---

### JuiceeTonemapEffect

Punches the active `WorldEnvironment` tonemap exposure. Flash-blindness from explosions, teleport arrivals, dimension shifts.

| Property | Type | Default | Description |
|---|---|---|---|
| `exposure_boost` | `float` | `3.0` | Target `tonemap_exposure` value. Default `1.0` = no change. |
| `duration` | `float` | `0.4` | Duration. |
| `white_boost` | `float` | `0.0` | Added to `tonemap_white` at peak. |

Requires a `WorldEnvironment` node.

---

### JuiceeShockwaveEffect

Expanding radial distortion ring originating from the context node's screen position. The ring travels outward; UV distortion strength fades as the ring expands.

| Property | Type | Default | Description |
|---|---|---|---|
| `max_radius` | `float` | `0.6` | Max ring radius in normalized screen units (0-1). |
| `strength` | `float` | `0.025` | UV displacement strength at the wave front. |
| `wave_width` | `float` | `0.15` | Width of the distortion band (normalized). |
| `duration` | `float` | `0.5` | Duration. |

**Shader:** `addons/juicee/shaders/shockwave.gdshader`

---

### JuiceeCinematicBarsEffect

Letterbox bars slide in from the top and bottom edges. Hold for `hold_duration` seconds, then slide back out. `hold_duration = 0` holds indefinitely - call `stop()` on the returned effect to slide out.

| Property | Type | Default | Description |
|---|---|---|---|
| `bar_color` | `Color` | `Color.BLACK` | Bar color. |
| `bar_height` | `float` | `0.1` | Bar height as a fraction of screen height (0.1 = 10% top + 10% bottom). |
| `enter_duration` | `float` | `0.3` | Slide-in time. |
| `hold_duration` | `float` | `2.0` | Hold time. `0` = hold until `stop()`. |
| `exit_duration` | `float` | `0.3` | Slide-out time. |
| `canvas_layer` | `int` | `200` | Z-order of the CanvasLayer. |

```gdscript
# Hold indefinitely until the cutscene ends:
var bars := Juicee.cinematic_bars(self, 0.1, 0.3, 0.0, 0.3)
await cutscene_finished
bars.stop()  # triggers the slide-out
```

---

### JuiceeScanLinesEffect

CRT scanline overlay with optional scroll. Retro monitors, broken screens, hacker aesthetic.

| Property | Type | Default | Description |
|---|---|---|---|
| `line_count` | `float` | `300.0` | Number of horizontal scanlines (50-1000). |
| `strength` | `float` | `0.25` | Darkening strength per dark line (0-1). |
| `scroll_speed` | `float` | `0.0` | Lines scroll down at this speed (0 = static). |
| `duration` | `float` | `1.0` | Duration. |
| `fade_out` | `bool` | `true` | Fade effect out at the end. |

**Shader:** `addons/juicee/shaders/scanlines.gdshader`

---

### JuiceeSpeedLinesEffect

Anime radial speed-lines overlay - streaks converging on the screen centre. Dashes, bursts of speed, focus and shock moments. *(New in 1.2.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `density` | `float` | `140.0` | Angular streak count (20-400). Higher = more, thinner lines. |
| `strength` | `float` | `0.5` | Peak streak opacity (0-1). |
| `center_clear` | `float` | `0.35` | Radius (0-0.9) of the clear centre with no lines over the focal point. |
| `line_color` | `Color` | `Color.WHITE` | Streak colour. White = speed, black = shock/focus. |
| `anim_speed` | `float` | `6.0` | Streak shimmer rate (0 = static). |
| `duration` | `float` | `0.4` | Duration. |
| `fade_out` | `bool` | `true` | Fade effect out at the end. |

**Shader:** `addons/juicee/shaders/speed_lines.gdshader`

---

### JuiceeFilmGrainEffect

Analog film grain noise overlay. Grain is quantized to `speed` FPS for authentic flutter rather than per-frame smooth noise.

| Property | Type | Default | Description |
|---|---|---|---|
| `strength` | `float` | `0.12` | Noise amplitude. `0.05` = subtle, `0.3` = heavy grain. |
| `speed` | `float` | `30.0` | Grain refresh rate in FPS. `24.0` = classic film. |
| `duration` | `float` | `1.0` | Duration. |
| `fade_out` | `bool` | `true` | Fade out. |

**Shader:** `addons/juicee/shaders/film_grain.gdshader`

---

### JuiceeRadialBlurEffect

Radial motion blur from a screen point. N-sample accumulation toward the center point.

| Property | Type | Default | Description |
|---|---|---|---|
| `strength` | `float` | `0.015` | Per-sample UV offset. |
| `samples` | `int` | `12` | Sample count. More = smoother, heavier cost. |
| `duration` | `float` | `0.4` | Duration. |
| `center_uv` | `Vector2` | `Vector2(0.5, 0.5)` | Blur center in normalized UV space. |
| `use_node_position` | `bool` | `false` | Derive `center_uv` from the context node's screen position at apply time. |
| `fade_out` | `bool` | `true` | Fade out. |

**Shader:** `addons/juicee/shaders/radial_blur.gdshader`

---

### JuiceeLensDistortionEffect

Barrel or pincushion lens distortion over the full screen. `strength > 0` warps outward (barrel / fisheye); `strength < 0` warps inward (pincushion / zoom lens). Pixels that map outside [0,1] UV are filled with black. Scope zoom, warp portals, dimensional rifts, drunk/dazed state.

**Accessibility tag:** `TAG_SCREENSHAKE`

| Property | Type | Default | Description |
|---|---|---|---|
| `strength` | `float` | `0.25` | Distortion magnitude. Range −1.0 to 1.0. |
| `duration` | `float` | `0.5` | Effect duration in seconds. |
| `fade_out` | `bool` | `true` | Fade strength to 0 at end. |

**Shader:** `addons/juicee/shaders/lens_distortion.gdshader`

---

### JuiceeDepthOfFieldEffect

Drives `CameraAttributesPractical` on a `Camera3D` for native engine DOF blur. Animates through three phases: fade-in (15%), hold (70%), fade-out (15%). Far and near blur are independently toggleable. Focus-pull cinematics, sniper scope, cinematic cutscene transitions.

**Dimensions:** 3D only

| Property | Type | Default | Description |
|---|---|---|---|
| `camera_path` | `NodePath` | `""` | Path to Camera3D. Empty = search context and its parent. |
| `blur_far` | `bool` | `true` | Enable far-plane blur. |
| `blur_near` | `bool` | `false` | Enable near-plane blur. |
| `far_distance` | `float` | `10.0` | Far blur start distance (metres). |
| `far_transition` | `float` | `5.0` | Far blur transition band (metres). |
| `near_distance` | `float` | `2.0` | Near blur start distance (metres). |
| `near_transition` | `float` | `1.0` | Near blur transition band (metres). |
| `duration` | `float` | `1.0` | Total duration. |
| `fade_out` | `bool` | `true` | Restore original camera attributes at end. |

---

## Camera (9 effects)

Camera effects target the active `Camera2D` found via `context.get_viewport().get_camera_2d()` or the active `Camera3D`. They use `JuiceeStateStack` to safely stack.

---

### JuiceeShakeEffect

Perlin noise or random jitter on `Camera2D.offset`. The definitive game-feel effect.

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity` | `float` | `8.0` | Max displacement in pixels. |
| `duration` | `float` | `0.3` | Duration. |
| `frequency` | `float` | `15.0` | Oscillations per second. |
| `decay` | `float` | `0.8` | How fast amplitude decays. `0` = constant, `5` = very fast. |
| `use_noise` | `bool` | `true` | Perlin noise (smooth) vs. random jitter (chaotic). |
| `roll_degrees` | `float` | `0.0` | Max camera roll layered on the positional shake; a touch of rotation reads much more violent. `0` = position only. |

**Runtime params:** `{"hit_direction": Vector2}` - biases the shake away from the hit direction for a recoil feel.  
**Accessibility tag:** `TAG_SCREENSHAKE`

---

### JuiceeShake3DEffect

Camera3D shake via offset on each axis. Independent per-axis scale for horizontal-only, vertical-only, or full 3D shake.

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity` | `float` | `0.1` | Max displacement per axis. |
| `duration` | `float` | `0.3` | Duration. |
| `frequency` | `float` | `15.0` | Oscillations per second. |
| `axis_scale` | `Vector3` | `Vector3(1,1,0)` | Per-axis intensity multiplier. Set Y=0 for horizontal-only. |

**Accessibility tag:** `TAG_SCREENSHAKE`

---

### JuiceeZoomEffect

Camera2D zoom punch in or out with overshoot and return.

| Property | Type | Default | Description |
|---|---|---|---|
| `zoom_factor` | `float` | `1.2` | Target zoom multiplier. `1.2` = 20% zoom in. `0.8` = zoom out. |
| `duration` | `float` | `0.4` | Duration of the full punch + return. |
| `overshoot` | `float` | `0.1` | Tween overshoot (uses `TRANS_SPRING`). |

---

### JuiceeFOV3DEffect

Camera3D field-of-view punch. Positive delta = zoom out (wider FOV), negative = zoom in.

| Property | Type | Default | Description |
|---|---|---|---|
| `fov_delta` | `float` | `15.0` | Degrees added to current FOV at peak. |
| `duration` | `float` | `0.4` | Duration. |

---

### JuiceeCameraFollowEffect

Smoothly lerps Camera2D to track a target Node2D for `duration` seconds, then returns to the original position.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_node_path` | `NodePath` | `""` | Target to follow. If empty, context IS the target. |
| `follow_speed` | `float` | `5.0` | Lerp speed toward the target (per second). |
| `duration` | `float` | `1.5` | How long to follow before returning. |
| `return_speed` | `float` | `3.0` | Lerp speed when returning. |

---

### JuiceeDirectionalShakeEffect

Kick-recoil shake with directional bias plus perpendicular noise. The camera "snaps" in the kick direction, then oscillates back. Use for gun fire, directional punch impacts, explosion knockback.

| Property | Type | Default | Description |
|---|---|---|---|
| `direction` | `Vector2` | `Vector2(0,-1)` | Kick direction. Gets normalized. |
| `kick_distance` | `float` | `12.0` | Max displacement of the initial kick in pixels. |
| `duration` | `float` | `0.35` | Total duration. |
| `frequency` | `float` | `18.0` | Oscillation frequency after the kick. |
| `perp_noise` | `float` | `0.3` | Perpendicular noise scale (0 = pure directional). |

**Runtime params:** `{"direction": Vector2}` - override direction per-shot.  
**Accessibility tag:** `TAG_SCREENSHAKE`

---

### JuiceeCameraBobEffect

Rhythmic sine-wave bob on `Camera2D.offset`. Uses a `sin(t * PI)` envelope for smooth ramp-in and ramp-out. Walk cycle, breathing idle, post-impact sway.

| Property | Type | Default | Description |
|---|---|---|---|
| `amplitude` | `Vector2` | `Vector2(0,3)` | Bob amplitude per axis in pixels. |
| `frequency` | `float` | `2.0` | Bobs per second. |
| `duration` | `float` | `2.0` | Duration. |
| `phase_offset` | `float` | `0.0` | Phase offset in radians - offset multiple simultaneous bobs. |

**Accessibility tag:** `TAG_SCREENSHAKE`

---

### JuiceeZoomPulseEffect

BPM-synced Camera2D zoom pulse. On each beat interval the camera zooms in by `zoom_boost`, then decays back via EASE_OUT. Use for beat-drops, bass-heavy music, rhythm-game feedback.

| Property | Type | Default | Description |
|---|---|---|---|
| `bpm` | `float` | `120.0` | Beats per minute for standalone mode. |
| `zoom_boost` | `float` | `0.08` | Zoom multiplier added per beat. `0.08` = 8% zoom in per beat. |
| `duration` | `float` | `4.0` | Total duration. |
| `clock_path` | `NodePath` | `""` | Optional `JuiceeBeatClock` in scene for tight musical sync. |
| `decay_time` | `float` | `0.35` | Seconds for each zoom to decay back. |

---

### JuiceeCameraRotationEffect

Dutch tilt - rotate Camera2D to `angle_degrees` then spring back. Three phases: tilt-in -> optional hold -> return. Uses `JuiceeStateStack` on the camera's `rotation` property for concurrent-safe restore. Car chases, punch impacts, dramatic reveals, disorientation, wave attacks.

**Accessibility tag:** `TAG_SCREENSHAKE`

| Property | Type | Default | Description |
|---|---|---|---|
| `angle_degrees` | `float` | `5.0` | Tilt angle in degrees. Negative = tilt left. Range −45 to 45. |
| `tilt_duration` | `float` | `0.3` | Seconds to tween to the tilted position. |
| `hold_duration` | `float` | `0.0` | Seconds to hold the tilt before returning. |
| `return_duration` | `float` | `0.4` | Seconds to spring back to neutral. |

---

## Object (50 effects)

Object effects target the context node directly (Node2D, CanvasItem, Control, Light2D, RigidBody2D). Most use `JuiceeStateStack` to handle concurrent safety.

---

### JuiceeFlashEffect

Blinks `modulate` on a CanvasItem N times. The quintessential hit acknowledgment.

| Property | Type | Default | Description |
|---|---|---|---|
| `flash_color` | `Color` | `Color.WHITE` | The modulate color to flash to. |
| `duration` | `float` | `0.15` | Duration per flash cycle (on + off). |
| `flash_count` | `int` | `1` | Number of flashes. |
| `boost` | `float` | `2.0` | Over-brighten multiplier on `flash_color` (modulate can exceed 1.0), so a white flash actually brightens an untinted sprite. `1.0` = plain tint. |

**Accessibility tag:** `TAG_FLASH`

---

### JuiceeModulateEffect

Smooth `modulate` color transition (unlike Flash which blinks). Tween from current color to `target_color`.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_color` | `Color` | `Color(1,0.5,0.5)` | Destination color. |
| `duration` | `float` | `0.4` | Tween duration. |
| `return_duration` | `float` | `0.3` | Time to return to original color (`0` = snap). |

---

### JuiceeBounceEffect

Squash & stretch scale punch on a Node2D. The most fundamental object feel effect.

| Property | Type | Default | Description |
|---|---|---|---|
| `scale_factor` | `float` | `1.3` | Peak scale multiplier. `1.3` = 30% bigger. |
| `squash_factor` | `float` | `0.7` | Squash phase multiplier (applied perpendicular to stretch). |
| `duration` | `float` | `0.3` | Total bounce duration. |
| `bounce_curve` | `Curve` | `null` | Optional designer curve. Falls back to TRANS_ELASTIC. |

---

### JuiceeJigglePhysicsEffect

Spring-mass jiggle on `scale` using real harmonic-oscillator physics. More flexible than canned tweens - tune stiffness/damping for the exact jelly feel you want.

| Property | Type | Default | Description |
|---|---|---|---|
| `impulse` | `Vector2` | `Vector2(0.4,-0.4)` | Initial scale impulse (X/Y perturbation). |
| `stiffness` | `float` | `8.0` | Spring stiffness constant. Higher = faster oscillation. |
| `damping` | `float` | `0.85` | Per-frame damping (0-1). Lower = more oscillations. |
| `mass` | `float` | `1.0` | Simulated mass. |
| `max_duration` | `float` | `2.0` | Max duration before force-stopping. |

---

### JuiceePositionEffect

Move Node2D by `offset` from current position, then return.

| Property | Type | Default | Description |
|---|---|---|---|
| `offset` | `Vector2` | `Vector2(0, -20)` | Displacement from the rest position, or the exact position when `relative = false`. |
| `duration` | `float` | `0.3` | Total move + return duration. |
| `return_to_original` | `bool` | `true` | Move back to the original position after the punch. |
| `relative` | `bool` | `true` | Offset from where the node already is, or the exact value to land on. |
| `trans_type` | `Tween.TransitionType` | `TRANS_BACK` | Tween transition. |
| `ease_type` | `Tween.EaseType` | `EASE_OUT` | Tween ease. |

---

### JuiceePosition3DEffect

Same as `PositionEffect` for Node3D.

| Property | Type | Default | Description |
|---|---|---|---|
| `offset` | `Vector3` | `Vector3(0, 0.5, 0)` | Displacement in world units, or the exact position when `relative = false`. |
| `duration` | `float` | `0.3` | Total move + return duration. |
| `return_to_original` | `bool` | `true` | Move back to the original position after the punch. |
| `relative` | `bool` | `true` | Offset from where the node already is, or the exact value to land on. |
| `trans_type` | `Tween.TransitionType` | `TRANS_BACK` | Tween transition. |
| `ease_type` | `Tween.EaseType` | `EASE_OUT` | Tween ease. |

---

### JuiceeRotationEffect

Rotate Node2D by `angle_degrees` then snap or tween back.

| Property | Type | Default | Description |
|---|---|---|---|
| `angle_degrees` | `float` | `15.0` | Rotation angle. Positive = clockwise. The exact angle when `relative = false`. |
| `duration` | `float` | `0.3` | Total rotate + return duration. |
| `return_to_original` | `bool` | `true` | Rotate back to the original angle after the punch. |
| `relative` | `bool` | `true` | Offset from where the node already is, or the exact value to land on. |
| `trans_type` | `Tween.TransitionType` | `TRANS_ELASTIC` | Tween transition. |
| `ease_type` | `Tween.EaseType` | `EASE_OUT` | Tween ease. |

---

### JuiceeRotation3DEffect

Rotation punch for Node3D using Basis interpolation.

| Property | Type | Default | Description |
|---|---|---|---|
| `axis` | `Vector3` | `Vector3.UP` | Rotation axis (auto-normalized). |
| `angle_degrees` | `float` | `15.0` | Angle of the punch. The exact orientation when `relative = false`. |
| `duration` | `float` | `0.3` | Total rotate + return duration. |
| `return_to_original` | `bool` | `true` | Rotate back to the original orientation after the punch. |
| `relative` | `bool` | `true` | Offset from where the node already is, or the exact value to land on. |
| `trans_type` | `Tween.TransitionType` | `TRANS_ELASTIC` | Tween transition. |
| `ease_type` | `Tween.EaseType` | `EASE_OUT` | Tween ease. |

---

### JuiceeTrailEffect

Ghost trail behind a Sprite2D by spawning semi-transparent copies at regular intervals.

| Property | Type | Default | Description |
|---|---|---|---|
| `trail_length` | `int` | `6` | Number of ghost copies. |
| `trail_interval` | `float` | `0.04` | Seconds between ghost spawns. |
| `duration` | `float` | `0.5` | Total trail duration. |
| `alpha_curve` | `Curve` | `null` | Optional custom fade curve for ghost alpha. |

---

### JuiceeBurstEffect

One-shot `CPUParticles2D` burst at the target's position. Fully configurable; no pre-existing particle node required.

| Property | Type | Default | Description |
|---|---|---|---|
| `amount` | `int` | `12` | Number of particles. |
| `color` | `Color` | `Color(1,0.8,0.3)` | Particle color. |
| `speed` | `float` | `180.0` | Initial particle speed in px/s. |
| `spread` | `float` | `120.0` | Spread angle in degrees. `360` = full circle. |
| `lifetime` | `float` | `0.6` | Particle lifetime. |
| `gravity` | `Vector2` | `Vector2(0,200)` | Applied gravity. |

---

### JuiceeConfettiEffect

Multi-color confetti burst. Colors cycle through a configurable palette.

| Property | Type | Default | Description |
|---|---|---|---|
| `amount` | `int` | `40` | Particle count. |
| `speed` | `float` | `200.0` | Initial speed. |
| `spread` | `float` | `360.0` | Spread angle. |
| `lifetime` | `float` | `1.2` | Particle lifetime. |
| `air_drag` | `float` | `0.0` | Air resistance, pieces shoot out then slow and drift like paper. `0` = ballistic. |
| `colors` | `Array[Color]` | (rainbow) | Color palette - particles cycle through these. |

---

### JuiceeLightFlashEffect

Flash a `Light2D`'s `energy` and `color`. Target must be a `Light2D` node.

| Property | Type | Default | Description |
|---|---|---|---|
| `peak_energy` | `float` | `3.0` | Peak light energy at the flash moment. |
| `flash_color` | `Color` | `Color.WHITE` | Light color at peak. |
| `duration` | `float` | `0.3` | Duration. |

---

### JuiceeSpringEffect

Harmonic-oscillator spring on any `Vector2` property. Use for bouncy menus, squash-on-hit, panel-into-view oscillation.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_path` | `NodePath` | `"."` | Node that owns the property (`.` = context). |
| `property` | `String` | `"scale"` | Property name (e.g., `"scale"`, `"position"`, `"modulate"`). |
| `impulse` | `Vector2` | `Vector2(0.3,-0.3)` | Initial velocity kick. |
| `stiffness` | `float` | `200.0` | Spring stiffness constant. |
| `damping` | `float` | `10.0` | Damping coefficient. |
| `mass` | `float` | `1.0` | Simulated mass. |
| `max_duration` | `float` | `2.0` | Force-stop after this time. |

---

### JuiceeAmbientFlashEffect

Repeating `modulate` flash for sustained danger states. Loops until `stop()` is called or `duration` expires.

| Property | Type | Default | Description |
|---|---|---|---|
| `flash_color` | `Color` | `Color(1,0.2,0.2,0.5)` | Flash color. |
| `duration` | `float` | `3.0` | Total run time (`0` = run until `stop()`). |
| `frequency` | `float` | `1.5` | Flashes per second. |
| `pulse_curve` | `Curve` | `null` | Optional custom pulse shape. |

**Accessibility tag:** `TAG_FLASH`

---

### JuiceeStrobeLightEffect

Square-wave `Light2D` energy pulse. Target must be `Light2D`. Lightning, flashbang, emergency siren.

| Property | Type | Default | Description |
|---|---|---|---|
| `pulse_count` | `int` | `6` | Number of on/off cycles. |
| `duration` | `float` | `0.5` | Total strobe duration. |
| `peak_energy` | `float` | `3.0` | Energy at the ON phase. |
| `on_ratio` | `float` | `0.5` | Fraction of each cycle spent in the ON state. |

**Accessibility tag:** `TAG_FLASH`

---

### JuiceeRecoilEffect

Directional position kick on Node2D with spring-back. Gun recoil, hit absorption.

| Property | Type | Default | Description |
|---|---|---|---|
| `direction` | `Vector2` | `Vector2(-1,0)` | Kick direction. Normalized automatically. |
| `kick_distance` | `float` | `12.0` | Displacement in pixels. |
| `return_duration` | `float` | `0.18` | Time to spring back. |
| `overshoot` | `float` | `0.2` | Spring overshoot. |

**Runtime params:** `{"direction": Vector2}` - override direction per-shot.  
**Accessibility tag:** `TAG_SCREENSHAKE`

---

### JuiceeOutlineEffect

Animates a colored outline on a `CanvasItem` via shader uniform. Selection ring, status glow, lock-on indicator.

| Property | Type | Default | Description |
|---|---|---|---|
| `outline_color` | `Color` | `Color(1,0.85,0.2)` | Outline color. |
| `outline_width` | `float` | `2.0` | Outline width in pixels. |
| `duration` | `float` | `0.8` | Duration. |
| `fade_out` | `bool` | `true` | Fade outline to 0. |
| `persistent` | `bool` | `false` | Keep outline until `stop()`. |

---

### JuiceeColorCycleEffect

Cycles `modulate` through the HSV hue wheel. Rainbow powerup, party mode, boss phase shift.

| Property | Type | Default | Description |
|---|---|---|---|
| `cycles` | `float` | `2.0` | Number of full hue cycles. |
| `duration` | `float` | `1.5` | Duration. |
| `saturation` | `float` | `1.0` | Color saturation. |
| `value` | `float` | `1.0` | Color value (brightness). |
| `preserve_alpha` | `bool` | `true` | Keep the original modulate alpha (else fully opaque). |
| `loop` | `bool` | `false` | Cycle forever until `stop()` - persistent "RAINBOW MODE". `duration` still sets cycle speed. |

---

### JuiceeSpinEffect

Full 360° rotation tween on Node2D. Coin pickups, death spin, victory twirl.

| Property | Type | Default | Description |
|---|---|---|---|
| `degrees_per_second` | `float` | `360.0` | Rotation speed. Negative = counter-clockwise. |
| `duration` | `float` | `1.0` | Total spin duration. `total_rotation = degrees_per_second * duration`. |
| `restore_on_end` | `bool` | `false` | Tween back to the original rotation when done. |
| `restore_duration` | `float` | `0.15` | Snap-back time (only with `restore_on_end`). |
| `ease_out` | `bool` | `false` | Start fast and decelerate into the stop, like a coin settling. `false` = constant speed. |
| `direction` | `float` | `1.0` | `1.0` = clockwise, `-1.0` = counter-clockwise. |

---

### JuiceeWiggleEffect

Random position jitter at `frequency` Hz with optional decay. Anxiety, confusion, low-health tremor.

| Property | Type | Default | Description |
|---|---|---|---|
| `amplitude` | `float` | `4.0` | Max displacement per axis in pixels. |
| `frequency` | `float` | `12.0` | Jitter updates per second. |
| `duration` | `float` | `0.5` | Duration. |
| `decay` | `bool` | `true` | Linearly decay amplitude to 0 over duration. |

---

### JuiceeSpriteBobEffect

Sine-wave bob along `bob_axis`. `sin(t * PI)` envelope for smooth start and stop. Floating pickups, hover loop, idle animations.

| Property | Type | Default | Description |
|---|---|---|---|
| `amplitude` | `float` | `6.0` | Bob amplitude in pixels. |
| `frequency` | `float` | `1.5` | Bobs per second. |
| `duration` | `float` | `3.0` | Duration. |
| `bob_axis` | `Vector2` | `Vector2(0,1)` | Axis to bob along. `Vector2(0,1)` = vertical. Normalized. |
| `phase_offset` | `float` | `0.0` | Phase in radians - offset multiple bobbing objects. |

---

### JuiceePopInEffect

TRANS_SPRING / EASE_OUT scale-in from `from_scale` to `1.0`. The most satisfying UI pop-in possible. Works on Node2D and Control.

| Property | Type | Default | Description |
|---|---|---|---|
| `from_scale` | `float` | `0.0` | Starting scale. `0.0` = pop in from nothing. |
| `duration` | `float` | `0.45` | Pop-in duration. Spring overshoot is handled by `TRANS_SPRING`. |

---

### JuiceeShakeControlEffect

Horizontal shake on a `Control` node with ±30% vertical noise and linear decay. Wrong-password field, invalid-action button.

| Property | Type | Default | Description |
|---|---|---|---|
| `amplitude` | `float` | `8.0` | Peak horizontal displacement in pixels. |
| `frequency` | `float` | `18.0` | Shakes per second. |
| `duration` | `float` | `0.4` | Duration (amplitude decays linearly to 0). |

---

### JuiceePulseEffect

Repeating EXPO scale pulse per interval. `count = 0` + `duration > 0` = infinite time-limited loop. Heartbeat, charge meter, selected state.

| Property | Type | Default | Description |
|---|---|---|---|
| `scale_factor` | `float` | `1.15` | Peak scale multiplier. |
| `interval` | `float` | `0.5` | Seconds between pulse peaks. |
| `count` | `int` | `0` | Fixed pulse count (`0` = time-limited by `duration`). |
| `duration` | `float` | `3.0` | Time-limit when `count = 0`. |
| `in_ratio` | `float` | `0.25` | Fraction of interval used for the scale-up phase. |

---

### JuiceeFadeEffect

Fade a CanvasItem's `modulate.a` to `target_alpha` over `duration`. With `restore_on_end = true`: fade to target, hold, then fade back to original. The most fundamental UI and game effect - always use this instead of tweening `modulate.a` manually.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_alpha` | `float` | `0.0` | Target alpha (0=transparent, 1=opaque). |
| `duration` | `float` | `0.5` | Duration to reach `target_alpha`. |
| `restore_on_end` | `bool` | `false` | Fade back to original alpha after hold. |
| `hold_duration` | `float` | `0.0` | Seconds to hold at `target_alpha` before restoring. |
| `restore_duration` | `float` | `0.4` | Duration of the return fade. |
| `transition` | `Tween.TransitionType` | `TRANS_SINE` | Tween transition type. |
| `easing` | `Tween.EaseType` | `EASE_IN_OUT` | Tween ease type. |

---

### JuiceeFlipEffect

Set `flip_h` / `flip_v` on a Sprite2D or AnimatedSprite2D using a per-axis mode: `TOGGLE` (invert), `SET_TRUE` (force flipped), or `SET_FALSE` (force unflipped). Optional `restore_on_end` with configurable hold time.

| Property | Type | Default | Description |
|---|---|---|---|
| `flip_h_mode` | `Mode` | `TOGGLE` | How to change `flip_h`: `TOGGLE`, `SET_TRUE`, or `SET_FALSE`. |
| `flip_v_mode` | `Mode` | `SET_FALSE` | How to change `flip_v`. `SET_FALSE` = no change to vertical flip. |
| `restore_on_end` | `bool` | `false` | Restore original flip state after hold. |
| `hold_duration` | `float` | `0.0` | Seconds to hold the new state before restoring. |

---

### JuiceeInstantiateEffect

Spawn a `PackedScene` at the context node's world position. Adds to the current scene tree under `parent_path` (or the root scene). Auto-frees the instance after `lifetime` seconds. Works for both 2D and 3D contexts.

| Property | Type | Default | Description |
|---|---|---|---|
| `scene` | `PackedScene` | `null` | Scene to spawn. Required - effect is a no-op if null. |
| `position_offset` | `Vector2` | `Vector2.ZERO` | World-space offset added to the context's position. |
| `parent_path` | `NodePath` | `""` | Parent node path. Empty = scene's current root. |
| `lifetime` | `float` | `2.0` | Seconds until the spawned instance is queue_freed. `0` = never auto-free. |
| `inherit_rotation` | `bool` | `false` | Copy the context's rotation to the spawned instance. |
| `inherit_scale` | `bool` | `false` | Copy the context's scale to the spawned instance. |

---

### JuiceeSizeDeltaEffect

Tween a Control node's `custom_minimum_size` or `size` to `target_size`. With `restore_on_end = true`, tweens back to the original size after an optional hold. Use `CUSTOM_MINIMUM_SIZE` for anchored layouts; `SIZE` for freely-positioned Controls.

| Property | Type | Default | Description |
|---|---|---|---|
| `size_target` | `SizeTarget` | `CUSTOM_MINIMUM_SIZE` | `CUSTOM_MINIMUM_SIZE` or `SIZE`. |
| `target_size` | `Vector2` | `Vector2(200, 50)` | Target size in pixels. |
| `duration` | `float` | `0.3` | Duration to reach `target_size`. |
| `restore_on_end` | `bool` | `false` | Tween back to original size after hold. |
| `hold_duration` | `float` | `0.0` | Seconds to hold at `target_size` before restoring. |
| `restore_duration` | `float` | `0.2` | Duration of the return tween. |
| `transition` | `Tween.TransitionType` | `TRANS_QUAD` | Tween transition type. |
| `easing` | `Tween.EaseType` | `EASE_OUT` | Tween ease type. |

---

### JuiceeShaderParameterEffect

Tween any `ShaderMaterial` uniform from `from_value` to `to_value`. Works on `CanvasItem` (reads `material` directly) and `MeshInstance3D` (reads `get_surface_override_material(surface_index)`). Falls back to mesh's base material if no override. Drive dissolve, emission intensity, scanline density - any float/vec/color uniform.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_path` | `NodePath` | `""` | Node with the shader material. Empty = context node. |
| `surface_index` | `int` | `0` | Surface index for MeshInstance3D. |
| `parameter_name` | `String` | `""` | Shader uniform name (without `shader_parameter/` prefix). |
| `from_value` | `Variant` | `0.0` | Start value. |
| `to_value` | `Variant` | `1.0` | End value. |
| `duration` | `float` | `0.5` | Tween duration. |
| `restore_on_end` | `bool` | `false` | Restore original uniform value when done. |
| `transition` | `Tween.TransitionType` | `TRANS_SINE` | Tween transition type. |
| `easing` | `Tween.EaseType` | `EASE_IN_OUT` | Tween ease type. |

---

### JuiceeFlickerEffect

Organic random modulate flicker on a CanvasItem. Randomises on/off intervals from `[min_interval, max_interval]`. `duration = 0` runs indefinitely until `stop()` is called. Torches, broken neon signs, ghost transparency, dying machinery, flickering hazard lights.

**Accessibility tag:** `TAG_FLASH`

| Property | Type | Default | Description |
|---|---|---|---|
| `off_color` | `Color` | `Color(0,0,0,0)` | Modulate color when "off". Default = transparent. |
| `min_interval` | `float` | `0.04` | Minimum seconds between state changes. |
| `max_interval` | `float` | `0.15` | Maximum seconds between state changes. |
| `duration` | `float` | `1.5` | Total run time. `0` = infinite until `stop()`. |
| `off_chance` | `float` | `0.3` | Probability (0-1) that each interval switches to "off". |

---

### JuiceeScaleEffect

General scale tween on `Node2D` or `Control` to `target_scale` with optional return to original. Unlike `BounceEffect` (squash-and-stretch math), this tweens directly to a designer-specified absolute scale. Use for emphasis, selection highlight, or UI panel resize.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_scale` | `Vector2` | `Vector2(1.5, 1.5)` | Scale multiplier when `relative`, otherwise the exact scale to reach. |
| `duration` | `float` | `0.3` | Seconds to reach `target_scale`. |
| `return_to_original` | `bool` | `true` | Tween back to original scale after. |
| `return_duration` | `float` | `0.2` | Duration of the return tween. |
| `relative` | `bool` | `true` | Multiply the node's current scale, or treat `target_scale` as the exact scale to land on. |
| `transition` | `Tween.TransitionType` | `TRANS_QUAD` | Tween transition type. |
| `easing` | `Tween.EaseType` | `EASE_OUT` | Tween ease type. |

---

### JuiceeScale3DEffect

The Node3D counterpart of `JuiceeScaleEffect`. Scale punch with an optional spring back. Pickups, impacts, props that grow and shrink.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_scale` | `Vector3` | `Vector3(1.5, 1.5, 1.5)` | Scale multiplier when `relative`, otherwise the exact scale to reach. |
| `duration` | `float` | `0.3` | Seconds to reach `target_scale`. |
| `return_to_original` | `bool` | `true` | Spring back to the original scale after. |
| `return_duration` | `float` | `0.25` | Duration of the return tween. |
| `relative` | `bool` | `true` | Multiply the node's current scale, or treat `target_scale` as the exact scale to land on. |
| `trans_type` | `Tween.TransitionType` | `TRANS_BACK` | Tween transition type. |
| `ease_type` | `Tween.EaseType` | `EASE_OUT` | Tween ease type. |

---

### JuiceeParticleEffect

Control an existing `CPUParticles2D` or `GPUParticles2D` by NodePath. Four actions: `EMIT` (enable + optional one-shot), `STOP`, `RESTART`, `TOGGLE`. Optional `wait_for_finish` stalls the calling sequence until the particle system's lifetime elapses.

| Property | Type | Default | Description |
|---|---|---|---|
| `particle_path` | `NodePath` | `""` | Path to the CPUParticles2D or GPUParticles2D. |
| `action` | `Action` | `EMIT` | `EMIT`, `STOP`, `RESTART`, or `TOGGLE`. |
| `wait_for_finish` | `bool` | `false` | Await the particle system's `lifetime` before continuing. |

---

### JuiceeLight3DEffect

Flash a `Light3D`'s energy and color to a peak value then decay back. Uses `JuiceeStateStack` to restore `light_energy` and `light_color` safely under concurrent calls. Muzzle flash, explosion light, magic pulse, flickering candle highlight.

**Dimensions:** 3D only

| Property | Type | Default | Description |
|---|---|---|---|
| `light_path` | `NodePath` | `""` | Path to Light3D. Empty = context node if it is a Light3D. |
| `peak_energy` | `float` | `5.0` | Peak `light_energy` at flash apex. |
| `flash_color` | `Color` | `Color.WHITE` | `light_color` during the flash. |
| `duration` | `float` | `0.25` | Total flash duration (fade-in 30% / hold 20% / fade-out 50%). |
| `restore_energy` | `bool` | `true` | Restore original energy/color on finish. |

---

### JuiceeMaterial3DEffect

Animate any property on a `MeshInstance3D`'s surface material. **Duplicates the material at apply time** to avoid affecting other mesh instances sharing the same resource. Configurable `restore_on_end`. Dissolve in/out, emission ramp, fresnel fade, hit-flash on 3D meshes.

**Dimensions:** 3D only

| Property | Type | Default | Description |
|---|---|---|---|
| `mesh_path` | `NodePath` | `""` | Path to MeshInstance3D. Empty = context node. |
| `surface_index` | `int` | `0` | Surface index on the mesh. |
| `property_name` | `String` | `""` | Material property path (e.g. `"albedo_color"`, `"emission_energy_multiplier"`). |
| `from_value` | `Variant` | `0.0` | Start value. |
| `to_value` | `Variant` | `1.0` | End value. |
| `duration` | `float` | `0.5` | Tween duration. |
| `restore_on_end` | `bool` | `false` | Restore original property value when done. |

---

### JuiceeImpactRingEffect

Expanding ring + radiating "POW" spikes drawn at a Node2D in world-space (`Line2D`, no shaders). Crits, parries, big landings, small explosions. Distinct from the full-screen shader `JuiceeShockwaveEffect` - this geometry sits on the object. *(New in 1.2.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `radius` | `float` | `42.0` | Ring radius in pixels at full scale. |
| `expand` | `float` | `2.4` | Final scale the flourish expands to. |
| `ring_width` | `float` | `5.0` | Ring line thickness in pixels. |
| `color` | `Color` | `(1, 0.85, 0.3)` | Ring + spike colour. |
| `spikes` | `int` | `8` | Radiating spike count (0 = ring only). |
| `spike_length` | `float` | `26.0` | How far each spike extends past the ring. |
| `duration` | `float` | `0.36` | Expand + fade duration. |

---

### JuiceeSwayEffect

Smooth pendulum rotation driven by a sine wave. Unlike `JuiceeWiggleEffect` (random jitter) or `JuiceeSpinEffect` (full revolution), it's a soft looping tilt. Idle "alive" UI, hanging signs, floating pickups, breathing titles. Works on Node2D and Control. *(New in 1.2.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `angle` | `float` | `6.0` | Peak sway angle to each side, in degrees. |
| `period` | `float` | `1.2` | Seconds for one full left->right->left cycle. |
| `cycles` | `float` | `2.0` | Full cycles to run. `0` = sway forever (until `stop()`). |
| `center_pivot` | `bool` | `true` | For Control targets, rotate around the centre instead of the corner. |

---

### JuiceeAfterimageEffect

Drops fading `Sprite2D` copies behind the node as it moves. Dashes, dodges, speed power-ups. The target (or its first Sprite2D child) supplies the texture. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `duration` | `float` | `0.3` | How long to keep dropping ghosts (match it to your dash length). |
| `interval` | `float` | `0.04` | Seconds between ghosts. Smaller = a denser trail. |
| `ghost_lifetime` | `float` | `0.35` | How long each ghost takes to fade out. |
| `color` | `Color` | `(0.6, 0.9, 1, 0.6)` | Ghost tint (multiplies the sprite). Alpha sets the starting opacity. |

---

### JuiceeBreatheEffect

A slow in-and-out idle scale loop. Living characters, resting pickups, soft title screens. `cycles = 0` breathes forever (until `stop()`). *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `amount` | `float` | `0.05` | How much it grows on the in-breath (`0.05` = 5% bigger at the peak). |
| `period` | `float` | `2.0` | Seconds per breath. |
| `cycles` | `int` | `3` | Number of breaths. `0` = forever. |

---

### JuiceeCrackEffect

Jagged fracture lines radiating from the impact point (`Line2D`, no shaders), then fading. Heavy landings, boss slams, shatters. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `count` | `int` | `5` | How many cracks radiate from the impact point. |
| `length` | `float` | `70.0` | How far each crack reaches, in pixels. |
| `jaggedness` | `float` | `0.4` | How much each crack zig-zags (`0` = straight spokes). |
| `thickness` | `float` | `5.0` | Line thickness at the base (each crack tapers to its tip). |
| `duration` | `float` | `0.5` | How long the cracks stay before fading. |
| `color` | `Color` | `(0.95, 0.95, 1, 0.9)` | Crack colour. |

---

### JuiceeGlowPulseEffect

A tinted brightness throb on the node's `modulate`. Charge-ups, power states, button shine. A white tint just brightens; a coloured tint pushes toward that hue at the peak. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `peak` | `float` | `1.8` | Brightness multiplier at the peak of each pulse. |
| `tint` | `Color` | `WHITE` | Colour the modulate moves toward at the peak. |
| `duration` | `float` | `0.5` | Duration of a single pulse (up and back). |
| `count` | `int` | `1` | How many pulses. |

---

### JuiceeHeartbeatEffect

A double-thump scale pulse (a big beat, then a smaller one) at a set BPM. Low health, tension, lock-on. `duration = 0` plays a single beat. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `amount` | `float` | `0.18` | Scale-up of the first (big) pop. The second pop is smaller. |
| `bpm` | `float` | `70.0` | Beats per minute. |
| `duration` | `float` | `2.0` | Total time. `0` = a single beat. |

---

### JuiceeHitSparkEffect

A directional spark spray off a hit point, aimed by the `hit_direction` runtime param. Clangs, parries, ricochets. Spawns short-lived `Line2D` sparks in 2D world-space. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `amount` | `int` | `10` | How many sparks fly. |
| `speed` | `float` | `420.0` | Spark speed (the actual value is randomized around this). |
| `cone` | `float` | `24.0` | Cone width in degrees around the hit direction. Small = a tight spray. |
| `lifetime` | `float` | `0.25` | How long each spark lives. |
| `color` | `Color` | `(1, 0.95, 0.6)` | Spark colour. |
| `default_direction` | `Vector2` | `RIGHT` | Aim used when no `hit_direction` is passed. |
| `gravity` | `Vector2` | `(0, 600)` | Gravity pulling the sparks down (`0` = a straight cone). |
| `spark_scale` | `float` | `1.4` | Visual size of each spark. |

---

### JuiceeHopEffect

A quick parabolic bounce up from and back to the resting position. Pickups, idle bobs, acknowledgements. Targets `position`. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `height` | `float` | `24.0` | How high it hops, in pixels. |
| `duration` | `float` | `0.4` | Total up + down time. |

---

### JuiceeJellyWobbleEffect

A decaying axis-stretch wobble that squishes the node along alternating axes. Squishy hits, gel bodies, gummy landings. Targets `scale`. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `amount` | `float` | `0.25` | Peak scale deviation at the start (`0.25` wobbles between ~75% and ~125%). |
| `frequency` | `float` | `4.0` | Wobbles per second. |
| `duration` | `float` | `0.6` | Total wobble time. |
| `decay` | `float` | `3.0` | How fast the wobble dies down (`0` = constant). |

---

### JuiceeSlashArcEffect

A crescent melee swoosh (a tapering `Line2D`) sweeping around the node, centred on `hit_direction`. Sword swings, claws, dash-attacks. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `radius` | `float` | `60.0` | How far from the node the slash sweeps. |
| `arc_degrees` | `float` | `140.0` | Angular length of the arc, how wide the swoosh is. |
| `thickness` | `float` | `14.0` | Thickness at the fattest point (the ends taper to nothing). |
| `duration` | `float` | `0.22` | How long the slash lasts before it's gone. |
| `color` | `Color` | `(1, 1, 1, 0.9)` | Slash colour. |
| `default_direction` | `Vector2` | `RIGHT` | Facing used when no `hit_direction` is passed. |

---

### JuiceeSparkleEffect

A scatter of little star pops around the node, appearing and fading. Pickups, collectibles, UI shine. The count thins out under Quality / LOD. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `count` | `int` | `6` | How many sparkles scatter around the node. |
| `spread` | `float` | `36.0` | Radius of the area the sparkles scatter over. |
| `sparkle_scale` | `float` | `2.0` | Visual size of each sparkle. |
| `color` | `Color` | `(1, 1, 0.7)` | Sparkle colour. |
| `duration` | `float` | `0.6` | Total time over which the sparkles appear and fade. |

---

### JuiceeSquashLandEffect

Flattens the node on impact (wide and short), then springs it back to shape. Platformer landings, stomps, jelly hops. Targets Node2D / Control via `scale`. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `squash_amount` | `float` | `0.4` | Squash strength at impact. `0.4` is about 140% wide / 60% tall at the peak. |
| `duration` | `float` | `0.35` | Total time for the squash plus the recovery. |
| `bounce` | `float` | `0.5` | Springiness of the recovery. `0` eases straight back with no rebound. |

---

### JuiceeStretchEffect

A directional smear-stretch (long along the motion axis, thin across it) that snaps back. Dash starts, launches, anticipation poses. Axis from `hit_direction`. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `amount` | `float` | `0.5` | How much it stretches (`0.5` = ~150% along the axis, ~70% across). |
| `stretch_time` | `float` | `0.08` | Time spent stretching out. |
| `return_time` | `float` | `0.2` | Time spent snapping back. |
| `default_direction` | `Vector2` | `RIGHT` | Axis used when no `hit_direction` is passed. |

---

### JuiceeWobbleRotationEffect

A decaying rotational shake that tilts the node back and forth and settles. Bumps, denials, jiggle reactions. Targets `rotation`. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `amount_degrees` | `float` | `18.0` | Peak tilt in degrees at the start. |
| `frequency` | `float` | `5.0` | Wobbles per second. |
| `duration` | `float` | `0.6` | Total time. |
| `decay` | `float` | `4.0` | How fast it settles (`0` = constant, higher = sooner). |

---

## Text (8 effects)

Text effects target `Label`, `RichTextLabel`, or `Control` nodes.

---

### JuiceeDamageNumberEffect

Spawns a floating damage number above the target Node2D. Crit support via runtime params.

| Property | Type | Default | Description |
|---|---|---|---|
| `base_color` | `Color` | `Color.WHITE` | Normal hit color. |
| `crit_color` | `Color` | `Color(1,0.85,0.2)` | Critical hit color. |
| `font_size` | `int` | `18` | Normal font size. |
| `crit_font_size` | `int` | `26` | Crit font size. |
| `float_height` | `float` | `60.0` | Pixels the number floats upward. |
| `duration` | `float` | `0.9` | Lifetime of the spawned label. |
| `offset` | `Vector2` | `Vector2(0,-20)` | Initial spawn offset from context. |

**Runtime params:** `{"damage": int, "is_crit": bool}` - pass via `play()` or `Juicee.damage_number()`.

---

### JuiceeFloatingTextEffect

Generic floating text label above a Node2D. Level Up!, pickup names, status messages.

| Property | Type | Default | Description |
|---|---|---|---|
| `text_color` | `Color` | `Color.WHITE` | Label color. |
| `font_size` | `int` | `16` | Font size. |
| `float_height` | `float` | `50.0` | Float travel distance. |
| `duration` | `float` | `0.8` | Lifetime. |
| `travel_mode` | `int` | `0` | `0`=up, `1`=down, `2`=random horizontal. |

**Runtime params:** `{"text": String, "color": Color}` - dynamically set text and color.

---

### JuiceeButtonPunchEffect

Scale punch for `Control` nodes. Bouncy button click, menu item highlight.

| Property | Type | Default | Description |
|---|---|---|---|
| `scale_factor` | `float` | `1.15` | Peak scale. |
| `duration` | `float` | `0.25` | Duration. |
| `punch_color` | `Color` | `Color.WHITE` | Optional modulate flash during punch (set alpha `0` to skip). |

---

### JuiceeTypewriterEffect

Char-by-char text reveal on a `Label` via `visible_ratio`. Dialog, intros, terminal vibes.

| Property | Type | Default | Description |
|---|---|---|---|
| `chars_per_second` | `float` | `30.0` | Reveal speed. |
| `click_sounds` | `Array[AudioStream]` | `[]` | Optional click sounds, one picked at random per character. |
| `click_volume_db` | `float` | `-6.0` | Click volume in dB. |
| `click_pitch_variance` | `float` | `1.15` | Random pitch range per click (`1.0` = no variance). |
| `skip_whitespace_clicks` | `bool` | `true` | Don't click on spaces. |
| `punctuation_pause` | `float` | `0.0` | Extra pause after `. ! ?` (half after `, ; :`) so typing breathes like speech. `0` = even pacing. |

**Runtime params:** `{"text": String}` - set the text to reveal.

---

### JuiceeNumberCountEffect

Tween a `Label`'s displayed number from X to Y. Score rollups, money counters, XP bars.

| Property | Type | Default | Description |
|---|---|---|---|
| `duration` | `float` | `1.0` | Tween duration. |
| `number_format` | `String` | `"%d"` | Printf format string. `"%.1f"` for decimals. |
| `prefix` | `String` | `""` | Text before the number. |
| `suffix` | `String` | `""` | Text after the number (e.g. `"G"` for gold). |

**Runtime params:** `{"from": float, "to": float}` - start and end values.

---

### JuiceeTextWobbleEffect

Sine-wave wobble on a `Control`'s position with linear decay. Drama text - GAME OVER, WAVE COMPLETE, BOSS APPROACHING.

| Property | Type | Default | Description |
|---|---|---|---|
| `amplitude` | `float` | `4.0` | Max offset in pixels. |
| `frequency` | `float` | `8.0` | Oscillations per second. |
| `duration` | `float` | `0.5` | Duration (amplitude decays to 0). |

---

### JuiceeTextScrambleEffect

Reveals a `Label`'s text by cycling random characters that lock in left to right. Decoding, hacker terminals, glitchy reveals. Pass the text via the `text` runtime param. *(New in 1.3.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `default_text` | `String` | `"DECODING"` | Text shown when the caller doesn't pass a `text` param. |
| `duration` | `float` | `0.8` | How long the scramble takes to fully resolve. |
| `charset` | `String` | `A-Z 0-9 !@#$%&*` | Characters cycled through for the not-yet-locked positions. |

---

### JuiceeRichTextEmphasisEffect

Temporarily wraps a `RichTextLabel`'s text (or one phrase in it) in an animated BBCode tag, then puts it back. Dialogue emphasis, tutorial callouts, cursed item names. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `mode` | `int` | `0` (Wave) | Animation: Wave, Shake, Rainbow, Tornado. |
| `phrase` | `String` | `""` | Phrase to emphasize. Empty = the whole text. Override per play with a `phrase` param. |
| `duration` | `float` | `1.5` | How long the emphasis lasts. `0` = stays until `stop()`. |

---

## Time (5 effects)

Time effects manipulate `Engine.time_scale`. They use real-time timers to restore state.

---

### JuiceeHitStopEffect

Instant `Engine.time_scale` freeze for tactile impact moments. ~50-100ms is the sweet spot for melee combat. Sets `time_scale` to `time_scale_during` for `freeze_duration`, then restores.

| Property | Type | Default | Description |
|---|---|---|---|
| `freeze_duration` | `float` | `0.08` | Duration in real-time seconds. |
| `time_scale_during` | `float` | `0.0` | `time_scale` value during freeze. `0.0` = full stop. |

---

### JuiceeTimeScaleRampEffect

Smooth slow-motion with ramp-in / hold / ramp-out. Bullet time, dramatic moments.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_scale` | `float` | `0.2` | Slow-mo `time_scale`. `0.1` = 10x slower. |
| `ramp_in` | `float` | `0.3` | Seconds to ramp from `1.0` to `target_scale`. |
| `hold` | `float` | `0.4` | Seconds to hold at `target_scale`. |
| `ramp_out` | `float` | `0.4` | Seconds to return to `1.0`. |

---

### JuiceeDelayEffect

Pure wait - `apply()` awaits a timer then returns. Useful for sequencing in a `JuiceeSequence`.

| Property | Type | Default | Description |
|---|---|---|---|
| `wait_time` | `float` | `0.5` | Seconds to wait. |
| `real_time` | `bool` | `false` | If `true`, uses real-time (ignores `time_scale`). |

---

### JuiceeFreezeFrameEffect

`Engine.time_scale = 0.0` for `duration` real-time seconds with optional white flash overlay. Visually heavier than `HitStop` - use for finishing blows, super-move activations, dramatic moments.

| Property | Type | Default | Description |
|---|---|---|---|
| `duration` | `float` | `0.06` | Real-time freeze duration. |
| `use_flash` | `bool` | `true` | Show white full-screen flash overlay. |
| `flash_color` | `Color` | `Color(1,1,1,0.9)` | Flash overlay color. |
| `flash_fade` | `float` | `0.08` | Seconds to fade out the flash after time resumes. |

---

### JuiceeStutterEffect

A rapid burst of micro-freezes (machine-gun hit-stop), each a brief `Engine.time_scale` drop with a gap between. Hit flurries, glitches, power surges. *(New in 1.3.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `count` | `int` | `5` | How many freeze stutters. |
| `freeze_time` | `float` | `0.03` | Real seconds each freeze lasts. |
| `gap_time` | `float` | `0.03` | Real seconds of normal speed between freezes. |
| `time_scale_during` | `float` | `0.0` | `Engine.time_scale` during each freeze (`0` = full stop). |

---

## Audio (10 effects)

Audio effects target audio buses or spawn temporary `AudioStreamPlayer` nodes. They work in both 2D and 3D scenes.

---

### JuiceeSoundEffect

Plays a random `AudioStream` from an array with pitch variance. Drop-in sound player without needing a persistent `AudioStreamPlayer` in the scene.

| Property | Type | Default | Description |
|---|---|---|---|
| `streams` | `Array[AudioStream]` | `[]` | Pool of streams - one picked at random per play. |
| `volume_db` | `float` | `0.0` | Volume offset in dB. |
| `pitch_min` | `float` | `0.9` | Min pitch scale. |
| `pitch_max` | `float` | `1.1` | Max pitch scale. |
| `bus` | `StringName` | `"Master"` | Target audio bus. |

---

### JuiceeMusicDuckEffect

Temporarily lower an audio bus volume then restore. Useful for momentarily quieting music under a cutscene voice line.

| Property | Type | Default | Description |
|---|---|---|---|
| `bus_name` | `StringName` | `"Music"` | Audio bus to duck. |
| `target_db` | `float` | `-12.0` | Ducked volume in dB. |
| `duck_time` | `float` | `0.2` | Ramp-down time. |
| `hold_time` | `float` | `1.0` | Hold at ducked volume. |
| `restore_time` | `float` | `0.4` | Ramp-up back to original. |

---

### JuiceeRumbleEffect

Gamepad vibration via `Input.start_joy_vibration()`.

| Property | Type | Default | Description |
|---|---|---|---|
| `weak_magnitude` | `float` | `0.5` | High-frequency motor magnitude (0-1). |
| `strong_magnitude` | `float` | `0.5` | Low-frequency motor magnitude (0-1). |
| `duration` | `float` | `0.2` | Vibration duration. |
| `device` | `int` | `0` | Gamepad device index. |

---

### JuiceeReverbEffect

Temporarily injects an `AudioEffectReverb` on an audio bus with wet ramp in/out. Boss intros, low-health states, cave echoes.

| Property | Type | Default | Description |
|---|---|---|---|
| `bus_name` | `StringName` | `"Master"` | Target audio bus. |
| `peak_wet` | `float` | `0.45` | Peak reverb wet mix (0-1). |
| `room_size` | `float` | `0.7` | Reverb room size. |
| `duration` | `float` | `1.5` | Total duration including fade in/out. |
| `fade_out` | `bool` | `true` | Fade reverb wet to 0 at the end. |

---

### JuiceePitchShiftEffect

Temporarily injects an `AudioEffectPitchShift` on an audio bus. Underwater, slow-mo audio, demon transformation.

| Property | Type | Default | Description |
|---|---|---|---|
| `bus_name` | `StringName` | `"Master"` | Target audio bus. |
| `target_pitch` | `float` | `0.7` | Target pitch scale. `0.5` = octave down, `2.0` = octave up. |
| `duration` | `float` | `1.0` | Duration. |
| `ramp_in` | `float` | `0.2` | Seconds to ramp from `1.0` to `target_pitch`. |
| `ramp_out` | `float` | `0.3` | Seconds to return to `1.0`. |

---

### JuiceeLowPassEffect

Ramps a temporary `AudioEffectLowPassFilter` on an audio bus from fully open down to `target_cutoff` and back - the muffled-on-hit, underwater, stunned/concussed, behind-a-wall feel. Pairs perfectly with Hit Stop. *(New in 1.2.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `bus_name` | `String` | `"Master"` | Target audio bus. |
| `target_cutoff` | `float` | `500.0` | Cutoff (Hz) at full muffle. Lower = more muffled (≈500 = "behind a wall"). |
| `duration` | `float` | `0.6` | Total duration: ramp-in + hold + ramp-out. |
| `ramp_in_fraction` | `float` | `0.15` | Fraction of duration spent muffling. |
| `ramp_out_fraction` | `float` | `0.35` | Fraction of duration spent opening back up. |

---

### JuiceeAudioSource3DEffect

Spawn a temporary `AudioStreamPlayer3D` at the context node's world position and play a random stream from the pool. The player is auto-freed when it finishes. For 2D contexts, derives 3D position from `Node2D.global_position` with a pixel-to-metre scale factor. Spatial SFX, footsteps, explosions, any world-space 3D sound.

| Property | Type | Default | Description |
|---|---|---|---|
| `streams` | `Array[AudioStream]` | `[]` | Pool of streams - one is chosen at random per play. |
| `volume_db` | `float` | `0.0` | Playback volume in dB. |
| `pitch_min` | `float` | `0.9` | Minimum pitch scale for random variance. |
| `pitch_max` | `float` | `1.1` | Maximum pitch scale for random variance. |
| `bus` | `StringName` | `"Master"` | Target audio bus. |
| `max_distance` | `float` | `20.0` | `AudioStreamPlayer3D.max_distance` (metres). |
| `attenuation_model` | `int` | `0` | `AudioStreamPlayer3D.attenuation_model` enum value. |
| `position_offset` | `Vector3` | `Vector3.ZERO` | World-space offset added to the spawn position. |

---

### JuiceeDistortionEffect

Ramps a temporary `AudioEffectDistortion` onto a bus and back. Blown speakers, radios, damage states. Pairs with Hit Stop, like Reverb / Low-Pass. *(New in 1.3.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `bus_name` | `String` | `"Master"` | Name of the audio bus to distort. |
| `peak_drive` | `float` | `0.5` | Peak distortion drive. |
| `mode` | `int` | `0` (Clip) | Distortion flavour: Clip, ATan, LoFi, Overdrive, WaveShape. |
| `duration` | `float` | `0.8` | Total duration: ramp-in + hold + ramp-out. |
| `ramp_in_fraction` | `float` | `0.15` | Ramp-in fraction of the duration. |
| `ramp_out_fraction` | `float` | `0.35` | Ramp-out fraction of the duration. |

---

### JuiceeTremoloEffect

Rhythmically wobbles an audio bus's volume up and down, a pulsing amplitude wobble. Underwater moments, dizziness, power fluctuation, radio interference. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `bus` | `StringName` | `Master` | Audio bus to wobble. |
| `depth_db` | `float` | `-12.0` | How deep each dip goes, in dB below the current volume. |
| `rate` | `float` | `6.0` | Wobbles per second. |
| `duration` | `float` | `1.5` | Total time the tremolo runs. |

---

### JuiceeProcSoundEffect

Synthesize a retro game sound at runtime with `JuiceeSfxr` (a GDScript sfxr port) - no audio asset needed. Coin pickups, laser shots, explosions, jumps, UI blips.

| Property | Type | Default | Description |
|---|---|---|---|
| `category` | `JuiceeSfxr.Category` | `PICKUP_COIN` | Which sfxr sound family to synthesize. |
| `sound_seed` | `int` | `0` | Fixed seed reproduces the exact same sound; `0` = a fresh variation each play. |
| `bus` | `StringName` | `&"Master"` | Audio bus to route playback through. |
| `volume_db` | `float` | `0.0` | Playback volume in decibels. |
| `pitch_min` | `float` | `1.0` | Minimum pitch multiplier (randomized per play). |
| `pitch_max` | `float` | `1.0` | Maximum pitch multiplier. |

---

## Physics (5 effects)

---

### JuiceeImpulseEffect

Applies a physics impulse to a `RigidBody2D`. Knockback, explosion push, projectile impact.

| Property | Type | Default | Description |
|---|---|---|---|
| `impulse` | `Vector2` | `Vector2(0,-300)` | Impulse vector in pixel-units. |
| `at_position` | `Vector2` | `Vector2.ZERO` | Local position for torque (zero = center of mass). |

**Runtime params:** `{"impulse": Vector2}` - override direction/magnitude per-hit.

---

### JuiceeAddForceEffect

Apply an impulse or continuous force to `RigidBody2D` or `RigidBody3D`. Three modes: `IMPULSE` (instant `apply_impulse`/`apply_central_impulse`), `CONSTANT_FORCE` (sustained over `duration` then cleared if `clear_force_on_end`), `TORQUE_IMPULSE` (angular velocity kick). Explosion push, wind gusts, magnetic pull, knockback, conveyor belts, one-shot jumps.

| Property | Type | Default | Description |
|---|---|---|---|
| `force` | `Vector2` | `Vector2(0,-300)` | Force/impulse for RigidBody2D. |
| `force_3d` | `Vector3` | `Vector3(0,5,0)` | Force/impulse for RigidBody3D. |
| `mode` | `Mode` | `IMPULSE` | `IMPULSE`, `CONSTANT_FORCE`, or `TORQUE_IMPULSE`. |
| `duration` | `float` | `0.3` | Sustain time for CONSTANT_FORCE mode. |
| `clear_force_on_end` | `bool` | `true` | Remove the constant force after `duration` (CONSTANT_FORCE only). |
| `at_position` | `Vector2` | `Vector2.ZERO` | Local position for offset impulse (2D only). |

---

### JuiceeKnockbackEffect

Shoves a `RigidBody2D` along `hit_direction` (falling back to `default_direction`), scaled by `force`. Aimed hit reactions, unlike Impulse's fixed vector. *(New in 1.3.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `target` | `NodePath` | `(empty)` | Path to the RigidBody2D. Empty = the context must be one. |
| `force` | `float` | `400.0` | Impulse strength (pixels/sec of velocity added). |
| `default_direction` | `Vector2` | `RIGHT` | Direction used when no `hit_direction` is passed. |

---

### JuiceeExplosionPushEffect

A radial impulse that shoves every `RigidBody2D` within `radius` away from the origin, falling off with distance. The whole-blast version of Impulse. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `origin` | `NodePath` | `(empty)` | Path to the blast origin (a Node2D). Empty = the context is the origin. |
| `radius` | `float` | `200.0` | Blast radius in pixels. Bodies outside get nothing. |
| `force` | `float` | `600.0` | Peak impulse at the centre. Falls off to `0` at the edge. |
| `falloff_exponent` | `float` | `1.0` | Falloff shape. `1` = linear, `2` = quadratic (softer edges). |
| `max_bodies` | `int` | `64` | Max bodies the query returns. |

---

### JuiceeGravityShiftEffect

Temporarily scales a `RigidBody2D`'s gravity then eases it back. Float and levitate moments, low-gravity zones, heavy slam-downs. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `target` | `NodePath` | `(empty)` | Path to the RigidBody2D. Empty = the context must be one. |
| `gravity_scale` | `float` | `0.0` | Gravity multiplier during the effect (`0` = weightless, `<0` = upward). |
| `duration` | `float` | `1.0` | How long the shifted gravity holds at full strength. |
| `blend_time` | `float` | `0.15` | Seconds to ease into and out of the shifted gravity. |

---

## Flow (12 effects)

Flow effects compose or coordinate other effects. They work in both 2D and 3D scenes.

---

### JuiceeSequenceEffect

Embeds another `JuiceeSequence` as a single step. Use for composable preset libraries - build a "hit reaction" `.tres`, then reference it from multiple sequences.

| Property | Type | Default | Description |
|---|---|---|---|
| `sequence` | `JuiceeSequence` | `null` | The embedded sequence to play. |

---

### JuiceePropertyTweenEffect

Tween any property on any node. Universal escape hatch for one-off tweens.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_path` | `NodePath` | `"."` | Node to tween (`.` = context). |
| `property` | `String` | `""` | Property name (e.g. `"position:x"`, `"material:shader_parameter/strength"`). |
| `from_value` | `Variant` | `null` | Start value (`null` = current value). |
| `to_value` | `Variant` | `null` | End value. |
| `duration` | `float` | `0.5` | Tween duration. |
| `transition` | `int` | `TRANS_QUAD` | `Tween.TransitionType`. |
| `easing` | `int` | `EASE_OUT` | `Tween.EaseType`. |

---

### JuiceeAnimationPlayerEffect

Triggers `AnimationPlayer.play()` as a sequence step. FEEL parity - blend Godot animations into Juicee sequences.

| Property | Type | Default | Description |
|---|---|---|---|
| `player_path` | `NodePath` | `""` | Path to the `AnimationPlayer`. |
| `animation_name` | `StringName` | `""` | Animation to play. |
| `speed` | `float` | `1.0` | Playback speed. |
| `wait_for_finish` | `bool` | `true` | Await the animation end before proceeding. |
| `blend_time` | `float` | `0.0` | Crossfade time from the current animation. |

---

### JuiceeSetActiveEffect

Show or hide a node for `duration` seconds then restore original visibility. Muzzle flash, hit spark, tutorial highlight.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_path` | `NodePath` | `"."` | Node to show/hide. |
| `action` | `Action` | `SHOW` | `SHOW`, `HIDE`, or `TOGGLE`. |
| `duration` | `float` | `0.5` | How long to hold the new visibility state. |

---

### JuiceeChainEffect

Composes N child `JuiceeEffect` resources as one reusable block. Build signature move combos as a single `.tres` asset.

| Property | Type | Default | Description |
|---|---|---|---|
| `effects` | `Array[JuiceeEffect]` | `[]` | Child effects. |
| `parallel` | `bool` | `false` | Play children simultaneously. |
| `step_delay` | `float` | `0.0` | Delay between each child when `parallel=false`. |

---

### JuiceeWaitForInputEffect

Pause sequence execution until the player presses a specified input action. Dialog advancement, tutorial checkpoints, cutscene pacing.

| Property | Type | Default | Description |
|---|---|---|---|
| `action` | `String` | `"ui_accept"` | Input action name (as configured in Project Settings -> Input Map). |
| `timeout` | `float` | `0.0` | Auto-advance after this many seconds (`0` = wait forever). |

---

### JuiceeBeatSyncEffect

Fire a child effect synchronized to a BPM beat for `duration` seconds. Two modes:

- **Clock mode**: set `clock_path` to a `JuiceeBeatClock` in the scene - fires exactly on the clock's `beat` signal for musically tight sync.
- **Standalone mode**: leave `clock_path` empty - fires at the computed `60/bpm * beats_per_trigger` interval internally.

| Property | Type | Default | Description |
|---|---|---|---|
| `effect` | `JuiceeEffect` | `null` | The child effect to fire each beat. |
| `bpm` | `float` | `120.0` | BPM for standalone mode. |
| `beats_per_trigger` | `int` | `1` | Fire every N beats (`1`=every beat, `2`=every other, `4`=every bar). |
| `duration` | `float` | `8.0` | Total run time (`0` = fire once and stop). |
| `clock_path` | `NodePath` | `""` | Optional `JuiceeBeatClock` for tight musical sync. |

---

### JuiceeEmitSignalEffect

Emit a named signal on the context node with an optional `Variant` argument. Bridge between Juicee sequences and gameplay systems without direct code coupling. The signal must be pre-declared on the context node. Use `argument = null` for no-arg signals.

| Property | Type | Default | Description |
|---|---|---|---|
| `signal_name` | `String` | `""` | Name of the signal to emit. |
| `argument` | `Variant` | `null` | Optional argument. Pass `null` for zero-argument signals. |

---

### JuiceeDebugLogEffect

Print, push_warning, or push_error a message from within a Juicee sequence. Supports `{context}` placeholder replaced with the context node's name at runtime. Zero game impact in shipping builds if guarded.

| Property | Type | Default | Description |
|---|---|---|---|
| `message` | `String` | `""` | Message text. Use `{context}` to embed the context node name. |
| `level` | `Level` | `PRINT` | `PRINT` (print), `PUSH_WARNING`, or `PUSH_ERROR`. |
| `include_context_name` | `bool` | `true` | Prefix message with `"[ContextName] "`. |

---

### JuiceeAnimationTreeEffect

Travel to an `AnimationTree` state machine state or set any tree parameter directly. `TRAVEL` mode calls `StateMachinePlayback.travel(parameter)` for smooth blended transitions. `SET_PARAMETER` mode writes any tree parameter (blend amounts, time scales, booleans, etc.). Auto-discovers an AnimationTree child if `tree_path` is empty.

| Property | Type | Default | Description |
|---|---|---|---|
| `tree_path` | `NodePath` | `""` | Path to the AnimationTree. Empty = search context children. |
| `mode` | `Mode` | `TRAVEL` | `TRAVEL` or `SET_PARAMETER`. |
| `parameter` | `String` | `"Idle"` | State name (TRAVEL) or parameter path (SET_PARAMETER), e.g. `"parameters/TimeScale/scale"`. |
| `value` | `Variant` | `true` | Value for SET_PARAMETER mode. Ignored in TRAVEL mode. |
| `playback_path` | `String` | `"parameters/playback"` | Path to the StateMachinePlayback parameter (TRAVEL mode only). |
| `wait_for_finish` | `bool` | `false` | Poll until the current node matches `parameter` and has played to end (TRAVEL only). |

---

### JuiceeSetPropertyEffect

Instantly `set_indexed(property_name, value)` on any node, then optionally restore the original value after `restore_delay` seconds. The direct-assignment complement to `PropertyTweenEffect` - no animation, just set. Toggle bool flags, snap positions, change label text, enable/disable collision layers mid-sequence.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_path` | `NodePath` | `""` | Node to modify. Empty = context node. |
| `property_name` | `String` | `""` | Property path (supports sub-paths: `"position:x"`, `"material:albedo_color"`). |
| `value` | `Variant` | `true` | Value to set. |
| `restore_delay` | `float` | `-1.0` | `-1` = never restore, `0` = restore immediately after setting, `> 0` = restore after N seconds. |

---

### JuiceeAutoDestructEffect

`queue_free()` the context node (or a target) after an optional delay. Essential for cleaning up temporary VFX objects spawned by `JuiceeInstantiateEffect` or other runtime spawners.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_path` | `NodePath` | `""` | Node to free. Empty = context node itself. |
| `delay` | `float` | `0.0` | Seconds to wait before freeing. `0` = queue_free on the next frame. |
| `free_parent` | `bool` | `false` | Free the parent of the resolved target instead of the target itself. Useful when the context is a child (e.g., sprite) but you want to remove the root object. |
