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

@export_group("Advanced")
## Colour the node pulses toward on each beat (its alpha is the strength). Transparent =
## no tint. A deep red here turns it into a proper low-health throb.
@export var color_pulse: Color = Color(1.0, 0.2, 0.2, 0.0)
## Size of the second (dub) pop relative to the first. 0.55 = a bit over half.
@export_range(0.1, 1.0, 0.05) var second_ratio: float = 0.55

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["color_pulse", "second_ratio"]))

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "A double scale pop (lub-dub) per beat.\nLow-health tension, ticking bombs, urgent UI."

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		_warn("JuiceeHeartbeatEffect: context is not a Node2D")
		return

	var play := _gen
	var original: Vector2 = _capture_state(target, "scale")
	var tinting := color_pulse.a > 0.0
	var orig_mod: Color = _capture_state(target, "modulate") if tinting else Color.WHITE
	var tint := orig_mod.lerp(color_pulse, color_pulse.a)
	tint.a = orig_mod.a
	var amt: float = amount * intensity_mult
	var beat := 60.0 / bpm
	var tree := target.get_tree()
	var elapsed := 0.0
	var total: float = duration if duration > 0.0 else beat
	while elapsed < total and is_instance_valid(target) and _gen == play:
		var t := _track(target.create_tween())
		t.tween_property(target, "scale", original * (1.0 + amt), beat * 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(target, "scale", original, beat * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(target, "scale", original * (1.0 + amt * second_ratio), beat * 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(target, "scale", original, beat * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Advanced: a colour throb in sync with the two pops.
		if tinting:
			var ct := _track(target.create_tween())
			ct.tween_property(target, "modulate", tint, beat * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			ct.tween_property(target, "modulate", orig_mod, beat * 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		elapsed += await _wait_step(tree, beat)
	# A newer play or stop() holds these now; releasing here would take them from it.
	if _gen != play:
		return
	_release_state(target, "scale")
	if tinting:
		_release_state(target, "modulate")
