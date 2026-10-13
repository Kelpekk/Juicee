# Effects reference

[Juicee](../README.md) / [Docs](../README.md#docs)

All 117 effects organized by category. Every `@export` parameter is documented. For base-class params (`chance`, `delay`, `intensity_min/max`, `cooldown`) see [api-reference.md](api-reference.md).

Each effect also lists an **Advanced** table. Those parameters are hidden in the inspector until you turn on Project Settings > Juicee > Advanced Properties, and all but four of them default to the behaviour the effect already had; [upgrading.md](upgrading.md) names the four and gives their old values. See [advanced-properties.md](advanced-properties.md).

**Accessibility tags** are noted where relevant - see `JuiceeAccessibility` in [api-reference.md](api-reference.md).

**The node an effect plays on** has to be the kind that effect works with, and where it is not, the effect looks for the nearest one that is: children first, then parents. [api-reference.md](api-reference.md#what-an-effect-plays-on) has the rules. The 2D transform effects want a `Node2D`; for `Control` nodes there are Button Punch, Shake Control, Size Delta and Text Wobble, plus Pulse, Scale, Pop In and Sway, which work on either.

Jump to: [Screen](#screen-18-effects), [Camera](#camera-9-effects), [Object](#object-50-effects), [Text](#text-8-effects), [Time](#time-5-effects), [Audio](#audio-10-effects), [Physics](#physics-5-effects), [Flow](#flow-12-effects).

---

## Screen (18 effects)

Screen effects render on a `CanvasLayer` above everything else. Shader-based effects read `SCREEN_TEXTURE` through a `BackBufferCopy`, and that **works on all three renderers, Compatibility included**.

### Keeping your HUD readable

Screen effects sit on a `CanvasLayer`, so anything on a lower layer is part of the
picture they distort. That is usually what you want for the world and rarely what you
want for a clock. Measured in a small racing game: a crash fires chromatic at 14 alongside lens
distortion, and with the HUD underneath it the timer read `6600.44` instead of `600.4`
and the ring count `1155` instead of `15`. Every number on screen was unreadable for
half a second, on the event that happens most.

The layers Juicee uses:

| layer | what is there |
|---|---|
| 126 - 130 | Screen Tint, Vignette, Blur, Chromatic, Color Grade, Glitch, Pixelate, Screen Wipe, Lens Distortion |
| 200 | Film Grain, Radial Blur, Scan Lines, Shockwave, Speed Lines, Cinematic Bars |
| 250 | Freeze Frame's flash, deliberately above everything |

Tint, vignette and colour grade only recolour, so text under them stays readable. The
rest displace pixels, and text under those does not. So:

- **A HUD that has to be read** goes above `200`. `210` clears every effect that
  displaces and still lets the Freeze Frame flash wash over it.
- **A HUD you want dragged into the effect** goes below `126`. A diegetic screen that
  glitches with the world is a real look; it is just not the default you want on a
  score counter.

Nothing in the addon assumes either, and no effect needed changing for this: it is one
number on your own `CanvasLayer`.

This page used to say the opposite - that the eleven screen shaders needed Forward+ or Mobile - which was wrong and steered Compatibility projects, including web exports, away from effects that work perfectly well for them. Measured on all three: every one of the eleven changes the picture, and by near-identical amounts. Vignette moves 0.3679 of a mean pixel on Forward+ and 0.3685 on Compatibility; chromatic 0.0547 against 0.0549. `temp/test_renderers.gd` is the harness if you want to re-run it on your own hardware.

> **Editor preview note:** In the Inspector ▶ Preview and JuiceeGraph ▶ Test flows, screen effects render inside the editor's preview viewport (smaller than the window). An amber outline marks the preview area. Run the project (F5/F6) for true full-screen rendering.

---

### JuiceeChromaticEffect

RGB channel split full-screen. Splits the screen into R, G, B samples offset by `intensity` pixels in opposite directions. Classic damage hit / glitch vibe.

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity` | `float` | `5.0` | Pixel offset between R / G / B channels - higher = more obvious distortion. |
| `duration` | `float` | `0.2` | Duration of the effect with fade-out to zero. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping how the split decays. FEEL-style curve control. |
| `hold_time` | `float` | `0.0` | Seconds to hold the split at full strength before it decays. 0 = decay immediately. |
| `oscillations` | `float` | `0.0` | Wobble the split this many times while it decays, for an unstable-signal look. 0 = a clean single decay. |

**Accessibility tag:** `TAG_CHROMATIC`  
**Shader:** `addons/juicee/shaders/chromatic.gdshader`

---

### JuiceeVignetteEffect

Edge-darkening overlay with color tint. Useful for damage indicators, atmospheric mood, horror tunnels.

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity` | `float` | `0.6` | Darkness at the screen edges (0 = invisible, 1 = solid). |
| `softness` | `float` | `0.45` | How feathered the vignette edge is. 0 = hard edge, 1 = very soft falloff. |
| `vignette_color` | `Color` | `Color(0.0, 0.0, 0.0, 1.0)` | Color tint of the vignette. Default is black, but try red for damage / gold for power-up. |
| `duration` | `float` | `0.8` | Total duration including fade-in and fade-out. |
| `fade_out` | `bool` | `true` | If true, vignette fades back to 0 at the end. If false, it stays at peak. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping the fade-in. FEEL-style curve control. |
| `hold_time` | `float` | `0.0` | Seconds to hold at full darkness before fading. 0 = fade straight back. |
| `pulse_count` | `int` | `1` | Throb in and out this many times across the duration instead of one fade in / out. 3+ with a red colour is the classic low-health pulse. |

**Shader:** `addons/juicee/shaders/vignette.gdshader`

---

### JuiceeBlurEffect

Full-screen blur. Use for pause menus, dream sequences, or death overlays.

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity` | `float` | `4.0` | Peak blur intensity in pixels (a 3x3 weighted kernel). |
| `duration` | `float` | `0.6` | Total duration including ramp-in and ramp-out. |
| `fade_out` | `bool` | `true` | If true, blur fades back to 0 at the end. If false, it stays at peak. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping how the blur ramps in. FEEL-style curve control. |
| `hold_time` | `float` | `0.0` | Seconds to hold at full blur before it fades. 0 = ramp straight back out. |
| `ramp_in_ratio` | `float` | `0.3` | Fraction of the duration spent ramping in. 0.3 = a quick blur-in, long fade-out. |

**Shader:** `addons/juicee/shaders/blur.gdshader`

---

### JuiceePixelateEffect

Full-screen pixelation. Retro hit flashes, damage moments, glitch sequences.

| Property | Type | Default | Description |
|---|---|---|---|
| `pixel_size` | `float` | `8.0` | Starting pixel size in screen pixels - higher = chunkier. |
| `duration` | `float` | `0.4` | How long the pixelation effect lasts. |
| `fade_out` | `bool` | `true` | If true, pixel size tweens from peak back to 1 (resolves to normal). If false, holds. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping how the pixels resolve back to normal. FEEL-style. |
| `hold_time` | `float` | `0.0` | Seconds to hold at full chunkiness before resolving. 0 = resolve immediately. |
| `steps` | `int` | `0` | Resolve in this many hard steps instead of smoothly, for a retro "loading" feel. 0 = smooth (the default). |

**Shader:** `addons/juicee/shaders/pixelate.gdshader`

---

### JuiceeGlitchEffect

Horizontal screen tear with chromatic split. Hacking aesthetic, broken systems, damage states.

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity` | `float` | `0.5` | Peak glitch intensity (0 = none, 1 = chaotic tear + chromatic split). |
| `duration` | `float` | `0.3` | How long the glitch effect lasts before fading out. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping how the glitch decays. FEEL-style curve control. |
| `hold_time` | `float` | `0.0` | Seconds to hold at full glitch before it decays. 0 = decay immediately. |
| `bursts` | `int` | `1` | Break the glitch into this many stuttering bursts with clean gaps between them, instead of one smooth decay. 1 = the classic single hit; 4+ = a broken-signal state. |

**Accessibility tag:** `TAG_CHROMATIC`  
**Shader:** `addons/juicee/shaders/glitch.gdshader`

---

### JuiceeColorGradeEffect

Saturation / contrast / brightness / tint shift on the full screen. Desaturate on damage, boost on level-up, go green for night vision.

| Property | Type | Default | Description |
|---|---|---|---|
| `saturation` | `float` | `0.5` | Color saturation. 0 = grayscale, 1 = normal, >1 = oversaturated. |
| `contrast` | `float` | `1.0` | Contrast around midpoint. 1 = normal, <1 = muddy, >1 = punchy. |
| `brightness` | `float` | `0.0` | Additive brightness offset (-1 = black, 0 = normal, +1 = white). |
| `tint` | `Color` | `Color.WHITE` | Color tint multiplier (e.g., red for damage, warm orange for sunset). |
| `duration` | `float` | `0.8` | Total duration including ramp-in and ramp-out. |
| `fade_out` | `bool` | `true` | If true, color grading lerps back to neutral. If false, holds at target values. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `hold_time` | `float` | `0.0` | Seconds to hold the graded look before it fades back. 0 = fade straight back. |
| `ramp_in_ratio` | `float` | `0.3` | Fraction of the duration spent grading in. 0.3 = a quick grade, slow release. |

**Shader:** `addons/juicee/shaders/color_grade.gdshader`

---

### JuiceeScreenTintEffect

Solid colored full-screen overlay (RGBA `ColorRect` on a `CanvasLayer`). Fastest screen effect - no shader needed. Red flash for damage, gold for level-up, white for explosion.

| Property | Type | Default | Description |
|---|---|---|---|
| `tint_color` | `Color` | `Color(1.0, 0.2, 0.2, 0.5)` | Color of the full-screen overlay. Alpha controls peak opacity. Common presets: red for damage, gold for level-up, blue for water hit. |
| `duration` | `float` | `0.4` | Total duration including fade-in and fade-out. |
| `fade_out` | `bool` | `true` | If true, overlay fades back to transparent. If false, it holds at peak. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `hold_time` | `float` | `0.0` | Seconds to hold at full tint before fading. 0 = fade straight back. |
| `pulse_count` | `int` | `1` | Flash in and out this many times across the duration instead of once. 3+ reads as an alarm strobe. |

**Accessibility tag:** `TAG_FLASH`  
**No shader** - solid `ColorRect` overlay.

---

### JuiceeScreenWipeEffect

Colored bar slides across the screen. Use for scene transitions.

| Property | Type | Default | Description |
|---|---|---|---|
| `wipe_from` | `WipeFrom` | `WipeFrom.LEFT` | Direction the wipe bar enters from. Options: `LEFT`, `RIGHT`, `TOP`, `BOTTOM`. |
| `wipe_color` | `Color` | `Color.BLACK` | Color of the wipe bar (typically opaque black for scene transitions). |
| `duration` | `float` | `0.6` | Total wipe duration: half to cover the screen, half to leave it. With Hold on, only the first half plays. |
| `hold` | `bool` | `false` | If true, the wipe stops at the center and stays covering the screen. Caller must clean up. If false (default), it wipes across and exits the opposite side. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping the bar's travel, replacing the cubic ease. FEEL-style. |
| `cover_time` | `float` | `0.0` | Seconds the screen stays fully covered before the bar exits. Only used when Hold is off. |

---

### JuiceeBloomEffect

Pulses the active `WorldEnvironment` glow parameters. **No custom shader** - animates Godot's built-in post-process. No overlay of its own. Works in 2D and 3D.

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity_boost` | `float` | `1.5` | Peak glow intensity (added on top of the env's current intensity). |
| `strength_multiplier` | `float` | `1.2` | Peak glow strength multiplier. |
| `bloom_amount` | `float` | `0.4` | Peak glow bloom amount. |
| `duration` | `float` | `0.6` | Total duration (ramp up + hold + ramp down). |
| `fade_out` | `bool` | `true` | If true, glow fades back to original at the end. If false, stays at peak. |
| `intensity_curve` | `Curve` | - | Optional intensity curve for designer-controlled feel (replaces the built-in ease on the swell). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `hold_time` | `float` | `0.0` | Seconds to hold at peak glow before it fades back. 0 = fade straight back. |
| `pulse_count` | `int` | `1` | Throb the glow in and out this many times instead of one swell. 3+ reads as a charging / powering-up pulse. |

Requires a `WorldEnvironment` node in the scene; glow is switched on for the play if it was off.

---

### JuiceeTonemapEffect

Punches the active `WorldEnvironment` tonemap exposure. Flash-blindness from explosions, teleport arrivals, dimension shifts.

| Property | Type | Default | Description |
|---|---|---|---|
| `exposure_boost` | `float` | `3.0` | Peak exposure boost (added on top of current). |
| `white_target` | `float` | `0.5` | Peak white shift (lower = blown out, higher = darker midtones). |
| `duration` | `float` | `0.4` | Total duration (ramp up + hold + ramp down). |
| `fade_out` | `bool` | `true` | If true, exposure fades back to original at end. If false, stays punched. |
| `exposure_curve` | `Curve` | - | Optional curve for the punch shape. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `hold_time` | `float` | `0.0` | Seconds to hold the blown-out exposure before it settles. 0 = settle immediately. A longer hold sells a proper flashbang. |
| `attack_ratio` | `float` | `0.3` | Fraction of the duration spent punching up. 0.3 = a fast overload, slow recovery. |

Requires a `WorldEnvironment` node.

---

### JuiceeShockwaveEffect

Expanding radial distortion ring originating from the context node's screen position. The ring travels outward; UV distortion strength fades as the ring expands.

| Property | Type | Default | Description |
|---|---|---|---|
| `max_radius` | `float` | `0.6` | Maximum ring radius, in screen heights. From the centre of a 16:9 screen, 0.5 reaches the top and bottom, about 0.9 the sides. |
| `ring_width` | `float` | `0.04` | Width of the distortion band (fraction of screen height). 0.04 is a tight sharp ring. |
| `strength` | `float` | `0.025` | Peak UV displacement at the ring centre. Higher = more dramatic warp. |
| `duration` | `float` | `0.5` | Total animation duration in seconds. |
| `radius_curve` | `Curve` | - | Optional easing curve for the radius expansion (null = ease-out quad). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `falloff` | `float` | `6.0` | How sharply the distortion falls off across the ring band. Low (1-3) = a soft wide swell; high (12+) = a thin hard-edged shock front. |
| `ripples` | `int` | `1` | Send this many rings out one after another, each weaker than the last, for a rolling aftershock. 1 = a single wave. |
| `ripple_spacing` | `float` | `0.25` | Delay between successive ripples, as a fraction of the duration. |

**Shader:** `addons/juicee/shaders/shockwave.gdshader`

---

### JuiceeCinematicBarsEffect

Letterbox bars slide in from the top and bottom edges. Hold for `hold_duration` seconds, then slide back out. `hold_duration = 0` holds indefinitely - call `stop()` on the returned effect to slide out.

**Accessibility tag:** `TAG_MOTION` (no switch of its own; reduced motion scales it)

| Property | Type | Default | Description |
|---|---|---|---|
| `bar_color` | `Color` | `Color(0.0, 0.0, 0.0, 1.0)` | Bar color (default matte black). |
| `bar_height` | `float` | `0.1` | How much of the screen each bar covers (0.1 = 10% top + 10% bottom, about 2.2:1 on a 16:9 screen; 0.12 gives 2.35:1). |
| `enter_duration` | `float` | `0.3` | Duration to slide in. |
| `hold_duration` | `float` | `2.0` | How long to hold the bars (0 = hold until stop() is called, great for dialogue). |
| `exit_duration` | `float` | `0.3` | Duration to slide out. 0 = instant hide. |
| `canvas_layer` | `int` | `200` | Canvas layer z-index. Keep high so bars render above everything. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `vertical_bars` | `bool` | `false` | Draw the bars on the sides instead of top and bottom (pillarbox), for a vertical video or a stylised narrow frame. |
| `fade_in_instead` | `bool` | `false` | Fade the bars in instead of sliding them, which suits a slower, softer transition. |
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing the built-in easing on the entrance. |

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
| `line_count` | `float` | `300.0` | Number of horizontal bands across the screen height. 300 = classic CRT density. |
| `strength` | `float` | `0.25` | How dark each alternate band gets. 0 = invisible, 1 = fully black bands. |
| `scroll_speed` | `float` | `0.0` | Vertical scroll speed in cycles per second. 0 = static bands. |
| `duration` | `float` | `2.0` | Total effect duration in seconds. |
| `fade_out` | `bool` | `true` | Fade strength out over the last 10% of duration. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping the line strength over the duration. FEEL-style. |
| `loop` | `bool` | `false` | Run until stop() is called, ignoring Duration. For a permanent CRT / retro monitor look. |
| `instability` | `float` | `0.0` | Randomly wobble the strength each frame by up to this fraction, for an unstable signal. 0 = rock-steady bands. |

**Shader:** `addons/juicee/shaders/scanlines.gdshader`

---

### JuiceeSpeedLinesEffect

Anime radial speed-lines overlay - streaks converging on the screen centre. Dashes, bursts of speed, focus and shock moments. *(New in 1.2.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `density` | `float` | `140.0` | Angular streak count - higher = more, thinner lines. |
| `strength` | `float` | `0.5` | Peak opacity of the streaks. |
| `center_clear` | `float` | `0.35` | Radius (0..1) of the clear zone in the middle (keeps the focal point readable). |
| `line_color` | `Color` | `Color.WHITE` | Streak colour - white = speed, black = shock/focus. |
| `anim_speed` | `float` | `6.0` | Animation rate - subtle shimmer of the streaks. 0 = static. |
| `duration` | `float` | `0.4` | Total effect duration in seconds. |
| `fade_out` | `bool` | `true` | Fade strength out over the last 10% of duration. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping the streak strength over the duration. FEEL-style. |
| `loop` | `bool` | `false` | Run until stop() is called, ignoring Duration. For a sustained dash / focus state. |

**Shader:** `addons/juicee/shaders/speed_lines.gdshader`

---

### JuiceeFilmGrainEffect

Analog film grain noise overlay. Grain is quantized to `speed` FPS for authentic flutter rather than per-frame smooth noise.

| Property | Type | Default | Description |
|---|---|---|---|
| `strength` | `float` | `0.15` | Grain intensity. 0.15 = cinematic, 0.35 = heavy VHS noise, 0.5 = broken signal. |
| `speed` | `float` | `15.0` | Grain animation rate in frames per second (15 = classic film, 24 = digital). |
| `duration` | `float` | `2.0` | Total effect duration in seconds. |
| `fade_out` | `bool` | `true` | Fade strength out at end of duration. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping the grain strength over the whole duration, so it can surge and settle instead of holding flat. FEEL-style curve control. |
| `loop` | `bool` | `false` | Run until stop() is called, ignoring Duration. For a permanent film / VHS look. |

**Shader:** `addons/juicee/shaders/film_grain.gdshader`

---

### JuiceeRadialBlurEffect

Radial motion blur from a screen point. N-sample accumulation toward the center point.

| Property | Type | Default | Description |
|---|---|---|---|
| `strength` | `float` | `0.05` | Max displacement per sample step. 0.02 = subtle, 0.06 = dramatic warp. |
| `samples` | `int` | `8` | Number of blur samples accumulated per pixel. More = smoother + heavier GPU cost. |
| `duration` | `float` | `0.4` | Total duration in seconds. |
| `center_uv` | `Vector2` | `Vector2(0.5, 0.5)` | Fixed screen-UV center (used when context is not a Node2D). |
| `use_node_position` | `bool` | `true` | If true and context is Node2D, derives center_uv from the node's screen position. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping the warp strength over the duration, replacing the built-in ramp-in / ease-out. FEEL-style curve control. |
| `hold_time` | `float` | `0.0` | Seconds to hold at full warp before it eases out. 0 = ease out immediately. |

**Shader:** `addons/juicee/shaders/radial_blur.gdshader`

---

### JuiceeLensDistortionEffect

Barrel or pincushion lens distortion over the full screen. `strength > 0` warps outward (barrel / fisheye); `strength < 0` warps inward (pincushion / zoom lens). Pixels that map outside [0,1] UV are filled with black. Scope zoom, warp portals, dimensional rifts, drunk/dazed state.

**Accessibility tag:** `TAG_SCREENSHAKE`

| Property | Type | Default | Description |
|---|---|---|---|
| `strength` | `float` | `0.25` | Distortion amount. Positive = barrel, negative = pincushion. |
| `duration` | `float` | `0.4` | Duration in seconds. |
| `fade_out` | `bool` | `true` | Fade the effect out over the last 20% of duration. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping the distortion over the duration, replacing the snap-in / hold / fade-out envelope. FEEL-style curve control. |
| `pulse_count` | `int` | `1` | Breathe the distortion in and out this many times across the duration, for a woozy / drugged / underwater state. 1 = a single warp. |

**Shader:** `addons/juicee/shaders/lens_distortion.gdshader`

---

### JuiceeDepthOfFieldEffect

Drives `CameraAttributesPractical` on a `Camera3D` for native engine DOF blur. Fades the blur in, holds it, then fades it out (15% / 70% / 15% by default). A camera with `CameraAttributesPhysical` gets a warning instead, since its blur comes from the lens aperture. Far and near blur are independently toggleable. Focus-pull cinematics, sniper scope, cinematic cutscene transitions.

**Dimensions:** 3D only

| Property | Type | Default | Description |
|---|---|---|---|
| `camera_path` | `NodePath` | `""` | Path to the Camera3D. Empty = search the viewport for the active camera. |
| `blur_far` | `bool` | `true` | Enable far-distance DOF blur. |
| `far_distance` | `float` | `10.0` | Distance at which far DOF begins (metres). |
| `far_transition` | `float` | `5.0` | Blur transition range past far_distance. |
| `blur_near` | `bool` | `false` | Enable near-distance DOF blur. |
| `near_distance` | `float` | `1.0` | Near DOF distance (metres). |
| `near_transition` | `float` | `0.5` | Near DOF transition range. |
| `blur_amount` | `float` | `0.1` | Peak blur strength: the camera's DOF Blur Amount at the height of the effect. |
| `duration` | `float` | `2.0` | Total duration: the blur fades in, holds, then fades out (Fade In Ratio sets the in and out share). |
| `fade_out` | `bool` | `true` | If true, the blur fades out at the end and the camera's DOF settings go back to how they were. If false, it stays on. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `focus_pull_from` | `float` | `-1.0` | Animate the far focus distance from this value to Far Distance over the fade-in, for a cinematic focus pull. -1 = snap straight to Far Distance (the default). |
| `fade_in_ratio` | `float` | `0.15` | Fraction of the duration spent fading the blur in, and again fading it out. 0.15 = a quick rack focus. |

---

## Camera (9 effects)

Camera effects target the active `Camera2D` found via `context.get_viewport().get_camera_2d()` or the active `Camera3D`. They use `JuiceeStateStack` to safely stack.

---

### JuiceeShakeEffect

Perlin noise or random jitter on `Camera2D.offset`. The definitive game-feel effect.

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity` | `float` | `8.0` | Maximum shake displacement in pixels. |
| `duration` | `float` | `0.3` | Total shake duration in seconds. |
| `frequency` | `float` | `15.0` | Shake oscillations per second. |
| `decay` | `float` | `0.8` | How quickly the shake amplitude falls off. 0 = constant, higher = faster decay. |
| `use_noise` | `bool` | `true` | If true, uses smooth Perlin noise. If false, uses random offsets (jittery). |
| `roll_degrees` | `float` | `1.2` | Max camera roll in degrees layered on the positional shake. A touch of rotation makes the same shake read much more violent. Try 1.5. 0 = position only. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `preset` | `Preset` | `Preset.CUSTOM` | A quick-tuned shake flavour. Anything but Custom overrides intensity / frequency / decay / roll with values picked for that feel; Custom uses the sliders above. Options: `CUSTOM`, `IMPACT`, `EARTHQUAKE`, `RUMBLE`, `HANDHELD`. |
| `target_path` | `NodePath` | `""` | Shake THIS node's position instead of the camera. Empty = shake the camera (the usual whole-screen shake). Point it at a sprite, HUD panel or weapon to shake just that node. |

**Runtime params:** `{"hit_direction": Vector2}` - pushes the shake along the hit direction (the way the hit travels) for a recoil feel.  
**Accessibility tag:** `TAG_SCREENSHAKE`

---

### JuiceeShake3DEffect

Camera3D shake that mostly turns the view (yaw, pitch and roll) with a small positional part, which `axis_scale` shapes per axis.

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity` | `float` | `0.06` | Shake displacement in world units. Small on purpose: in 3D a sliding camera is the part that reads badly, so most of the shake wants to come from Tilt and Roll below. |
| `duration` | `float` | `0.3` | Total shake duration in seconds. |
| `frequency` | `float` | `15.0` | Shake oscillations per second. |
| `decay` | `float` | `0.8` | How quickly the shake amplitude falls off. 0 = constant, higher = faster decay. |
| `use_noise` | `bool` | `true` | If true, uses smooth Perlin noise. If false, uses random offsets (jittery). |
| `axis_scale` | `Vector3` | `Vector3.ONE` | Per-axis multiplier on the positional part of the shake. Set Y to 0 for no vertical slide (Tilt and Roll still turn the view). |
| `tilt_degrees` | `float` | `1.6` | Yaw and pitch shake in degrees: the camera looking around rather than moving. This is the part that carries a 3D shake. |
| `roll_degrees` | `float` | `0.9` | Camera roll in degrees, the twist that comes with a hit. Combined with Tilt it is the full three-axis shake the reference recommends. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `directional_bias` | `Vector3` | `Vector3.ZERO` | Bias the shake along this world direction, so it recoils away from an impact. Zero = an even shake in all directions. |

**Accessibility tag:** `TAG_SCREENSHAKE`

---

### JuiceeZoomEffect

Camera2D zoom punch in or out with overshoot and return.

| Property | Type | Default | Description |
|---|---|---|---|
| `zoom_factor` | `float` | `1.2` | Camera2D zoom multiplier (>1 = zoom in, <1 = zoom out). |
| `duration` | `float` | `0.4` | Total duration of the zoom punch in seconds. |
| `return_to_original` | `bool` | `true` | If true, camera zoom returns to original after the punch. |
| `trans_type` | `Tween.TransitionType` | `Tween.TRANS_BACK` | Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest. |
| `ease_type` | `Tween.EaseType` | `Tween.EASE_OUT` | Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing Transition/Ease for the zoom. FEEL-style. |
| `hold_time` | `float` | `0.0` | Seconds to hold at the target zoom before returning. 0 = zoom straight back. |

---

### JuiceeFOV3DEffect

Camera3D field-of-view punch. Positive delta = zoom out (wider FOV), negative = zoom in.

| Property | Type | Default | Description |
|---|---|---|---|
| `fov_delta` | `float` | `10.0` | Amount to add to the camera's FOV in degrees (positive = zoom out, negative = zoom in). |
| `duration` | `float` | `0.4` | Total duration of the FOV punch in seconds. |
| `return_to_original` | `bool` | `true` | If true, FOV returns to its original value after the punch. |
| `trans_type` | `Tween.TransitionType` | `Tween.TRANS_BACK` | Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest. |
| `ease_type` | `Tween.EaseType` | `Tween.EASE_OUT` | Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing Transition/Ease for the FOV shift. FEEL-style. |
| `hold_time` | `float` | `0.0` | Seconds to hold the changed FOV before it returns. 0 = return straight away. |
| `pulse_count` | `int` | `1` | Pulse in and out this many times instead of one shift, for a breathing zoom. |

---

### JuiceeCameraFollowEffect

Smoothly lerps Camera2D to track a target Node2D for `duration` seconds, then returns to the original position.

| Property | Type | Default | Description |
|---|---|---|---|
| `duration` | `float` | `1.5` | How long (seconds) the camera follows the context node. |
| `follow_speed` | `float` | `5.0` | Lerp speed - higher = snappier follow, lower = smoother lag. |
| `return_to_original` | `bool` | `true` | If true, camera lerps back to its original position when duration ends. |
| `return_duration` | `float` | `0.6` | Duration of the return-to-original lerp. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `follow_offset` | `Vector2` | `Vector2.ZERO` | Offset (pixels) held from the target, so the camera frames it off-centre instead of dead centre. e.g. (0, -60) keeps the subject low in frame. |
| `look_ahead` | `float` | `0.0` | Lead the target by this many pixels per unit of its speed, so the camera looks ahead in the direction of travel. 0 = no look-ahead. |
| `deadzone` | `float` | `0.0` | Stop correcting once the camera is within this many pixels of the target, so it settles instead of micro-drifting. 0 = always correct. |

---

### JuiceeDirectionalShakeEffect

Kick-recoil shake with directional bias plus perpendicular noise. The camera is kicked away from `direction` and eases back, with sideways noise on top. Use for gun fire, directional punch impacts, explosion knockback.

| Property | Type | Default | Description |
|---|---|---|---|
| `direction` | `Vector2` | `Vector2.RIGHT` | Impact direction. Camera kicks opposite to this (hit from right = camera moves left). |
| `kick_distance` | `float` | `20.0` | How far the camera is initially kicked along the direction axis (pixels). |
| `side_intensity` | `float` | `4.0` | Amplitude of the perpendicular noise shake layered on top of the kick. |
| `duration` | `float` | `0.3` | Total shake duration. |
| `frequency` | `float` | `16.0` | Shake oscillations per second. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `roll_degrees` | `float` | `0.0` | Camera roll in degrees layered on the kick, so a big hit also twists the view. |
| `decay_power` | `float` | `1.0` | How fast the sideways shake and roll die away. 1 = linear falloff, 2+ = they die quickly. |

**Runtime params:** `{"direction": Vector2}` - override direction per-shot.  
**Accessibility tag:** `TAG_SCREENSHAKE`

---

### JuiceeCameraBobEffect

Rhythmic sine-wave bob on `Camera2D.offset`. Uses a `sin(t * PI)` envelope for smooth ramp-in and ramp-out. Walk cycle, breathing idle, post-impact sway.

| Property | Type | Default | Description |
|---|---|---|---|
| `amplitude` | `Vector2` | `Vector2(0.0, 4.0)` | Per-axis bob amplitude in pixels. (0, 4) = vertical only, (3, 3) = circular. |
| `frequency` | `float` | `2.0` | Bob cycles per second (2.0 = leisurely walk, 3.5 = run, 0.5 = breathing). |
| `duration` | `float` | `2.0` | Total duration in seconds. |
| `phase_offset` | `float` | `0.0` | Phase offset in radians. PI/2 = start at peak instead of zero crossing. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `loop` | `bool` | `false` | Bob until stop() is called, ignoring Duration. For a walk cycle that runs while the player is moving. |
| `roll_degrees` | `float` | `0.0` | Camera roll in degrees synced to the bob, so footsteps also tilt the view. 0 = none. |
| `figure_eight` | `bool` | `false` | Horizontal bob runs at half the vertical rate, the way a real walk cycle does (one sway per two steps). Off = both axes share the same frequency. |

**Accessibility tag:** `TAG_SCREENSHAKE`

---

### JuiceeZoomPulseEffect

BPM-synced Camera2D zoom pulse. On each beat interval the camera zooms in by `pulse_amount`, then eases back. Use for beat-drops, bass-heavy music, rhythm-game feedback.

| Property | Type | Default | Description |
|---|---|---|---|
| `bpm` | `float` | `120.0` | Beats per minute - controls how often the zoom pulse fires. |
| `pulse_amount` | `float` | `0.08` | Zoom overshoot per beat (fraction). 0.08 = 8% zoom-in per pulse. |
| `duration` | `float` | `4.0` | Total duration in seconds (0 = one beat only). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `invert` | `bool` | `false` | Pulse OUT (zoom away) on each beat instead of in. A punch-out reads as a bass drop. |
| `attack_ratio` | `float` | `0.15` | Fraction of each beat spent zooming in. 0.15 = a sharp punch; 0.5 = a smooth breath. |
| `accent_every` | `int` | `1` | Every Nth beat pulses harder by this multiplier, so a bar lands with an accent. 1 = every beat identical. |
| `accent_multiplier` | `float` | `1.8` | How much stronger an accented beat is. |

---

### JuiceeCameraRotationEffect

Dutch tilt - rotate Camera2D to `angle_degrees` then spring back. Three phases: tilt-in -> optional hold -> return. Uses `JuiceeStateStack` on the camera's `rotation` property for concurrent-safe restore. Car chases, punch impacts, dramatic reveals, disorientation, wave attacks.

**Accessibility tag:** `TAG_SCREENSHAKE`

| Property | Type | Default | Description |
|---|---|---|---|
| `angle_degrees` | `float` | `5.0` | Peak rotation angle in degrees. Positive = clockwise. |
| `tilt_duration` | `float` | `0.3` | Seconds to tilt to the peak angle. |
| `hold_duration` | `float` | `0.0` | Seconds to hold at peak angle. 0 = return straight away. |
| `return_duration` | `float` | `0.4` | Seconds to return to original rotation. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing the built-in easing on the tilt in. FEEL-style. |
| `oscillations` | `int` | `1` | Rock back and forth this many times instead of a single tilt-and-return. 3+ reads as a disoriented / drunk camera. |

---

## Object (50 effects)

Object effects target the context node directly (Node2D, CanvasItem, Control, Light2D, RigidBody2D). Most use `JuiceeStateStack` to handle concurrent safety.

---

### JuiceeFlashEffect

Blinks `modulate` on a CanvasItem N times. The quintessential hit acknowledgment.

| Property | Type | Default | Description |
|---|---|---|---|
| `flash_color` | `Color` | `Color.WHITE` | Color to flash to. White = bright flash, red = damage, etc. |
| `duration` | `float` | `0.15` | Total duration spread across all flashes. |
| `flash_count` | `int` | `1` | Number of flashes to perform. 1 = single, 3 = blink three times. |
| `boost` | `float` | `2.0` | Over-brighten multiplier on flash_color (modulate can exceed 1.0), so a white flash actually brightens an untinted sprite. 1.0 = plain tint to flash_color. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `flash_decay` | `float` | `1.0` | Each successive flash is this fraction as strong as the one before, so a burst fades out instead of strobing evenly. 1 = every flash equal. |
| `hold_time` | `float` | `0.0` | Seconds held at full brightness before each flash falls off. 0 = an instant blink. |

**Accessibility tag:** `TAG_FLASH`

---

### JuiceeModulateEffect

Smooth `modulate` color transition (unlike Flash which blinks). Tween from current color to `target_color` and back (with `return_to_original`, the default).

| Property | Type | Default | Description |
|---|---|---|---|
| `target_color` | `Color` | `Color(1.5, 0.5, 0.5, 1.0)` | Target color to lerp the modulate to. Values >1 brighten beyond white. |
| `duration` | `float` | `0.5` | Total duration (split half tween-in, half tween-out if return_to_original). |
| `return_to_original` | `bool` | `true` | If true, lerps back to the original modulate after reaching target. |
| `trans_type` | `Tween.TransitionType` | `Tween.TRANS_SINE` | Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest. |
| `ease_type` | `Tween.EaseType` | `Tween.EASE_IN_OUT` | Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing Transition/Ease for the colour shift. FEEL-style. |
| `hold_time` | `float` | `0.0` | Seconds to hold at the target colour before returning. 0 = shift straight back. |

---

### JuiceeBounceEffect

Uniform scale punch on a Node2D that springs back. The most fundamental object feel effect.

| Property | Type | Default | Description |
|---|---|---|---|
| `scale_factor` | `float` | `1.3` | Peak scale multiplier. 1.3 = 30% bigger at peak. |
| `duration` | `float` | `0.3` | Total bounce duration (40% punch-out + 60% return-with-elastic). |
| `ease_type` | `Tween.EaseType` | `Tween.EASE_OUT` | Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends. |
| `trans_type` | `Tween.TransitionType` | `Tween.TRANS_ELASTIC` | Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing Transition/Ease for the return. FEEL-style. |
| `anticipation` | `float` | `0.0` | Anticipation dip: squash to (1 - this) of size for a beat before punching up. 0 = none. |

---

### JuiceeJigglePhysicsEffect

Spring-mass jiggle on `scale` using real harmonic-oscillator physics. More flexible than canned tweens - tune stiffness/damping for the exact jelly feel you want.

| Property | Type | Default | Description |
|---|---|---|---|
| `stiffness` | `float` | `8.0` | Spring stiffness (k). Higher = faster oscillation, snappier feel. |
| `damping` | `float` | `2.5` | Damping coefficient. Higher = settles faster, lower = wobbles longer. |
| `impulse` | `Vector2` | `Vector2(0.4, -0.4)` | Initial velocity impulse on the spring (relative scale offset per axis). |
| `duration` | `float` | `0.7` | Simulation time, followed by a quick ease back to rest. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `rotation_jiggle` | `float` | `0.0` | Degrees of rotation jiggle driven by the same spring, for a wobblier gel. 0 = scale only. |

---

### JuiceePositionEffect

Move Node2D by `offset` from current position, then return.

| Property | Type | Default | Description |
|---|---|---|---|
| `offset` | `Vector2` | `Vector2(0, -20)` | Offset to apply to the node's position at peak (in pixels). |
| `duration` | `float` | `0.3` | Total punch duration in seconds. |
| `return_to_original` | `bool` | `true` | If true, returns to original position after the punch. |
| `relative` | `bool` | `true` | Offset from where the node already is (true), or the exact value to land on (false). |
| `trans_type` | `Tween.TransitionType` | `Tween.TRANS_BACK` | Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest. |
| `ease_type` | `Tween.EaseType` | `Tween.EASE_OUT` | Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing Transition/Ease for the move-to-peak. FEEL-style curve control. |

---

### JuiceePosition3DEffect

Same as `PositionEffect` for Node3D.

| Property | Type | Default | Description |
|---|---|---|---|
| `offset` | `Vector3` | `Vector3(0, 0.5, 0)` | Offset to apply to the node's position at peak (in world units). |
| `duration` | `float` | `0.3` | Total punch duration in seconds. |
| `return_to_original` | `bool` | `true` | If true, returns to original position after the punch. |
| `relative` | `bool` | `true` | Offset from where the node already is (true), or the exact value to land on (false). |
| `trans_type` | `Tween.TransitionType` | `Tween.TRANS_BACK` | Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest. |
| `ease_type` | `Tween.EaseType` | `Tween.EASE_OUT` | Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing Transition/Ease for the move. FEEL-style. |
| `hold_time` | `float` | `0.0` | Seconds to hold at the offset before returning. 0 = move straight back. |
| `use_local_space` | `bool` | `false` | Read Offset along the node's own forward/up/right instead of the parent's axes, so a recoil pushes backwards whichever way the node is facing. Relative moves only: an exact destination is already a point, not a direction. |

---

### JuiceeRotationEffect

Rotate Node2D by `angle_degrees` then tween back (or stay there, with `return_to_original` off).

| Property | Type | Default | Description |
|---|---|---|---|
| `angle_degrees` | `float` | `15.0` | Peak rotation in degrees (positive = clockwise in Godot 2D). |
| `duration` | `float` | `0.3` | Total rotation punch duration in seconds. |
| `return_to_original` | `bool` | `true` | If true, rotates back to original after the punch. |
| `relative` | `bool` | `true` | Offset from where the node already is (true), or the exact value to land on (false). |
| `trans_type` | `Tween.TransitionType` | `Tween.TRANS_ELASTIC` | Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest. |
| `ease_type` | `Tween.EaseType` | `Tween.EASE_OUT` | Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing Transition/Ease for the swing-to-peak. FEEL-style curve control. |

---

### JuiceeRotation3DEffect

Rotation punch for Node3D using quaternion interpolation.

| Property | Type | Default | Description |
|---|---|---|---|
| `axis` | `Vector3` | `Vector3.UP` | Axis to rotate around (will be auto-normalized). |
| `angle_degrees` | `float` | `15.0` | Peak rotation around the axis in degrees. |
| `duration` | `float` | `0.3` | Total rotation punch duration in seconds. |
| `return_to_original` | `bool` | `true` | If true, rotates back to original orientation after the punch. |
| `relative` | `bool` | `true` | Offset from where the node already is (true), or the exact value to land on (false). |
| `trans_type` | `Tween.TransitionType` | `Tween.TRANS_ELASTIC` | Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest. |
| `ease_type` | `Tween.EaseType` | `Tween.EASE_OUT` | Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing Transition/Ease for the turn. FEEL-style. |
| `hold_time` | `float` | `0.0` | Seconds to hold at the rotated angle before returning. 0 = turn straight back. |
| `oscillations` | `int` | `1` | Rock back and forth this many times instead of a single turn, decaying each swing. |

---

### JuiceeTrailEffect

Ghost trail behind a `Sprite2D` or `AnimatedSprite2D` by spawning semi-transparent copies at regular intervals. The target itself, or the first sprite node under it, supplies the picture.

| Property | Type | Default | Description |
|---|---|---|---|
| `duration` | `float` | `1.0` | How long to keep spawning ghost copies. The tail then drains from its oldest end. |
| `interval` | `float` | `0.05` | Time between ghost spawns. Lower = denser trail. |
| `max_ghosts` | `int` | `10` | Cap on simultaneous ghosts on screen (oldest get queued for deletion). |
| `ghost_modulate` | `Color` | `Color(1.0, 1.0, 1.0, 0.4)` | Color/alpha applied to each ghost (semi-transparent by default). |
| `fade_ghosts` | `bool` | `true` | If true, older ghosts get progressively more transparent. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `fade_to` | `Color` | `Color(1.0, 1.0, 1.0, 0.0)` | Colour the oldest ghosts fade toward, so a trail can cool from white to a tint instead of only losing alpha. |
| `taper` | `float` | `1.0` | Size of the oldest ghost as a fraction of the sprite, growing back to full size toward the newest. 1 = no taper. |
| `world_space` | `bool` | `true` | Leave ghosts in world space instead of following the node, so the tail stays where it was drawn (a proper motion trail rather than a shadow stack). |

---

### JuiceeBurstEffect

One-shot `CPUParticles2D` burst at the target's position. Fully configurable; no pre-existing particle node required.

| Property | Type | Default | Description |
|---|---|---|---|
| `amount` | `int` | `12` | Number of particles to emit. |
| `speed` | `float` | `260.0` | Average particle speed (actual is randomized 0.7×-1.3× this). |
| `spread` | `float` | `180.0` | Spread angle in degrees either side of the direction (180 = full circle, 90 = half circle). |
| `lifetime` | `float` | `0.5` | How long particles live before disappearing. |
| `color` | `Color` | `Color(1.0, 0.8, 0.3, 1.0)` | Particle color. |
| `gravity` | `Vector2` | `Vector2.ZERO` | Gravity applied per second to particles (e.g., Vector2(0, 980) for falling). |
| `particle_scale` | `float` | `2.4` | Visual size of each particle. Without this the engine draws 1px dots that are nearly invisible - this scales the built-in particle texture (see Particle Shape). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `particle_shape` | `ParticleShape` | `ParticleShape.DOT` | Shape of each particle: a round DOT, a chunky SQUARE (debris), a 4-point STAR, or a STREAK that faces the way it flies. Options: `DOT`, `SQUARE`, `STAR`, `STREAK`. |
| `fade_to` | `Color` | `Color(1.0, 1.0, 1.0, 0.0)` | Colour each particle fades toward as it dies. Default is transparent white (a plain fade). Set a tint (e.g. deep red, alpha 0) for embers that cool as they fly out. |
| `air_drag` | `float` | `0.0` | Air resistance. Particles shoot out then slow, instead of flying ballistic. 0 = none. |
| `spin_degrees` | `float` | `0.0` | Degrees per second each particle spins. 0 = no spin (best for round dots). |
| `shrink` | `bool` | `true` | If true, particles shrink to nothing over their life instead of holding their size. |

---

### JuiceeConfettiEffect

Multi-color confetti burst. Each piece takes one colour from a configurable palette.

| Property | Type | Default | Description |
|---|---|---|---|
| `amount` | `int` | `40` | Number of confetti particles. |
| `speed` | `float` | `200.0` | Average particle speed (randomized 0.5×-1.5×). |
| `spread` | `float` | `180.0` | Spread angle in degrees either side of Direction (180 = every direction, 90 = half circle). |
| `direction` | `Vector2` | `Vector2.RIGHT` | Which way the pieces fly, Spread either side of it. Up with a spread of 30-60 pours a fountain. |
| `lifetime` | `float` | `1.2` | Particle lifetime in seconds. |
| `gravity` | `Vector2` | `Vector2(0, 250)` | Gravity per second. Default falls down for celebratory rain. |
| `air_drag` | `float` | `0.0` | Air resistance. Pieces shoot out, then slow and drift down like paper instead of flying ballistic. Try 40. 0 = no drag. |
| `colors` | `PackedColorArray` | `PackedColorArray(1, 0.3, 0.3, 1, 1, 0.8, 0.3, 1, 0.3, 1, 0.4, 1, 0.3, 0.6, 1, 1, 0.9, 0.4, 1, 1)` | Color palette - each piece takes one of these colours at random. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `piece_shape` | `PieceShape` | `PieceShape.SQUARE` | Piece shape: SQUARE confetti, RECT paper strips, round CIRCLE dots, or STAR sparkle. Options: `SQUARE`, `RECT`, `CIRCLE`, `STAR`. |
| `piece_scale` | `float` | `1.75` | Average visual size of each piece (randomized around it). |
| `spin_speed` | `float` | `360.0` | Max spin speed in degrees/sec (each piece spins a random amount up to this). 0 = flat. |

---

### JuiceeLightFlashEffect

Flash a `Light2D`'s `energy` and `color`. Target must be a `Light2D` node.

| Property | Type | Default | Description |
|---|---|---|---|
| `target` | `NodePath` | `""` | Path to the Light2D to flash. If empty, the context itself must be a Light2D. |
| `peak_energy` | `float` | `3.0` | Peak energy value at the top of the flash. |
| `flash_color` | `Color` | `Color.WHITE` | Color the light tweens to at peak. |
| `duration` | `float` | `0.3` | Total flash duration (30% ramp-in + 70% ramp-out). |
| `return_to_original` | `bool` | `true` | If true, light returns to its original energy/color after the flash. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping the energy rise to the peak. FEEL-style curve control. |
| `pulse_count` | `int` | `1` | Flash this many times in the duration instead of once. 3+ reads as an alarm. |
| `size_boost` | `float` | `1.0` | Also scale the light's texture_scale at the peak, so the pool of light swells with the flash. 1 = the size never changes. |

---

### JuiceeSpringEffect

Harmonic-oscillator spring on any `Vector2` or `float` property. Use for bouncy menus, squash-on-hit, panel-into-view oscillation.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_path` | `NodePath` | `""` | Node path to the target (e.g., "../Button" or "%MenuButton"). Resolved relative to the `context` node passed to apply(). |
| `property` | `String` | `"scale"` | Name of the property to spring. A Vector2 ("scale", "position", "pivot_offset") uses both impulse axes; a float ("rotation", "skew") springs on impulse.x. |
| `impulse` | `Vector2` | `Vector2(4.0, 4.0)` | Initial velocity kick. Bigger = stronger overshoot. Tuned for a visible scale punch by default; lower it for subtle springs or raise it for position kicks. |
| `stiffness` | `float` | `200.0` | Spring stiffness (k). Higher = snappier return, more oscillation cycles. |
| `damping` | `float` | `10.0` | Damping coefficient (c). Higher = settles faster, less ringy. |
| `mass` | `float` | `1.0` | Mass - higher = more inertia, slower oscillation. |
| `max_duration` | `float` | `2.0` | Maximum simulation duration in seconds - bails out if still ringing after this. |
| `settle_threshold` | `float` | `0.01` | Settled threshold - both displacement and velocity must be below this length to consider the simulation done early. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `initial_offset` | `Vector2` | `Vector2.ZERO` | Start the spring already displaced by this much and release it, instead of kicking it with velocity. A pulled-back catapult rather than a flick. |
| `max_displacement` | `float` | `0.0` | Clamp how far the spring may travel from rest, so a hard hit cannot fling a UI element off screen. 0 = no limit. |

---

### JuiceeAmbientFlashEffect

Repeating `modulate` flash for sustained danger states. Loops until `stop()` is called or `duration` expires.

| Property | Type | Default | Description |
|---|---|---|---|
| `flash_color` | `Color` | `Color(1.0, 0.3, 0.3, 1.0)` | Peak flash color the modulate pulses toward. Full alpha keeps the node opaque as it tints (a red danger pulse); a low alpha would read as fading out, not flashing. |
| `duration` | `float` | `3.0` | Total duration across all cycles. |
| `frequency` | `float` | `1.5` | Cycles per second (higher = more frantic). |
| `hold_at_end` | `bool` | `false` | If true, holds at flash_color at the end. If false, the original colour comes straight back. |
| `pulse_curve` | `Curve` | - | Easing curve for each pulse (null = a sine ease). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `waveform` | `Waveform` | `Waveform.TRIANGLE` | Pulse shape: TRIANGLE fades in and out (an alarm throb), SQUARE snaps between the two colours (a police light), SAWTOOTH ramps up then cuts (a strobe sweep). Options: `TRIANGLE`, `SQUARE`, `SAWTOOTH`. |

**Accessibility tag:** `TAG_FLASH`

---

### JuiceeStrobeLightEffect

Square-wave `Light2D` energy pulse. Target must be `Light2D`. Lightning, flashbang, emergency siren.

| Property | Type | Default | Description |
|---|---|---|---|
| `pulse_count` | `int` | `6` | Number of on/off pulses across the duration. |
| `duration` | `float` | `0.5` | Total duration of the strobe. |
| `peak_energy` | `float` | `3.0` | Peak energy during the "on" phase. |
| `strobe_color` | `Color` | `Color(1, 1, 1, 0)` | If set, light color is overridden during the strobe (resets at end). Leave alpha at 0 to keep the light's own colour. |
| `on_ratio` | `float` | `0.4` | Fraction of each pulse spent in the ON state. 0.5 = even on/off, 0.2 = quick flashes with darkness between (more dramatic). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `irregularity` | `float` | `0.0` | Randomize each pulse length by this fraction, for a failing / broken strobe rather than a metronome. 0 = perfectly even pulses. |
| `energy_decay` | `float` | `1.0` | Each pulse is this fraction as bright as the one before, so the strobe dies out. 1 = every pulse equal. |

**Accessibility tag:** `TAG_FLASH`

---

### JuiceeRecoilEffect

Directional position kick on Node2D with spring-back. Gun recoil, hit absorption.

| Property | Type | Default | Description |
|---|---|---|---|
| `direction` | `Vector2` | `Vector2(-1, 0)` | Direction of the kick (gets normalized). Pass via runtime params for dynamic per-shot direction. |
| `kick_distance` | `float` | `12.0` | Magnitude in pixels of the initial kick. |
| `attack` | `float` | `0.05` | How long the kick spends extending out (very brief). |
| `return_duration` | `float` | `0.18` | How long the spring-back lasts (longer than attack for "ease-back" feel). |
| `settle_wobble` | `float` | `1.5` | Settle wobble: above 0.1 the return springs back with an elastic wobble; at or below, it overshoots once. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing the spring-back for the return. FEEL-style. |
| `rotation_kick` | `float` | `0.0` | Degrees the node also rotates on the kick (a gun barrel rising), returning with it. |

**Runtime params:** `{"direction": Vector2}` - override direction per-shot.  
**Accessibility tag:** `TAG_SCREENSHAKE`

---

### JuiceeOutlineEffect

Animates a colored outline around a `Sprite2D`, `AnimatedSprite2D`, `TextureRect`, `TextureButton` or `NinePatchRect` via shader uniform, drawn in the texture's transparent margin. Selection ring, status glow, lock-on indicator.

**Shader:** `addons/juicee/shaders/outline.gdshader`

| Property | Type | Default | Description |
|---|---|---|---|
| `outline_width` | `float` | `2.0` | Peak outline width in pixels. |
| `outline_color` | `Color` | `Color(1.0, 0.85, 0.20, 1.0)` | Outline color. |
| `duration` | `float` | `0.8` | Duration: ramp-in + hold + ramp-out. |
| `fade_out` | `bool` | `true` | If true, outline fades back to 0 at end. If false, holds (caller cleans up with a follow-up effect or `target.material = null`). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `pulse_count` | `int` | `1` | Pulse the outline in and out this many times across the duration, instead of one ramp-in / ramp-out. 1 = a single ramp; 3+ = a throbbing lock-on ring. |
| `hold_time` | `float` | `0.0` | Seconds to hold the outline at full width before it fades. |

---

### JuiceeColorCycleEffect

Cycles `modulate` through the HSV hue wheel, or through your own `colors`. Rainbow powerup, party mode, boss phase shift.

| Property | Type | Default | Description |
|---|---|---|---|
| `cycles` | `float` | `2.0` | Number of full revolutions across the duration (one revolution = the whole hue wheel, or one full pass through `colors` if you set some). |
| `duration` | `float` | `1.5` | Total duration of the cycling. |
| `colors` | `PackedColorArray` | `PackedColorArray()` | Optional custom colors to cycle through instead of the rainbow. Leave it empty for the HSV wheel; add colors and the effect sweeps through them. `saturation` and `value` below only apply to the rainbow. |
| `smooth` | `bool` | `true` | Palette only: blend smoothly between colors (a gradient sweep), or turn it off to hold each color then hard-switch to the next, the way police lights or a strobe flash. |
| `bounce` | `bool` | `false` | Palette only: bounce back and forth through the colors (first to last and back) instead of looping (where the last color wraps around to the first). |
| `saturation` | `float` | `1.0` | Saturation of the cycled hue (0 = grayscale, 1 = full color). Rainbow only. |
| `value` | `float` | `1.0` | Value/brightness of the cycled hue (1 = full bright). Rainbow only. |
| `preserve_alpha` | `bool` | `true` | If true, alpha is preserved from the original modulate. If false, fully opaque. |
| `loop` | `bool` | `false` | If true, cycle forever (until stop()). `duration` still sets the cycle SPEED (cycles per duration), it just no longer ends the effect. Great for a persistent "RAINBOW MODE" glow on a title, powerup, or victory banner. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `hue_drift` | `float` | `0.0` | Extra hue rotation (degrees) applied on top of the cycle, so a palette can drift as it plays instead of repeating exactly. |
| `speed_ramp` | `float` | `1.0` | Speed up (>1) or slow down (<1) as the cycle progresses, for a spin-up or wind-down. |

---

### JuiceeSpinEffect

Spins a Node2D at `degrees_per_second` for `duration`. Coin pickups, death spin, victory twirl.

| Property | Type | Default | Description |
|---|---|---|---|
| `degrees_per_second` | `float` | `360.0` | Degrees rotated per second. Negative = counter-clockwise. 360 = one full rotation/sec. |
| `duration` | `float` | `1.0` | Total spin duration in seconds. It turns degrees_per_second * duration degrees in all. |
| `restore_on_end` | `bool` | `false` | If true, tweens rotation back to the original angle after spinning ends. |
| `restore_duration` | `float` | `0.15` | Duration of the snap-back tween (only used when restore_on_end = true). |
| `ease_out` | `bool` | `false` | Start fast and decelerate into the stop, like a coin settling, instead of spinning at constant speed and stopping dead. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn speed curve (0..1) over the spin. Replaces Ease Out / constant speed with your own accel/decel shape. FEEL-style curve control. |
| `windup` | `float` | `0.0` | Anticipation: wind back this many degrees (opposite the spin) before launching. |

---

### JuiceeWiggleEffect

Random position jitter at `frequency` Hz with optional decay. Anxiety, confusion, low-health tremor.

| Property | Type | Default | Description |
|---|---|---|---|
| `amplitude` | `float` | `6.0` | Max position displacement in pixels. |
| `frequency` | `float` | `12.0` | Position update rate per second (higher = jitterier, lower = sluggish wobble). |
| `duration` | `float` | `1.0` | Total wiggle duration in seconds. |
| `decay` | `bool` | `true` | Amplitude decays to 0 by end of duration. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `axis` | `WiggleAxis` | `WiggleAxis.BOTH` | Which axis jitters: BOTH, HORIZONTAL only, or VERTICAL only. Options: `BOTH`, `HORIZONTAL`, `VERTICAL`. |
| `rotation_jitter` | `float` | `0.0` | Also jitter rotation by up to this many degrees, for a frantic rattle. 0 = position only. |

---

### JuiceeSpriteBobEffect

Sine-wave bob along `bob_axis`. `sin(t * PI)` envelope for smooth start and stop. Floating pickups, hover loop, idle animations.

| Property | Type | Default | Description |
|---|---|---|---|
| `amplitude` | `float` | `4.0` | Peak displacement in pixels. |
| `frequency` | `float` | `1.5` | Bob cycles per second. 1.5 = gentle float, 3.0 = nervous flutter. |
| `duration` | `float` | `2.0` | Total duration in seconds. |
| `phase_offset` | `float` | `0.0` | Phase offset in radians (PI/2 = start at peak). |
| `bob_axis` | `Vector2` | `Vector2(0.0, 1.0)` | Direction of the bob. (0, 1) = vertical, (1, 0) = horizontal. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `loop` | `bool` | `false` | Bob forever (ignores Duration, no fade in/out) until stop() - a true idle loop. |
| `rotation_sway` | `float` | `0.0` | Tilt this many degrees in sync with the bob, for a rocking float. 0 = position only. |

---

### JuiceePopInEffect

TRANS_SPRING / EASE_OUT scale-in from `from_scale` to the node's own scale. Menus opening, pickups spawning, icons appearing. Works on Node2D and Control.

| Property | Type | Default | Description |
|---|---|---|---|
| `from_scale` | `float` | `0.0` | Scale the pop starts from (0 = invisible, 0.5 = half size). An absolute scale, not a fraction of the node's own. |
| `duration` | `float` | `0.35` | Total animation duration including spring settle. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing the built-in spring for the scale-in. |
| `fade_in` | `bool` | `false` | Also fade the node in from transparent while it pops. |
| `slide_from` | `Vector2` | `Vector2.ZERO` | Slide in from this pixel offset while scaling (e.g. (0, -40) drops in from above). |

---

### JuiceeShakeControlEffect

Horizontal shake on a `Control` node with ±30% vertical noise and linear decay. Wrong-password field, invalid-action button.

| Property | Type | Default | Description |
|---|---|---|---|
| `intensity` | `float` | `10.0` | Peak horizontal displacement in pixels. Vertical Ratio sets how much of it goes vertical. |
| `duration` | `float` | `0.3` | Total shake duration in seconds. |
| `frequency` | `float` | `20.0` | Updates per second (higher = more jittery). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `vertical_ratio` | `float` | `0.3` | Vertical shake as a fraction of the horizontal. 0 = pure left/right (the classic "wrong answer" wobble), 1 = shakes equally in both axes. |
| `rotation_jitter` | `float` | `0.0` | Rotation jitter in degrees layered on the shake, for a more violent rattle. 0 = none. |

---

### JuiceePulseEffect

Repeating EXPO scale pulse per interval. `count = 0` pulses until `duration` runs out, or until `stop()` when `duration` is 0. Heartbeat, charge meter, selected state.

| Property | Type | Default | Description |
|---|---|---|---|
| `scale_amount` | `float` | `0.15` | Scale overshoot per pulse as a fraction (0.15 = 15% larger at peak). |
| `count` | `int` | `3` | Number of pulses to fire. 0 = fire until `duration` runs out. |
| `pulse_interval` | `float` | `0.5` | Seconds between the start of each pulse. |
| `duration` | `float` | `0.0` | Maximum run time in seconds, whatever Count says. 0 = no limit (with Count 0 it pulses until stop()). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing the built-in easing for the grow phase. |
| `up_ratio` | `float` | `0.25` | Fraction of each pulse spent growing (rest is the ease back). 0.25 = a quick punch. |

---

### JuiceeFadeEffect

Fade a CanvasItem's `modulate.a` to `target_alpha` over `duration`. With `restore_on_end = true`: fade to target, hold, then fade back to original. The most fundamental UI and game effect - always use this instead of tweening `modulate.a` manually.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_alpha` | `float` | `0.0` | Target alpha. 0.0 = fully transparent, 1.0 = fully opaque. |
| `duration` | `float` | `0.5` | Duration to reach target_alpha. |
| `restore_on_end` | `bool` | `false` | If true, tween back to original alpha after reaching target_alpha. |
| `hold_duration` | `float` | `0.0` | Hold time at target_alpha before restoring (only when restore_on_end = true). |
| `restore_duration` | `float` | `0.4` | Duration of the return tween (only when restore_on_end = true). |
| `transition` | `Tween.TransitionType` | `Tween.TRANS_SINE` | Tween transition. |
| `easing` | `Tween.EaseType` | `Tween.EASE_IN_OUT` | Tween ease. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing Transition/Ease for the fade. FEEL-style. |
| `from_alpha` | `float` | `-1.0` | Force the fade to START from this alpha (e.g. 0 for a guaranteed fade-in). -1 = start from the node's current alpha. |

---

### JuiceeFlipEffect

Set `flip_h` / `flip_v` on a Sprite2D or AnimatedSprite2D using a per-axis mode: `TOGGLE` (invert), `SET_TRUE` (force flipped), or `SET_FALSE` (force unflipped). Optional `restore_on_end` with configurable hold time.

| Property | Type | Default | Description |
|---|---|---|---|
| `flip_h_mode` | `Mode` | `Mode.TOGGLE` | How to apply the flip_h change. Options: `TOGGLE`, `SET_TRUE`, `SET_FALSE`. |
| `flip_v_mode` | `Mode` | `Mode.SET_FALSE` | How to apply the flip_v change. The default SET_FALSE leaves an unflipped sprite as it is (and un-flips one already flipped). Options: `TOGGLE`, `SET_TRUE`, `SET_FALSE`. |
| `restore_on_end` | `bool` | `false` | If true, restore original flip state after hold_duration. |
| `hold_duration` | `float` | `0.0` | Seconds to hold the new flip state before restoring. 0 = restore immediately. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `animate` | `bool` | `false` | Animate the flip as a card/coin turn (the node squashes edge-on and back) instead of an instant swap. The boolean flips at the halfway point, hidden by the squash. |
| `flip_duration` | `float` | `0.3` | Duration of the animated flip (only when Animate is on). |

---

### JuiceeInstantiateEffect

Spawn a `PackedScene` at the context node's world position. Adds to the current scene tree under `parent_path` (or the current scene). Auto-frees the instance after `lifetime` seconds. Works for both 2D and 3D contexts; the scatter, rotation and scale variety options are 2D only.

| Property | Type | Default | Description |
|---|---|---|---|
| `scene` | `PackedScene` | - | Scene to spawn. Must be set - effect is a no-op if null. |
| `position_offset` | `Vector2` | `Vector2.ZERO` | World-space offset added to the context's position. |
| `parent_path` | `NodePath` | `""` | Optional parent node path. Empty = scene's current root scene. |
| `lifetime` | `float` | `2.0` | Seconds until the spawned instance is queue_freed. 0 = never auto-free. |
| `inherit_rotation` | `bool` | `false` | Copy the context node's rotation to the spawned instance. |
| `inherit_scale` | `bool` | `false` | Copy the context node's scale to the spawned instance. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `count` | `int` | `1` | Spawn this many copies instead of one (a shower of debris, a burst of pickups). |
| `scatter_radius` | `float` | `0.0` | Scatter each copy randomly within this radius (pixels) of the spawn point. 2D only. |
| `random_rotation` | `bool` | `false` | Give each copy a random rotation, so a pile of debris is not all aligned. 2D only. |
| `scale_variance` | `float` | `0.0` | Randomize each copy's scale by this fraction (0.3 = 70%-130%), for natural variety. 2D only. |

---

### JuiceeSizeDeltaEffect

Tween a Control node's `custom_minimum_size` or `size` to `target_size`. With `restore_on_end = true`, tweens back to the original size after an optional hold. Use `CUSTOM_MINIMUM_SIZE` for anchored layouts; `SIZE` for freely-positioned Controls.

| Property | Type | Default | Description |
|---|---|---|---|
| `size_target` | `SizeTarget` | `SizeTarget.CUSTOM_MINIMUM_SIZE` | Which size property to animate. Options: `CUSTOM_MINIMUM_SIZE`, `SIZE`. |
| `target_size` | `Vector2` | `Vector2(200.0, 50.0)` | Target size in pixels. |
| `duration` | `float` | `0.3` | Duration to reach target size. |
| `restore_on_end` | `bool` | `false` | If true, tween back to original size after reaching target_size. |
| `hold_duration` | `float` | `0.0` | Hold time at target size before restoring (only when restore_on_end = true). |
| `restore_duration` | `float` | `0.2` | Duration of the return tween (only when restore_on_end = true). |
| `transition` | `Tween.TransitionType` | `Tween.TRANS_QUAD` | Tween transition. |
| `easing` | `Tween.EaseType` | `Tween.EASE_OUT` | Tween ease. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing Transition/Ease for the resize. FEEL-style. |
| `relative` | `bool` | `false` | Treat Target Size as a delta added to the current size, not an absolute size. |

---

### JuiceeShaderParameterEffect

Tween any `ShaderMaterial` uniform from `from_value` to `to_value`. Works on `CanvasItem` (reads `material` directly) and `MeshInstance3D` (reads `get_active_material(surface_index)`, the material actually drawn). Drive dissolve, emission intensity, scanline density - any float/vec/color uniform.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_path` | `NodePath` | `""` | Node with a ShaderMaterial. Empty = context node itself. |
| `surface_index` | `int` | `0` | For MeshInstance3D: which surface (0 = first surface). |
| `parameter_name` | `String` | `""` | Name of the shader uniform to animate (as written in the shader). |
| `from_value` | `Variant` | `null` | Starting value. Leave null to use the current value at apply() time. |
| `to_value` | `Variant` | `1.0` | Target value to animate to. |
| `duration` | `float` | `0.4` | Animation duration in seconds. |
| `restore_on_end` | `bool` | `true` | Restore original uniform value at the end. |
| `transition` | `Tween.TransitionType` | `Tween.TRANS_QUAD` | Tween transition type. |
| `easing` | `Tween.EaseType` | `Tween.EASE_OUT` | Tween ease type. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing the built-in easing for the parameter sweep. |
| `ping_pong` | `bool` | `false` | Sweep to the value and back again (the return takes another Duration), which is what a one-shot shader pulse (a dissolve blip, a hit rim-light) wants. |
| `oscillations` | `int` | `1` | Oscillate the parameter this many times across the duration instead of a single sweep, for a throbbing shader. |

---

### JuiceeFlickerEffect

Organic random modulate flicker on a CanvasItem. Randomises on/off intervals from `[min_interval, max_interval]`. `duration = 0` runs indefinitely until `stop()` is called. Torches, broken neon signs, ghost transparency, dying machinery, flickering hazard lights.

**Accessibility tag:** `TAG_FLASH`

| Property | Type | Default | Description |
|---|---|---|---|
| `off_color` | `Color` | `Color(1.0, 1.0, 1.0, 0.0)` | Color during the "off" phase. Default is transparent, so the node blinks out and back (damage i-frames, respawn). For a dying-neon dim, set a dark opaque colour. |
| `min_interval` | `float` | `0.04` | Minimum interval between state changes (seconds). |
| `max_interval` | `float` | `0.15` | Maximum interval between state changes (seconds). |
| `duration` | `float` | `1.0` | Total duration. 0 = flicker until stop() is called. |
| `off_chance` | `float` | `0.4` | Probability (0-1) that any given interval toggles to OFF. Lower = mostly on with rare flickers. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `analog` | `bool` | `false` | Analogue mode: instead of snapping between on and off, drift the brightness randomly between Min Brightness and 1 for a guttering candle / dying-neon glow. |
| `min_brightness` | `float` | `0.35` | Analogue mode only: dimmest the node gets while guttering. |

---

### JuiceeScaleEffect

General scale tween on `Node2D` or `Control` to `target_scale` with optional return to original. Unlike `BounceEffect` (a fixed punch that always returns), this tweens to `target_scale`: a multiplier on the current scale, or an exact scale with `relative` off. Use for emphasis, selection highlight, or UI panel resize.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_scale` | `Vector2` | `Vector2(1.5, 1.5)` | Target scale: a multiplier on the node's current scale when Relative is on, the exact scale when it is off. |
| `duration` | `float` | `0.3` | Duration of the scale-to animation. |
| `return_to_original` | `bool` | `true` | If true, tween back to the original scale after reaching target. |
| `return_duration` | `float` | `0.25` | Duration of the return animation. Ignored when return_to_original=false. |
| `relative` | `bool` | `true` | Multiply the node's current scale (true), or treat target_scale as the exact scale to reach (false). |
| `transition` | `Tween.TransitionType` | `Tween.TRANS_BACK` | Transition type for the scale-to phase. |
| `easing` | `Tween.EaseType` | `Tween.EASE_OUT` | Ease type for scale-to. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) that replaces the Transition/Ease above for the scale-to phase. Leave null for the built-in easing. This is FEEL-style curve control. |
| `hold_time` | `float` | `0.0` | Seconds to hold at the target scale before returning. 0 = return straight away. |

---

### JuiceeScale3DEffect

The Node3D counterpart of `JuiceeScaleEffect`. Scale punch that can ease back to the original scale. Pickups, impacts, props that grow and shrink.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_scale` | `Vector3` | `Vector3(1.5, 1.5, 1.5)` | Scale multiplier when `relative` (1.5 = half again as big), or the exact scale to land on when not. |
| `duration` | `float` | `0.3` | Total punch duration in seconds. |
| `return_to_original` | `bool` | `true` | If true, eases back to the original scale after the punch. |
| `return_duration` | `float` | `0.25` | Duration of the return animation. Ignored when return_to_original = false. |
| `relative` | `bool` | `true` | Multiply the node's current scale (true), or treat target_scale as the exact scale to reach (false). |
| `trans_type` | `Tween.TransitionType` | `Tween.TRANS_BACK` | Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest. |
| `ease_type` | `Tween.EaseType` | `Tween.EASE_OUT` | Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing Transition/Ease for the scale. FEEL-style. |
| `hold_time` | `float` | `0.0` | Seconds to hold at the target scale before returning. 0 = return straight away. |

---

### JuiceeParticleEffect

Control an existing particle node, 2D or 3D, by NodePath (empty = the node it plays on). Four actions: `EMIT` (restart the emitter for a fresh burst), `STOP`, `RESTART` (the same restart, with emitting forced on), `TOGGLE`. Optional `wait_for_finish` stalls the calling sequence until the particle system's lifetime elapses.

| Property | Type | Default | Description |
|---|---|---|---|
| `particle_path` | `NodePath` | `""` | Path to the particle node. Empty = the node this plays on. |
| `action` | `Action` | `Action.EMIT` | What to do with the particle node. Options: `EMIT`, `STOP`, `RESTART`, `TOGGLE`. |
| `wait_for_finish` | `bool` | `false` | If true and the action is EMIT or RESTART, wait until the particles have died before continuing. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `amount_override` | `int` | `0` | Override the node's particle amount for this play, so one emitter can do a small puff and a big blast. 0 = keep whatever the node is set to. |
| `lifetime_scale` | `float` | `1.0` | Scale the emitter's lifetime for this play. 1 = unchanged. |
| `restore_overrides` | `bool` | `true` | Restore the overridden amount and lifetime when the effect finishes. |

---

### JuiceeLight3DEffect

Flash a `Light3D`'s energy and color to a peak value then decay back. Uses `JuiceeStateStack` to restore `light_energy` and `light_color` safely under concurrent calls. Muzzle flash, explosion light, magic pulse, flickering candle highlight.

**Dimensions:** 3D only

| Property | Type | Default | Description |
|---|---|---|---|
| `light_path` | `NodePath` | `""` | Path to the Light3D node. Empty = context must be a Light3D. |
| `peak_energy` | `float` | `5.0` | Peak light energy at the flash moment. |
| `flash_color` | `Color` | `Color.WHITE` | Light color at the flash peak. White = keep current color. |
| `duration` | `float` | `0.3` | Total duration of the energy ramp up + decay. |
| `restore_energy` | `bool` | `true` | Restore original energy after the flash (true) or leave at peak (false). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping the energy rise to the peak. FEEL-style curve control. |
| `pulse_count` | `int` | `1` | Flash this many times within the duration instead of once. 3+ reads as an alarm. |
| `energy_decay` | `float` | `1.0` | Each pulse is this fraction as bright as the one before, so a burst dies out. |

---

### JuiceeMaterial3DEffect

Animate any property on a `MeshInstance3D`'s surface material. **Duplicates the material at apply time** to avoid affecting other mesh instances sharing the same resource. Configurable `restore_on_end`. Dissolve in/out, emission ramp, fresnel fade, hit-flash on 3D meshes.

**Dimensions:** 3D only

| Property | Type | Default | Description |
|---|---|---|---|
| `mesh_path` | `NodePath` | `""` | Path to the MeshInstance3D. Empty = context itself. |
| `surface_index` | `int` | `0` | Which surface (0 = first surface). |
| `property_name` | `String` | `"albedo_color"` | Material property to tween: a BaseMaterial3D property, or a shader parameter on a ShaderMaterial. Examples: "albedo_color", "emission", "emission_energy_multiplier", "roughness", "metallic". |
| `from_value` | `Variant` | `null` | Start value (null = current material value at apply time). |
| `to_value` | `Variant` | `Color(1.0, 0.2, 0.2, 1.0)` | Target value to tween to. |
| `duration` | `float` | `0.3` | Tween duration. |
| `restore_on_end` | `bool` | `true` | Restore the original material at the end. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing the quad ease for the property tween. |
| `ping_pong` | `bool` | `false` | Return to the starting value after reaching the target, instead of holding there. A hit flash wants this on; a permanent recolour wants it off. |
| `hold_time` | `float` | `0.0` | Seconds to hold at the target value before returning (only with Ping Pong). |

---

### JuiceeImpactRingEffect

Expanding ring + radiating "POW" spikes drawn at a Node2D in world-space (`Line2D`, no shaders). Crits, parries, big landings, small explosions. Distinct from the full-screen shader `JuiceeShockwaveEffect` - this geometry sits on the object. *(New in 1.2.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `radius` | `float` | `42.0` | Ring radius in pixels. The ring starts at half this and grows to Radius times Expand. |
| `expand` | `float` | `2.4` | Final scale the whole flourish expands to (2.4 = ends 2.4× its drawn size). |
| `ring_width` | `float` | `6.0` | Thickness of the ring line in pixels. |
| `color` | `Color` | `Color(1.0, 0.85, 0.3)` | Ring + spike colour. |
| `spikes` | `int` | `8` | Number of radiating impact spikes around the ring. 0 = ring only. |
| `spike_length` | `float` | `34.0` | How far each spike extends past the ring, in pixels. |
| `duration` | `float` | `0.45` | Total duration of the expand + fade. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `echo_ring` | `float` | `0.0` | Send a second, smaller ring out behind the first for a layered blast. 0 = one ring. |
| `spin_degrees` | `float` | `0.0` | Degrees the ring (and its spikes) rotate as it expands, so the burst swirls. |
| `spike_variance` | `float` | `0.35` | Randomize each spike's length by this fraction, so the star reads hand-drawn instead of perfectly regular. 0 = uniform spikes. |

---

### JuiceeSwayEffect

Smooth pendulum rotation driven by a sine wave. Unlike `JuiceeWiggleEffect` (random jitter) or `JuiceeSpinEffect` (full revolution), it's a soft looping tilt. Idle "alive" UI, hanging signs, floating pickups, breathing titles. Works on Node2D and Control. *(New in 1.2.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `angle` | `float` | `6.0` | Peak sway angle to each side, in degrees. |
| `period` | `float` | `1.2` | Seconds for one full swing, left to right and back again. |
| `cycles` | `float` | `2.0` | Number of full cycles to run. 0 = sway forever (until stop()). |
| `center_pivot` | `bool` | `true` | For Control targets, rotate around the centre instead of the top-left corner. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `pivot` | `Vector2` | `Vector2.ZERO` | Hinge offset (pixels) to swing around like a pendulum. (0,0) tilts in place; (0,-40) hangs and swings from a point above, e.g. a hanging sign or lantern. |
| `lean_degrees` | `float` | `0.0` | A resting lean (degrees) that the sway rocks around, instead of straight up. |

---

### JuiceeAfterimageEffect

Drops fading sprite copies behind the node as it moves. Dashes, dodges, speed power-ups. The target, or the first `Sprite2D` or `AnimatedSprite2D` under it, supplies the picture. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `duration` | `float` | `0.3` | How long to keep dropping ghosts (match it to your dash / dodge length). |
| `interval` | `float` | `0.04` | Seconds between ghosts. Smaller = a denser trail. |
| `ghost_lifetime` | `float` | `0.35` | How long each ghost takes to fade out. |
| `color` | `Color` | `Color(0.6, 0.9, 1.0, 0.6)` | Ghost tint (multiplies the sprite). The alpha sets the starting opacity. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ghost_end_scale` | `float` | `1.0` | Each ghost shrinks (or grows) to this fraction of the sprite over its life. 1 = it holds the original size. |
| `ghost_spin` | `float` | `0.0` | Degrees each ghost rotates as it fades, so a dash trail spirals slightly. |
| `fade_to` | `Color` | `Color(1.0, 1.0, 1.0, 0.0)` | Colour each ghost fades toward before vanishing. Leave alpha 0 for a plain fade; set a hot tint for an energy trail that cools as it dissipates. |

---

### JuiceeBreatheEffect

A slow in-and-out idle scale loop. Living characters, resting pickups, soft title screens. `cycles = 0` breathes forever (until `stop()`). *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `amount` | `float` | `0.05` | How much it grows on the in-breath (0.05 = 5% bigger at the peak). |
| `period` | `float` | `2.0` | Seconds per breath. |
| `cycles` | `int` | `3` | Number of breaths. 0 = forever. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `axis` | `BreatheAxis` | `BreatheAxis.BOTH` | Which axis expands on the in-breath: BOTH (uniform), HORIZONTAL, or VERTICAL only. Options: `BOTH`, `HORIZONTAL`, `VERTICAL`. |
| `bob_pixels` | `float` | `0.0` | Also rise this many pixels on the in-breath, for a gentle float-with-breath. 0 = none. |

---

### JuiceeCrackEffect

Jagged fracture lines radiating from the impact point (`Line2D`, no shaders), then fading. Heavy landings, boss slams, shatters. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `count` | `int` | `5` | How many cracks radiate out from the impact point. |
| `length` | `float` | `70.0` | How far each crack reaches, in pixels. |
| `jaggedness` | `float` | `0.4` | Jaggedness, how much each crack zig-zags off a straight line (0 = straight spokes). |
| `thickness` | `float` | `5.0` | Line thickness at the base (each crack tapers to a point at its tip). |
| `duration` | `float` | `0.5` | How long each crack lasts, fade included: it snaps out, holds, then fades. |
| `color` | `Color` | `Color(0.95, 0.95, 1.0, 0.9)` | Crack color. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `segments` | `int` | `4` | Zig-zag resolution: points per crack. More = finer, more organic fractures. |
| `spread_angle` | `float` | `360.0` | Cone (degrees) the cracks spread over, centred on Aim Degrees. 360 = a full radial burst (the default); 90 = a directional fan, e.g. cracks away from an impact face. |
| `aim_degrees` | `float` | `0.0` | Direction the cone points, in degrees. Only meaningful when Spread Angle < 360. |
| `length_variance` | `float` | `0.0` | Random length variation per crack (0.4 = each is 60%-140% of Length). 0 = all equal. |

---

### JuiceeGlowPulseEffect

A tinted brightness throb on the node's `modulate`. Charge-ups, power states, button shine. A white tint just brightens; a coloured tint pushes toward that hue at the peak. *(New in 1.5.0.)*

**Accessibility tag:** `TAG_FLASH`

| Property | Type | Default | Description |
|---|---|---|---|
| `peak` | `float` | `1.8` | Brightness multiplier at the peak of each pulse. |
| `tint` | `Color` | `Color.WHITE` | Tint the modulate moves toward at the peak (white = just brighter). |
| `duration` | `float` | `0.5` | Duration of a single pulse (up and back). |
| `count` | `int` | `1` | How many pulses. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing the sine for the brighten phase. FEEL-style. |
| `hold_time` | `float` | `0.0` | Seconds to hold at peak brightness on each pulse before easing back. 0 = no hold. |

---

### JuiceeHeartbeatEffect

A double-thump scale pulse (a big beat, then a smaller one) at a set BPM. Low health, tension, lock-on. `duration = 0` plays a single beat. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `amount` | `float` | `0.18` | Scale-up of the first (big) pop. The second pop is smaller. |
| `bpm` | `float` | `70.0` | Beats per minute. |
| `duration` | `float` | `2.0` | Total time. 0 = a single beat. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `color_pulse` | `Color` | `Color(1.0, 0.2, 0.2, 0.0)` | Colour the node pulses toward on each beat (its alpha is the strength). Transparent = no tint. A deep red here turns it into a proper low-health throb. |
| `second_ratio` | `float` | `0.55` | Size of the second (dub) pop relative to the first. 0.55 = a bit over half. |

---

### JuiceeHitSparkEffect

A directional spark spray off a hit point, aimed by the `hit_direction` runtime param. Clangs, parries, ricochets. Spawns short-lived `CPUParticles2D` sparks in 2D world-space. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `amount` | `int` | `10` | How many sparks fly. |
| `speed` | `float` | `420.0` | Spark speed (actual is randomized around this). |
| `cone` | `float` | `24.0` | Half-width of the cone, in degrees either side of the hit direction. Small = a tight, focused spray. |
| `lifetime` | `float` | `0.25` | How long each spark lives. |
| `color` | `Color` | `Color(1.0, 0.95, 0.6, 1.0)` | Spark color. |
| `default_direction` | `Vector2` | `Vector2.RIGHT` | Aim used when the caller doesn't pass {"hit_direction": ...}. Sparks fly this way. |
| `gravity` | `Vector2` | `Vector2(0, 600)` | Gravity pulling the sparks down as they fly (0 = straight cone). |
| `spark_scale` | `float` | `2.2` | Visual size of each spark. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `spark_shape` | `JuiceeBurstEffect.ParticleShape` | `JuiceeBurstEffect.ParticleShape.STREAK` | Shape of each spark: a STREAK facing the way it flies, a round DOT, a chunky SQUARE (debris), or a 4-point STAR (glinty). Options: `DOT`, `SQUARE`, `STAR`, `STREAK`. |
| `fade_to` | `Color` | `Color(1.0, 1.0, 1.0, 0.0)` | Colour each spark fades toward as it dies. Default transparent white (plain fade); set a warm tint (deep orange, alpha 0) for sparks that cool as they arc away. |
| `air_drag` | `float` | `0.0` | Air resistance. Sparks fly then slow instead of shooting straight. 0 = none. |

---

### JuiceeHopEffect

A quick parabolic bounce up from and back to the resting position. Pickups, idle bobs, acknowledgements. Targets `position`. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `height` | `float` | `24.0` | How high it hops, in pixels. |
| `duration` | `float` | `0.4` | Total up + down time. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `squash` | `float` | `0.0` | Squash and stretch through the hop: stretches tall rising, flattens on landing. 0 = pure position hop. This is what makes a hop read as juicy. |
| `hops` | `int` | `1` | Number of hops, each lower and quicker than the last (a ball settling). 1 = one hop. |

---

### JuiceeJellyWobbleEffect

A decaying axis-stretch wobble that squishes the node along alternating axes. Squishy hits, gel bodies, gummy landings. Targets `scale`. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `amount` | `float` | `0.25` | Peak scale deviation at the start (0.25 = wobbles between ~75% and ~125%). |
| `frequency` | `float` | `4.0` | Wobbles per second. |
| `duration` | `float` | `0.6` | Total wobble time. |
| `decay` | `float` | `3.0` | How fast the wobble dies down. 0 = constant, higher = settles sooner. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `volume_preserve` | `bool` | `true` | Keep volume (squash one axis while the other stretches, the classic jelly). Off wobbles both axes together, so it pulses in and out instead. |
| `rotation_wobble` | `float` | `0.0` | Degrees of rotation wobble layered on the squash, for extra jiggle. 0 = scale only. |

---

### JuiceeSlashArcEffect

A crescent melee swoosh (a tapering `Line2D`) sweeping around the node, centred on `hit_direction`. Sword swings, claws, dash-attacks. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `radius` | `float` | `60.0` | Radius of the arc, how far from the node the slash sweeps. |
| `arc_degrees` | `float` | `140.0` | Angular length of the arc in degrees, how wide the swoosh is. |
| `thickness` | `float` | `22.0` | Thickness of the slash at its fattest point (the ends taper to nothing). |
| `duration` | `float` | `0.26` | How long the slash lasts before it's gone. |
| `color` | `Color` | `Color(1.0, 1.0, 1.0, 1.0)` | Slash color. |
| `default_direction` | `Vector2` | `Vector2.RIGHT` | Facing used when the caller doesn't pass {"hit_direction": ...}, the arc centers here. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `sweep_degrees` | `float` | `55.0` | Sweep the arc through this many extra degrees during its life, so the slash travels instead of appearing whole. 0 = it flashes in place. |
| `echo_strength` | `float` | `0.0` | Draw a fainter echo arc just behind the main one, for a layered double-slash. |
| `expand` | `float` | `1.15` | How much the arc expands outward as it fades. 1.15 is the default flare; 1 = no growth. |

---

### JuiceeSparkleEffect

A scatter of little star pops around the node, appearing and fading. Pickups, collectibles, UI shine. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `count` | `int` | `9` | How many sparkles scatter around the node. |
| `spread` | `float` | `64.0` | Radius of the area the sparkles scatter over. |
| `sparkle_scale` | `float` | `2.0` | Visual size of each sparkle. |
| `color` | `Color` | `Color(1.0, 1.0, 0.7, 1.0)` | Sparkle color. Ignored when an Advanced palette is set. |
| `duration` | `float` | `0.6` | Total time over which the sparkles appear and fade. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `star_points` | `int` | `4` | Points on each star. 4 = classic twinkle, 5-6 = a fuller sparkle, 8 = a starburst. |
| `spawn_shape` | `SpawnShape` | `SpawnShape.SCATTER` | How the sparkles are placed: SCATTER (random within the radius), RING (evenly on the circle), or BURST (all from the centre, thrown outward - pair with Drift). Options: `SCATTER`, `RING`, `BURST`. |
| `palette` | `PackedColorArray` | `PackedColorArray()` | Optional colours to pick from per sparkle. Non-empty overrides Color, so a pickup can sparkle in a gold/white mix or a full rainbow. |
| `drift` | `float` | `0.0` | Extra distance (px) each sparkle drifts outward over its life. 0 = it pops in place. |
| `spin` | `float` | `0.0` | Degrees each sparkle spins over its life. 0 = a fixed random tilt. |

---

### JuiceeSquashLandEffect

Flattens the node on impact (wide and short), then springs it back to shape. Platformer landings, stomps, jelly hops. Targets a Node2D's `scale`. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `squash_amount` | `float` | `0.4` | Squash strength at the moment of impact. 0.4 = about 140% wide / 60% tall at the peak. |
| `duration` | `float` | `0.35` | Total time for the squash plus the recovery. |
| `bounce` | `float` | `0.5` | Spring overshoot on the way back: the node stretches tall past its size before it settles. 0 = ease straight back with no rebound. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `flatten_axis` | `FlattenAxis` | `FlattenAxis.VERTICAL` | Which way it flattens: VERTICAL (a floor landing, wide + short) or HORIZONTAL (a wall slam, tall + thin). Options: `VERTICAL`, `HORIZONTAL`. |

---

### JuiceeStretchEffect

A directional smear-stretch (long along the motion axis, thin across it) that snaps back. Dash starts, launches, anticipation poses. Axis from `hit_direction`. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `amount` | `float` | `0.5` | How much it stretches (0.5 = 150% along the motion axis, ~77% across it). |
| `stretch_time` | `float` | `0.08` | Time spent stretching out. |
| `return_time` | `float` | `0.2` | Time spent snapping back. |
| `default_direction` | `Vector2` | `Vector2.RIGHT` | Axis used when no {"hit_direction": ...} is passed. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing the snap-back easing on the return. FEEL-style. |
| `cross_thin` | `float` | `0.6` | How much the cross axis thins as it stretches (volume feel). 0 = pure stretch, no thinning. |

---

### JuiceeWobbleRotationEffect

A decaying rotational shake that tilts the node back and forth and settles. Bumps, denials, jiggle reactions. Targets `rotation`. *(New in 1.5.0.)*

**Accessibility tag:** `TAG_SCREENSHAKE`

| Property | Type | Default | Description |
|---|---|---|---|
| `amount_degrees` | `float` | `18.0` | Peak tilt in degrees at the start. |
| `frequency` | `float` | `5.0` | Wobbles per second. |
| `duration` | `float` | `0.6` | Total time. |
| `decay` | `float` | `4.0` | How fast it settles. 0 = constant, higher = sooner. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `pivot` | `Vector2` | `Vector2.ZERO` | Hinge offset (pixels) to swing around, like a pendulum. (0,0) rotates in place; (0, -40) hangs and swings from a point above the node, e.g. a sign on a hook. |

---

## Text (8 effects)

Text effects target `Label`, `RichTextLabel`, or `Control` nodes.

---

### JuiceeDamageNumberEffect

Spawns a floating damage number above the target Node2D. Crit support via runtime params. The number lives in the scene, so a hit that frees its target still shows: it rises from where the target was.

| Property | Type | Default | Description |
|---|---|---|---|
| `default_damage` | `int` | `10` | Default damage value when the caller doesn't pass `damage` via runtime params. |
| `color` | `Color` | `Color.WHITE` | Color for normal damage hits. |
| `crit_color` | `Color` | `Color(1.0, 0.85, 0.20, 1.0)` | Color override for critical hits (when `is_crit` is true in params). |
| `rise_distance` | `float` | `80.0` | How far up the number floats (pixels) before fading away. |
| `float_sway` | `float` | `5.0` | Horizontal weave amplitude (px) while floating, so the number drifts gently instead of sliding straight up. 0 = dead-straight rise. |
| `spread` | `float` | `40.0` | Random horizontal offset spread so overlapping hits don't stack perfectly. |
| `font_size` | `int` | `28` | Font size in pixels for normal hits. |
| `crit_size_multiplier` | `float` | `1.5` | Multiplier for crit font_size (so crits feel bigger). |
| `crit_shake` | `float` | `9.0` | Rotation shake amplitude (degrees) on crit spawn - makes big hits feel violent. Decays to zero over a few quick wobbles. 0 = off. Only applies to crits. |
| `font` | `Font` | - | Optional custom font. Leave null to use the project's default UI font. |
| `duration` | `float` | `0.8` | Total animation duration (rise + fade). |
| `prefix` | `String` | `""` | Optional prefix text (e.g. "-" for damage, "+" for healing, "✦" for special). |
| `outline_width` | `int` | `2` | Black outline around the digits - keeps numbers readable on any background. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `thousands_separator` | `String` | `""` | Group the digits with this separator, so 12345 reads as 12,345. Empty = no grouping. |
| `arc_distance` | `float` | `0.0` | Toss the number sideways in an arc (pixels) instead of floating straight up, the way loot numbers pop out of an enemy. 0 = a straight rise. |
| `suffix` | `String` | `""` | Text appended after the number (e.g. "!", " dmg"). Pairs with Prefix. |

**Runtime params:** `{"damage": int, "is_crit": bool}` - pass via `play()` or `Juicee.damage_number()`.

---

### JuiceeFloatingTextEffect

Generic floating text label above a Node2D. Level Up!, pickup names, status messages. Like Damage Number, it keeps rising when its node is freed.

| Property | Type | Default | Description |
|---|---|---|---|
| `default_text` | `String` | `"Hello!"` | Default text shown when caller doesn't pass `text` via runtime params. |
| `color` | `Color` | `Color.WHITE` | Text color (overridable via `color` runtime param). |
| `rise_direction` | `RiseDirection` | `RiseDirection.UP` | Direction the label travels during the animation. Options: `UP`, `DOWN`, `RANDOM_HORIZONTAL_DRIFT`. |
| `travel_distance` | `float` | `100.0` | How far the label moves (pixels). |
| `spread` | `float` | `30.0` | Random offset perpendicular to the travel direction, so two spawns at the same place don't perfectly overlap. |
| `font_size` | `int` | `24` | Font size in pixels. |
| `font` | `Font` | - | Optional custom font. |
| `duration` | `float` | `1.2` | Total animation duration. |
| `outline_width` | `int` | `2` | Black outline width - readability on busy backgrounds. |
| `pop_in_amount` | `float` | `0.3` | Pop-in scale punch at start (set 0 to disable). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) shaping the travel, replacing the quart ease-out. |
| `fade_start_ratio` | `float` | `0.5` | Fraction of the duration the text stays fully opaque before fading. 0.5 = the default (fade over the second half); 0.9 = it hangs and then snaps out. |
| `spin_degrees` | `float` | `0.0` | Slowly rotate the label this many degrees over its life, for a lazy tumble. 0 = none. |

**Runtime params:** `{"text": String, "color": Color}` - dynamically set text and color.

---

### JuiceeButtonPunchEffect

Scale punch for `Control` nodes. Bouncy button click, menu item highlight.

| Property | Type | Default | Description |
|---|---|---|---|
| `scale_factor` | `float` | `1.15` | Peak scale factor on punch (1.2 = 20% bigger). |
| `duration` | `float` | `0.25` | Total animation duration (punch out + ease back). |
| `pre_dip` | `float` | `0.95` | Pre-punch dip - squash slightly before the punch so the bounce reads stronger. Set to 1.0 to disable. |
| `flash_color` | `Color` | `Color(1.0, 1.0, 1.0, 0.0)` | Optional color flash during the punch (set alpha 0 to disable). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing the built-in easing on the punch. FEEL-style. |
| `rotation_kick` | `float` | `0.0` | Degrees the button also tilts on the punch, which reads as a physical press rather than a pure scale pop. 0 = no tilt. |

---

### JuiceeTypewriterEffect

Char-by-char text reveal on a `Label` or `RichTextLabel` via `visible_ratio`. Dialog, intros, terminal vibes.

| Property | Type | Default | Description |
|---|---|---|---|
| `full_text` | `String` | `""` | Default text to type. If empty, uses the Label's current `text` as-is. |
| `chars_per_second` | `float` | `30.0` | Characters revealed per second (higher = faster typing). |
| `click_sounds` | `Array[AudioStream]` | `[]` | Optional click sounds. One is picked at random per character revealed. Leave empty for silent typewriter. |
| `click_volume_db` | `float` | `-6.0` | Click sound volume in dB. |
| `click_pitch_variance` | `float` | `1.15` | Random pitch range for variation (1.0 = no variance). |
| `skip_whitespace_clicks` | `bool` | `true` | Skip whitespace silently (don't play click for spaces). |
| `punctuation_pause` | `float` | `0.0` | Extra pause in seconds after sentence punctuation (. ! ?), half of it after , ; : so the typing breathes like speech. Try 0.25. Note that a pause makes the reveal outlast `chars_per_second`, so 0 = even typing, and predictable total duration. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `cursor_char` | `String` | `""` | Blinking cursor appended while typing (e.g. "_" or "\|"). Empty = no cursor. |
| `cursor_blink_rate` | `float` | `2.0` | Cursor blinks per second. |
| `cursor_after_finish` | `bool` | `false` | Keep the cursor visible after the text finishes typing (a waiting-for-input prompt). |

**Runtime params:** `{"text": String}` - set the text to reveal.

---

### JuiceeNumberCountEffect

Tween a `Label`'s displayed number from X to Y. Score rollups, money counters, XP bars.

| Property | Type | Default | Description |
|---|---|---|---|
| `from_value` | `float` | `0.0` | Default starting value when no `from` runtime param is provided. |
| `to_value` | `float` | `100.0` | Default end value when no `to` runtime param is provided. |
| `duration` | `float` | `1.0` | Total animation duration. |
| `number_format` | `String` | `"%d"` | printf-style format for the number (e.g. "%d" for integer, "%.2f" for 2 decimals). |
| `prefix` | `String` | `""` | Text shown BEFORE the number (e.g. "$", "Score: "). |
| `suffix` | `String` | `""` | Text shown AFTER the number (e.g. " pts", " coins", "%"). |
| `trans_type` | `Tween.TransitionType` | `Tween.TRANS_EXPO` | Shape of the tween curve. Expo with Ease Out rolls to a stop. |
| `ease_type` | `Tween.EaseType` | `Tween.EASE_OUT` | Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing Transition/Ease for the count. FEEL-style. |
| `thousands_separator` | `String` | `""` | Group the integer part with this separator ("," or " " or "."), so 1234567 reads as 1,234,567. Empty = no grouping. |
| `pad_digits` | `int` | `0` | Pad the integer part with leading zeros to this many digits (e.g. 5 = "00042"). 0 = no padding. |

**Runtime params:** `{"from": float, "to": float}` - start and end values.

---

### JuiceeTextWobbleEffect

Sine-wave wobble on a `Control`'s position with linear decay. Drama text - GAME OVER, WAVE COMPLETE, BOSS APPROACHING.

| Property | Type | Default | Description |
|---|---|---|---|
| `amplitude` | `float` | `8.0` | Peak wobble offset in pixels. |
| `frequency` | `float` | `12.0` | Oscillations per second. Higher = jittery, lower = smooth. |
| `duration` | `float` | `0.5` | Total wobble duration. |
| `decay` | `float` | `0.7` | How quickly the wobble decays. 0 = constant wobble, 1 = full fadeout at end. |
| `y_axis_ratio` | `float` | `0.6` | Vertical-to-horizontal wobble ratio (1 = equal both axes, 0 = horizontal only). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `rotation_wobble` | `float` | `0.0` | Rotation wobble in degrees, layered on the positional sway. Drama text tilts as it shakes. 0 = position only. |
| `scale_pulse` | `float` | `0.0` | Scale pulse amount synced to the wobble (0.1 = 10% throb). 0 = no scale change. |

---

### JuiceeTextScrambleEffect

Reveals a `Label`'s text by cycling random characters that lock in left to right. Decoding, hacker terminals, glitchy reveals. Pass the text via the `text` runtime param. *(New in 1.3.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `default_text` | `String` | `"DECODING"` | Text shown when the caller doesn't pass {"text": ...}. |
| `duration` | `float` | `0.8` | How long the scramble takes to fully resolve. |
| `charset` | `String` | `"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%&*"` | Characters cycled through for the not-yet-locked positions. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `lock_order` | `LockOrder` | `LockOrder.LEFT_TO_RIGHT` | The order characters lock into place: left to right (a terminal decode), right to left, from the centre outward, or in a random scatter. Options: `LEFT_TO_RIGHT`, `RIGHT_TO_LEFT`, `CENTER_OUT`, `RANDOM`. |
| `scramble_rate` | `float` | `30.0` | How many times per second the unlocked characters re-roll. Lower = a chunkier, more readable churn; higher = frantic static. |

---

### JuiceeRichTextEmphasisEffect

Temporarily wraps a `RichTextLabel`'s text (or one phrase in it) in an animated BBCode tag, then puts it back. Dialogue emphasis, tutorial callouts, cursed item names. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `mode` | `int` | `0` | Animation applied to the text. Options: `Wave`, `Shake`, `Rainbow`, `Tornado`. |
| `phrase` | `String` | `""` | Phrase to emphasize. Empty = the whole text. Override per play with {"phrase": ...}. |
| `duration` | `float` | `1.5` | How long the emphasis lasts. 0 = stays until stop(). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `amplitude` | `float` | `24.0` | Size of the motion: wave height, shake level, or tornado radius, depending on Mode. Rainbow ignores it. |
| `rate` | `float` | `6.0` | Speed of the motion: wave/tornado frequency, or shake rate. |
| `rainbow_saturation` | `float` | `0.8` | Rainbow only: colour saturation of the sweep. |

---

## Time (5 effects)

Time effects manipulate `Engine.time_scale`. They use real-time timers to restore state.

---

### JuiceeHitStopEffect

Instant `Engine.time_scale` freeze for tactile impact moments. ~50-100ms is the sweet spot for melee combat. Sets `time_scale` to `time_scale_during` for `freeze_duration`, then restores.

| Property | Type | Default | Description |
|---|---|---|---|
| `freeze_duration` | `float` | `0.08` | How long (in real seconds) the freeze lasts. ~0.05-0.15 is the sweet spot for impact. |
| `time_scale_during` | `float` | `0.0` | Engine.time_scale value during the freeze. 0 = full stop, 0.05 = bullet-time, 1 = no freeze. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `recover_time` | `float` | `0.0` | Ease time back up to normal over this many real seconds instead of snapping, which reads as a heavy blow recovering rather than a hard cut. 0 = an instant restore. |
| `pre_delay` | `float` | `0.0` | Delay (real seconds) before the freeze bites, so the hit lands first and THEN time stops - a trick fighting games use to sell the connect. |

---

### JuiceeTimeScaleRampEffect

Smooth slow-motion with ramp-in / hold / ramp-out. Bullet time, dramatic moments.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_scale` | `float` | `0.2` | Engine.time_scale at the bottom of the ramp. 0.2 = cinematic slow-mo, 0.5 = subtle. |
| `ramp_in` | `float` | `0.15` | Time to ramp down to target_scale. |
| `hold` | `float` | `0.4` | How long to hold at target_scale before ramping back. |
| `ramp_out` | `float` | `0.3` | Time to ramp back up to normal speed. |
| `trans_type` | `Tween.TransitionType` | `Tween.TRANS_SINE` | Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping the ramp into slow motion. FEEL-style curve control. |
| `pitch_bus` | `StringName` | `""` | Pitch the audio bus down with the slow motion, so the whole moment sags together instead of the music carrying on at full speed. Empty = leave audio alone. Options: `Master`. |

---

### JuiceeDelayEffect

Pure wait - `apply()` awaits a timer then returns. Useful for sequencing in a `JuiceeSequence`.

| Property | Type | Default | Description |
|---|---|---|---|
| `duration` | `float` | `0.5` | Seconds to wait. Used inside sequences to space effects apart. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `variance` | `float` | `0.0` | Randomize the wait by this fraction (0.5 = 50%-150% of Duration), so repeated sequences do not land on exactly the same beat. |
| `ignore_time_scale` | `bool` | `false` | Wait in real seconds, ignoring Engine.time_scale, so a delay still runs during a hit-stop or slow-motion moment. |

---

### JuiceeFreezeFrameEffect

`Engine.time_scale = 0.0` for `duration` real-time seconds with optional white flash overlay. Visually heavier than `HitStop` - use for finishing blows, super-move activations, dramatic moments.

| Property | Type | Default | Description |
|---|---|---|---|
| `duration` | `float` | `0.06` | Freeze duration in real-time seconds (ignores Engine.time_scale). |
| `flash_color` | `Color` | `Color(1.0, 1.0, 1.0, 0.9)` | Flash color shown during the freeze. White = classic fighting game super. |
| `use_flash` | `bool` | `true` | Show the full-screen flash overlay. Disable for a pure time-freeze without visual. |
| `flash_fade` | `float` | `0.08` | Seconds for the flash to fade out AFTER time resumes. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `time_scale_during` | `float` | `0.0` | Time scale during the freeze. 0 = a dead stop (the default); 0.05-0.15 = a brief slow-motion beat instead, which keeps a hint of motion in the frame. |
| `pre_delay` | `float` | `0.0` | Delay (real seconds) before the freeze bites, so the hit lands first. |

---

### JuiceeStutterEffect

A rapid burst of micro-freezes (machine-gun hit-stop), each a brief `Engine.time_scale` drop with a gap between. Hit flurries, glitches, power surges. *(New in 1.3.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `count` | `int` | `5` | How many freeze stutters. |
| `freeze_time` | `float` | `0.03` | Real seconds each freeze lasts. |
| `gap_time` | `float` | `0.03` | Real seconds of normal speed between freezes. |
| `time_scale_during` | `float` | `0.0` | Engine.time_scale during each freeze (0 = full stop). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `decay` | `float` | `1.0` | Each successive stutter gets shorter by this factor, so the judder accelerates into normal time instead of chugging evenly. 1 = every stutter identical. |
| `jitter` | `float` | `0.0` | Randomize each freeze/gap length by this fraction, for an irregular broken judder. |

---

## Audio (10 effects)

Audio effects target audio buses or spawn temporary `AudioStreamPlayer` nodes. They work in both 2D and 3D scenes.

---

### JuiceeSoundEffect

Plays a random `AudioStream` from an array with pitch variance. Drop-in sound player without needing a persistent `AudioStreamPlayer` in the scene.

| Property | Type | Default | Description |
|---|---|---|---|
| `streams` | `Array[AudioStream]` | `[]` | One or more AudioStream resources - one is picked at random each play. |
| `bus` | `StringName` | `&"Master"` | Audio bus to route playback through (must exist in the project's audio bus layout). Options: `Master`. |
| `pitch_min` | `float` | `0.9` | Minimum pitch multiplier (1.0 = original pitch, 0.5 = octave down). |
| `pitch_max` | `float` | `1.1` | Maximum pitch multiplier (1.0 = original pitch, 2.0 = octave up). |
| `volume_db` | `float` | `0.0` | Volume in decibels (0 = original, -6 = half loudness, +6 = double). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `avoid_repeats` | `bool` | `true` | Never play the same stream twice in a row when picking at random. With a handful of footstep or hit variations this alone removes most of the machine-gun repetition. |
| `fade_in` | `float` | `0.0` | Fade the sound in over this many seconds instead of starting at full volume. |
| `fade_out` | `float` | `0.0` | Fade the sound out over the last seconds of its length. 0 = it ends naturally. |
| `random_delay` | `float` | `0.0` | Random delay before the sound fires, so a burst of them scatters instead of landing on one frame. |

---

### JuiceeMusicDuckEffect

Temporarily lower an audio bus volume then restore. Useful for momentarily quieting music under a cutscene voice line.

| Property | Type | Default | Description |
|---|---|---|---|
| `bus` | `StringName` | `&"Master"` | Audio bus to duck (lower volume of). Typically "Music" or "Master". Options: `Master`. |
| `duck_db` | `float` | `-15.0` | How much to lower volume in dB. -15 = noticeably quieter, -30 = barely audible. |
| `ramp_in` | `float` | `0.15` | Time to ramp volume down. |
| `hold` | `float` | `1.0` | How long to hold at lowered volume. |
| `ramp_out` | `float` | `0.5` | Time to ramp volume back up. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `pump_count` | `int` | `1` | Pump the duck repeatedly instead of holding it, the classic sidechain pulse under a kick drum. 1 = one plain duck. |
| `pump_bpm` | `float` | `120.0` | Beats per minute the pumping follows (only used when Pump Count is above 1). |

---

### JuiceeRumbleEffect

Gamepad vibration through Juicee's haptics mixer, so overlapping rumbles combine. Without the Juicee autoload it falls back to `Input.start_joy_vibration()`.

**Accessibility tag:** `TAG_HAPTIC`

| Property | Type | Default | Description |
|---|---|---|---|
| `device` | `int` | `0` | Gamepad device index (0 = first connected, up to 7). |
| `weak_magnitude` | `float` | `0.5` | Weak (small) motor intensity (0-1). Subtle, high-frequency buzz. |
| `strong_magnitude` | `float` | `0.5` | Strong (large) motor intensity (0-1). Low-frequency rumble - the "thud". |
| `duration` | `float` | `0.2` | How long the rumble lasts in seconds. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `fade_out` | `bool` | `false` | Fade the rumble out over its duration instead of cutting off, which reads as an impact settling rather than a switch flipping. |
| `all_devices` | `bool` | `false` | Rumble every connected controller, not just Device. |
| `pulse_count` | `int` | `1` | Pulse the rumble this many times across the duration (a heartbeat / alarm buzz). |

---

### JuiceeReverbEffect

Temporarily injects an `AudioEffectReverb` on an audio bus with wet ramp in/out. Boss intros, low-health states, cave echoes.

| Property | Type | Default | Description |
|---|---|---|---|
| `bus_name` | `String` | `"Master"` | Name of the AudioBus to apply reverb to (e.g. "Master", "SFX", "Music"). Options: `Master`. |
| `peak_wet` | `float` | `0.45` | Peak wet level (0 = dry, 1 = full reverb). |
| `room_size` | `float` | `0.8` | Room size (0 = small, 1 = huge cathedral). |
| `damping` | `float` | `0.5` | Damping - how much high frequencies decay. |
| `spread` | `float` | `1.0` | Spread - left/right reverb decorrelation (more = wider). |
| `duration` | `float` | `1.5` | Total duration: ramp-in + hold + ramp-out. |
| `ramp_in_fraction` | `float` | `0.15` | Ramp-in fraction of duration (0.2 = 20% spent ramping up). |
| `ramp_out_fraction` | `float` | `0.35` | Ramp-out fraction of duration. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `predelay_msec` | `float` | `150.0` | Delay before the reverb tail starts (milliseconds). Larger values push the space further away, the difference between a tiled room and a canyon. |
| `hipass` | `float` | `0.0` | High-pass applied to the reverb tail (0-1). Raise it to keep bass out of the wash so the mix stays clear. |
| `dry` | `float` | `1.0` | Dry (unprocessed) signal level kept alongside the reverb. |

---

### JuiceePitchShiftEffect

Temporarily injects an `AudioEffectPitchShift` on an audio bus. Underwater, slow-mo audio, demon transformation.

| Property | Type | Default | Description |
|---|---|---|---|
| `bus_name` | `String` | `"Master"` | Name of the AudioBus to pitch-shift. Options: `Master`. |
| `target_pitch` | `float` | `0.7` | Target pitch scale. 1.0 = normal, 0.5 = octave down (deep), 2.0 = octave up. |
| `duration` | `float` | `1.0` | Total duration: ramp-in + hold + ramp-out. |
| `ramp_in_fraction` | `float` | `0.2` | Ramp-in fraction. |
| `ramp_out_fraction` | `float` | `0.3` | Ramp-out fraction. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `vibrato_rate` | `float` | `0.0` | Wobble the pitch this many times per second on top of the shift, for a warped-tape or seasick vibrato. 0 = a steady shift. |
| `vibrato_depth` | `float` | `0.2` | How far the vibrato swings the pitch, as a fraction of the shift. |

---

### JuiceeLowPassEffect

Ramps a temporary `AudioEffectLowPassFilter` on an audio bus from fully open down to `target_cutoff` and back - the muffled-on-hit, underwater, stunned/concussed, behind-a-wall feel. Pairs perfectly with Hit Stop. *(New in 1.2.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `bus_name` | `String` | `"Master"` | Name of the AudioBus to muffle. Options: `Master`. |
| `target_cutoff` | `float` | `500.0` | Cutoff frequency at full muffle, in Hz. Lower = more muffled (500 ≈ "behind a wall"). |
| `duration` | `float` | `0.6` | Total duration: ramp-in + hold + ramp-out. |
| `ramp_in_fraction` | `float` | `0.15` | Ramp-in fraction (how fast it muffles). |
| `ramp_out_fraction` | `float` | `0.35` | Ramp-out fraction (how fast it opens back up). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `resonance` | `float` | `0.5` | Resonance at the cutoff. Higher values ring around the cutoff frequency, which is what makes a filter sweep sing rather than just going dull. |
| `rolloff_db` | `int` | `1` | Filter steepness in dB per octave. Steeper cuts more of the top end away. Options: `6 dB`, `12 dB`, `18 dB`, `24 dB`. |

---

### JuiceeAudioSource3DEffect

Spawn a temporary `AudioStreamPlayer3D` at the context node's world position and play a random stream from the pool. The player is auto-freed when it finishes. For 2D contexts, derives 3D position from `Node2D.global_position` with a pixel-to-metre scale factor. Spatial SFX, footsteps, explosions, any world-space 3D sound.

| Property | Type | Default | Description |
|---|---|---|---|
| `streams` | `Array[AudioStream]` | `[]` | Pool of AudioStreams - one is picked at random per play. |
| `volume_db` | `float` | `0.0` | Volume offset in dB. |
| `pitch_min` | `float` | `0.9` | Lower end of the pitch range a play picks from at random. |
| `pitch_max` | `float` | `1.1` | Upper end of that range. Equal to Pitch Min for no variation at all. |
| `bus` | `StringName` | `&"Master"` | Target audio bus name. Options: `Master`. |
| `max_distance` | `float` | `40.0` | Maximum audible distance in metres. |
| `attenuation_model` | `int` | `0` | Attenuation model (maps to AudioStreamPlayer3D.AttenuationModel). 0=InverseDistance, 1=InverseSquareDistance, 2=Logarithmic, 3=Disabled. |
| `position_offset` | `Vector3` | `Vector3.ZERO` | Offset the playback position in 3D space relative to the context. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `unit_size` | `float` | `10.0` | Size of the sound's "unit" sphere. Larger values keep it loud further out before the attenuation curve takes over. |
| `doppler_tracking` | `int` | `0` | Pitch-shift the sound based on relative motion (the doppler effect), tracked in idle or physics step. Off = no doppler. Options: `Disabled`, `Idle`, `Physics`. |
| `panning_strength` | `float` | `1.0` | How strongly the sound is panned across the stereo field by its position. |

---

### JuiceeDistortionEffect

Ramps a temporary `AudioEffectDistortion` onto a bus and back. Blown speakers, radios, damage states. Pairs with Hit Stop, like Reverb / Low-Pass. *(New in 1.3.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `bus_name` | `String` | `"Master"` | Name of the AudioBus to distort (e.g. "Master", "SFX", "Music"). Options: `Master`. |
| `peak_drive` | `float` | `0.5` | Peak distortion drive. |
| `mode` | `int` | `0` | Distortion flavour. Options: `Clip`, `ATan`, `LoFi`, `Overdrive`, `WaveShape`. |
| `duration` | `float` | `0.8` | Total duration: ramp-in + hold + ramp-out. |
| `ramp_in_fraction` | `float` | `0.15` | Ramp-in fraction of duration. |
| `ramp_out_fraction` | `float` | `0.35` | Ramp-out fraction of duration. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `pre_gain_db` | `float` | `0.0` | Pre-gain in dB applied before the distortion stage. Pushing this harder drives the signal further into the shaping curve. |
| `post_gain_db` | `float` | `0.0` | Post-gain in dB to bring the level back down after distorting. |
| `keep_hf_hz` | `float` | `16000.0` | Frequencies above this (Hz) pass through clean and only the ones below it are distorted. Lower it to keep more of the top end clear. |

---

### JuiceeTremoloEffect

Rhythmically wobbles an audio bus's volume up and down, a pulsing amplitude wobble. Underwater moments, dizziness, power fluctuation, radio interference. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `bus` | `StringName` | `&"Master"` | Audio bus to wobble. Typically "Master", "Music", or "SFX". Options: `Master`. |
| `depth_db` | `float` | `-12.0` | How deep each dip goes, in dB below the current volume. |
| `rate` | `float` | `6.0` | Wobbles per second. |
| `duration` | `float` | `1.5` | Total time the tremolo runs. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `waveform` | `int` | `0` | Shape of the volume wobble: a smooth Sine, a hard on/off Square (helicopter chop), or a Saw that drops sharply and rises. Options: `Sine`, `Square`, `Saw`. |
| `fade_fraction` | `float` | `0.0` | Ease the tremolo in and out over this fraction of the duration, so it doesn't start and stop mid-wobble. |

---

### JuiceeProcSoundEffect

Synthesize a retro game sound at runtime with `JuiceeSfxr` (a GDScript sfxr port) - no audio asset needed. Coin pickups, laser shots, explosions, jumps, UI blips.

| Property | Type | Default | Description |
|---|---|---|---|
| `category` | `JuiceeSfxr.Category` | `JuiceeSfxr.Category.PICKUP_COIN` | Which classic sfxr sound family to synthesize. Options: `PICKUP_COIN`, `LASER_SHOOT`, `EXPLOSION`, `POWERUP`, `HIT_HURT`, `JUMP`, `BLIP_SELECT`, `RANDOM`. |
| `sound_seed` | `int` | `0` | A fixed seed plays the exact same sound every time. 0 = one of eight random variations. |
| `bus` | `StringName` | `&"Master"` | Audio bus to route playback through (must exist in the project's bus layout). Options: `Master`. |
| `volume_db` | `float` | `0.0` | Volume in decibels (0 = as synthesized, -6 = half loudness, +6 = double). |
| `pitch_min` | `float` | `1.0` | Minimum pitch multiplier (randomized per play for variety). |
| `pitch_max` | `float` | `1.0` | Maximum pitch multiplier. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `repeat_count` | `int` | `1` | Fire the sound this many times in quick succession, for a burst (multi-hit, coin shower, rapid fire). 1 = a single shot. |
| `repeat_interval` | `float` | `0.06` | Seconds between repeats. |
| `repeat_falloff_db` | `float` | `0.0` | Each repeat is this many dB quieter than the one before, so a burst trails off. |

---

## Physics (5 effects)

---

### JuiceeImpulseEffect

Applies a physics impulse to a `RigidBody2D`. Knockback, explosion push, projectile impact.

| Property | Type | Default | Description |
|---|---|---|---|
| `target` | `NodePath` | `""` | Path to the RigidBody2D to push. If empty, the context itself must be a RigidBody2D. |
| `impulse` | `Vector2` | `Vector2(200, -100)` | Impulse vector applied at the body's center (pixels/sec for velocity). |
| `random_cone_degrees` | `float` | `0.0` | If > 0, impulse direction is randomized within this cone (in degrees) for variety. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `spin` | `float` | `0.0` | Random spin (degrees/sec, +/-) applied along with the impulse. |
| `reset_velocity` | `bool` | `false` | Zero the body's velocity first, so the impulse lands the same every time. |
| `force_variance` | `float` | `0.0` | Randomize the impulse magnitude by this fraction (0.3 = 70%-130% each fire), so a stream of launches has natural variety. |

**Runtime params:** `{"impulse": Vector2}` - override direction/magnitude per-hit.

---

### JuiceeAddForceEffect

Apply an impulse or continuous force to `RigidBody2D` or `RigidBody3D`. Three modes: `IMPULSE` (instant `apply_impulse`/`apply_central_impulse`), `CONSTANT_FORCE` (sustained over `duration` then cleared if `clear_force_on_end`), `TORQUE_IMPULSE` (angular velocity kick). Explosion push, wind gusts, magnetic pull, knockback, conveyor belts, one-shot jumps.

| Property | Type | Default | Description |
|---|---|---|---|
| `force` | `Vector2` | `Vector2(0, -300)` | Force/impulse direction and magnitude. |
| `force_3d` | `Vector3` | `Vector3(0, 5, 0)` | 3D force (used when context is RigidBody3D). |
| `mode` | `Mode` | `Mode.IMPULSE` | Application mode. Options: `IMPULSE`, `CONSTANT_FORCE`, `TORQUE_IMPULSE`. |
| `duration` | `float` | `0.3` | Duration for CONSTANT_FORCE mode (seconds). |
| `clear_force_on_end` | `bool` | `true` | If true, clear the constant force when duration ends (CONSTANT_FORCE mode only). |
| `at_position` | `Vector2` | `Vector2.ZERO` | IMPULSE mode on a RigidBody2D only: offset from the centre of mass (local position). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `torque` | `float` | `0.0` | Rotational force applied alongside the linear one, so a push also spins the body. |
| `force_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping how the force ramps over the duration (Force mode only). Null = a constant push for the whole duration. |

---

### JuiceeKnockbackEffect

Shoves a `RigidBody2D` along `hit_direction` (falling back to `default_direction`), scaled by `force`. Aimed hit reactions, unlike Impulse's fixed vector. *(New in 1.3.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `target` | `NodePath` | `""` | Path to the RigidBody2D. Empty = the context itself must be a RigidBody2D. |
| `force` | `float` | `400.0` | Impulse strength (pixels/sec of velocity added). |
| `default_direction` | `Vector2` | `Vector2.RIGHT` | Direction used when no {"hit_direction": ...} is passed. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `lift` | `float` | `0.0` | Extra upward force added to the shove, so hits pop the body off the ground instead of sliding it along. 0 = a flat push. |
| `spin` | `float` | `0.0` | Random spin (degrees/sec, +/-) imparted by the hit, so bodies tumble. |
| `reset_velocity` | `bool` | `false` | Zero the body's current velocity before the shove, so knockback distance is consistent no matter how fast it was already moving. |

---

### JuiceeExplosionPushEffect

A radial impulse that shoves every `RigidBody2D` within `radius` away from the origin, falling off with distance. The whole-blast version of Impulse. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `origin` | `NodePath` | `""` | Path to the blast origin (a Node2D). Empty = the context itself is the origin. |
| `radius` | `float` | `200.0` | Blast radius in pixels. Bodies outside get nothing. |
| `force` | `float` | `600.0` | Peak impulse at the centre (pixels/sec of velocity). Falls off to 0 at the edge. |
| `falloff_exponent` | `float` | `1.0` | Falloff shape. 1 = linear, 2 = quadratic (softer edges, punchier centre). |
| `max_bodies` | `int` | `64` | Max bodies the query returns. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `lift` | `float` | `0.0` | Extra upward force added to every pushed body, so a blast throws debris up and out instead of skidding it along the floor. |
| `spin` | `float` | `0.0` | Random spin (degrees/sec, +/-) imparted to each body, so debris tumbles. |
| `collision_mask` | `int` | `0` | Physics layers the blast affects (0 = every layer, the default). |
| `include_partial_overlap` | `bool` | `true` | Also push bodies whose centre is outside the radius but whose shape overlaps it, with the weak push from the blast's outer edge. Off = only bodies whose own position is inside the radius get pushed. |

---

### JuiceeGravityShiftEffect

Temporarily scales a `RigidBody2D`'s gravity then eases it back. Float and levitate moments, low-gravity zones, heavy slam-downs. *(New in 1.5.0.)*

| Property | Type | Default | Description |
|---|---|---|---|
| `target` | `NodePath` | `""` | Path to the RigidBody2D. Empty = the context itself must be a RigidBody2D. |
| `gravity_scale` | `float` | `0.0` | Gravity multiplier during the effect. 0 = weightless, <1 = light, >1 = heavy, <0 = upward. |
| `duration` | `float` | `1.0` | How long the shifted gravity holds at full strength. |
| `blend_time` | `float` | `0.15` | Seconds to ease into and out of the shifted gravity. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn curve (0..1) shaping the ease into the shifted gravity. FEEL-style. |
| `velocity_damp` | `float` | `0.0` | Also damp the body's velocity while gravity is shifted (0 = untouched, 1 = heavily damped), so a float feels weightless rather than coasting. |

---

## Flow (12 effects)

Flow effects compose or coordinate other effects. They work in both 2D and 3D scenes.

---

### JuiceeSequenceEffect

Embeds another `JuiceeSequence` as a single step. Use for composable preset libraries - build a "hit reaction" `.tres`, then reference it from multiple sequences.

| Property | Type | Default | Description |
|---|---|---|---|
| `sequence` | `JuiceeSequence` | - | Nested JuiceeSequence to play as a single step. Use for reusable presets: build "hit_combo.tres" once, drop it into bigger sequences. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `repeat_count` | `int` | `1` | Play the nested sequence this many times back to back. 1 = once. |
| `repeat_delay` | `float` | `0.0` | Pause between repeats, in seconds. |
| `loop_forever` | `bool` | `false` | Keep replaying until stop() is called, for an ambient loop built from a sequence. |

---

### JuiceePropertyTweenEffect

Tween any property on any node. Universal escape hatch for one-off tweens.

| Property | Type | Default | Description |
|---|---|---|---|
| `property_path` | `NodePath` | `^"."` | Path to the node holding the property. "." means the context itself. |
| `property` | `String` | `""` | Property name to animate. Supports sub-paths like "modulate:a", "position:y", "scale". |
| `to_value` | `Variant` | `null` | Target value to tween toward (any type the property accepts: float, Vector2, Color, ...). |
| `duration` | `float` | `0.5` | How long the animation takes. |
| `return_to_original` | `bool` | `true` | If true, tweens back to the original value after reaching target. |
| `trans_type` | `Tween.TransitionType` | `Tween.TRANS_SINE` | Shape of the tween curve: Back overshoots, Elastic springs, Sine is the gentlest. |
| `ease_type` | `Tween.EaseType` | `Tween.EASE_IN_OUT` | Where the easing sits: Out starts fast and settles, In builds up to the end, In Out eases both ends. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `ease_curve` | `Curve` | - | Hand-drawn easing curve (0..1) replacing Transition/Ease for the tween. FEEL-style. |
| `hold_time` | `float` | `0.0` | Seconds to hold at the target value before returning. 0 = come straight back. |
| `oscillations` | `int` | `1` | Bounce between the original and target this many times across the duration, instead of a single there-and-back. A quick way to build a throb out of any property. |

---

### JuiceeAnimationPlayerEffect

Triggers `AnimationPlayer.play()` as a sequence step, so a clip you already have runs in time with the other effects.

| Property | Type | Default | Description |
|---|---|---|---|
| `player_path` | `NodePath` | `""` | Node path to the AnimationPlayer node (relative to context, or absolute). |
| `animation_name` | `String` | `""` | Animation name to play (must exist in the AnimationPlayer). |
| `speed` | `float` | `1.0` | Playback speed multiplier (1.0 = normal, 2.0 = double-time). To reverse, use Play Backwards. |
| `blend_time` | `float` | `-1.0` | Custom blend time. -1 uses the AnimationPlayer's default. |
| `wait_for_finish` | `bool` | `true` | If true, the sequence step waits for animation_finished before continuing. If false, the step returns immediately (fire-and-forget). |
| `max_wait` | `float` | `5.0` | Safety timeout when wait_for_finish is true - bails out if anim doesn't end. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `start_at_ratio` | `float` | `0.0` | Start the animation this far in (0-1 of its length) instead of from the beginning, so a reaction can skip a wind-up that already played. |
| `play_backwards` | `bool` | `false` | Play the animation backwards from its end. |
| `speed_variance` | `float` | `0.0` | Randomize the playback speed by this fraction each time, so repeated plays of the same clip do not look mechanically identical. |

---

### JuiceeSetActiveEffect

Show or hide a node for `duration` seconds then restore original visibility. Muzzle flash, hit spark, tutorial highlight.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_path` | `NodePath` | `""` | Node path to toggle (relative to context, or absolute). |
| `action` | `Action` | `Action.SHOW` | What to do for the duration: show it, hide it, or flip its current state. Options: `SHOW`, `HIDE`, `TOGGLE`. |
| `duration` | `float` | `0.5` | How long to keep the new state before restoring the original visibility. |
| `restore_on_end` | `bool` | `true` | If true, the original visibility is restored at the end. If false, the change is permanent (useful for one-shot reveals). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `blink_count` | `int` | `1` | Blink the node this many times across the duration instead of holding one state, which is the usual damage / respawn i-frame flicker. |
| `affect_processing` | `bool` | `false` | Also toggle the node's processing and physics, so a hidden node stops running its logic instead of just going invisible. |

---

### JuiceeChainEffect

Composes N child `JuiceeEffect` resources as one reusable block. Build signature move combos as a single `.tres` asset.

| Property | Type | Default | Description |
|---|---|---|---|
| `effects` | `Array[JuiceeEffect]` | `[]` | Effects to run, in order. |
| `step_delay` | `float` | `0.0` | Delay before each child fires (extra pacing between steps). Ignored when Parallel is on. |
| `parallel` | `bool` | `false` | If true, all children fire at once instead of waiting in sequence. |
| `wait_for_finish` | `bool` | `true` | If true, this chain waits for every child to finish before returning. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `reverse_order` | `bool` | `false` | Play the chain in reverse order, so one resource can drive both an open and a close. |
| `repeat_count` | `int` | `1` | Run the whole chain this many times. 1 = once through. |
| `repeat_delay` | `float` | `0.0` | Pause between repeats, in seconds. |
| `pick_random_one` | `bool` | `false` | Fire only ONE randomly chosen child instead of the whole list, so a hit can pick a different reaction each time. |

---

### JuiceeWaitForInputEffect

Pause sequence execution until the player presses a specified input action. Dialog advancement, tutorial checkpoints, cutscene pacing.

| Property | Type | Default | Description |
|---|---|---|---|
| `action` | `StringName` | `&"ui_accept"` | Input action to wait for. A dropdown of the project's real actions: ui_accept (Space, Enter, the A button), ui_select, ui_cancel, and anything under Project Settings > Input Map. Options: `ui_accept`, `ui_cancel`, `ui_select`. |
| `timeout` | `float` | `0.0` | Maximum wait time in seconds. 0 = wait indefinitely until the action fires. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `extra_actions` | `Array[StringName]` | `[]` | Also accept any of these extra actions, so a prompt can take several buttons. |
| `accept_any_input` | `bool` | `false` | Accept any key / button / click at all, not just mapped actions. Useful for a "press anything to continue" prompt. |
| `input_lockout` | `float` | `0.0` | Ignore input for this many seconds first, so the keypress that opened a prompt does not immediately dismiss it. |

---

### JuiceeBeatSyncEffect

Fire a child effect synchronized to a BPM beat for `duration` seconds. Two modes:

- **Clock mode**: set `clock_path` to a `JuiceeBeatClock` in the scene - fires exactly on the clock's `beat` signal for musically tight sync.
- **Standalone mode**: leave `clock_path` empty - fires at the computed `60/bpm * beats_per_trigger` interval internally.

| Property | Type | Default | Description |
|---|---|---|---|
| `effect` | `JuiceeEffect` | - | The effect to fire on each beat. Can be any JuiceeEffect resource. |
| `bpm` | `float` | `120.0` | Beats per minute used in standalone mode (and shown in graph editor). |
| `beats_per_trigger` | `int` | `1` | Fire every N beats (1 = every beat, 2 = every other beat, 4 = every bar). |
| `duration` | `float` | `8.0` | How long to keep running in seconds (0 = fire exactly once then stop). |
| `clock_path` | `NodePath` | `""` | Optional path to a JuiceeBeatClock node in the scene for tight sync. Leave empty to use standalone BPM mode. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `start_offset_beats` | `int` | `0` | Wait this many beats before the first trigger, so a layer can enter on the second bar. |
| `offbeat` | `bool` | `false` | Fire on off-beats instead of the beat itself (a swung, syncopated feel). |
| `accent_every` | `int` | `1` | Multiply the effect's intensity on every Nth trigger, so a bar lands with an accent. 1 = every trigger identical. |
| `accent_multiplier` | `float` | `1.6` | How much stronger an accented trigger is. |

---

### JuiceeEmitSignalEffect

Emit a named signal on the context node with an optional `Variant` argument. Bridge between Juicee sequences and gameplay systems without direct code coupling. The signal must be pre-declared on the context node. Use `argument = null` for no-arg signals.

| Property | Type | Default | Description |
|---|---|---|---|
| `signal_name` | `StringName` | `""` | Name of the signal to emit on the context node. |
| `argument` | `Variant` | `null` | Optional first argument passed with the signal. Only used if the signal expects arguments - leave null for no-arg signals. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `target_path` | `NodePath` | `""` | Emit on this node instead of the context (e.g. an autoload event bus). Empty = the context node itself. |
| `create_if_missing` | `bool` | `false` | Register the signal on the target if it does not exist yet, instead of warning. Lets a sequence announce a custom event without wiring it up in advance. |

---

### JuiceeDebugLogEffect

Print, push_warning, or push_error a message from within a Juicee sequence. Supports `{context}` placeholder replaced with the context node's name at runtime. Zero game impact in shipping builds if guarded.

| Property | Type | Default | Description |
|---|---|---|---|
| `message` | `String` | `"Juicee sequence reached this step."` | Message to print. Supports a basic {context} placeholder for the node name. |
| `level` | `Level` | `Level.PRINT` | Log level. Options: `PRINT`, `PUSH_WARNING`, `PUSH_ERROR`. |
| `include_context_name` | `bool` | `true` | Also print the context node's name alongside the message. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `include_timestamp` | `bool` | `false` | Prefix each line with the time since the game started, so you can read the spacing between steps in a sequence. |
| `debug_builds_only` | `bool` | `false` | Only log when the project is running a debug build, so release builds stay quiet. |

---

### JuiceeAnimationTreeEffect

Travel to an `AnimationTree` state machine state or set any tree parameter directly. `TRAVEL` mode calls `StateMachinePlayback.travel(parameter)` for smooth blended transitions. `SET_PARAMETER` mode writes any tree parameter (blend amounts, time scales, booleans, etc.). Auto-discovers an AnimationTree child if `tree_path` is empty.

| Property | Type | Default | Description |
|---|---|---|---|
| `tree_path` | `NodePath` | `""` | Path to the AnimationTree node. Empty = look for AnimationTree as a child of context. |
| `mode` | `Mode` | `Mode.TRAVEL` | How to drive the AnimationTree. Options: `TRAVEL`, `SET_PARAMETER`. |
| `parameter` | `String` | `"Idle"` | For TRAVEL: target state name (must exist in the StateMachinePlayback). For SET_PARAMETER: parameter path, e.g. "parameters/TimeScale/scale". |
| `value` | `Variant` | `true` | For SET_PARAMETER: the value to set. Ignored in TRAVEL mode. |
| `playback_path` | `String` | `"parameters/playback"` | For TRAVEL: path to the StateMachinePlayback parameter (default works for most trees). |
| `wait_for_finish` | `bool` | `false` | Wait for the travel to finish before the step ends. TRAVEL mode only. |
| `max_wait` | `float` | `5.0` | Safety timeout (seconds) for `wait_for_finish` in TRAVEL mode - bail out if the target state is never reached (e.g. a typo'd state name) instead of looping forever. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `blend_time` | `float` | `0.0` | Blend the parameter to its value over this many seconds instead of setting it instantly, so a state change eases rather than snaps. Numbers only: anything else still snaps. SET_PARAMETER mode. |
| `restore_on_end` | `bool` | `false` | Put the parameter back where it was once the effect is done, so a dip in a blend or in a time scale recovers on its own. With Blend Time it eases back over the same time; without one it snaps there and straight back, which nobody will see. |

---

### JuiceeSetPropertyEffect

Instantly `set_indexed(property_name, value)` on any node, then optionally restore the original value after `restore_delay` seconds. The direct-assignment complement to `PropertyTweenEffect` - no animation, just set. Toggle bool flags, snap positions, change label text, enable/disable collision layers mid-sequence.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_path` | `NodePath` | `""` | Node to modify. Empty = context node. |
| `property_name` | `String` | `""` | Property name (supports sub-paths: "position:x", "material:albedo_color"). |
| `value` | `Variant` | `true` | Value to set. |
| `restore_delay` | `float` | `-1.0` | Restore the original value after restore_delay seconds (0 = restore immediately after setting, -1 = never restore). |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `tween_time` | `float` | `0.0` | Tween to the value over this many seconds instead of setting it instantly. Works for numbers, vectors and colours; anything else still snaps. |
| `toggle_bool` | `bool` | `false` | Toggle a bool property instead of writing Value, so one resource can flip a flag. |

---

### JuiceeAutoDestructEffect

`queue_free()` the context node (or a target) after an optional delay. Essential for cleaning up temporary VFX objects spawned by `JuiceeInstantiateEffect` or other runtime spawners.

| Property | Type | Default | Description |
|---|---|---|---|
| `target_path` | `NodePath` | `""` | Node to free. Empty = context node itself. |
| `destruct_delay` | `float` | `0.0` | Seconds to wait before freeing. 0 = queue_free immediately (next frame). |
| `free_parent` | `bool` | `false` | Free the PARENT of the resolved target instead of the target itself. Useful when the context is a child (e.g., sprite) but you want to free the root. |

**Advanced** - shown when `juicee/advanced_properties` is on, see [advanced-properties.md](advanced-properties.md):

| Property | Type | Default | Description |
|---|---|---|---|
| `fade_out_time` | `float` | `0.0` | Fade the node out over this many seconds just before it is freed, so it dissolves instead of vanishing. 0 = it disappears instantly. |
| `shrink_out` | `bool` | `false` | Also shrink the node to nothing during that fade. |
| `detach_first` | `bool` | `false` | Detach the node from its parent the moment the timer starts, so a dying object stops following its spawner while it plays out. |
