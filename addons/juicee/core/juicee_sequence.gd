@tool
@icon("res://addons/juicee/icons/juicee_resource.svg")
class_name JuiceeSequence
extends Resource

signal started
signal finished
signal stopped
## Emitted just before each effect's apply() is called. Used by graph debugger to highlight blocks.
signal effect_started(effect: JuiceeEffect)
signal effect_finished(effect: JuiceeEffect)

var _cancelled: bool = false
var _playing: bool = false
var _paused: bool = false

## Ordered list of effects to play. Add via the Inspector's "+ Add Effect" button
## or build visually in the JuiceeGraph bottom panel.
@export var effects: Array[JuiceeEffect] = []
## If true, all effects fire at once (parallel). If false, they run one after another (sequential).
@export var parallel: bool = false
## When parallel = true, this is the delay in seconds between each effect's start.
## 0 = all fire simultaneously. Useful for "shotgun" hits where effects cascade.
@export_range(0.0, 2.0, 0.01) var stagger_delay: float = 0.0
## Minimum seconds between plays of this sequence, when a JuiceePlayer fires it.
## 0 falls back to the player's own cooldown.
##
## This is what makes several sequences on one player workable: a pickup wants no
## cooldown at all and a bullet-time reaction wants a second and a half of one, and
## a cooldown that lives only on the node cannot say both.
@export_range(0.0, 10.0, 0.01) var cooldown: float = 0.0

## Connections between blocks in the graph editor, stored as "from_id:from_port:to_id:to_port".
## Written by JuiceeGraphEditor. Saved with the sequence but kept out of the Inspector, since
## editing it by hand only breaks the graph.
@export_storage var graph_connections: PackedStringArray = []

## Plays the sequence on `context`. Optional `params` dict is forwarded to each effect's
## apply() so effects can react to runtime data (hit direction, damage, etc).
func play(context: Node, params: Dictionary = {}) -> void:
	# A play started while another is running replaces it, as an effect's does: the older one
	# stops at its next step rather than carrying on beside the new one, sharing its flags. A
	# pause belonged to that play. A sequence with no steps plays too, and ends at once, so
	# whoever listens hears started and finished as for any other.
	_gen += 1
	var play_gen := _gen
	_cancelled = false
	_paused = false
	_playing = true
	# The steps as they are now: a play goes through the list it began with, whatever is added to
	# it or taken from it meanwhile, and stop() stops those.
	_steps = effects.duplicate()
	started.emit()
	if parallel:
		await _play_parallel(context, params, play_gen, _steps)
	else:
		await _play_sequential(context, params, play_gen, _steps)
	# Replaced by a newer play, or ended by stop(), which sent stopped itself.
	if play_gen != _gen:
		return
	_playing = false
	finished.emit()

## Bumped by every play() and stop(); a running play stops at its next step once it has moved.
var _gen: int = 0
## The steps the last play began with.
var _steps: Array = []

## Cancels the sequence and stops every effect inside it. Manual-loop and tween-based
## effects (anything that called `_track()` or checks `_cancelled`) will bail out.
## Safe to call when not playing - does nothing.
func stop() -> void:
	var was_playing := _playing
	_gen += 1
	_cancelled = true
	_playing = false
	_paused = false
	# Every effect still playing, still waiting out its delay (it would start after the stop
	# otherwise), or holding what it left in place when it ended, as fade_out off does. That last
	# one was meant to be covered here and never was, since a held effect is not playing. The
	# steps the play began with as well as the list as it is now, should the two differ.
	for e in _steps + effects:
		if e and (e.is_busy() or e.is_holding()):
			e.stop()
	# From here rather than from the play's coroutine, which may never come back: a step
	# stopped mid-tween does not.
	if was_playing:
		stopped.emit()

func is_playing() -> bool:
	return _playing

## Pause at the seam between effects - the currently-running effect finishes,
## then the sequence waits here until resume() is called.
## Has no effect if the sequence is not playing.
func pause() -> void:
	if _playing:
		_paused = true

## Resume a paused sequence. The next effect in the list will start immediately.
func resume() -> void:
	_paused = false

func is_paused() -> bool:
	return _paused

func _play_sequential(context: Node, params: Dictionary, play_gen: int, steps: Array) -> void:
	for effect in steps:
		if play_gen != _gen:
			return
		# The node it plays on is gone: the steps left would each be handed a freed node.
		if not is_instance_valid(context):
			return
		# Hold at the seam between effects while paused.
		while _paused and play_gen == _gen and is_instance_valid(context) and context.is_inside_tree():
			await context.get_tree().process_frame
		if play_gen != _gen:
			return
		if not effect:
			continue
		effect_started.emit(effect)
		var refused := JuiceeEffect.start_nested(effect, context, params)
		if not refused.is_empty():
			push_warning("JuiceeSequence: " + refused)
		# Polled, not awaited: a step stopped from outside, or one whose node left the tree, never
		# returns from apply(), and awaiting it held the whole sequence up for good.
		while effect.is_busy() and play_gen == _gen and is_instance_valid(context) and context.is_inside_tree():
			await context.get_tree().process_frame
		if play_gen != _gen:
			return
		effect_finished.emit(effect)

func _play_parallel(context: Node, params: Dictionary, play_gen: int, steps: Array) -> void:
	var valid_effects: Array[JuiceeEffect] = []
	for e in steps:
		if e:
			valid_effects.append(e)
	if valid_effects.is_empty():
		return
	if not is_instance_valid(context) or not context.is_inside_tree():
		push_warning("JuiceeSequence: the node it was played on is not in the scene tree")
		return
	var tree := context.get_tree()

	# Fire all effects without awaiting - they all run concurrently.
	for i in valid_effects.size():
		if play_gen != _gen:
			return
		# The node it plays on went during the stagger: the rest would be handed a freed node.
		if not is_instance_valid(context):
			return
		effect_started.emit(valid_effects[i])
		var refused := JuiceeEffect.start_nested(valid_effects[i], context, params)
		if not refused.is_empty():
			push_warning("JuiceeSequence: " + refused)
		if stagger_delay > 0.0 and i < valid_effects.size() - 1:
			await tree.create_timer(stagger_delay, true, false, false).timeout

	if play_gen != _gen:
		return

	# Poll every frame until every concurrently-running effect has finished.
	# Also waits for effects that are still in their pre-delay (_pending_start),
	# so a parallel sequence where all effects have delay > 0 doesn't exit
	# before any of them have actually started.
	while play_gen == _gen and is_instance_valid(context) and context.is_inside_tree():
		var any_active := false
		for eff in valid_effects:
			if eff and (eff.is_playing() or eff._pending_start):
				any_active = true
				break
		if not any_active:
			break
		await tree.process_frame

	if play_gen != _gen:
		return
	for eff in valid_effects:
		effect_finished.emit(eff)
