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

func get_category_name() -> String: return "Camera"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	var cam: Camera2D = context.get_viewport().get_camera_2d()
	if not cam:
		push_warning("JuiceeZoomPulseEffect: no Camera2D in viewport")
		return

	var original_zoom: Vector2 = _capture_state(cam, "zoom")
	var beat_interval := 60.0 / bpm
	var elapsed := 0.0
	var tree := context.get_tree()
	var eff_pulse := pulse_amount * intensity_mult
	var total_dur := duration if duration > 0.0 else beat_interval

	while elapsed < total_dur and is_instance_valid(cam) and not _cancelled:
		# Quick zoom-in (15% of beat), decay back (85%).
		var zoom_in := _track(cam.create_tween())
		zoom_in.tween_property(cam, "zoom", original_zoom * (1.0 + eff_pulse), beat_interval * 0.15)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		zoom_in.tween_property(cam, "zoom", original_zoom, beat_interval * 0.85)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
		await tree.create_timer(beat_interval, true, false, false).timeout
		elapsed += beat_interval

	_release_state(cam, "zoom")
