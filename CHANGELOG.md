# Changelog

All notable changes to **Juicee** are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.1.0] — 2026-06-18

Stability + tooling release. Adds a **C# bridge** so the entire `Juicee` singleton API is callable from .NET/C# projects, **procedural sound effects** (zero audio assets), and fixes every bug surfaced by a full code-safety audit.

### Added

- **Graph editor — faster add-node search** — the right-click effect popup now ranks matches by relevance (prefix › name substring › description/category › tight typo-match) as a flat, best-first list. `shke` finds Shake and `filmgr` finds Film Grain, while loose scattered subsequence matches are filtered out (typing `man` no longer pulls in "ani**m**ation", "film gr**a**i**n**", etc.). The matched characters in each result are **bolded** so you can see why it matched. Full keyboard flow: type to filter, **↑/↓** to move the highlight, **Enter** to drop the top match — no mouse needed.
- **Graph editor — connection validation** — connecting a node to itself or in a way that closes a loop is now rejected with a brief banner ("That would create a loop"), keeping every graph a valid DAG for the Trigger walk / `JuiceeGraphPlayer`.
- **Graph editor — keyboard completeness** — `Ctrl+X` (cut), `Ctrl+A` (select all), `Esc` (deselect), on top of the existing `Ctrl+C/V/D/Z`.
- **Graph editor — node context menu** — right-click a block for Duplicate / Copy / Disconnect all / Delete (surfaces the shortcuts; right-click on empty canvas still opens the add-effect search).
- **Graph editor — slimmer connection lines** — resting connection lines are now thinner and antialiased (the chunky default 4.0 width). _(Note: the in-progress drag-preview line is drawn by the engine and not addon-controllable; on Godot 4.7 it renders thicker — an upstream engine detail.)_
- **Graph editor — copy / paste / duplicate + Alt+G** — select one or more blocks and `Ctrl+C` / `Ctrl+V` / `Ctrl+D` them. Pasted nodes get fresh ids, their effect resources are deep-copied (so property edits stay independent), connections internal to the copied set are remapped onto the new nodes, repeated pastes cascade their offset, and the whole operation is a single undo step. **Alt+G** toggles the JuiceeGraph bottom panel open/closed (works even while it's hidden).
- **Procedural sound effects** _(experimental)_ — `JuiceeSfxr` (`addons/juicee/audio/juicee_sfxr.gd`), a faithful GDScript port of DrPetter's sfxr that **synthesizes retro game sounds at runtime with zero audio assets**: pickups, lasers, explosions, power-ups, hits, jumps, UI blips. Exposed three ways: the new `JuiceeProcSoundEffect` (works in the graph editor, Inspector, and sequences), `Juicee.sfx(context, category)` for one-liners, and an opt-in `Juicee.sfx_enabled = true` that makes the **built-in presets audible** (`preset_hit`, `preset_pickup`, `preset_explosion`, …) without bundling a single `.wav`. A fixed `seed` reproduces the exact same sound; `seed = 0` gives a fresh variation each call. Generation costs a few milliseconds and seeded sounds are cached. See [`docs/procedural-sfx.md`](docs/procedural-sfx.md).
- **C# support** ([#3](https://github.com/Kelpekk/Juicee/issues/3)) — `addons/juicee/csharp/Juicee.cs`, a static bridge that exposes the **complete** `Juicee` singleton API to C#/.NET Godot projects with typed methods, IntelliSense, and mirrored enums (`Juicee.FlipMode`, `Juicee.ForceMode`, `Juicee.ParticleAction`, `Juicee.SetActiveAction`, `Juicee.LogLevel`, `Juicee.AnimTreeMode`, `Juicee.SfxCategory`). Calls forward to the GDScript autoload at runtime — one shared implementation, no duplicated effect logic. Inert in GDScript-only projects (a loose `.cs` file is ignored without a .NET SDK). See [`docs/csharp.md`](docs/csharp.md).

### Fixed

- **Godot 4.7 compatibility** — on Godot 4.7 the Trigger block (an output-only node) spammed `GraphNode … get_input_port_position(0) out of bounds` every frame, because 4.7's new accessibility pass queries the input port of every slot. The Trigger now carries a transparent, invisible input port so the port cache is never empty — no error spam, no visual change.
- **8 broken singleton wrappers** silently no-op'd — they assigned non-existent effect properties (e.g. `spin` set `speed` instead of `degrees_per_second`; `shake_control` set `shake_control` instead of `intensity`; `pulse`, `blur`, `glitch`, `zoom_pulse`, and `preset_dash`'s blur were likewise wrong). All now map to the correct exported properties.
- **Permanent time-freeze** when time effects overlapped — `hit_stop`, `freeze_frame`, and `time_scale_ramp` each restored `Engine.time_scale` to a raw snapshot, so a second effect starting mid-freeze could capture `0.0` and lock the game frozen. All three now route `Engine.time_scale` through the ref-counted `JuiceeStateStack`, restoring the true original only when the last effect releases.
- **`pulse_effect` crash** when its target was freed mid-loop — added `is_instance_valid(context)` guards (also hardened the sequence runner's loops).
- **`radial_blur` / `shockwave` shader compile errors on GPU** — `hint_range(...)` is only valid on `float`/`int` uniforms, not `vec2`; it was applied to `center_uv` / `origin_uv`, which compiled fine in headless (no shader compilation) but failed on a real GPU. Removed the invalid hints.
- **HiDPI / editor scaling** — the graph editor, hover panel, graph blocks, and inspector plugin now scale all hardcoded pixel dimensions by `EditorInterface.get_editor_scale()`, so the UI is correct on Retina / 150–200% displays.
- **Anchor-override warnings** — full-screen overlays and centered labels used manual sizes with mismatched anchors; switched to proper presets (`PRESET_TOP_WIDE`, `PRESET_TOP_LEFT`) to silence the warnings.
- **Project icon path** — `config/icon` pointed at a non-existent `icons/` path; corrected to `res://addons/juicee/JuiceeEffect.svg`.
- **Updater "up to date" message** — when the installed version was *newer* than the latest published release (a development build), the *Check for Updates* dialog wrongly claimed "You're up to date" while showing `Latest < Installed`. It now reports an "ahead of the latest release (development build)" state instead.
- **License now ships with the download** — the Asset Library/Store package contains only `addons/`, which excluded the repo-root `LICENSE`. Added `addons/juicee/LICENSE.md` so the MIT license travels with the installed plugin (per the store's licensing requirement).
- **Plugin description** — replaced the long comma-separated effect run-on in `plugin.cfg` with a concise summary (categories + workflows), which reads cleanly in the editor's plugin list and the store.

## [1.0.0] — 2026-06-10

First public release — **ULTIMATE edition**. Aimed at full feature parity with Unity's FEEL addon and beyond, free + MIT.

### Effects (90 total)

#### Batch 4 — 5 fundamental essentials (●)

**Object category (+4):**
- `JuiceeFadeEffect` — fade a CanvasItem's alpha to a target value over duration. `restore_on_end = true` fades out, holds, fades back in. The most fundamental UI/game effect: death fade, spawn reveal, ghost transparency, cutscene fade to black.
- `JuiceeFlipEffect` — set `flip_h` / `flip_v` on a Sprite2D or AnimatedSprite2D. Three modes per axis: `TOGGLE`, `SET_TRUE`, `SET_FALSE`. Optional `restore_on_end` with `hold_duration`. Directional facing, hit reaction mirror, coin/card flip reveal.
- `JuiceeInstantiateEffect` — spawn a `PackedScene` at the context node's world position with optional offset, rotation/scale inheritance, and auto-free after `lifetime` seconds. Blood splats, hit sparks, VFX, enemy/pickup/projectile spawning as a sequence step.
- `JuiceeSizeDeltaEffect` — tween a Control's `custom_minimum_size` or `size` to a target value. Optional `restore_on_end`. Health bar grow/shrink, animated panel expand/collapse, tooltip appear, progress bar fill.

**Flow category (+1):**
- `JuiceeAutoDestructEffect` — `queue_free()` the context node (or a target) after an optional delay. Optional `free_parent` flag to free the root instead of the direct target. Clean up temporary VFX nodes, hit sparks, spawned floating text, enemy corpses at the end of a death sequence.

**New singleton wrappers:**
- `Juicee.fade(target, alpha, duration)` — FadeEffect shorthand
- `Juicee.flip(target, flip_h_mode, flip_v_mode)` — FlipEffect shorthand
- `Juicee.instantiate_scene(context, scene, lifetime, offset)` — InstantiateEffect shorthand
- `Juicee.auto_destruct(context, delay)` — AutoDestructEffect shorthand
- `Juicee.resize_control(target, target_size, duration)` — SizeDeltaEffect shorthand
- `Juicee.wait(context, seconds)` — DelayEffect shorthand (was missing)
- `Juicee.punch_position_3d(target, offset_3d, duration)` — Position3DEffect shorthand (was missing)
- `Juicee.punch_rotation_3d(target, angle_degrees, axis, duration)` — Rotation3DEffect shorthand (was missing)

#### Batch 3 — 15 new deep-system effects (★)

**Screen category (+2):**
- `JuiceeLensDistortionEffect` — barrel/pincushion lens distortion via `lens_distortion.gdshader`. `strength > 0` = barrel (fisheye), `strength < 0` = pincushion (zoom lens). Configurable fade-out. Scope zoom, warp portals, dimensional rifts.
- `JuiceeDepthOfFieldEffect` — drives `CameraAttributesPractical` on a Camera3D for a real DOF blur (not a screen shader). Animated fade-in, hold, fade-out. Far/near blur independently toggleable. Focus-pull cinematics, sniper scope, cinematic transitions.

**Camera category (+1):**
- `JuiceeCameraRotationEffect` — Dutch tilt: smoothly rotate Camera2D by `angle_degrees` then spring back. Three-phase: tilt-in → hold → return. Uses `JuiceeStateStack` for concurrent safety. Car chases, punch impacts, dramatic reveals, disorientation.

**Object category (+6):**
- `JuiceeShaderParameterEffect` — tween any `ShaderMaterial` uniform from `from_value` to `to_value`. Works on CanvasItem and MeshInstance3D surface materials. Configurable `restore_on_end`. Drive dissolve, fresnel glow, scanline density — anything your shader exposes as a uniform.
- `JuiceeFlickerEffect` — organic random modulate flicker on a CanvasItem. Randomised on/off intervals from `[min_interval, max_interval]`. Configurable `off_color` (default transparent), `off_chance`, and `duration` (0 = infinite until `stop()`). Torches, broken neon lights, ghost transparency, dying machinery.
- `JuiceeScaleEffect` — general scale tween to `target_scale` with optional spring-back. Unlike `BounceEffect` (which uses squash-and-stretch math), this directly tweens to a designer-specified scale. Configurable `return_to_original`, `return_duration`, `transition`, and `easing`.
- `JuiceeParticleEffect` — control an existing `CPUParticles2D` or `GPUParticles2D` by NodePath. Four actions: `EMIT` (enable + one-shot), `STOP`, `RESTART`, `TOGGLE`. Optional `wait_for_finish` stalls the sequence until the particle system finishes its lifetime.
- `JuiceeLight3DEffect` — flash a `Light3D`'s `light_energy` and `light_color` to a peak then fade back. Uses `JuiceeStateStack` to restore original values. Muzzle flash, explosion light, magic pulse, flickering candle highlight.
- `JuiceeMaterial3DEffect` — animate any property on a `MeshInstance3D`'s surface material. **Duplicates the material on play** to avoid affecting other mesh instances sharing the same resource. Configurable `restore_on_end`. Dissolve effect, emission ramp, fresnel fade.

**Audio category (+1):**
- `JuiceeAudioSource3DEffect` — spawn a temporary `AudioStreamPlayer3D` at the context's world position. Position derived from `Node3D.global_position` directly; for 2D contexts, converts `Node2D.global_position` to a Vector3 with configurable `pixel_scale`. Auto-frees on finish. Random stream from pool, pitch variance, configurable bus and attenuation model.

**Physics category (+1):**
- `JuiceeAddForceEffect` — apply an impulse or continuous force to `RigidBody2D` or `RigidBody3D`. Three modes: `IMPULSE` (instant velocity change), `CONSTANT_FORCE` (sustained over `duration` then cleared), `TORQUE_IMPULSE` (angular kick). Separate `force` (Vector2) and `force_3d` (Vector3) params. Explosion push, wind gusts, magnetic pull, knockback.

**Flow category (+4):**
- `JuiceeEmitSignalEffect` — emit a signal by name on the context node with an optional `Variant` argument. Bridge between Juicee sequences and gameplay systems without code coupling. Signal must exist on the context.
- `JuiceeDebugLogEffect` — print, push_warning, or push_error a message from a sequence step. Supports `{context}` placeholder for the context node's name. `include_context_name` flag. Zero-overhead in production (guard with Godot's `OS.is_debug_build()` pattern if needed).
- `JuiceeAnimationTreeEffect` — travel to an `AnimationTree` state machine state or set a parameter directly. `TRAVEL` mode calls `StateMachinePlayback.travel()` for smooth transitions; `SET_PARAMETER` mode sets any tree parameter (blend amounts, time scales, booleans). Optional `wait_for_finish` polls until the target state is reached.
- `JuiceeSetPropertyEffect` — instantly `set_indexed(property_name, value)` on any node, then optionally restore the original after `restore_delay` seconds. The direct-assignment version of `PropertyTweenEffect` — no animation, just set. Toggle bool flags, snap positions, change label text, set collision layers mid-sequence.

#### ULTIMATE additions — 25 new effects + Condition graph node + pause/resume 🔥

**Screen category (+5):**
- `JuiceeShockwaveEffect` — expanding radial distortion ring from the context node's screen position. Animates a Gaussian-falloff UV warp ring that expands outward with strength fading as the ring grows. Explosions, teleport arrivals, spell impacts, landing slams.
- `JuiceeCinematicBarsEffect` — letterbox bars slide in from top/bottom, hold for configurable duration (0 = hold until `stop()` for dialogue sequences), then slide out. Uses pure `ColorRect` on a `CanvasLayer` — zero shader overhead. Boss intros, cutscene boundaries, dramatic slow-mo moments.
- `JuiceeScanLinesEffect` — CRT scanline overlay with optional scroll speed. Retro monitors, broken screens, hacker aesthetic. Fade in/hold/fade out envelope. `scanlines.gdshader`.
- `JuiceeFilmGrainEffect` — analog film grain noise overlay. Cinematic grit, horror atmosphere, film emulation. Quantized to configurable FPS for authentic grain flutter. `film_grain.gdshader`.
- `JuiceeRadialBlurEffect` — radial motion blur from a screen point. Speed lines, warp drives, dash impacts. Supports deriving center from a Node2D's screen position at runtime. `radial_blur.gdshader`.

**Camera category (+3):**
- `JuiceeDirectionalShakeEffect` — kick-recoil shake in a specific direction plus perpendicular noise. Exponential decay. Gun fire, directional punches, blast knockback. Direction overridable via runtime params.
- `JuiceeCameraBobEffect` — rhythmic sine-wave camera bob along a configurable axis. Sin(t·π) envelope for smooth start and stop. Walk cycles, breathing idle, post-impact sway.
- `JuiceeZoomPulseEffect` — BPM-synchronized Camera2D zoom pulse. Beat-drops, music-reactive screens, bass-rumble feel. Integrates with `JuiceeBeatClock` or runs standalone.

**Object category (+6):**
- `JuiceeAmbientFlashEffect` — repeating modulate flash for sustained states (low-health siren, boss enrage, alarm pulsing). Sustains across multiple cycles with configurable frequency and optional `pulse_curve`.
- `JuiceeStrobeLightEffect` — square-wave `Light2D` strobe (lightning strikes, flashbangs, emergency sirens). Configurable pulse count, on-ratio, and peak energy.
- `JuiceeRecoilEffect` — directional position kick on Node2D with spring-back. Gun recoil, hit absorption, stiff-arm impact. Direction can be overridden per-shot via runtime params.
- `JuiceeOutlineEffect` — animates a colored outline around a CanvasItem via built-in shader uniform. Selection ring, status glow (poisoned/burning/frozen), lock-on indicator.
- `JuiceeColorCycleEffect` — cycles `modulate` through the HSV hue wheel. Rainbow powerup, party mode, boss phase shift. Configurable cycles, saturation, and value.
- `JuiceeSpinEffect` — full 360° rotation tween on Node2D. Optional `restore_on_end` snap-back. Coin pickups, death spin, victory twirl.
- `JuiceeWiggleEffect` — random position jitter at configurable Hz with optional decay. Anxiety, confusion, low-health tremor. Uses `JuiceeStateStack` for safe concurrent use.
- `JuiceeSpriteBobEffect` — sine-wave bob along a configurable axis. Sin(t·π) envelope. Floating pickups, hover loops, idle animations.
- `JuiceePopInEffect` — TRANS_SPRING / EASE_OUT scale-in from `from_scale` (default 0). The most satisfying pop-in possible. Works on both Node2D and Control.
- `JuiceeShakeControlEffect` — horizontal shake on Control nodes with ±30% vertical noise and linear decay. Wrong-password UI, invalid-action feedback.
- `JuiceePulseEffect` — repeating EXPO scale pulse per interval. `count=0` + `duration>0` = time-limited infinite loop. Heartbeat, charge meter, selected-state indicator.

**Time category (+1):**
- `JuiceeFreezeFrameEffect` — `Engine.time_scale = 0.0` for N real-time seconds, then restores. Optional white flash overlay. Feels heavier than `HitStop` — true engine freeze.

**Flow category (+5):**
- `JuiceeAnimationPlayerEffect` — triggers `AnimationPlayer.play()` as a step in a Juicee sequence. FEEL parity — blend existing sprite/mesh animations into juice sequences. Optional `wait_for_finish` stalls the sequence until the animation ends.
- `JuiceeSetActiveEffect` — shows/hides a node for N seconds then restores original visibility. Muzzle flash, hit spark, tutorial highlight, one-shot reveals.
- `JuiceeChainEffect` — composes N child `JuiceeEffect` resources as a single reusable block. Build signature move combos as one `.tres` asset. Supports sequential + parallel modes.
- `JuiceeBeatSyncEffect` — fires a child effect synchronized to a BPM beat. Clock mode (connects to `JuiceeBeatClock.beat` signal for musical tight-sync) or standalone mode (internal timer). Configurable beats_per_trigger and duration.
- `JuiceeWaitForInputEffect` — pauses sequence execution until the player presses a specified action. Optional timeout. Dialog advancement, tutorial checkpoints, cutscene pacing.

**Graph editor — Condition node:**
- New **Condition** graph block evaluates a GDScript expression against `context`. Port 0 = True branch, Port 1 = False branch. Uses Godot's `Expression` class — write `context.health < 20`, `context.is_in_group("player")`, etc. Both editor Debug Test and runtime JuiceeGraphPlayer honor the same evaluation.

**JuiceeSequence — pause / resume:**
- `JuiceeSequence.pause()` / `resume()` / `is_paused()` — pause at the seam between effects. The currently running effect finishes naturally, then the sequence gates until `resume()` is called.

**New core node:**
- `JuiceeBeatClock extends Node` — accumulator-based BPM tracker. `start()`, `stop()`, `reset()`. Emits `beat(beat_number: int)` signal. `get_beat_phase()` returns 0-1 within the current beat. `auto_start` export. Drop into a scene and point `JuiceeBeatSyncEffect` or `JuiceeZoomPulseEffect` at it.

#### ULTIMATE preset library — 6 new presets 🔥

- `Juicee.preset_combo(target)` — 3× escalating hit-stops + chromatic + burst. Combo finisher.
- `Juicee.preset_dash(target, direction)` — chromatic + blur + zoom + position kick. Dodge/dash feel.
- `Juicee.preset_pickup(item_node)` — bounce + flash + confetti + floating text. Coin / item collect.
- `Juicee.preset_boss_intro(target)` — zoom + vignette + shake + ominous red tint. Boss entrance.
- `Juicee.preset_low_health_pulse(sprite)` — sustained red ambient flash (returns a stoppable effect reference). Low-health danger loop.
- `Juicee.preset_victory(target)` — confetti + zoom + color cycle + warm tint + rumble. Win screen.

#### Graph editor 2D/3D tags 🔥

Every effect in the popup search list and on graph block titlebars now shows small `2D` / `3D` tag icons indicating which scene types the effect targets. Effects that work in both show both icons (screen FX, audio, time, flow). Built-in `video-2d.svg` / `video-3d.svg` icons from the Godot icon set.

---

### Effects (45 total, up from initial 34-effect plan — pre-ULTIMATE baseline)

The original v1.0 scope shipped 34 effects. The "ULTRA" push added **11 new effects** plus a built-in preset library to reach feature parity with what action-game devs expect from a polished game-feel toolkit:

**New Text category (6 effects)** — restoring the action-game text feedback that v0.x removed:
- `JuiceeDamageNumberEffect` — floating damage numbers with crit support (alt color, larger font, scale punch). Pass `{"damage": 999, "is_crit": true}` via `play()`.
- `JuiceeFloatingTextEffect` — generic spawned text (Level Up!, pickup names, status messages) with 3 travel directions (up, down, random horizontal drift).
- `JuiceeButtonPunchEffect` — Control-targeting scale-punch with optional color flash. The bouncy button feel of polished menus.
- `JuiceeTypewriterEffect` — char-by-char Label reveal via `visible_ratio`, with optional click sounds + pitch variance.
- `JuiceeNumberCountEffect` — tween a Label's number from X to Y with printf format + prefix + suffix. Score rollups, money displays.
- `JuiceeTextWobbleEffect` — sine-wave wobble on Control position with decay. Drama text: GAME OVER, BOSS APPROACHING.

**WorldEnvironment integration (2 effects)** — animate Godot's built-in post-process pipeline. Zero custom shader code, native performance, 2D + 3D:
- `JuiceeBloomEffect` — pulses `environment.glow_intensity` / `glow_strength` / `glow_bloom` with optional curve. Boss intros, level-ups, power-ups.
- `JuiceeTonemapEffect` — punches `environment.tonemap_exposure` / `tonemap_white` for flashbang / camera-overload feel. Explosions, teleports, dimension shifts.

**Audio bus FX (2 effects)** — temporarily inject AudioServer effects, animate wet/pitch, remove cleanly:
- `JuiceeReverbEffect` — adds `AudioEffectReverb` on a bus with wet ramp in/out. Boss intros, low-health states, dimension shifts.
- `JuiceePitchShiftEffect` — adds `AudioEffectPitchShift` with target_pitch ramp. Underwater, slow-mo audio, demon transformations.

**Spring physics (1 effect)**:
- `JuiceeSpringEffect` — harmonic-oscillator simulation on any Vector2 property. Universal animator: button.scale bouncing, menu position oscillation, sprite squash-on-hit. Stiffness / damping / mass / impulse / max_duration. Captures rest value via `JuiceeStateStack` for concurrent safety.

### Drop-in preset library (built-in Juicee singleton helpers)

Six battle-tested game-feel sequences callable as one-line API calls:
- `Juicee.preset_hit(target)` — light shake + flash
- `Juicee.preset_hit_crit(target)` — hit_stop + bigger shake + chromatic + bright flash
- `Juicee.preset_level_up(target)` — shake + zoom + bounce + confetti + warm tint
- `Juicee.preset_damage_taken(player)` — hit_stop + shake + red tint + vignette + rumble
- `Juicee.preset_death(player)` — slow-mo + persistent blur + pixelate + grayscale + glitch
- `Juicee.preset_explosion(target)` — hit_stop + burst + shake + chromatic

These build the sequence inline using the new effect classes — no `.tres` files to manage, no resource path lookup.

### Architecture

- Resource-first — every effect is one `.gd` file extending `JuiceeEffect`; sequences are `JuiceeSequence.tres` containers; `JuiceePlayer` is a Node that plays them.
- Three workflows on the same resources: **Singleton** (`Juicee.shake_camera(...)`), **Inspector** (drop a `JuiceePlayer`, build sequence in custom card UI), **JuiceeGraph** (visual bottom panel with Trigger / Split / Loop / Random flow nodes).
- Ref-counted `JuiceeStateStack` — concurrent effects on the same property restore the TRUE original value when all release, not a mid-effect snapshot.
- Generation-token cancellation in `JuiceeEffect.apply()` — spamming play replaces the previous in-flight run instead of stacking N coroutines that each fire after their delay.
- `_track()` framework for tween-driven effects so `stop()` actually kills them mid-flight.
- **Curve-based parameter helper** (`_tween_curved`) — any effect can opt into `@export var <param>_curve: Curve` for designer-painted easing shapes. Falls back to standard `set_trans`/`set_ease` if curve is null. Full effect-by-effect retrofit lands in v1.1; v1.0 ships the foundation plus opt-in on Bloom and Tonemap.

### Categories (8 total)

- **Screen (10)**: Chromatic, Vignette, Blur, Pixelate, Glitch, Color Grade, Screen Tint, Screen Wipe, **Bloom**, **Tonemap**
- **Camera (5)**: Shake, Shake 3D, Zoom, FOV 3D, Camera Follow
- **Object (13)**: Flash, Modulate, Bounce, Jiggle Physics, Position, Position 3D, Rotation, Rotation 3D, Trail, Burst, Confetti, Light Flash, **Spring**
- **Text (6, new category)**: **Damage Number**, **Floating Text**, **Button Punch**, **Typewriter**, **Number Count**, **Text Wobble**
- **Time (3)**: Hit Stop, Time Scale Ramp, Delay
- **Audio (5)**: Sound, Music Duck, Rumble, **Reverb**, **Pitch Shift**
- **Physics (1)**: Impulse (RigidBody2D)
- **Flow (2)**: Sequence (nested), Property Tween (universal escape hatch)

### Graph editor

- Auto-discovery of effect scripts via `addons/juicee/effects/` scan — adding a new effect is a single file, no enum / registry / case statement to update.
- Categorized popup (Screen / Camera / Object / Text / Time / Audio / Physics / Flow) with search, tooltips, and category-colored ports.
- **Split** / **Random** with `+` / `−` controls to add/remove output paths (2 – 8).
- **Random weights editor** in the props panel — per-output `SpinBox` plus live percentage labels.
- **Loop** with live `Repeat × N` subtitle that updates as you change the count.
- Tooltips on every block; inline property docstrings + slider + min/max endpoints in the side panel.
- Enum properties rendered as `OptionButton` dropdowns; colors as `ColorPickerButton`.
- **Test** button walks the graph in real time, highlighting blocks as they execute. Delay phase shows a fill bar that grows over the configured delay duration. Honors Random weights.
- **Export Sequence** flattens the graph into a plain `JuiceeSequence.tres` for use with `JuiceePlayer.sequence`.
- **Check for Updates** button — Godot has no built-in addon updater, so this calls the GitHub releases API, shows what's new, and (on confirmation) downloads + extracts the latest archive over `addons/juicee/`.
- **Editor preview hint outline** — soft amber outline + label during shader effect testing in editor, marking the `SCREEN_TEXTURE`-bound area. Hidden in runtime.
- Native Godot editor look — inherits the editor theme so the panel matches VisualShader / AnimationTree.

### Documentation
- [`README.md`](README.md) — install + quickstart for all three workflows.
- [`docs/how-to-write-effect.md`](docs/how-to-write-effect.md) — 30-line template for community contributions.
- [`docs/philosophy.md`](docs/philosophy.md) — when to use Inspector vs Graph vs Singleton, and why.
- [`addons/juicee/examples/effects_showcase.tscn`](addons/juicee/examples/effects_showcase.tscn) — keyboard-driven demo of every effect.

### Deferred to v1.1

These were considered for v1.0 but pushed to keep the release scope sane:
- `JuiceeDoFEffect` — WorldEnvironment depth-of-field (rare in 2D, requires 3D camera + active DoF setup).
- `JuiceeAudioCurveEffect` — animate any bus property via Curve resource (covered partially by ReverbEffect / PitchShiftEffect for common cases).
- `.tres` preset files in `addons/juicee/presets/` (currently shipping as inline singleton helpers `Juicee.preset_*`).
- Demo scenes library (combat / boss_intro / pickup / ui / death) — `effects_showcase.tscn` covers most cases for v1.0.
- Curve-based parameter retrofit across all 53 effects (foundation helper ships; per-effect opt-in lands in v1.1).

[1.1.0]: https://github.com/Kelpekk/Juicee/releases/tag/v1.1.0
[1.0.0]: https://github.com/Kelpekk/Juicee/releases/tag/v1.0.0
