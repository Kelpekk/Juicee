## Cinematic letterbox bars - slide in from top and bottom for cutscene feel.
##
## Use for: boss intros, cutscene boundaries, dramatic slow-mo moments,
## dialogue sequences, "you have entered X zone" callouts.
##
## The bars animate in over `enter_duration`, hold for `hold_duration`
## (0 = hold until `stop()` is called), then animate out. Each bar is a
## simple ColorRect on a CanvasLayer - zero shader overhead, works in 2D + 3D.
@tool
class_name JuiceeCinematicBarsEffect
extends JuiceeEffect

## Bar color (default matte black).
@export var bar_color: Color = Color(0.0, 0.0, 0.0, 1.0)
## How much of the screen each bar covers (0.1 = 10% top + 10% bottom = classic 2.35:1).
@export_range(0.0, 0.45, 0.005) var bar_height: float = 0.1
## Duration to slide in.
@export_range(0.05, 2.0, 0.05) var enter_duration: float = 0.3
## How long to hold the bars (0 = hold until stop() is called, great for dialogue).
@export_range(0.0, 30.0, 0.1) var hold_duration: float = 2.0
## Duration to slide out. 0 = instant hide.
@export_range(0.0, 2.0, 0.05) var exit_duration: float = 0.3
## Canvas layer z-index. Keep high so bars render above everything.
@export_range(100, 250, 1) var canvas_layer: int = 200

const LAYER_NAME := &"_juicee_cinematic_bars"

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_MOTION
func get_category_name() -> String: return "Screen"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	_sweep_overlay_layers(context, LAYER_NAME)

	var layer := CanvasLayer.new()
	layer.name = LAYER_NAME
	layer.layer = canvas_layer
	context.add_child(layer)

	var vp_size: Vector2 = context.get_viewport().get_visible_rect().size
	var bar_px: float = vp_size.y * bar_height * intensity_mult

	var top := ColorRect.new()
	top.color = bar_color
	top.size = Vector2(vp_size.x, bar_px)
	top.position = Vector2(0.0, -bar_px)  # starts hidden above screen
	layer.add_child(top)

	var bot := ColorRect.new()
	bot.color = bar_color
	bot.size = Vector2(vp_size.x, bar_px)
	bot.position = Vector2(0.0, vp_size.y)  # starts hidden below screen
	layer.add_child(bot)

	var tree := context.get_tree()

	# Slide IN.
	if enter_duration > 0.0:
		var tween := _track(layer.create_tween())
		tween.set_parallel(true)
		tween.tween_property(top, "position:y", 0.0, enter_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(bot, "position:y", vp_size.y - bar_px, enter_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished

	if _cancelled or not is_instance_valid(layer):
		layer.queue_free() if is_instance_valid(layer) else null
		return

	# Hold - either timed or manual (hold_duration = 0 -> wait for stop()).
	if hold_duration > 0.0:
		await tree.create_timer(hold_duration, true, false, false).timeout
	else:
		# Hold until _cancelled (stop() was called externally).
		while not _cancelled and is_instance_valid(layer):
			await tree.process_frame

	if not is_instance_valid(layer):
		return

	# Slide OUT.
	if exit_duration > 0.0:
		var tween_out := layer.create_tween()
		tween_out.set_parallel(true)
		tween_out.tween_property(top, "position:y", -bar_px, exit_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween_out.tween_property(bot, "position:y", vp_size.y, exit_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tween_out.finished

	if is_instance_valid(layer):
		layer.queue_free()
