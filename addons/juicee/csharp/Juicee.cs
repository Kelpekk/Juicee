using Godot;
using Godot.Collections;

namespace JuiceeFX;

/// <summary>
/// C# bridge for the Juicee game-feel addon (https://github.com/Kelpekk/Juicee).
///
/// Every method forwards to the GDScript <c>Juicee</c> autoload singleton at
/// runtime, so there is a single shared implementation - no duplicated effect
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

	/// <summary>JuiceeSfxr.Category - procedural sound families.</summary>
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

	/// <summary>Play effects at a quarter of their strength (Juicee.accessibility.reduced_motion).</summary>
	public static void SetReducedMotion(bool enabled) => SetAccessibility("reduced_motion", enabled);

	/// <summary>Disable flash, strobe, flicker, glow pulse, ambient flash and screen tint (Juicee.accessibility.no_flash).</summary>
	public static void SetNoFlash(bool enabled) => SetAccessibility("no_flash", enabled);

	/// <summary>Disable shake, directional shake, recoil, camera bob, camera rotation, wobble rotation and lens distortion (Juicee.accessibility.no_screenshake).</summary>
	public static void SetNoScreenshake(bool enabled) => SetAccessibility("no_screenshake", enabled);

	/// <summary>Disable chromatic aberration and glitch (Juicee.accessibility.no_chromatic).</summary>
	public static void SetNoChromatic(bool enabled) => SetAccessibility("no_chromatic", enabled);

	/// <summary>Disable rumble (Juicee.accessibility.no_haptics).</summary>
	public static void SetNoHaptics(bool enabled) => SetAccessibility("no_haptics", enabled);

	/// <summary>How much the particle-heavy effects spawn: 0 Low, 1 Medium, 2 High.</summary>
	public enum Quality { Low, Medium, High }

	/// <summary>Set the quality tier for Burst, Confetti, Hit Spark and Sparkle. Low spawns four pieces in ten, Medium seven, High all of them.</summary>
	public static void SetQuality(Quality level) => Invoke("set_quality", (int)level);

	private static void SetAccessibility(StringName flag, bool value)
	{
		Node s = Singleton;
		if (s == null) return;
		GodotObject access = s.Get("accessibility").AsGodotObject();
		access?.Set(flag, value);
	}

	// ─── Camera ──────────────────────────────────────────────────────────────

	/// <summary>Shake the active Camera2D found via the context's viewport.</summary>
	public static GodotObject ShakeCamera(Node context, float intensity = 8f, float duration = 0.3f, float frequency = 15f)
		=> InvokeRet("shake_camera", context, intensity, duration, frequency).AsGodotObject();

	/// <summary>3D camera shake.</summary>
	public static GodotObject ShakeCamera3D(Node context, float intensity = 0.1f, float duration = 0.3f)
		=> InvokeRet("shake_camera_3d", context, intensity, duration).AsGodotObject();

	/// <summary>Camera2D zoom punch.</summary>
	public static GodotObject ZoomCamera(Node context, float zoomFactor = 1.2f, float duration = 0.4f)
		=> InvokeRet("zoom_camera", context, zoomFactor, duration).AsGodotObject();

	// ─── Time ────────────────────────────────────────────────────────────────

	/// <summary>Instant Engine.time_scale freeze for impact moments.</summary>
	public static GodotObject HitStop(Node context, float freezeDuration = 0.08f, float timeScaleDuring = 0f)
		=> InvokeRet("hit_stop", context, freezeDuration, timeScaleDuring).AsGodotObject();

	/// <summary>Smooth slow-motion ramp.</summary>
	public static GodotObject SlowMo(Node context, float targetScale = 0.2f, float hold = 0.4f)
		=> InvokeRet("slow_mo", context, targetScale, hold).AsGodotObject();

	/// <summary>Engine.time_scale = 0 for N real seconds with a full-screen flash: a HitStop with a visual beat.</summary>
	public static GodotObject FreezeFrame(Node context, float freezeDuration = 0.1f, bool whiteFlash = true)
		=> InvokeRet("freeze_frame", context, freezeDuration, whiteFlash).AsGodotObject();

	/// <summary>Pause for N seconds - stalls a sequence with no visual change.</summary>
	public static GodotObject Wait(Node context, float duration = 0.5f)
		=> InvokeRet("wait", context, duration).AsGodotObject();

	// ─── Object feedback ─────────────────────────────────────────────────────

	/// <summary>Flash a CanvasItem's modulate.</summary>
	public static GodotObject Flash(CanvasItem target, Color? flashColor = null, float duration = 0.15f, int count = 1)
		=> InvokeRet("flash", target, flashColor ?? Colors.White, duration, count).AsGodotObject();

	/// <summary>Uniform scale punch on a Node2D that springs back.</summary>
	public static GodotObject Bounce(Node2D target, float scaleFactor = 1.3f, float duration = 0.3f)
		=> InvokeRet("bounce", target, scaleFactor, duration).AsGodotObject();

	/// <summary>Position punch with return. relative=false lands on offset exactly.</summary>
	public static GodotObject PunchPosition(Node2D target, Vector2 offset, float duration = 0.3f, bool returnToOriginal = true, bool relative = true)
		=> InvokeRet("punch_position", target, offset, duration, returnToOriginal, relative).AsGodotObject();

	/// <summary>Rotation punch with return. relative=false turns to angleDegrees exactly.</summary>
	public static GodotObject PunchRotation(Node2D target, float angleDegrees = 15f, float duration = 0.3f, bool returnToOriginal = true, bool relative = true)
		=> InvokeRet("punch_rotation", target, angleDegrees, duration, returnToOriginal, relative).AsGodotObject();

	/// <summary>3D position punch - move Node3D by offset (world units) then return.</summary>
	public static GodotObject PunchPosition3D(Node3D target, Vector3? offset = null, float duration = 0.3f, bool returnToOriginal = true, bool relative = true)
		=> InvokeRet("punch_position_3d", target, offset ?? new Vector3(0, 0.5f, 0), duration, returnToOriginal, relative).AsGodotObject();

	/// <summary>3D rotation punch - rotate Node3D around axis then return.</summary>
	public static GodotObject PunchRotation3D(Node3D target, float angleDegrees = 15f, Vector3? axis = null, float duration = 0.3f, bool returnToOriginal = true, bool relative = true)
		=> InvokeRet("punch_rotation_3d", target, angleDegrees, axis ?? Vector3.Up, duration, returnToOriginal, relative).AsGodotObject();

	/// <summary>Spin a Node2D at speedDegPerSec for duration.</summary>
	public static GodotObject Spin(Node2D target, float speedDegPerSec = 360f, float duration = 0.6f, bool restore = false)
		=> InvokeRet("spin", target, speedDegPerSec, duration, restore).AsGodotObject();

	/// <summary>Random position jitter at Hz with optional decay.</summary>
	public static GodotObject Wiggle(Node2D target, float amplitude = 4f, float frequency = 12f, float duration = 0.5f)
		=> InvokeRet("wiggle", target, amplitude, frequency, duration).AsGodotObject();

	/// <summary>Sine-wave bob along an axis (floating pickups, hover, idle).</summary>
	public static GodotObject SpriteBob(Node2D target, float amplitudePx = 6f, float bobFreq = 1.5f, float duration = 3f, Vector2? axis = null)
		=> InvokeRet("sprite_bob", target, amplitudePx, bobFreq, duration, axis ?? new Vector2(0, 1)).AsGodotObject();

	/// <summary>Spring overshoot scale-in from zero, for menus, pickups and icons appearing.</summary>
	public static GodotObject PopIn(Node target, float fromScale = 0f)
		=> InvokeRet("pop_in", target, fromScale).AsGodotObject();

	/// <summary>Horizontal shake on a Control (wrong-password / invalid-action feedback).</summary>
	public static GodotObject ShakeControl(Control target, float amplitude = 8f, float duration = 0.4f, float frequency = 18f)
		=> InvokeRet("shake_control", target, amplitude, duration, frequency).AsGodotObject();

	/// <summary>Fade a CanvasItem's alpha to a target value.</summary>
	public static GodotObject Fade(CanvasItem target, float targetAlpha = 0f, float duration = 0.5f, bool restoreOnEnd = false, float restoreDuration = 0.4f)
		=> InvokeRet("fade", target, targetAlpha, duration, restoreOnEnd, restoreDuration).AsGodotObject();

	/// <summary>Flip a Sprite2D / AnimatedSprite2D.</summary>
	public static GodotObject Flip(Node target, FlipMode flipHMode = FlipMode.Toggle, FlipMode flipVMode = FlipMode.SetFalse, bool restoreOnEnd = false, float holdDuration = 0f)
		=> InvokeRet("flip", target, (int)flipHMode, (int)flipVMode, restoreOnEnd, holdDuration).AsGodotObject();

	/// <summary>Spawn a PackedScene at the context's position; auto-freed after lifetime.</summary>
	public static GodotObject InstantiateScene(Node context, PackedScene scene, float lifetime = 2f, Vector2? offset = null)
		=> InvokeRet("instantiate_scene", context, scene, lifetime, offset ?? Vector2.Zero).AsGodotObject();

	/// <summary>queue_free the context (or target_path) after a delay.</summary>
	public static GodotObject AutoDestruct(Node context, float delay = 0f, NodePath targetPath = null)
		=> InvokeRet("auto_destruct", context, delay, targetPath ?? new NodePath()).AsGodotObject();

	/// <summary>Tween a Control's custom_minimum_size to a target size.</summary>
	public static GodotObject ResizeControl(Control target, Vector2 targetSize, float duration = 0.3f, bool restoreOnEnd = false)
		=> InvokeRet("resize_control", target, targetSize, duration, restoreOnEnd).AsGodotObject();

	/// <summary>Repeating scale pulse (heartbeat, charge meter, selected state).</summary>
	public static GodotObject Pulse(Node target, float scaleFactor = 1.15f, float interval = 0.5f, int count = 0, float duration = 3f)
		=> InvokeRet("pulse", target, scaleFactor, interval, count, duration).AsGodotObject();

	/// <summary>Tween any ShaderMaterial uniform from one value to another.</summary>
	public static GodotObject ShaderParameter(Node target, string paramName, Variant fromValue, Variant toValue, float duration = 0.5f, bool restoreOnEnd = false, int surfaceIndex = 0)
		=> InvokeRet("shader_parameter", target, paramName, fromValue, toValue, duration, restoreOnEnd, surfaceIndex).AsGodotObject();

	/// <summary>Organic random modulate flicker (torches, broken lights, ghosts). duration 0 = forever.</summary>
	public static GodotObject Flicker(CanvasItem target, float duration = 1.5f, Color? offColor = null, float offChance = 0.3f)
		=> InvokeRet("flicker", target, duration, offColor ?? new Color(0, 0, 0, 0), offChance).AsGodotObject();

	/// <summary>General scale tween with optional spring-back.</summary>
	public static GodotObject ScaleTo(Node target, Vector2? targetScale = null, float duration = 0.3f, bool returnToOriginal = true, float returnDuration = 0.2f, bool relative = true)
		=> InvokeRet("scale_to", target, targetScale ?? new Vector2(1.5f, 1.5f), duration, returnToOriginal, returnDuration, relative).AsGodotObject();

	/// <summary>Scale punch on a Node3D, optionally easing back.</summary>
	public static GodotObject ScaleTo3D(Node target, Vector3? targetScale = null, float duration = 0.3f, bool returnToOriginal = true, float returnDuration = 0.2f, bool relative = true)
		=> InvokeRet("scale_to_3d", target, targetScale ?? new Vector3(1.5f, 1.5f, 1.5f), duration, returnToOriginal, returnDuration, relative).AsGodotObject();

	/// <summary>Control an existing particle node by path, 2D or 3D.</summary>
	public static GodotObject ParticleEmit(Node context, NodePath particlePath, ParticleAction action = ParticleAction.Emit, bool waitForFinish = false)
		=> InvokeRet("particle_emit", context, particlePath, (int)action, waitForFinish).AsGodotObject();

	/// <summary>Flash a Light3D's energy and color (muzzle flash, explosion, magic pulse).</summary>
	public static GodotObject Light3DFlash(Node target, float peakEnergy = 5f, Color? flashColor = null, float duration = 0.25f, NodePath lightPath = null)
		=> InvokeRet("light_3d_flash", target, peakEnergy, flashColor ?? Colors.White, duration, lightPath ?? new NodePath()).AsGodotObject();

	/// <summary>Animate a MeshInstance3D material property (dissolve, emission, fresnel).</summary>
	public static GodotObject Material3D(Node target, string propertyName, Variant fromValue, Variant toValue, float duration = 0.5f, bool restoreOnEnd = false, int surfaceIndex = 0)
		=> InvokeRet("material_3d", target, propertyName, fromValue, toValue, duration, restoreOnEnd, surfaceIndex).AsGodotObject();

	// ─── Particles ───────────────────────────────────────────────────────────

	/// <summary>One-shot particle burst at the target's position.</summary>
	public static GodotObject Burst(Node2D target, int amount = 12, Color? color = null, float spread = 120f)
		=> InvokeRet("burst", target, amount, color ?? new Color(1f, 0.8f, 0.3f), spread).AsGodotObject();

	/// <summary>Multi-color confetti burst.</summary>
	public static GodotObject Confetti(Node2D target, int amount = 40)
		=> InvokeRet("confetti", target, amount).AsGodotObject();

	// ─── Screen FX ───────────────────────────────────────────────────────────

	/// <summary>Chromatic aberration (RGB split), full-screen.</summary>
	public static GodotObject Chromatic(Node context, float intensity = 5f, float duration = 0.2f)
		=> InvokeRet("chromatic", context, intensity, duration).AsGodotObject();

	/// <summary>Edge-darkening vignette with color tint.</summary>
	public static GodotObject Vignette(Node context, float intensity = 0.6f, float duration = 0.8f, Color? color = null)
		=> InvokeRet("vignette", context, intensity, duration, color ?? Colors.Black).AsGodotObject();

	/// <summary>Full-screen blur.</summary>
	public static GodotObject Blur(Node context, float blurAmount = 4f, float duration = 0.6f)
		=> InvokeRet("blur", context, blurAmount, duration).AsGodotObject();

	/// <summary>Digital glitch tear + chromatic split.</summary>
	public static GodotObject Glitch(Node context, float strength = 0.5f, float duration = 0.3f)
		=> InvokeRet("glitch", context, strength, duration).AsGodotObject();

	/// <summary>Colored full-screen flash (damage red, level-up gold, etc.).</summary>
	public static GodotObject ScreenTint(Node context, Color tintColor, float duration = 0.4f)
		=> InvokeRet("screen_tint", context, tintColor, duration).AsGodotObject();

	/// <summary>Smooth modulate color shift on a CanvasItem (unlike flash, which blinks).</summary>
	public static GodotObject ModulateTo(CanvasItem target, Color color, float duration = 0.4f)
		=> InvokeRet("modulate_to", target, color, duration).AsGodotObject();

	/// <summary>Spring-based jiggle on a Node2D's scale (jelly feel).</summary>
	public static GodotObject Jiggle(Node2D target, Vector2? impulse = null, float stiffness = 8f)
		=> InvokeRet("jiggle", target, impulse ?? new Vector2(0.4f, -0.4f), stiffness).AsGodotObject();

	/// <summary>Full-screen color grading shift (saturation, contrast, tint).</summary>
	public static GodotObject ColorGrade(Node context, float saturation = 0.5f, float contrast = 1.2f, Color? tint = null, float duration = 0.8f)
		=> InvokeRet("color_grade", context, saturation, contrast, tint ?? Colors.White, duration).AsGodotObject();

	/// <summary>Full-screen pixelation.</summary>
	public static GodotObject Pixelate(Node context, float pixelSize = 8f, float duration = 0.5f)
		=> InvokeRet("pixelate", context, pixelSize, duration).AsGodotObject();

	/// <summary>Light2D energy/color flash.</summary>
	public static GodotObject LightFlash(Light2D target, float peakEnergy = 3f, Color? color = null, float duration = 0.3f)
		=> InvokeRet("light_flash", target, peakEnergy, color ?? Colors.White, duration).AsGodotObject();

	/// <summary>Full-screen wipe transition (colored bar slides across).</summary>
	public static GodotObject ScreenWipe(Node context, int fromSide = 0, Color? color = null, float duration = 0.6f)
		=> InvokeRet("screen_wipe", context, fromSide, color ?? Colors.Black, duration).AsGodotObject();

	/// <summary>Expanding radial shockwave distortion ring from the context's screen position.</summary>
	public static GodotObject Shockwave(Node context, float maxRadius = 0.6f, float strength = 0.025f, float duration = 0.5f)
		=> InvokeRet("shockwave", context, maxRadius, strength, duration).AsGodotObject();

	/// <summary>Cinematic letterbox bars: slide in, hold, slide out. Returns the effect (call <c>stop</c> when holdDuration=0).</summary>
	public static GodotObject CinematicBars(Node context, float barHeight = 0.1f, float enterDuration = 0.3f, float holdDuration = 2f, float exitDuration = 0.3f)
		=> InvokeRet("cinematic_bars", context, barHeight, enterDuration, holdDuration, exitDuration).AsGodotObject();

	/// <summary>Dutch tilt - rotate Camera2D then spring back.</summary>
	public static GodotObject CameraRotation(Node context, float angleDegrees = 5f, float tiltDuration = 0.3f, float holdDuration = 0f, float returnDuration = 0.4f)
		=> InvokeRet("camera_rotation", context, angleDegrees, tiltDuration, holdDuration, returnDuration).AsGodotObject();

	/// <summary>Temporary Camera2D lerp to follow a target Node2D.</summary>
	public static GodotObject CameraFollow(Node2D target, float duration = 1.5f, float followSpeed = 5f)
		=> InvokeRet("camera_follow", target, duration, followSpeed).AsGodotObject();

	/// <summary>CRT scanline overlay.</summary>
	public static GodotObject ScanLines(Node context, float lineCount = 300f, float strength = 0.25f, float duration = 1f, float scrollSpeed = 0f)
		=> InvokeRet("scan_lines", context, lineCount, strength, duration, scrollSpeed).AsGodotObject();

	/// <summary>Anime radial speed-lines overlay (dashes, speed bursts, focus/shock moments).</summary>
	public static GodotObject SpeedLines(Node context, float strength = 0.5f, float duration = 0.4f, Color? color = null, float density = 140f)
		=> InvokeRet("speed_lines", context, strength, duration, color ?? Colors.White, density).AsGodotObject();

	/// <summary>Analog film grain overlay.</summary>
	public static GodotObject FilmGrain(Node context, float grainStrength = 0.12f, float grainSpeed = 30f, float duration = 1f)
		=> InvokeRet("film_grain", context, grainStrength, grainSpeed, duration).AsGodotObject();

	/// <summary>Radial motion blur (speed lines, warp, dash). Centres on the context when it is a Node2D, otherwise on center.</summary>
	public static GodotObject RadialBlur(Node context, float blurStrength = 0.015f, float duration = 0.4f, Vector2? center = null)
		=> InvokeRet("radial_blur", context, blurStrength, duration, center ?? new Vector2(0.5f, 0.5f)).AsGodotObject();

	/// <summary>Barrel (&gt;0) or pincushion (&lt;0) lens distortion.</summary>
	public static GodotObject LensDistortion(Node context, float strength = 0.25f, float duration = 0.5f, bool fadeOut = true)
		=> InvokeRet("lens_distortion", context, strength, duration, fadeOut).AsGodotObject();

	/// <summary>Camera3D depth-of-field blur (focus pull, cinematic transitions).</summary>
	public static GodotObject DepthOfField(Node context, float farDistance = 10f, float duration = 1f, bool blurFar = true, bool fadeOut = true, NodePath cameraPath = null)
		=> InvokeRet("depth_of_field", context, farDistance, duration, blurFar, fadeOut, cameraPath ?? new NodePath()).AsGodotObject();

	/// <summary>Directional kick shake (gun fire, punches, blast knockback).</summary>
	public static GodotObject DirectionalShake(Node context, Vector2? direction = null, float kickDistance = 12f, float duration = 0.35f)
		=> InvokeRet("directional_shake", context, direction ?? new Vector2(0, -1), kickDistance, duration).AsGodotObject();

	/// <summary>Rhythmic sine-wave camera bob (walk cycle, breathing idle).</summary>
	public static GodotObject CameraBob(Node context, Vector2? amplitude = null, float frequency = 2f, float duration = 2f)
		=> InvokeRet("camera_bob", context, amplitude ?? new Vector2(0, 3), frequency, duration).AsGodotObject();

	/// <summary>BPM-synced Camera2D zoom pulse.</summary>
	public static GodotObject ZoomPulse(Node context, float bpm = 120f, float zoomBoost = 0.08f, float duration = 4f)
		=> InvokeRet("zoom_pulse", context, bpm, zoomBoost, duration).AsGodotObject();

	// ─── Audio / Hardware ────────────────────────────────────────────────────

	/// <summary>Play a random AudioStream with pitch variance.</summary>
	public static GodotObject PlaySound(Node context, Array<AudioStream> streams, float pitchMin = 0.9f, float pitchMax = 1.1f)
		=> InvokeRet("play_sound", context, streams, pitchMin, pitchMax).AsGodotObject();

	/// <summary>Gamepad vibration.</summary>
	public static GodotObject Rumble(Node context, float weak = 0.5f, float strong = 0.5f, float duration = 0.2f, int device = 0)
		=> InvokeRet("rumble", context, weak, strong, duration, device).AsGodotObject();

	/// <summary>Spawn a temporary AudioStreamPlayer3D at the context's world position.</summary>
	public static GodotObject Audio3D(Node context, Array<AudioStream> streams, float volumeDb = 0f, float pitchMin = 0.9f, float pitchMax = 1.1f, string bus = "Master", float maxDistance = 20f)
		=> InvokeRet("audio_3d", context, streams, volumeDb, pitchMin, pitchMax, bus, maxDistance).AsGodotObject();

	/// <summary>[Experimental] Synthesize and play a retro game sound at runtime - no audio asset needed. seed 0 = one of eight random variations.</summary>
	public static GodotObject Sfx(Node context, SfxCategory category, int seed = 0, float volumeDb = 0f, float pitchMin = 1f, float pitchMax = 1f, string bus = "Master")
		=> InvokeRet("sfx", context, (int)category, seed, volumeDb, pitchMin, pitchMax, bus).AsGodotObject();

	/// <summary>Enable procedurally-synthesized sound on the built-in presets (preset_hit, preset_pickup, ...). Opt-in.</summary>
	public static void SetSfxEnabled(bool enabled)
	{
		Node s = Singleton;
		s?.Set("sfx_enabled", enabled);
	}

	// ─── Physics ─────────────────────────────────────────────────────────────

	/// <summary>Apply an impulse or force to a RigidBody2D / RigidBody3D.</summary>
	public static GodotObject AddForce(Node target, Vector2? force = null, ForceMode mode = ForceMode.Impulse, Vector3? force3D = null, float duration = 0.3f)
		=> InvokeRet("add_force", target, force ?? new Vector2(0, -300), (int)mode, force3D ?? Vector3.Zero, duration).AsGodotObject();

	// ─── Text / UI ───────────────────────────────────────────────────────────

	/// <summary>Floating damage number above a Node2D (crit support).</summary>
	public static GodotObject DamageNumber(Node2D target, int damage, bool isCrit = false)
		=> InvokeRet("damage_number", target, damage, isCrit).AsGodotObject();

	/// <summary>Generic floating text above a Node2D (Level Up!, pickup names, status).</summary>
	public static GodotObject FloatingText(Node2D target, string text, Color? textColor = null)
		=> InvokeRet("floating_text", target, text, textColor ?? Colors.White).AsGodotObject();

	/// <summary>Scale-punch a UI Control (button click, menu highlight).</summary>
	public static GodotObject ButtonPunch(Control target, float scaleFactor = 1.15f, float duration = 0.25f)
		=> InvokeRet("button_punch", target, scaleFactor, duration).AsGodotObject();

	/// <summary>Reveal a Label's text char-by-char.</summary>
	public static GodotObject Typewriter(Label target, string text, float charsPerSecond = 30f)
		=> InvokeRet("typewriter", target, text, charsPerSecond).AsGodotObject();

	/// <summary>Tween a Label's number from one value to another (score rollups).</summary>
	public static GodotObject CountTo(Label target, float fromVal, float toVal, float duration = 1f, string numberFormat = "%d", string prefix = "", string suffix = "")
		=> InvokeRet("count_to", target, fromVal, toVal, duration, numberFormat, prefix, suffix).AsGodotObject();

	/// <summary>Sine-wave wobble on a Control with decay (GAME OVER, BOSS APPROACHING).</summary>
	public static GodotObject TextWobble(Control target, float amplitude = 4f, float duration = 0.5f)
		=> InvokeRet("text_wobble", target, amplitude, duration).AsGodotObject();

	// ─── WorldEnvironment ────────────────────────────────────────────────────

	/// <summary>Pulse the active WorldEnvironment glow (bloom).</summary>
	public static GodotObject Bloom(Node context, float intensityBoost = 1.5f, float duration = 0.6f)
		=> InvokeRet("bloom", context, intensityBoost, duration).AsGodotObject();

	/// <summary>Punch the active WorldEnvironment tonemap exposure (flashbang).</summary>
	public static GodotObject TonemapPunch(Node context, float exposureBoost = 3f, float duration = 0.4f)
		=> InvokeRet("tonemap_punch", context, exposureBoost, duration).AsGodotObject();

	// ─── Spring physics ──────────────────────────────────────────────────────

	/// <summary>Spring-bounce a Vector2 property on the target (universal animator).</summary>
	public static GodotObject Spring(Node target, string propertyName, Vector2 kick, float stiffness = 200f, float damping = 10f)
		=> InvokeRet("spring", target, propertyName, kick, stiffness, damping).AsGodotObject();

	// ─── Audio bus FX ────────────────────────────────────────────────────────

	/// <summary>Temporarily add reverb to an audio bus.</summary>
	public static GodotObject Reverb(Node context, string bus = "Master", float peakWet = 0.45f, float duration = 1.5f)
		=> InvokeRet("reverb", context, bus, peakWet, duration).AsGodotObject();

	/// <summary>Temporarily pitch-shift an audio bus (slow-mo audio, underwater).</summary>
	public static GodotObject PitchShift(Node context, float targetPitch = 0.7f, string bus = "Master", float duration = 1f)
		=> InvokeRet("pitch_shift", context, targetPitch, bus, duration).AsGodotObject();

	/// <summary>Temporarily low-pass ("muffle") an audio bus (muffled-on-hit, underwater, stunned).</summary>
	public static GodotObject LowPass(Node context, float targetCutoff = 500f, string bus = "Master", float duration = 0.6f)
		=> InvokeRet("low_pass", context, targetCutoff, bus, duration).AsGodotObject();

	/// <summary>Ramp a temporary distortion on an audio bus (blown speakers, radio, damage).</summary>
	public static GodotObject Distortion(Node context, string busName = "Master", float peakDrive = 0.5f, float duration = 0.8f)
		=> InvokeRet("distortion", context, busName, peakDrive, duration).AsGodotObject();

	/// <summary>A rapid burst of micro-freezes (machine-gun hit-stop) for hit flurries / glitches.</summary>
	public static GodotObject Stutter(Node context, int count = 5, float freezeTime = 0.03f, float gapTime = 0.03f)
		=> InvokeRet("stutter", context, count, freezeTime, gapTime).AsGodotObject();

	/// <summary>Shove a RigidBody2D along a direction (a hit reaction).</summary>
	public static GodotObject Knockback(Node2D body, Vector2? direction = null, float force = 400f)
		=> InvokeRet("knockback", body, direction ?? Vector2.Right, force).AsGodotObject();

	/// <summary>Reveal a Label's text by locking in scrambling characters (decode / hacker effect).</summary>
	public static GodotObject TextScramble(Label label, string text = "", float duration = 0.8f)
		=> InvokeRet("text_scramble", label, text, duration).AsGodotObject();

	// ─── Composition ─────────────────────────────────────────────────────────

	/// <summary>Trigger an AnimationPlayer animation as a sequence step.</summary>
	public static GodotObject AnimationPlayer(Node context, NodePath playerPath, string animationName, float speed = 1f, bool waitForFinish = true)
		=> InvokeRet("animation_player", context, playerPath, animationName, speed, waitForFinish).AsGodotObject();

	/// <summary>Show/hide a node for N seconds then restore.</summary>
	public static GodotObject SetActive(Node context, NodePath targetPath, float duration = 0.5f, SetActiveAction action = SetActiveAction.Show)
		=> InvokeRet("set_active", context, targetPath, duration, (int)action).AsGodotObject();

	/// <summary>Repeating modulate flash for sustained danger states (siren, low-health).</summary>
	public static GodotObject AmbientFlash(CanvasItem target, Color? flashColor = null, float duration = 3f, float frequency = 1.5f)
		=> InvokeRet("ambient_flash", target, flashColor ?? new Color(1f, 0.2f, 0.2f, 0.5f), duration, frequency).AsGodotObject();

	/// <summary>Square-wave strobe a Light2D (lightning, flashbang, siren).</summary>
	public static GodotObject StrobeLight(Light2D target, int pulseCount = 6, float duration = 0.5f, float peakEnergy = 3f)
		=> InvokeRet("strobe_light", target, pulseCount, duration, peakEnergy).AsGodotObject();

	/// <summary>Directional position kick (gun recoil, absorbing a hit).</summary>
	public static GodotObject Recoil(Node2D target, Vector2? direction = null, float kickDistance = 12f, float returnDuration = 0.18f)
		=> InvokeRet("recoil", target, direction ?? new Vector2(-1, 0), kickDistance, returnDuration).AsGodotObject();

	/// <summary>Animate a colored outline on a CanvasItem (selection ring, status glow).</summary>
	public static GodotObject Outline(CanvasItem target, Color? outlineColor = null, float outlineWidth = 2f, float duration = 0.8f)
		=> InvokeRet("outline", target, outlineColor ?? new Color(1f, 0.85f, 0.2f, 1f), outlineWidth, duration).AsGodotObject();

	/// <summary>Cycle a CanvasItem's modulate through the hue wheel (rainbow, party mode). <paramref name="loop"/>=true runs until <c>stop</c> (RAINBOW MODE).</summary>
	public static GodotObject ColorCycle(CanvasItem target, float cycles = 2f, float duration = 1.5f, float saturation = 1f, bool loop = false)
		=> InvokeRet("color_cycle", target, cycles, duration, saturation, loop).AsGodotObject();

	/// <summary>Expanding impact ring + radiating spikes drawn at a Node2D (crit / explosion "POW"). No shaders.</summary>
	public static GodotObject ImpactRing(Node2D target, Color? color = null, int spikes = 8, float radius = 42f)
		=> InvokeRet("impact_ring", target, color ?? new Color(1f, 0.85f, 0.3f), spikes, radius).AsGodotObject();

	/// <summary>Gentle continuous rotation sway (pendulum). <paramref name="cycles"/>=0 sways forever (until <c>stop</c>).</summary>
	public static GodotObject Sway(Node target, float angle = 6f, float period = 1.2f, float cycles = 0f)
		=> InvokeRet("sway", target, angle, period, cycles).AsGodotObject();

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

	/// <summary>Boss entrance: zoom + vignette + shake + rumble + ominous tint. The vignette and tint stay on until the context is freed.</summary>
	public static void PresetBossIntro(Node context)
		=> Invoke("preset_boss_intro", context);

	/// <summary>Low-health loop: repeating red ambient flash. Returns the effect; call <c>stop</c> to end it.</summary>
	public static GodotObject PresetLowHealthPulse(CanvasItem target, float duration = 10f)
		=> InvokeRet("preset_low_health_pulse", target, duration).AsGodotObject();

	/// <summary>Victory: confetti + zoom + color cycle + warm tint + fanfare rumble.</summary>
	public static void PresetVictory(Node context)
		=> Invoke("preset_victory", context);

	// ─── Flow / Sequencing ───────────────────────────────────────────────────

	/// <summary>Runs a list of effects in sequence (or, with parallel, all at once). Wraps JuiceeChainEffect.</summary>
	public static GodotObject Chain(Node context, Array<Resource> chainEffects, bool parallel = false, float stepDelay = 0f)
		=> InvokeRet("chain", context, chainEffects, parallel, stepDelay).AsGodotObject();

	/// <summary>Pause a sequence until the player presses an action (timeout 0 = wait forever).</summary>
	public static GodotObject WaitForInput(Node context, string action = "ui_accept", float timeout = 0f)
		=> InvokeRet("wait_for_input", context, action, timeout).AsGodotObject();

	/// <summary>Fire a child JuiceeEffect resource synced to a BPM beat.</summary>
	public static GodotObject BeatSync(Node context, Resource childEffect, float bpm = 120f, float duration = 8f, int beatsPerTrigger = 1, NodePath clockPath = null)
		=> InvokeRet("beat_sync", context, childEffect, bpm, duration, beatsPerTrigger, clockPath ?? new NodePath()).AsGodotObject();

	/// <summary>Emit a signal by name on the context node.</summary>
	public static GodotObject EmitSignalOn(Node context, string signalName, Variant argument = default)
		=> InvokeRet("emit_signal_on", context, signalName, argument).AsGodotObject();

	/// <summary>Print / warn / error a message from a sequence step.</summary>
	public static GodotObject DebugLog(Node context, string message, LogLevel level = LogLevel.Print)
		=> InvokeRet("debug_log", context, message, (int)level).AsGodotObject();

	/// <summary>Travel to an AnimationTree state, or set a tree parameter.</summary>
	public static GodotObject AnimationTreeTravel(Node context, string stateOrParam, AnimTreeMode mode = AnimTreeMode.Travel, Variant? value = null, NodePath treePath = null)
		=> InvokeRet("animation_tree_travel", context, stateOrParam, (int)mode, value ?? Variant.From(true), treePath ?? new NodePath()).AsGodotObject();

	/// <summary>Instantly set any property; restoreDelay &lt;0 never restores, 0 immediate, &gt;0 after delay.</summary>
	public static GodotObject SetProperty(Node context, string propertyName, Variant value, float restoreDelay = -1f, NodePath targetPath = null)
		=> InvokeRet("set_property", context, propertyName, value, restoreDelay, targetPath ?? new NodePath()).AsGodotObject();

	/// <summary>Hop: a quick jump arc up and back down (pickups, coins, an idle "notice me").</summary>
	public static GodotObject Hop(Node2D target, float height = 24f, float duration = 0.4f)
		=> InvokeRet("hop", target, height, duration).AsGodotObject();

	/// <summary>Landing squash: flatten on impact, then spring back (platformer landings, jelly hops).</summary>
	public static GodotObject SquashLand(Node2D target, float squashAmount = 0.4f, float duration = 0.35f, float bounceBack = 0.5f)
		=> InvokeRet("squash_land", target, squashAmount, duration, bounceBack).AsGodotObject();

	/// <summary>Springy squash-stretch scale oscillation that decays (slimes, gel, bouncy UI).</summary>
	public static GodotObject JellyWobble(Node2D target, float amount = 0.25f, float frequency = 4f, float duration = 0.6f, float decay = 3f)
		=> InvokeRet("jelly_wobble", target, amount, frequency, duration, decay).AsGodotObject();

	/// <summary>Stretch/smear along a direction, then snap back (dashes, jumps, thrown objects).</summary>
	public static GodotObject Stretch(Node2D target, Vector2? direction = null, float amount = 0.5f)
		=> InvokeRet("stretch", target, direction ?? Vector2.Right, amount).AsGodotObject();

	/// <summary>Fading ghost copies left behind as a Sprite2D or AnimatedSprite2D moves (dashes, dodges, jumps).</summary>
	public static GodotObject Trail(Node2D target, float duration = 0.6f, int maxGhosts = 8)
		=> InvokeRet("trail", target, duration, maxGhosts).AsGodotObject();

	/// <summary>Scatter of little star pops around the target (pickups, level-ups, UI shine).</summary>
	public static GodotObject Sparkle(Node2D target, int count = 6, float spread = 36f, float starScale = 1f)
		=> InvokeRet("sparkle", target, count, spread, starScale).AsGodotObject();

	/// <summary>Fading copies left behind as the node moves: dashes, dodges, fast attacks.</summary>
	public static GodotObject Afterimage(Node2D target, float duration = 0.3f, float ghostLifetime = 0.35f)
		=> InvokeRet("afterimage", target, duration, ghostLifetime).AsGodotObject();

	/// <summary>Slow idle swell, for a character standing still.</summary>
	public static GodotObject Breathe(Node2D target, float amount = 0.05f, float period = 2f, int cycles = 3)
		=> InvokeRet("breathe", target, amount, period, cycles).AsGodotObject();

	/// <summary>Two-beat pulse at a heart rate: low health, tension, a charging attack.</summary>
	public static GodotObject Heartbeat(Node2D target, float amount = 0.18f, float bpm = 70f, float duration = 2f)
		=> InvokeRet("heartbeat", target, amount, bpm, duration).AsGodotObject();

	/// <summary>Pulse a CanvasItem brighter and back.</summary>
	public static GodotObject GlowPulse(CanvasItem target, float peak = 1.8f, float duration = 0.5f, int count = 1)
		=> InvokeRet("glow_pulse", target, peak, duration, count).AsGodotObject();

	/// <summary>Rotation wobble that decays, like a sign left swinging.</summary>
	public static GodotObject WobbleRotation(Node2D target, float amountDegrees = 18f, float frequency = 5f, float duration = 0.6f)
		=> InvokeRet("wobble_rotation", target, amountDegrees, frequency, duration).AsGodotObject();

	/// <summary>Directional spark spray off a hit point.</summary>
	public static GodotObject HitSpark(Node2D target, Vector2 direction, int amount = 10, float speed = 420f)
		=> InvokeRet("hit_spark", target, direction, amount, speed).AsGodotObject();

	/// <summary>Crescent melee swoosh through the node.</summary>
	public static GodotObject SlashArc(Node2D target, float angleDegrees = 0f, float radius = 60f, float arcDegrees = 140f)
		=> InvokeRet("slash_arc", target, angleDegrees, radius, arcDegrees).AsGodotObject();

	/// <summary>Jagged fracture lines radiating from the node.</summary>
	public static GodotObject Crack(Node2D target, int count = 5, float length = 70f, float thickness = 5f)
		=> InvokeRet("crack", target, count, length, thickness).AsGodotObject();

	/// <summary>One push on a RigidBody2D.</summary>
	public static GodotObject Impulse(Node body, Vector2 impulseForce, float randomConeDegrees = 0f)
		=> InvokeRet("impulse", body, impulseForce, randomConeDegrees).AsGodotObject();

	/// <summary>Push every RigidBody2D around the origin away from it.</summary>
	public static GodotObject ExplosionPush(Node2D origin, float radius = 200f, float force = 600f)
		=> InvokeRet("explosion_push", origin, radius, force).AsGodotObject();

	/// <summary>Change a RigidBody2D's gravity for a while.</summary>
	public static GodotObject GravityShift(Node body, float gravityScale = 0f, float duration = 1f)
		=> InvokeRet("gravity_shift", body, gravityScale, duration).AsGodotObject();

	/// <summary>Wave, shake, rainbow or tornado on a RichTextLabel.</summary>
	public static GodotObject RichTextEmphasis(Node label, int mode = 0, string phrase = "", float duration = 1.5f)
		=> InvokeRet("rich_text_emphasis", label, mode, phrase, duration).AsGodotObject();

	/// <summary>Duck a bus while something louder happens, then bring it back.</summary>
	public static GodotObject MusicDuck(Node context, string bus = "Master", float duckDb = -15f, float hold = 1f)
		=> InvokeRet("music_duck", context, bus, duckDb, hold).AsGodotObject();

	/// <summary>Wobble a bus's volume: a damage hum, a dying engine.</summary>
	public static GodotObject Tremolo(Node context, string bus = "Master", float depthDb = -12f, float rate = 6f)
		=> InvokeRet("tremolo", context, bus, depthDb, rate).AsGodotObject();

	/// <summary>Punch a Camera3D's field of view and let it come back.</summary>
	public static GodotObject FovPunch(Node context, float fovDelta = 10f, float duration = 0.4f)
		=> InvokeRet("fov_punch", context, fovDelta, duration).AsGodotObject();

	/// <summary>Tween any property on any node.</summary>
	public static GodotObject TweenProperty(Node target, string property, Variant toValue, float duration = 0.5f)
		=> InvokeRet("tween_property", target, property, toValue, duration).AsGodotObject();

	/// <summary>Compile every screen shader now instead of on the frame of the first effect that uses one.
	/// Returns at once and does the work over the next four frames, so call it from a loading screen and
	/// give it those frames before gameplay starts. Safe to call more than once.</summary>
	public static void Warmup() => Invoke("warmup");

	/// <summary>True once <see cref="Warmup"/> has been called, which is not the same as finished: the
	/// compiling takes the four frames after the call.</summary>
	public static bool IsWarmedUp() => InvokeRet("is_warmed_up").AsBool();
}
