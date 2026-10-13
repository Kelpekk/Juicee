## Rhythmic Camera2D zoom pulse at a given BPM.
##
## Each beat: camera snaps to a slightly higher zoom level then eases back.
## Use for: beat-synced music visualization, bass-drop impact, heartbeat tension,
## rhythm-game countdown, boss arena pulse.
@tool
class_name JuiceeZoomPulseEffect
extends JuiceeEffect

## Beats per minute - controls how often the zoom pulse fires.
@export_range(20.0, 300.0, 1.0) var bpm: float = 120.0
## Zoom overshoot per beat (fraction). 0.08 = 8% zoom-in per pulse.
@export_range(0.005, 0.5, 0.005) var pulse_amount: float = 0.08
## Total duration in seconds (0 = one beat only).
@export_range(0.0, 60.0, 0.5) var duration: float = 4.0

@export_group("Advanced")
## Pulse OUT (zoom away) on each beat instead of in. A punch-out reads as a bass drop.
@export var invert: bool = false
## Fraction of each beat spent zooming in. 0.15 = a sharp punch; 0.5 = a smooth breath.
@export_range(0.05, 0.9, 0.05) var attack_ratio: float = 0.15
## Every Nth beat pulses harder by this multiplier, so a bar lands with an accent.
## 1 = every beat identical.
@export_range(1, 8, 1) var accent_every: int = 1
## How much stronger an accented beat is.
@export_range(1.0, 4.0, 0.1) var accent_multiplier: float = 1.8

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["invert", "attack_ratio", "accent_every", "accent_multiplier"]))

func get_category_name() -> String: return "Camera"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	var cam: Camera2D = context.get_viewport().get_camera_2d()
	if not cam:
		_warn("JuiceeZoomPulseEffect: no Camera2D in viewport")
		return

	var original_zoom: Vector2 = _capture_state(cam, "zoom")
	var beat_interval := 60.0 / bpm
	var elapsed := 0.0
	var tree := context.get_tree()
	var eff_pulse := pulse_amount * intensity_mult
	var total_dur := duration if duration > 0.0 else beat_interval

	var beat_index := 0
	while elapsed < total_dur and is_instance_valid(cam) and _gen == play:
		# Accent every Nth beat so a bar lands harder than its off-beats.
		var accent: float = accent_multiplier if (accent_every > 1 and beat_index % accent_every == 0) else 1.0
		# invert punches the zoom out instead of in (a bass-drop pull-back).
		var amount: float = eff_pulse * accent * (-1.0 if invert else 1.0)
		var zoom_in := _track(cam.create_tween())
		zoom_in.tween_property(cam, "zoom", _camera_zoom(original_zoom * (1.0 + amount)), beat_interval * attack_ratio)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		zoom_in.tween_property(cam, "zoom", original_zoom, beat_interval * (1.0 - attack_ratio))\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
		elapsed += await _wait_step(tree, beat_interval)
		if _gen != play:
			return
		beat_index += 1

	# A newer play or stop() holds what this one held.
	if _gen != play:
		return
	_release_state(cam, "zoom")
