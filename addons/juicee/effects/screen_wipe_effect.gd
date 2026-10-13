## Screen wipe transition - colored bar slides across the screen.
## Great for scene transitions, level intros, dramatic reveals.
@tool
class_name JuiceeScreenWipeEffect
extends JuiceeEffect

enum WipeFrom { LEFT, RIGHT, TOP, BOTTOM }

const LAYER_NAME := &"_juicee_screen_wipe_overlay"

## Direction the wipe bar enters from.
@export var wipe_from: WipeFrom = WipeFrom.LEFT
## Color of the wipe bar (typically opaque black for scene transitions).
@export var wipe_color: Color = Color.BLACK
## Total wipe duration: half to cover the screen, half to leave it. With Hold on, only the first half plays.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.6
## If true, the wipe stops at the center and stays covering the screen. Caller must clean up.
## If false (default), it wipes across and exits the opposite side.
@export var hold: bool = false

@export_group("Advanced")
## Hand-drawn curve (0..1) shaping the bar's travel, replacing the cubic ease. FEEL-style.
@export var ease_curve: Curve
## Seconds the screen stays fully covered before the bar exits. Only used when Hold is off.
@export_range(0.0, 10.0, 0.05) var cover_time: float = 0.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["ease_curve", "cover_time"]))

func _apply(context: Node, _intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return

	_sweep_overlay_layers(context, LAYER_NAME)

	var viewport_size: Vector2 = context.get_viewport().get_visible_rect().size
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = LAYER_NAME
	layer.layer = 129
	context.add_child(layer)
	# Freed by stop() mid-wipe: the rect takes mouse input, so one left behind blocks the game.
	_free_on_stop(layer)

	var rect: ColorRect = ColorRect.new()
	rect.color = wipe_color
	rect.size = viewport_size
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(rect)

	var start_pos: Vector2 = Vector2.ZERO
	var end_pos: Vector2 = Vector2.ZERO
	match wipe_from:
		WipeFrom.LEFT:
			start_pos = Vector2(-viewport_size.x, 0)
			end_pos = Vector2.ZERO
		WipeFrom.RIGHT:
			start_pos = Vector2(viewport_size.x, 0)
			end_pos = Vector2.ZERO
		WipeFrom.TOP:
			start_pos = Vector2(0, -viewport_size.y)
			end_pos = Vector2.ZERO
		WipeFrom.BOTTOM:
			start_pos = Vector2(0, viewport_size.y)
			end_pos = Vector2.ZERO

	rect.position = start_pos
	var tween: Tween = _track(layer.create_tween())
	# ease_curve (advanced) overrides the cubic ease on the way in.
	if ease_curve:
		_tween_curved(tween, rect, "position", start_pos, end_pos, duration * 0.5, ease_curve)
	else:
		tween.tween_property(rect, "position", end_pos, duration * 0.5)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	if not hold:
		# Advanced cover_time keeps the screen fully covered before the bar exits, which
		# is the window a scene swap wants to happen in.
		if cover_time > 0.0:
			tween.tween_interval(cover_time)
		# Wipe back out the opposite side
		var exit_pos: Vector2 = -start_pos
		if ease_curve:
			_tween_curved(tween, rect, "position", end_pos, exit_pos, duration * 0.5, ease_curve)
		else:
			tween.tween_property(rect, "position", exit_pos, duration * 0.5)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	await tween.finished
	if _gen != play:
		return
	if is_instance_valid(layer):
		if hold:
			# Held covering the screen until stop() or the next wipe takes it down.
			_free_when_released(layer)
		else:
			layer.queue_free()
