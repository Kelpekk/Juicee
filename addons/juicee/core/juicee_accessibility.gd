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
## zero per-effect code required. The intensity_multiplier scales shake/wobble
## to a barely perceptible level rather than zero so the game still feels alive.
extends RefCounted
class_name JuiceeAccessibility

## Master switch - silently halves ALL effect intensities (everything feels
## a bit calmer without removing the juice entirely).
var reduced_motion: bool = false:
	set(v):
		reduced_motion = v
		changed.emit()

## Disables all flash, strobe, and AmbientFlash effects entirely.
## Recommended for players with photosensitive epilepsy.
var no_flash: bool = false:
	set(v):
		no_flash = v
		changed.emit()

## Disables camera shake and rotation punch effects.
## Useful for players prone to motion sickness.
var no_screenshake: bool = false:
	set(v):
		no_screenshake = v
		changed.emit()

## Disables all full-screen chromatic aberration, glitch, and pixelate effects.
var no_chromatic: bool = false:
	set(v):
		no_chromatic = v
		changed.emit()

## Overall intensity multiplier for effects that are still allowed.
## Automatically set to 0.25 when [member reduced_motion] is true,
## but can be overridden for finer control (0.0 = silent, 1.0 = full).
var intensity_scale: float = 1.0:
	set(v):
		intensity_scale = clampf(v, 0.0, 1.0)
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
		"intensity_scale": intensity_scale,
	}

func from_dict(d: Dictionary) -> void:
	reduced_motion  = d.get("reduced_motion",  false)
	no_flash        = d.get("no_flash",        false)
	no_screenshake  = d.get("no_screenshake",  false)
	no_chromatic    = d.get("no_chromatic",    false)
	intensity_scale = d.get("intensity_scale", 1.0)

# --- Internal API used by JuiceeEffect ----------------------------------------

## Returns true if the effect type is allowed under current settings.
## Pass one of the TAG_* constants below.
func is_allowed(tag: int) -> bool:
	match tag:
		TAG_FLASH:      return not no_flash
		TAG_SCREENSHAKE: return not no_screenshake
		TAG_CHROMATIC:  return not no_chromatic
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

## Particle-density multiplier for effects that spawn a lot of nodes (sparks,
## sparkles, confetti). There's no quality/LOD tier here yet, so this returns 1.0
## (full density); it's the hook a future "spawn fewer particles on weak hardware"
## setting would drive, letting those effects thin out without touching their code.
func density_scale() -> float:
	return 1.0

# --- Tag constants - assigned to effects via get_accessibility_tag() ----------

const TAG_NONE       := 0   # No accessibility concern (audio, time, flow, etc.)
const TAG_FLASH      := 1   # Flash, StrobeLight, AmbientFlash, ScreenTint bright
const TAG_SCREENSHAKE := 2  # Shake, Shake3D, Recoil, PositionEffect
const TAG_CHROMATIC  := 3   # Chromatic, Glitch, ColorGrade desaturate
const TAG_MOTION     := 4   # Blur, Pixelate, Vignette, Zoom (caught by reduced_motion)
