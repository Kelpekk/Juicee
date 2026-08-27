## Single-frame time freeze with optional bright full-screen flash.
##
## Distinguished from HitStop: FreezeFrame is a VISUAL BEAT - a distinct
## flash + hold that telegraphs a decisive moment (finishing blow, super move
## activation, critical hit). HitStop is tactile micro-pause feedback.
##
## Use for: fighting-game super flash, finishing blow, sniper headshot,
## "you win" moment, combo finalizer, screen clear.
@tool
class_name JuiceeFreezeFrameEffect
extends JuiceeEffect

## Freeze duration in real-time seconds (ignores Engine.time_scale).
@export_range(0.01, 0.5, 0.005) var duration: float = 0.06
## Flash color shown during the freeze. White = classic fighting game super.
@export var flash_color: Color = Color(1.0, 1.0, 1.0, 0.9)
## Show the full-screen flash overlay. Disable for a pure time-freeze without visual.
@export var use_flash: bool = true
## Seconds for the flash to fade out AFTER time resumes.
@export_range(0.02, 0.5, 0.01) var flash_fade: float = 0.08

const LAYER_NAME := &"_juicee_freeze_frame_flash"

func get_category_name() -> String: return "Time"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var tree := context.get_tree()
	var eff_dur := duration * intensity_mult

	# Full-screen flash overlay.
	var layer: CanvasLayer = null
	var rect: ColorRect = null
	if use_flash:
		var result := _spawn_screen_solid_overlay(context, LAYER_NAME, 250)
		if not result.is_empty():
			layer = result[0]
			rect = result[1]
			rect.color = flash_color

	# Freeze Engine.time_scale. Ref-counted via JuiceeStateStack so overlapping
	# freezes / hit-stops don't restore each other's frozen value - capturing into
	# a plain local would let a second freeze record the already-frozen 0.0 and
	# restore to that, leaving time_scale permanently stuck at 0 (game frozen).
	_capture_state(Engine, "time_scale")
	Engine.time_scale = 0.0

	# Wait using real-time (ignore_time_scale=true so it fires despite time_scale=0).
	await tree.create_timer(eff_dur, true, false, true).timeout

	_release_state(Engine, "time_scale")

	if _cancelled:
		if is_instance_valid(layer):
			layer.queue_free()
		return

	# Fade the flash out now that time has resumed.
	if use_flash and is_instance_valid(rect):
		var fade := rect.create_tween()
		fade.tween_property(rect, "color:a", 0.0, flash_fade)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await fade.finished

	if is_instance_valid(layer):
		layer.queue_free()
