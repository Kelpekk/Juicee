## Executes a JuiceeGraphResource against a target node.
## Usage:  JuiceeGraphPlayer.play(load("res://my_sequence.tres"), self)
##
## For the simpler Inspector-first flow, prefer JuiceeSequence + JuiceePlayer directly.
class_name JuiceeGraphPlayer
extends Node

static func play(resource: JuiceeGraphResource, context: Node) -> void:
	if not resource:
		push_error("JuiceeGraphPlayer: resource is null")
		return
	if not is_instance_valid(context):
		push_error("JuiceeGraphPlayer: context is not valid")
		return
	var trigger := resource.find_trigger()
	if not trigger:
		push_error("JuiceeGraphPlayer: graph has no Trigger node")
		return
	var runner := JuiceeGraphPlayer.new()
	context.add_child(runner)
	await runner._chain(trigger, resource, context)
	if is_instance_valid(runner):
		runner.queue_free()

# Walks the graph. Flow control nodes (split/random/loop) have special semantics.
func _chain(data: JuiceeGraphNodeData, resource: JuiceeGraphResource, context: Node) -> void:
	# Live debugger: tell the editor this block is about to fire.
	if EngineDebugger.is_active() and not resource.resource_path.is_empty():
		EngineDebugger.send_message("juicee:block_fire", [resource.resource_path, data.id])

	# For effect nodes, also send start/end so the editor can show an "active" glow.
	if data.effect and EngineDebugger.is_active() and not resource.resource_path.is_empty():
		EngineDebugger.send_message("juicee:block_start", [resource.resource_path, data.id])
		await _execute(data, context)
		if EngineDebugger.is_active():
			EngineDebugger.send_message("juicee:block_end", [resource.resource_path, data.id])
	else:
		await _execute(data, context)

	var nexts := resource.get_next(data.id)
	if nexts.is_empty():
		return

	match data.type:
		"split":
			# Parallel fan-out: all outputs run concurrently, but we WAIT for every
			# branch to finish before returning - otherwise the runner (and any nodes
			# chained after a branch) can be freed mid-flight, cutting the branch off.
			var remaining := [nexts.size()]
			for next in nexts:
				_run_branch(next, resource, context, remaining)
			while remaining[0] > 0:
				await get_tree().process_frame
		"random":
			# Pick one output based on weights.
			var weights: Array = data.properties.get("weights", [])
			var idx := _weighted_random_index(weights, nexts.size())
			await _chain(nexts[idx], resource, context)
		"loop":
			# Run the connected subgraph N times sequentially, or forever if infinite.
			if bool(data.properties.get("infinite", false)):
				# Runs until the runner leaves the tree (context freed / scene change).
				# Yield every pass so an instant chain can't lock up the frame.
				while is_instance_valid(self) and is_inside_tree():
					await _chain(nexts[0], resource, context)
					if not (is_instance_valid(self) and is_inside_tree()):
						break
					await get_tree().process_frame
			else:
				var count: int = int(data.properties.get("count", 1))
				for i in count:
					await _chain(nexts[0], resource, context)
		"condition":
			# Evaluate a GDScript expression. Port 0 = true, Port 1 = false.
			var expr_str: String = data.properties.get("expression", "true")
			var expr := Expression.new()
			var result: bool = true
			if expr.parse(expr_str, ["context"]) == OK:
				var val := expr.execute([context], context)
				if not expr.has_execute_failed():
					result = bool(val)
				else:
					push_warning("JuiceeGraphPlayer: Condition expression failed: " + expr_str)
			else:
				push_warning("JuiceeGraphPlayer: Condition expression parse error: " + expr_str)
			var port := 0 if result else 1
			if nexts.size() > port:
				await _chain(nexts[port], resource, context)
		_:
			await _chain(nexts[0], resource, context)

# Runs one Split branch to completion, then marks it done (remaining is a 1-element
# array used as a shared mutable counter so the Split can join on all branches).
func _run_branch(data: JuiceeGraphNodeData, resource: JuiceeGraphResource, context: Node, remaining: Array) -> void:
	await _chain(data, resource, context)
	remaining[0] -= 1

# Polymorphic execution - Effects call their .apply(); flow nodes are pure topology.
func _execute(data: JuiceeGraphNodeData, context: Node) -> void:
	if data.effect:
		await data.effect.apply(context)

## Picks an index in [0, fallback_size) using `weights` as relative probabilities.
## Used by both the runtime walker and the editor's debug Test runner so the
## preview honors weights the same way a real play would.
static func _weighted_random_index(weights: Array, fallback_size: int) -> int:
	if weights.is_empty() or weights.size() < fallback_size:
		return randi() % fallback_size
	var total: float = 0.0
	for w in weights.slice(0, fallback_size):
		total += max(0.0, float(w))
	if total <= 0.0:
		return randi() % fallback_size
	var roll := randf() * total
	var acc: float = 0.0
	for i in fallback_size:
		acc += max(0.0, float(weights[i]))
		if roll <= acc:
			return i
	return fallback_size - 1
