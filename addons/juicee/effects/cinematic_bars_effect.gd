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
## How much of the screen each bar covers (0.1 = 10% top + 10% bottom, about 2.2:1 on a 16:9 screen; 0.12 gives 2.35:1).
@export_range(0.0, 0.45, 0.005) var bar_height: float = 0.1
## Duration to slide in.
@export_range(0.05, 2.0, 0.05) var enter_duration: float = 0.3
## How long to hold the bars (0 = hold until stop() is called, great for dialogue).
@export_range(0.0, 30.0, 0.1) var hold_duration: float = 2.0
## Duration to slide out. 0 = instant hide.
@export_range(0.0, 2.0, 0.05) var exit_duration: float = 0.3
## Canvas layer z-index. Keep high so bars render above everything.
@export_range(100, 250, 1) var canvas_layer: int = 200

@export_group("Advanced")
## Draw the bars on the sides instead of top and bottom (pillarbox), for a vertical
## video or a stylised narrow frame.
@export var vertical_bars: bool = false
## Fade the bars in instead of sliding them, which suits a slower, softer transition.
@export var fade_in_instead: bool = false
## Hand-drawn easing curve (0..1) replacing the built-in easing on the entrance.
@export var ease_curve: Curve

func _validate_property(property_info: Dictionary) -> void:
	_gate_advanced(property_info, PackedStringArray(["vertical_bars", "fade_in_instead", "ease_curve"]))

const LAYER_NAME := &"_juicee_cinematic_bars"

func get_accessibility_tag() -> int: return JuiceeAccessibility.TAG_MOTION
func get_category_name() -> String: return "Screen"

func _apply(context: Node, intensity_mult: float) -> void:
	var play := _gen
	if not context or not context.is_inside_tree():
		return
	_sweep_overlay_layers(context, LAYER_NAME)

	var layer := CanvasLayer.new()
	layer.name = LAYER_NAME
	layer.layer = canvas_layer
	context.add_child(layer)

	var vp_size: Vector2 = context.get_viewport().get_visible_rect().size
	# Advanced vertical_bars draws a pillarbox (side bars) instead of a letterbox.
	var along: float = vp_size.x if vertical_bars else vp_size.y
	var bar_px: float = along * bar_height * intensity_mult

	var top := ColorRect.new()
	top.color = bar_color
	bot_size_setup(top, vp_size, bar_px)
	layer.add_child(top)

	var bot := ColorRect.new()
	bot.color = bar_color
	bot_size_setup(bot, vp_size, bar_px)
	layer.add_child(bot)
	# Off-screen start positions, on whichever axis the bars use.
	if vertical_bars:
		top.position = Vector2(-bar_px, 0.0)
		bot.position = Vector2(vp_size.x, 0.0)
	else:
		top.position = Vector2(0.0, -bar_px)
		bot.position = Vector2(0.0, vp_size.y)
	# fade_in_instead starts them in place and fades them up.
	if fade_in_instead:
		if vertical_bars:
			top.position = Vector2.ZERO
			bot.position = Vector2(vp_size.x - bar_px, 0.0)
		else:
			top.position = Vector2.ZERO
			bot.position = Vector2(0.0, vp_size.y - bar_px)
		top.modulate.a = 0.0
		bot.modulate.a = 0.0

	var tree := context.get_tree()
	# stop() during the slide-in kills its tween, and nothing would ever take the bars down: free
	# them at once then. During the hold the loop below sees the stop and slides them out.
	var phase := ["enter"]
	var layer_id := layer.get_instance_id()
	_on_stop(func() -> void:
		if phase[0] == "enter":
			_free_by_id(layer_id))

	# Slide IN.
	if enter_duration > 0.0:
		var tween := _track(layer.create_tween())
		tween.set_parallel(true)
		if fade_in_instead:
			tween.tween_property(top, "modulate:a", 1.0, enter_duration)
			tween.tween_property(bot, "modulate:a", 1.0, enter_duration)
		else:
			var axis: String = "position:x" if vertical_bars else "position:y"
			var bot_home: float = (vp_size.x - bar_px) if vertical_bars else (vp_size.y - bar_px)
			if ease_curve:
				var top_from: float = top.position.x if vertical_bars else top.position.y
				var bot_from: float = bot.position.x if vertical_bars else bot.position.y
				_tween_curved(tween, top, axis, top_from, 0.0, enter_duration, ease_curve)
				_tween_curved(tween, bot, axis, bot_from, bot_home, enter_duration, ease_curve)
			else:
				tween.tween_property(top, axis, 0.0, enter_duration)\
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(bot, axis, bot_home, enter_duration)\
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished

	# Stopped or replaced during the slide-in: the cleanup above has taken the bars down.
	if _gen != play or not is_instance_valid(layer):
		return

	# Hold - either timed or manual (hold_duration = 0 -> wait for stop()). Frame by frame either
	# way, so a stop() during a timed hold takes the bars out now, not when the hold would end.
	phase[0] = "hold"
	var held := 0.0
	while _gen == play and is_instance_valid(layer) and (hold_duration <= 0.0 or held < hold_duration):
		await tree.process_frame
		held += tree.root.get_process_delta_time()
	# From here the bars slide out whatever ended the hold, stop() included: that is how a manual
	# hold ends. A newer play has swept this layer away already.
	phase[0] = "exit"

	if not is_instance_valid(layer):
		return

	# Slide OUT.
	if exit_duration > 0.0:
		var tween_out := layer.create_tween()
		tween_out.set_parallel(true)
		if fade_in_instead:
			tween_out.tween_property(top, "modulate:a", 0.0, exit_duration)
			tween_out.tween_property(bot, "modulate:a", 0.0, exit_duration)
		else:
			var out_axis: String = "position:x" if vertical_bars else "position:y"
			var bot_gone: float = vp_size.x if vertical_bars else vp_size.y
			tween_out.tween_property(top, out_axis, -bar_px, exit_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween_out.tween_property(bot, out_axis, bot_gone, exit_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await _tween_done(tween_out)

	if is_instance_valid(layer):
		layer.queue_free()

## Sizes one bar for the current orientation: full-width strips for a letterbox,
## full-height strips for a pillarbox.
func bot_size_setup(bar: ColorRect, vp_size: Vector2, bar_px: float) -> void:
	if vertical_bars:
		bar.size = Vector2(bar_px, vp_size.y)
	else:
		bar.size = Vector2(vp_size.x, bar_px)
