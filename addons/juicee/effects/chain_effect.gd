## Compose N child JuiceeEffect resources into a single sequence step.
##
## Lets you build reusable "macro effects" without opening the JuiceeGraph
## editor: just drop a ChainEffect into a sequence and fill its `effects`
## array. Each child runs in order with per-step delays (or all in parallel).
##
## Use for: encapsulating signature moves as a single Resource (e.g. a
## `signature_uppercut.tres` that bundles shake + hit-stop + flash + zoom),
## sharing reusable combos across scenes without copy-paste.
@tool
class_name JuiceeChainEffect
extends JuiceeEffect

## Effects to run, in order.
@export var effects: Array[JuiceeEffect] = []
## Delay before each child fires (extra pacing between steps). Ignored when Parallel is on.
@export_range(0.0, 2.0, 0.01) var step_delay: float = 0.0
## If true, all children fire at once instead of waiting in sequence.
@export var parallel: bool = false
## If true, this chain waits for every child to finish before returning.
@export var wait_for_finish: bool = true

@export_group("Advanced")
## Play the chain in reverse order, so one resource can drive both an open and a close.
@export var reverse_order: bool = false
## Run the whole chain this many times. 1 = once through.
@export_range(1, 32, 1) var repeat_count: int = 1
## Pause between repeats, in seconds.
@export_range(0.0, 10.0, 0.05) var repeat_delay: float = 0.0
## Fire only ONE randomly chosen child instead of the whole list, so a hit can pick a
## different reaction each time.
@export var pick_random_one: bool = false

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["reverse_order", "repeat_count", "repeat_delay", "pick_random_one"]))

func get_category_name() -> String:
	return "Flow"

func _apply(context: Node, _intensity_mult: float) -> void:
	if effects.is_empty():
		_warn("JuiceeChainEffect: no effects to chain")
		return
	var tree := context.get_tree() if context else null
	var play := _gen

	# Advanced pick_random_one turns the chain into a variation pool: fire a single
	# random child so repeated hits do not always play the same reaction.
	if pick_random_one:
		var pool: Array[JuiceeEffect] = []
		for child in effects:
			if child:
				pool.append(child)
		if pool.is_empty():
			return
		var chosen: JuiceeEffect = pool[randi() % pool.size()]
		if _start_child(chosen, context, _runtime_params) and wait_for_finish:
			await _wait_for([chosen], tree, play)
			if _gen != play:
				return
		return

	# Advanced repeat_count runs the whole chain again (with repeat_delay between
	# passes), and reverse_order lets one resource drive an open and its close.
	var passes: int = maxi(1, repeat_count)
	for pass_i in passes:
		if _gen != play:
			break
		await _run_once(context, tree, play)
		if _gen != play:
			return
		if pass_i < passes - 1 and repeat_delay > 0.0 and tree:
			await tree.create_timer(repeat_delay, true, false, false).timeout

## Until none of `children` is playing or waiting out a delay, or this play is over. Polled, not
## awaited: a child stopped from outside, or one that leaves the tree with its node, never returns
## from apply(), and one listed twice sends one finished for two starts, so awaiting either held
## the chain up for good.
func _wait_for(children: Array, tree: SceneTree, play: int) -> void:
	if not tree:
		return
	while _gen == play:
		var busy := false
		for child in children:
			if child and (child as JuiceeEffect).is_busy():
				busy = true
				break
		if not busy:
			return
		await tree.process_frame

## One pass through the child effects.
func _run_once(context: Node, tree: SceneTree, play: int) -> void:
	var ordered: Array[JuiceeEffect] = effects.duplicate()
	if reverse_order:
		ordered.reverse()

	if parallel:
		var fired: Array = []
		for child in ordered:
			if not child or _gen != play:
				continue
			# Fire without await - each coroutine starts concurrently.
			if _start_child(child, context, _runtime_params):
				fired.append(child)
		if wait_for_finish:
			await _wait_for(fired, tree, play)
	else:
		for child in ordered:
			if not child or _gen != play:
				break
			if step_delay > 0.0 and tree:
				await tree.create_timer(step_delay, true, false, false).timeout
			if _gen != play or not is_instance_valid(context):
				break
			if _start_child(child, context, _runtime_params) and wait_for_finish:
				await _wait_for([child], tree, play)
