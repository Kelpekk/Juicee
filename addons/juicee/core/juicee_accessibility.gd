## Juicee Accessibility layer - global motion/flash reduction for players
## who are sensitive to screen shake, bright flashes, or strobing.
##
## Attach to the Juicee autoload (already done via JuiceeEffect.is_allowed())
## or configure in your settings screen:
## [codeblock]
## # In your accessibility settings UI:
## Juicee.accessibility.reduced_motion = true
## Juicee.accessibility.no_flash       = true
## Juicee.accessibility.no_screenshake = true
## [/codeblock]
##
## All JuiceeEffect subclasses query [method is_allowed] before applying -
## zero per-effect code required. Reduced motion scales effects down to a quarter
## rather than to zero, so the game still feels alive.
extends RefCounted
class_name JuiceeAccessibility

## How much the particle-heavy effects are allowed to spawn. LOW is for phones and for the
## players who turn the setting down themselves.
enum Quality { LOW, MEDIUM, HIGH }

## Master switch: effects play at a quarter of their strength (everything feels calmer
## without removing the juice entirely). Durations do not change, and effects with no
## strength to scale (Flip, Instantiate, the Flow steps and similar) play as usual.
var reduced_motion: bool = false:
	set(v):
		reduced_motion = v
		changed.emit()

## Disables Flash, Strobe Light, Flicker, Glow Pulse, Ambient Flash and Screen Tint.
## Recommended for players with photosensitive epilepsy.
var no_flash: bool = false:
	set(v):
		no_flash = v
		changed.emit()

## Disables Shake, Shake 3D, Directional Shake, Recoil, Camera Bob, Camera Rotation,
## Wobble Rotation and Lens Distortion.
## Useful for players prone to motion sickness.
var no_screenshake: bool = false:
	set(v):
		no_screenshake = v
		changed.emit()

## Disables Chromatic and Glitch.
var no_chromatic: bool = false:
	set(v):
		no_chromatic = v
		changed.emit()

## Disables gamepad and handheld vibration entirely.
## Every other category here had a switch and this one did not, which left players
## who need vibration off with no way to turn it off.
var no_haptics: bool = false:
	set(v):
		no_haptics = v
		changed.emit()

## Overall intensity multiplier for effects that are still allowed.
## Automatically set to 0.25 when [member reduced_motion] is true,
## but can be overridden for finer control (0.0 = silent, 1.0 = full).
var intensity_scale: float = 1.0:
	set(v):
		# clampf() lets NaN through, and NaN here would reach every effect's strength.
		if not is_finite(v):
			push_warning("JuiceeAccessibility: intensity_scale %s is not a number from 0 to 1, so it stays %s" % [v, intensity_scale])
			return
		intensity_scale = clampf(v, 0.0, 1.0)
		changed.emit()

## Quality tier for the effects that spawn a lot of particles: Burst, Confetti, Hit Spark and
## Sparkle thin out on the lower ones. Nothing else changes, so the same play still happens.
var quality: Quality = Quality.HIGH:
	set(v):
		quality = clampi(v, Quality.LOW, Quality.HIGH) as Quality
		changed.emit()

## Emitted whenever any accessibility flag changes.
## Connect in your HUD/debug-overlay to update tooltips or icons.
signal changed

## Convenience: load/save to a plain Dictionary (for your game's save system).
func to_dict() -> Dictionary:
	return {
		"reduced_motion": reduced_motion,
		"no_flash":       no_flash,
		"no_screenshake": no_screenshake,
		"no_chromatic":   no_chromatic,
		"no_haptics":     no_haptics,
		"intensity_scale": intensity_scale,
		"quality":        quality,
	}

## Takes back what to_dict() gave. A value of the wrong kind, which a save file edited by hand or
## written by another version can hold, falls back to the default rather than stopping the load.
func from_dict(d: Dictionary) -> void:
	reduced_motion  = _flag(d.get("reduced_motion"))
	no_flash        = _flag(d.get("no_flash"))
	no_screenshake  = _flag(d.get("no_screenshake"))
	no_chromatic    = _flag(d.get("no_chromatic"))
	no_haptics      = _flag(d.get("no_haptics"))
	var scale: Variant = d.get("intensity_scale", 1.0)
	intensity_scale = float(scale) if typeof(scale) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(scale)) else 1.0
	var tier: Variant = d.get("quality", Quality.HIGH)
	quality = (int(tier) as Quality) if typeof(tier) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(tier)) else Quality.HIGH

static func _flag(v: Variant) -> bool:
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return float(v) != 0.0
	return false

# --- Internal API used by JuiceeEffect ----------------------------------------

## Returns true if the effect type is allowed under current settings.
## Pass one of the TAG_* constants below.
func is_allowed(tag: int) -> bool:
	match tag:
		TAG_FLASH:      return not no_flash
		TAG_SCREENSHAKE: return not no_screenshake
		TAG_CHROMATIC:  return not no_chromatic
		TAG_HAPTIC:     return not no_haptics
		_:              return true

## Returns the effective intensity multiplier for this effect type.
## Already accounts for [member reduced_motion] and [member intensity_scale].
func effective_multiplier(tag: int) -> float:
	if not is_allowed(tag):
		return 0.0
	var base := intensity_scale
	if reduced_motion:
		base *= 0.25
	return base

## Particle-density multiplier for the effects that spawn a lot of nodes. LOW spawns four in
## ten, MEDIUM seven; the effect still plays, with fewer pieces in it.
func density_scale() -> float:
	match quality:
		Quality.LOW:
			return 0.4
		Quality.MEDIUM:
			return 0.7
		_:
			return 1.0

# --- Tag constants - assigned to effects via get_accessibility_tag() ----------

const TAG_NONE       := 0   # No accessibility concern (audio, time, flow, etc.)
const TAG_FLASH      := 1   # Flash, StrobeLight, AmbientFlash, Flicker, GlowPulse, ScreenTint
const TAG_SCREENSHAKE := 2  # Shake, Shake3D, DirectionalShake, Recoil, CameraBob, CameraRotation, WobbleRotation, LensDistortion
const TAG_CHROMATIC  := 3   # Chromatic, Glitch
const TAG_MOTION     := 4   # CinematicBars. No switch of its own; reduced_motion scales it like everything else
const TAG_HAPTIC     := 5   # Rumble, and anything else that reaches the player physically
