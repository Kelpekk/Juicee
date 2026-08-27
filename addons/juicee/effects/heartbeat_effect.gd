## Heartbeat: a quick double scale pop (lub-dub) per beat, the tension throb of a
## low-health warning, a ticking bomb, or a "this matters" pulse on UI.
@tool
class_name JuiceeHeartbeatEffect
extends JuiceeEffect

## Scale-up of the first (big) pop. The second pop is smaller.
@export_range(0.05, 0.6, 0.01) var amount: float = 0.18
## Beats per minute.
@export_range(20.0, 200.0, 1.0) var bpm: float = 70.0
## Total time. 0 = a single beat.
@export_range(0.0, 30.0, 0.1) var duration: float = 2.0

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "A double scale pop (lub-dub) per beat.\nLow-health tension, ticking bombs, urgent UI."

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		push_warning("JuiceeHeartbeatEffect: context is not a Node2D")
		return

	var original: Vector2 = _capture_state(target, "scale")
	var amt: float = amount * intensity_mult
	var beat := 60.0 / bpm
	var tree := target.get_tree()
	var elapsed := 0.0
	var total: float = duration if duration > 0.0 else beat
	while elapsed < total and is_instance_valid(target) and not _cancelled:
		var t := _track(target.create_tween())
		t.tween_property(target, "scale", original * (1.0 + amt), beat * 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(target, "scale", original, beat * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(target, "scale", original * (1.0 + amt * 0.55), beat * 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(target, "scale", original, beat * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tree.create_timer(beat, true, false, false).timeout
		elapsed += beat
	_release_state(target, "scale")
