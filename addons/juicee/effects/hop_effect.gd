## Hop: a quick upward jump arc and back down, a happy little bounce for pickups,
## button presses, a coin, or an idle "notice me".
@tool
class_name JuiceeHopEffect
extends JuiceeEffect

## How high it hops, in pixels.
@export_range(2.0, 200.0, 1.0) var height: float = 24.0
## Total up + down time.
@export_range(0.1, 2.0, 0.05) var duration: float = 0.4

@export_group("Advanced")
## Squash and stretch through the hop: stretches tall rising, flattens on landing.
## 0 = pure position hop. This is what makes a hop read as juicy.
@export_range(0.0, 0.8, 0.05) var squash: float = 0.0
## Number of hops, each lower and quicker than the last (a ball settling). 1 = one hop.
@export_range(1, 8, 1) var hops: int = 1

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["squash", "hops"]))

func get_category_name() -> String:
	return "Object"

func get_description() -> String:
	return "A quick upward jump arc and back down.\nPickups, coins, button presses, idle notice."

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		_warn("JuiceeHopEffect: context is not a Node2D")
		return

	var original: Vector2 = _capture_state(target, "position")
	var use_squash := squash > 0.0
	var original_scale: Vector2 = _capture_state(target, "scale") if use_squash else Vector2.ONE
	var stretch_scale := original_scale * Vector2(1.0 - squash * 0.35, 1.0 + squash * 0.5)
	var squash_scale := original_scale * Vector2(1.0 + squash * 0.5, 1.0 - squash * 0.35)

	var tween := _track(target.create_tween())
	var h: float = _px(height) * intensity_mult
	var d: float = duration
	# Each hop is lower and quicker; a single hop (default) is the classic arc.
	for i in _capped(maxi(1, hops), 1000, "hops"):
		var top := original - Vector2(0, h)
		# Up fast (decelerate), down a touch slower (accelerate) for a natural arc.
		tween.tween_property(target, "position", top, d * 0.45)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if use_squash:
			tween.parallel().tween_property(target, "scale", stretch_scale, d * 0.45)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(target, "position", original, d * 0.55)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if use_squash:
			tween.parallel().tween_property(target, "scale", squash_scale, d * 0.55)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		h *= 0.55
		d *= 0.82
	if use_squash:
		tween.tween_property(target, "scale", original_scale, 0.12)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	if _gen != play:
		return
	_release_state(target, "position")
	if use_squash:
		_release_state(target, "scale")
