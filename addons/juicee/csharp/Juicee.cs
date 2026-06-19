using Godot;
using Godot.Collections;

namespace JuiceeFX;

/// <summary>
/// C# bridge for the Juicee game-feel addon (https://github.com/Kelpekk/Juicee).
///
/// Every method forwards to the GDScript <c>Juicee</c> autoload singleton at
/// runtime, so there is a single shared implementation — no duplicated effect
/// logic. Just add <c>using JuiceeFX;</c> and call, e.g.:
///
/// <code>
/// Juicee.ShakeCamera(this, 15f, 0.3f);
/// Juicee.HitStop(this, 0.08f);
/// Juicee.Flash(mySprite, Colors.Red);
/// Juicee.PresetHitCrit(this);
/// </code>
///
/// Requires the .NET / Mono build of Godot. In a GDScript-only project this
/// file is simply ignored (a loose .cs file is inert without a .csproj).
/// The Juicee plugin must be enabled (Project &gt; Project Settings &gt; Plugins).
/// </summary>
public static class Juicee
{
	// ─── Mirrored GDScript enums ─────────────────────────────────────────────

	/// <summary>JuiceeFlipEffect.Mode</summary>
	public enum FlipMode { Toggle = 0, SetTrue = 1, SetFalse = 2 }

	/// <summary>JuiceeAddForceEffect.Mode</summary>
	public enum ForceMode { Impulse = 0, ConstantForce = 1, TorqueImpulse = 2 }

	/// <summary>JuiceeParticleEffect.Action</summary>
	public enum ParticleAction { Emit = 0, Stop = 1, Restart = 2, Toggle = 3 }

	/// <summary>JuiceeSetActiveEffect.Action</summary>
	public enum SetActiveAction { Show = 0, Hide = 1, Toggle = 2 }

	/// <summary>JuiceeDebugLogEffect.Level</summary>
	public enum LogLevel { Print = 0, PushWarning = 1, PushError = 2 }

	/// <summary>JuiceeAnimationTreeEffect.Mode</summary>
	public enum AnimTreeMode { Travel = 0, SetParameter = 1 }

	/// <summary>JuiceeSfxr.Category — procedural sound families.</summary>
	public enum SfxCategory
	{
		PickupCoin = 0, LaserShoot = 1, Explosion = 2, Powerup = 3,
		HitHurt = 4, Jump = 5, BlipSelect = 6, Random = 7,
	}

	// ─── Singleton resolution + call forwarding ──────────────────────────────

	private static Node _singleton;

	/// <summary>The live GDScript <c>Juicee</c> autoload node, or null if missing.</summary>
	public static Node Singleton
	{
		get
		{
			if (_singleton == null || !GodotObject.IsInstanceValid(_singleton))
			{
				_singleton = null;
				if (Engine.GetMainLoop() is SceneTree tree)
					_singleton = tree.Root.GetNodeOrNull("/root/Juicee");
				if (_singleton == null)
					GD.PushError("Juicee: singleton not found at /root/Juicee. " +
						"Enable the Juicee plugin in Project Settings > Plugins.");
			}
			return _singleton;
		}
	}

	private static void Invoke(StringName method, params Variant[] args)
	{
		Node s = Singleton;
		s?.Call(method, args);
	}

	private static Variant InvokeRet(StringName method, params Variant[] args)
	{
		Node s = Singleton;
		return s != null ? s.Call(method, args) : default;
	}

	// ─── Accessibility ───────────────────────────────────────────────────────

	/// <summary>Silence shake/wobble effects (Juicee.accessibility.reduced_motion).</summary>
	public static void SetReducedMotion(bool enabled) => SetAccessibility("reduced_motion", enabled);

	/// <summary>Disable flash/strobe effects (Juicee.accessibility.no_flash).</summary>
	public static void SetNoFlash(bool enabled) => SetAccessibility("no_flash", enabled);

	/// <summary>Disable camera shake only (Juicee.accessibility.no_screenshake).</summary>
	public static void SetNoScreenshake(bool enabled) => SetAccessibility("no_screenshake", enabled);

	private static void SetAccessibility(StringName flag, bool value)
	{
		Node s = Singleton;
		if (s == null) return;
		GodotObject access = s.Get("accessibility").AsGodotObject();
		access?.Set(flag, value);
	}

	// ─── Camera ──────────────────────────────────────────────────────────────

	/// <summary>Shake the active Camera2D found via the context's viewport.</summary>
	public static void ShakeCamera(Node context, float intensity = 8f, float duration = 0.3f, float frequency = 15f)
		=> Invoke("shake_camera", context, intensity, duration, frequency);

	/// <summary>3D camera shake.</summary>
	public static void ShakeCamera3D(Node context, float intensity = 0.1f, float duration = 0.3f)
		=> Invoke("shake_camera_3d", context, intensity, duration);

	/// <summary>Camera2D zoom punch.</summary>
	public static void ZoomCamera(Node context, float zoomFactor = 1.2f, float duration = 0.4f)
		=> Invoke("zoom_camera", context, zoomFactor, duration);

	// ─── Time ────────────────────────────────────────────────────────────────

	/// <summary>Instant Engine.time_scale freeze for impact moments.</summary>
	public static void HitStop(Node context, float freezeDuration = 0.08f, float timeScaleDuring = 0f)
		=> Invoke("hit_stop", context, freezeDuration, timeScaleDuring);

	/// <summary>Smooth slow-motion ramp.</summary>
	public static void SlowMo(Node context, float targetScale = 0.2f, float hold = 0.4f)
		=> Invoke("slow_mo", context, targetScale, hold);

	/// <summary>Engine.time_scale = 0 for N real seconds (true freeze, heavier than HitStop).</summary>
	public static void FreezeFrame(Node context, float freezeDuration = 0.1f, bool whiteFlash = true)
		=> Invoke("freeze_frame", context, freezeDuration, whiteFlash);

	/// <summary>Pause for N seconds — stalls a sequence with no visual change.</summary>
	public static void Wait(Node context, float duration = 0.5f)
		=> Invoke("wait", context, duration);

	// ─── Object feedback ─────────────────────────────────────────────────────

	/// <summary>Flash a CanvasItem's modulate.</summary>
	public static void Flash(CanvasItem target, Color? flashColor = null, float duration = 0.15f, int count = 1)
		=> Invoke("flash", target, flashColor ?? Colors.White, duration, count);

	/// <summary>Squash &amp; stretch scale punch on a Node2D.</summary>
	public static void Bounce(Node2D target, float scaleFactor = 1.3f, float duration = 0.3f)
		=> Invoke("bounce", target, scaleFactor, duration);

	/// <summary>Position punch with return.</summary>
	public static void PunchPosition(Node2D target, Vector2 offset, float duration = 0.3f)
		=> Invoke("punch_position", target, offset, duration);

	/// <summary>Rotation punch with return.</summary>
	public static void PunchRotation(Node2D target, float angleDegrees = 15f, float duration = 0.3f)
		=> Invoke("punch_rotation", target, angleDegrees, duration);

	/// <summary>3D position punch — move Node3D by offset (world units) then return.</summary>
	public static void PunchPosition3D(Node3D target, Vector3? offset = null, float duration = 0.3f)
		=> Invoke("punch_position_3d", target, offset ?? new Vector3(0, 0.5f, 0), duration);

	/// <summary>3D rotation punch — rotate Node3D around axis then return.</summary>
	public static void PunchRotation3D(Node3D target, float angleDegrees = 15f, Vector3? axis = null, float duration = 0.3f)
		=> Invoke("punch_rotation_3d", target, angleDegrees, axis ?? Vector3.Up, duration);

	/// <summary>Full 360° rotation tween on Node2D.</summary>
	public static void Spin(Node2D target, float speedDegPerSec = 360f, float duration = 0.6f, bool restore = false)
		=> Invoke("spin", target, speedDegPerSec, duration, restore);

	/// <summary>Random position jitter at Hz with optional decay.</summary>
	public static void Wiggle(Node2D target, float amplitude = 4f, float frequency = 12f, float duration = 0.5f)
		=> Invoke("wiggle", target, amplitude, frequency, duration);

	/// <summary>Sine-wave bob along an axis (floating pickups, hover, idle).</summary>
	public static void SpriteBob(Node2D target, float amplitudePx = 6f, float bobFreq = 1.5f, float duration = 3f, Vector2? axis = null)
		=> Invoke("sprite_bob", target, amplitudePx, bobFreq, duration, axis ?? new Vector2(0, 1));

	/// <summary>SPRING overshoot scale-in from zero (satisfying pop-in).</summary>
	public static void PopIn(Node target, float fromScale = 0f)
		=> Invoke("pop_in", target, fromScale);

	/// <summary>Horizontal shake on a Control (wrong-password / invalid-action feedback).</summary>
	public static void ShakeControl(Control target, float amplitude = 8f, float duration = 0.4f, float frequency = 18f)
		=> Invoke("shake_control", target, amplitude, duration, frequency);

	/// <summary>Fade a CanvasItem's alpha to a target value.</summary>
	public static void Fade(CanvasItem target, float targetAlpha = 0f, float duration = 0.5f, bool restoreOnEnd = false, float restoreDuration = 0.4f)
		=> Invoke("fade", target, targetAlpha, duration, restoreOnEnd, restoreDuration);

	/// <summary>Flip a Sprite2D / AnimatedSprite2D.</summary>
	public static void Flip(Node target, FlipMode flipHMode = FlipMode.Toggle, FlipMode flipVMode = FlipMode.SetFalse, bool restoreOnEnd = false, float holdDuration = 0f)
		=> Invoke("flip", target, (int)flipHMode, (int)flipVMode, restoreOnEnd, holdDuration);

	/// <summary>Spawn a PackedScene at the context's position; auto-freed after lifetime.</summary>
	public static void InstantiateScene(Node context, PackedScene scene, float lifetime = 2f, Vector2? offset = null)
		=> Invoke("instantiate_scene", context, scene, lifetime, offset ?? Vector2.Zero);

	/// <summary>queue_free the context (or target_path) after a delay.</summary>
	public static void AutoDestruct(Node context, float delay = 0f, NodePath targetPath = null)
		=> Invoke("auto_destruct", context, delay, targetPath ?? new NodePath());

	/// <summary>Tween a Control's custom_minimum_size to a target size.</summary>
	public static void ResizeControl(Control target, Vector2 targetSize, float duration = 0.3f, bool restoreOnEnd = false)
		=> Invoke("resize_control", target, targetSize, duration, restoreOnEnd);

	/// <summary>Repeating scale pulse (heartbeat, charge meter, selected state).</summary>
	public static void Pulse(Node target, float scaleFactor = 1.15f, float interval = 0.5f, int count = 0, float duration = 3f)
		=> Invoke("pulse", target, scaleFactor, interval, count, duration);

	/// <summary>Tween any ShaderMaterial uniform from one value to another.</summary>
	public static void ShaderParameter(Node target, string paramName, Variant fromValue, Variant toValue, float duration = 0.5f, bool restoreOnEnd = false, int surfaceIndex = 0)
		=> Invoke("shader_parameter", target, paramName, fromValue, toValue, duration, restoreOnEnd, surfaceIndex);

	/// <summary>Organic random modulate flicker (torches, broken lights, ghosts). duration 0 = forever.</summary>
	public static void Flicker(CanvasItem target, float duration = 1.5f, Color? offColor = null, float offChance = 0.3f)
		=> Invoke("flicker", target, duration, offColor ?? new Color(0, 0, 0, 0), offChance);

	/// <summary>General scale tween with optional spring-back.</summary>
	public static void ScaleTo(Node target, Vector2? targetScale = null, float duration = 0.3f, bool returnToOriginal = true, float returnDuration = 0.2f)
		=> Invoke("scale_to", target, targetScale ?? new Vector2(1.5f, 1.5f), duration, returnToOriginal, returnDuration);

	/// <summary>Control an existing CPUParticles2D / GPUParticles2D by path.</summary>
	public static void ParticleEmit(Node context, NodePath particlePath, ParticleAction action = ParticleAction.Emit, bool waitForFinish = false)
		=> Invoke("particle_emit", context, particlePath, (int)action, waitForFinish);

	/// <summary>Flash a Light3D's energy and color (muzzle flash, explosion, magic pulse).</summary>
	public static void Light3DFlash(Node target, float peakEnergy = 5f, Color? flashColor = null, float duration = 0.25f, NodePath lightPath = null)
		=> Invoke("light_3d_flash", target, peakEnergy, flashColor ?? Colors.White, duration, lightPath ?? new NodePath());

	/// <summary>Animate a MeshInstance3D material property (dissolve, emission, fresnel).</summary>
	public static void Material3D(Node target, string propertyName, Variant fromValue, Variant toValue, float duration = 0.5f, bool restoreOnEnd = false, int surfaceIndex = 0)
		=> Invoke("material_3d", target, propertyName, fromValue, toValue, duration, restoreOnEnd, surfaceIndex);

	// ─── Particles ───────────────────────────────────────────────────────────

	/// <summary>One-shot particle burst at the target's position.</summary>
	public static void Burst(Node2D target, int amount = 12, Color? color = null, float spread = 120f)
		=> Invoke("burst", target, amount, color ?? new Color(1f, 0.8f, 0.3f), spread);

	/// <summary>Multi-color confetti burst.</summary>
	public static void Confetti(Node2D target, int amount = 40)
		=> Invoke("confetti", target, amount);

	// ─── Screen FX ───────────────────────────────────────────────────────────

	/// <summary>Chromatic aberration (RGB split), full-screen.</summary>
	public static void Chromatic(Node context, float intensity = 5f, float duration = 0.2f)
		=> Invoke("chromatic", context, intensity, duration);

	/// <summary>Edge-darkening vignette with color tint.</summary>
	public static void Vignette(Node context, float intensity = 0.6f, float duration = 0.8f, Color? color = null)
		=> Invoke("vignette", context, intensity, duration, color ?? Colors.Black);

	/// <summary>Full-screen blur.</summary>
	public static void Blur(Node context, float blurAmount = 4f, float duration = 0.6f)
		=> Invoke("blur", context, blurAmount, duration);

	/// <summary>Digital glitch tear + chromatic split.</summary>
	public static void Glitch(Node context, float strength = 0.5f, float duration = 0.3f)
		=> Invoke("glitch", context, strength, duration);

	/// <summary>Colored full-screen flash (damage red, level-up gold, etc.).</summary>
	public static void ScreenTint(Node context, Color tintColor, float duration = 0.4f)
		=> Invoke("screen_tint", context, tintColor, duration);

	/// <summary>Smooth modulate color shift on a CanvasItem (unlike flash, which blinks).</summary>
	public static void ModulateTo(CanvasItem target, Color color, float duration = 0.4f)
		=> Invoke("modulate_to", target, color, duration);

	/// <summary>Spring-based jiggle on a Node2D's scale (jelly feel).</summary>
	public static void Jiggle(Node2D target, Vector2? impulse = null, float stiffness = 8f)
		=> Invoke("jiggle", target, impulse ?? new Vector2(0.4f, -0.4f), stiffness);

	/// <summary>Full-screen color grading shift (saturation, contrast, tint).</summary>
	public static void ColorGrade(Node context, float saturation = 0.5f, float contrast = 1.2f, Color? tint = null, float duration = 0.8f)
		=> Invoke("color_grade", context, saturation, contrast, tint ?? Colors.White, duration);

	/// <summary>Full-screen pixelation.</summary>
	public static void Pixelate(Node context, float pixelSize = 8f, float duration = 0.5f)
		=> Invoke("pixelate", context, pixelSize, duration);

	/// <summary>Light2D energy/color flash.</summary>
	public static void LightFlash(Light2D target, float peakEnergy = 3f, Color? color = null, float duration = 0.3f)
		=> Invoke("light_flash", target, peakEnergy, color ?? Colors.White, duration);

	/// <summary>Full-screen wipe transition (colored bar slides across).</summary>
	public static void ScreenWipe(Node context, int fromSide = 0, Color? color = null, float duration = 0.6f)
		=> Invoke("screen_wipe", context, fromSide, color ?? Colors.Black, duration);

	/// <summary>Expanding radial shockwave distortion ring from the context's screen position.</summary>
	public static void Shockwave(Node context, float maxRadius = 0.6f, float strength = 0.025f, float duration = 0.5f)
		=> Invoke("shockwave", context, maxRadius, strength, duration);

	/// <summary>Cinematic letterbox bars: slide in, hold, slide out. Returns the effect (call <c>stop</c> when holdDuration=0).</summary>
	public static GodotObject CinematicBars(Node context, float barHeight = 0.1f, float enterDuration = 0.3f, float holdDuration = 2f, float exitDuration = 0.3f)
		=> InvokeRet("cinematic_bars", context, barHeight, enterDuration, holdDuration, exitDuration).AsGodotObject();

	/// <summary>Dutch tilt — rotate Camera2D then spring back.</summary>
	public static void CameraRotation(Node context, float angleDegrees = 5f, float tiltDuration = 0.3f, float holdDuration = 0f, float returnDuration = 0.4f)
		=> Invoke("camera_rotation", context, angleDegrees, tiltDuration, holdDuration, returnDuration);

	/// <summary>Temporary Camera2D lerp to follow a target Node2D.</summary>
	public static void CameraFollow(Node2D target, float duration = 1.5f, float followSpeed = 5f)
		=> Invoke("camera_follow", target, duration, followSpeed);

	/// <summary>CRT scanline overlay.</summary>
	public static void ScanLines(Node context, float lineCount = 300f, float strength = 0.25f, float duration = 1f, float scrollSpeed = 0f)
		=> Invoke("scan_lines", context, lineCount, strength, duration, scrollSpeed);

	/// <summary>Analog film grain overlay.</summary>
	public static void FilmGrain(Node context, float grainStrength = 0.12f, float grainSpeed = 30f, float duration = 1f)
		=> Invoke("film_grain", context, grainStrength, grainSpeed, duration);

	/// <summary>Radial motion blur from a screen point (speed lines, warp, dash).</summary>
	public static void RadialBlur(Node context, float blurStrength = 0.015f, float duration = 0.4f, Vector2? center = null)
		=> Invoke("radial_blur", context, blurStrength, duration, center ?? new Vector2(0.5f, 0.5f));

	/// <summary>Barrel (&gt;0) or pincushion (&lt;0) lens distortion.</summary>
	public static void LensDistortion(Node context, float strength = 0.25f, float duration = 0.5f, bool fadeOut = true)
		=> Invoke("lens_distortion", context, strength, duration, fadeOut);

	/// <summary>Camera3D depth-of-field blur (focus pull, cinematic transitions).</summary>
	public static void DepthOfField(Node context, float farDistance = 10f, float duration = 1f, bool blurFar = true, bool fadeOut = true, NodePath cameraPath = null)
		=> Invoke("depth_of_field", context, farDistance, duration, blurFar, fadeOut, cameraPath ?? new NodePath());

	/// <summary>Directional kick shake (gun fire, punches, blast knockback).</summary>
	public static void DirectionalShake(Node context, Vector2? direction = null, float kickDistance = 12f, float duration = 0.35f)
		=> Invoke("directional_shake", context, direction ?? new Vector2(0, -1), kickDistance, duration);

	/// <summary>Rhythmic sine-wave camera bob (walk cycle, breathing idle).</summary>
	public static void CameraBob(Node context, Vector2? amplitude = null, float frequency = 2f, float duration = 2f)
		=> Invoke("camera_bob", context, amplitude ?? new Vector2(0, 3), frequency, duration);

	/// <summary>BPM-synced Camera2D zoom pulse.</summary>
	public static void ZoomPulse(Node context, float bpm = 120f, float zoomBoost = 0.08f, float duration = 4f)
		=> Invoke("zoom_pulse", context, bpm, zoomBoost, duration);

	// ─── Audio / Hardware ────────────────────────────────────────────────────

	/// <summary>Play a random AudioStream with pitch variance.</summary>
	public static void PlaySound(Node context, Array<AudioStream> streams, float pitchMin = 0.9f, float pitchMax = 1.1f)
		=> Invoke("play_sound", context, streams, pitchMin, pitchMax);

	/// <summary>Gamepad vibration.</summary>
	public static void Rumble(Node context, float weak = 0.5f, float strong = 0.5f, float duration = 0.2f, int device = 0)
		=> Invoke("rumble", context, weak, strong, duration, device);

	/// <summary>Spawn a temporary AudioStreamPlayer3D at the context's world position.</summary>
	public static void Audio3D(Node context, Array<AudioStream> streams, float volumeDb = 0f, float pitchMin = 0.9f, float pitchMax = 1.1f, string bus = "Master", float maxDistance = 20f)
		=> Invoke("audio_3d", context, streams, volumeDb, pitchMin, pitchMax, bus, maxDistance);

	/// <summary>[Experimental] Synthesize and play a retro game sound at runtime — no audio asset needed. seed 0 = fresh variation each call.</summary>
	public static void Sfx(Node context, SfxCategory category, int seed = 0, float volumeDb = 0f, float pitchMin = 1f, float pitchMax = 1f, string bus = "Master")
		=> Invoke("sfx", context, (int)category, seed, volumeDb, pitchMin, pitchMax, bus);

	/// <summary>Enable procedurally-synthesized sound on the built-in presets (preset_hit, preset_pickup, …). Opt-in.</summary>
	public static void SetSfxEnabled(bool enabled)
	{
		Node s = Singleton;
		s?.Set("sfx_enabled", enabled);
	}

	// ─── Physics ─────────────────────────────────────────────────────────────

	/// <summary>Apply an impulse or force to a RigidBody2D / RigidBody3D.</summary>
	public static void AddForce(Node target, Vector2? force = null, ForceMode mode = ForceMode.Impulse, Vector3? force3D = null, float duration = 0.3f)
		=> Invoke("add_force", target, force ?? new Vector2(0, -300), (int)mode, force3D ?? Vector3.Zero, duration);

	// ─── Text / UI ───────────────────────────────────────────────────────────

	/// <summary>Floating damage number above a Node2D (crit support).</summary>
	public static void DamageNumber(Node2D target, int damage, bool isCrit = false)
		=> Invoke("damage_number", target, damage, isCrit);

	/// <summary>Generic floating text above a Node2D (Level Up!, pickup names, status).</summary>
	public static void FloatingText(Node2D target, string text, Color? textColor = null)
		=> Invoke("floating_text", target, text, textColor ?? Colors.White);

	/// <summary>Scale-punch a UI Control (button click, menu highlight).</summary>
	public static void ButtonPunch(Control target, float scaleFactor = 1.15f, float duration = 0.25f)
		=> Invoke("button_punch", target, scaleFactor, duration);

	/// <summary>Reveal a Label's text char-by-char.</summary>
	public static void Typewriter(Label target, string text, float charsPerSecond = 30f)
		=> Invoke("typewriter", target, text, charsPerSecond);

	/// <summary>Tween a Label's number from one value to another (score rollups).</summary>
	public static void CountTo(Label target, float fromVal, float toVal, float duration = 1f, string numberFormat = "%d", string prefix = "", string suffix = "")
		=> Invoke("count_to", target, fromVal, toVal, duration, numberFormat, prefix, suffix);

	/// <summary>Sine-wave wobble on a Control with decay (GAME OVER, BOSS APPROACHING).</summary>
	public static void TextWobble(Control target, float amplitude = 4f, float duration = 0.5f)
		=> Invoke("text_wobble", target, amplitude, duration);

	// ─── WorldEnvironment ────────────────────────────────────────────────────

	/// <summary>Pulse the active WorldEnvironment glow (bloom).</summary>
	public static void Bloom(Node context, float intensityBoost = 1.5f, float duration = 0.6f)
		=> Invoke("bloom", context, intensityBoost, duration);

	/// <summary>Punch the active WorldEnvironment tonemap exposure (flashbang).</summary>
	public static void TonemapPunch(Node context, float exposureBoost = 3f, float duration = 0.4f)
		=> Invoke("tonemap_punch", context, exposureBoost, duration);

	// ─── Spring physics ──────────────────────────────────────────────────────

	/// <summary>Spring-bounce a Vector2 property on the target (universal animator).</summary>
	public static void Spring(Node target, string propertyName, Vector2 kick, float stiffness = 200f, float damping = 10f)
		=> Invoke("spring", target, propertyName, kick, stiffness, damping);

	// ─── Audio bus FX ────────────────────────────────────────────────────────

	/// <summary>Temporarily add reverb to an audio bus.</summary>
	public static void Reverb(Node context, string bus = "Master", float peakWet = 0.45f, float duration = 1.5f)
		=> Invoke("reverb", context, bus, peakWet, duration);

	/// <summary>Temporarily pitch-shift an audio bus (slow-mo audio, underwater).</summary>
	public static void PitchShift(Node context, float targetPitch = 0.7f, string bus = "Master", float duration = 1f)
		=> Invoke("pitch_shift", context, targetPitch, bus, duration);

	// ─── Composition ─────────────────────────────────────────────────────────

	/// <summary>Trigger an AnimationPlayer animation as a sequence step.</summary>
	public static void AnimationPlayer(Node context, NodePath playerPath, string animationName, float speed = 1f, bool waitForFinish = true)
		=> Invoke("animation_player", context, playerPath, animationName, speed, waitForFinish);

	/// <summary>Show/hide a node for N seconds then restore.</summary>
	public static void SetActive(Node context, NodePath targetPath, float duration = 0.5f, SetActiveAction action = SetActiveAction.Show)
		=> Invoke("set_active", context, targetPath, duration, (int)action);

	/// <summary>Repeating modulate flash for sustained danger states (siren, low-health).</summary>
	public static void AmbientFlash(CanvasItem target, Color? flashColor = null, float duration = 3f, float frequency = 1.5f)
		=> Invoke("ambient_flash", target, flashColor ?? new Color(1f, 0.2f, 0.2f, 0.5f), duration, frequency);

	/// <summary>Square-wave strobe a Light2D (lightning, flashbang, siren).</summary>
	public static void StrobeLight(Light2D target, int pulseCount = 6, float duration = 0.5f, float peakEnergy = 3f)
		=> Invoke("strobe_light", target, pulseCount, duration, peakEnergy);

	/// <summary>Directional position kick (gun recoil, absorbing a hit).</summary>
	public static void Recoil(Node2D target, Vector2? direction = null, float kickDistance = 12f, float returnDuration = 0.18f)
		=> Invoke("recoil", target, direction ?? new Vector2(-1, 0), kickDistance, returnDuration);

	/// <summary>Animate a colored outline on a CanvasItem (selection ring, status glow).</summary>
	public static void Outline(CanvasItem target, Color? outlineColor = null, float outlineWidth = 2f, float duration = 0.8f)
		=> Invoke("outline", target, outlineColor ?? new Color(1f, 0.85f, 0.2f, 1f), outlineWidth, duration);

	/// <summary>Cycle a CanvasItem's modulate through the hue wheel (rainbow, party mode).</summary>
	public static void ColorCycle(CanvasItem target, float cycles = 2f, float duration = 1.5f, float saturation = 1f)
		=> Invoke("color_cycle", target, cycles, duration, saturation);

	/// <summary>
	/// Play a pre-built JuiceeSequence resource (e.g. load a .tres). Optional params
	/// dictionary is forwarded to every effect for runtime customization.
	/// </summary>
	public static void PlaySequence(Resource sequence, Node context, Dictionary parameters = null)
		=> Invoke("play_sequence", sequence, context, parameters ?? new Dictionary());

	// ─── Built-in presets ────────────────────────────────────────────────────

	/// <summary>Light hit reaction: brief shake + flash.</summary>
	public static void PresetHit(Node context, Color? hitColor = null)
		=> Invoke("preset_hit", context, hitColor ?? Colors.White);

	/// <summary>Critical hit: hit_stop + bigger shake + chromatic + bright flash.</summary>
	public static void PresetHitCrit(Node context)
		=> Invoke("preset_hit_crit", context);

	/// <summary>Level-up: shake + zoom + bounce + confetti + warm tint.</summary>
	public static void PresetLevelUp(Node context)
		=> Invoke("preset_level_up", context);

	/// <summary>Player damage taken: hit_stop + shake + red tint + vignette + rumble.</summary>
	public static void PresetDamageTaken(Node context)
		=> Invoke("preset_damage_taken", context);

	/// <summary>Player death: slow-mo + persistent blur + pixelate + grayscale + glitch.</summary>
	public static void PresetDeath(Node context)
		=> Invoke("preset_death", context);

	/// <summary>Explosion impact: hit_stop + burst + shake + chromatic.</summary>
	public static void PresetExplosion(Node context, Color? burstColor = null)
		=> Invoke("preset_explosion", context, burstColor ?? new Color(1f, 0.6f, 0.2f, 1f));

	/// <summary>Combo finisher: 3× escalating hit-stops + shakes + burst + chromatic.</summary>
	public static void PresetCombo(Node context)
		=> Invoke("preset_combo", context);

	/// <summary>Quick-dodge dash: chromatic + blur + zoom + position kick.</summary>
	public static void PresetDash(Node context, Vector2? direction = null)
		=> Invoke("preset_dash", context, direction ?? Vector2.Right);

	/// <summary>Item / coin pickup: bounce + flash + confetti + floating text.</summary>
	public static void PresetPickup(Node2D target, string labelText = "+1")
		=> Invoke("preset_pickup", target, labelText);

	/// <summary>Boss entrance: zoom + vignette + shake + rumble + ominous tint.</summary>
	public static void PresetBossIntro(Node context)
		=> Invoke("preset_boss_intro", context);

	/// <summary>Low-health loop: repeating red ambient flash. Returns the effect; call <c>stop</c> to end it.</summary>
	public static GodotObject PresetLowHealthPulse(CanvasItem target, float duration = 10f)
		=> InvokeRet("preset_low_health_pulse", target, duration).AsGodotObject();

	/// <summary>Victory: confetti + zoom + color cycle + warm tint + fanfare rumble.</summary>
	public static void PresetVictory(Node context)
		=> Invoke("preset_victory", context);

	// ─── Flow / Sequencing ───────────────────────────────────────────────────

	/// <summary>Pause a sequence until the player presses an action (timeout 0 = wait forever).</summary>
	public static void WaitForInput(Node context, string action = "ui_accept", float timeout = 0f)
		=> Invoke("wait_for_input", context, action, timeout);

	/// <summary>Fire a child JuiceeEffect resource synced to a BPM beat.</summary>
	public static void BeatSync(Node context, Resource childEffect, float bpm = 120f, float duration = 8f, int beatsPerTrigger = 1, NodePath clockPath = null)
		=> Invoke("beat_sync", context, childEffect, bpm, duration, beatsPerTrigger, clockPath ?? new NodePath());

	/// <summary>Emit a signal by name on the context node.</summary>
	public static void EmitSignalOn(Node context, string signalName, Variant argument = default)
		=> Invoke("emit_signal_on", context, signalName, argument);

	/// <summary>Print / warn / error a message from a sequence step.</summary>
	public static void DebugLog(Node context, string message, LogLevel level = LogLevel.Print)
		=> Invoke("debug_log", context, message, (int)level);

	/// <summary>Travel to an AnimationTree state, or set a tree parameter.</summary>
	public static void AnimationTreeTravel(Node context, string stateOrParam, AnimTreeMode mode = AnimTreeMode.Travel, Variant? value = null, NodePath treePath = null)
		=> Invoke("animation_tree_travel", context, stateOrParam, (int)mode, value ?? Variant.From(true), treePath ?? new NodePath());

	/// <summary>Instantly set any property; restoreDelay &lt;0 never restores, 0 immediate, &gt;0 after delay.</summary>
	public static void SetProperty(Node context, string propertyName, Variant value, float restoreDelay = -1f, NodePath targetPath = null)
		=> Invoke("set_property", context, propertyName, value, restoreDelay, targetPath ?? new NodePath());
}
