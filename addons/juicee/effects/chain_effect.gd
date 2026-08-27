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
## Delay before each child fires (extra pacing between steps).
@export_range(0.0, 2.0, 0.01) var step_delay: float = 0.0
## If true, all children fire at once instead of waiting in sequence.
@export var parallel: bool = false
## If true, this chain waits for every child to finish before returning.
@export var wait_for_finish: bool = true

func get_category_name() -> String:
	return "Flow"

func _apply(context: Node, _intensity_mult: float) -> void:
	if effects.is_empty():
		return
	var tree := context.get_tree() if context else null

	if parallel:
		# Count children that will actually fire.
		var total := 0
		for child in effects:
			if child:
				total += 1
		if total == 0:
			return
		var done_count := [0]
		for child in effects:
			if not child or _cancelled:
				continue
			if wait_for_finish:
				child.finished.connect(func() -> void: done_count[0] += 1, CONNECT_ONE_SHOT)
			# Fire without await - each coroutine starts concurrently.
			child.apply(context, _runtime_params)
			# A child blocked by chance/cooldown/accessibility returns synchronously
			# and never emits `finished` - tally it now so the join can't wait forever.
			if wait_for_finish and not child.is_busy():
				done_count[0] += 1
		if wait_for_finish and tree:
			while done_count[0] < total and not _cancelled and is_instance_valid(context):
				await tree.process_frame
	else:
		for child in effects:
			if not child or _cancelled:
				break
			if step_delay > 0.0 and tree:
				await tree.create_timer(step_delay, true, false, false).timeout
			if _cancelled:
				break
			if wait_for_finish:
				await child.apply(context, _runtime_params)
			else:
				child.apply(context, _runtime_params)
