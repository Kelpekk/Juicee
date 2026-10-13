## Executes a JuiceeGraphResource against a target node.
## Usage:  JuiceeGraphPlayer.play(load("res://my_sequence.tres"), self)
##
## For the simpler Inspector-first flow, prefer JuiceeSequence + JuiceePlayer directly.
class_name JuiceeGraphPlayer
extends Node

## Blocks a walk may pass in one frame. A graph whose blocks take no time (muted, instant, empty)
## and loop back on themselves, or a Loop of a billion around one, would otherwise never let the
## frame end; past this the walk waits for the next frame and carries on.
const STEPS_PER_FRAME := 256
## Branches one play may have running at once. A Split wired back into itself doubles them on every
## pass, which ran the game out of memory; past this a Split starts no more of them.
const MAX_BRANCHES := 1024
## Loops one walk may have inside each other. A Loop whose chain leads back into it starts it again
## inside itself on every pass, and thousands deep the script VM failed with "Stack underflow
## (Engine Bug)"; past this a Loop runs its chain no deeper.
const MAX_LOOP_DEPTH := 64

var _context: Node
var _tree: SceneTree
var _frame := -1
var _steps := 0
var _branches := 0
var _warned_branches := false
var _loop_depth := 0
var _warned_loops := false
var _observer := Callable()
var _keep_going := Callable()

static func play(resource: JuiceeGraphResource, context: Node) -> void:
	await run(resource, context)

## play() for a caller that watches the walk, as the editor's Test does, so a Test runs the way the
## game will. `observer` is called with ("fire", block, ""), when a block is reached, ("end", block,
## "") once its effect is done, and ("warn", block, message) for a Condition that could not be
## read. The walk ends early, at its next step, once `keep_going` returns false.
static func run(resource: JuiceeGraphResource, context: Node, observer := Callable(),
		keep_going := Callable()) -> void:
	if not resource:
		push_warning("JuiceeGraphPlayer: resource is null")
		return
	if not is_instance_valid(context) or not context.is_inside_tree():
		push_warning("JuiceeGraphPlayer: the node to play on is not in the scene tree")
		return
	var trigger := resource.find_trigger()
	if not trigger:
		push_warning("JuiceeGraphPlayer: graph has no Trigger node")
		return
	var runner := JuiceeGraphPlayer.new()
	runner._context = context
	runner._tree = context.get_tree()
	runner._observer = observer
	runner._keep_going = keep_going
	# Under the tree's root rather than the node it plays on: freed with that node, the runner
	# took its own coroutines down mid-walk. The walk ends by itself once the node is gone.
	runner._tree.root.add_child(runner)
	await runner._chain(trigger, resource)
	if is_instance_valid(runner):
		runner.queue_free()

## Whether the walk can go on: the node it plays on is still in the scene, and whoever watches the
## walk still wants it.
func _alive() -> bool:
	if not is_instance_valid(_context) or not _context.is_inside_tree():
		return false
	return not _keep_going.is_valid() or bool(_keep_going.call())

## Whether this walk has not said `message` yet. A cycle through a Condition that cannot be read
## passes it 256 times a frame, and as many warnings a frame, each printed with its backtrace,
## made one frame take close to two seconds, measured.
func _first_time(message: String) -> bool:
	if _said.has(message):
		return false
	_said[message] = true
	return true

var _said := {}

func _tell(event: String, data: JuiceeGraphNodeData, message := "") -> void:
	if _observer.is_valid():
		_observer.call(event, data, message)

## Counts a step, and waits a frame when this frame has had its share.
func _tick() -> void:
	var frame := Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_steps = 0
	_steps += 1
	if _steps > STEPS_PER_FRAME:
		await _tree.process_frame

## Walks from `start` until the wires run out. One block after another in a loop rather than one
## call per block: a graph a few hundred blocks long, or one wired back on itself, ran the script
## stack out, which took the GDScript VM down with it.
func _chain(start: JuiceeGraphNodeData, resource: JuiceeGraphResource) -> void:
	var data := start
	while data and _alive():
		await _tick()
		if not _alive():
			return
		await _fire(data, resource)
		if not _alive():
			return
		var nexts := resource.get_next(data.id)
		if nexts.is_empty():
			return
		match data.type:
			"split":
				# Parallel fan-out: all outputs run concurrently, but we WAIT for every
				# branch to finish before returning - otherwise the runner (and any nodes
				# chained after a branch) can be freed mid-flight, cutting the branch off.
				var remaining := [0]
				for next in nexts:
					if _branches >= MAX_BRANCHES:
						if not _warned_branches:
							_warned_branches = true
							push_warning("JuiceeGraphPlayer: the graph keeps splitting into itself, so no more than %d branches run at once" % MAX_BRANCHES)
						break
					remaining[0] += 1
					_run_branch(next, resource, remaining)
				while remaining[0] > 0 and _alive():
					await _tree.process_frame
				return
			"random":
				data = random_next(resource, data)
			"loop":
				if _loop_depth >= MAX_LOOP_DEPTH:
					if not _warned_loops:
						_warned_loops = true
						push_warning("JuiceeGraphPlayer: a Loop's chain leads back into the Loop, so it runs no more than %d deep" % MAX_LOOP_DEPTH)
					return
				_loop_depth += 1
				await _loop(data, nexts[0], resource)
				_loop_depth -= 1
				return
			"condition":
				var checked := evaluate_condition(data, _context)
				if not str(checked[1]).is_empty() and _first_time(str(checked[1])):
					push_warning("JuiceeGraphPlayer: " + str(checked[1]))
					_tell("warn", data, str(checked[1]))
				data = condition_next(resource, data, bool(checked[0]))
			_:
				data = nexts[0]

## Runs a Loop's chain its count of times one after another, or, with `infinite`, until the node
## it plays on leaves the tree.
func _loop(data: JuiceeGraphNodeData, body: JuiceeGraphNodeData, resource: JuiceeGraphResource) -> void:
	if bool(data.properties.get("infinite", false)):
		# Yield every pass so an instant chain can't lock up the frame.
		while _alive():
			await _chain(body, resource)
			if not _alive():
				break
			await _tree.process_frame
	else:
		for i in _count(data.properties.get("count", 1)):
			if not _alive():
				break
			await _chain(body, resource)

## A Loop's count as a number of passes: a whole number, or a string of one. Anything else, a
## word or nothing at all, is one pass, and a negative one is none.
static func _count(value: Variant) -> int:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return maxi(0, int(value)) if is_finite(float(value)) else 1
		TYPE_STRING, TYPE_STRING_NAME:
			return maxi(0, int(str(value))) if str(value).is_valid_int() and str(value).length() < 10 else 1
	return 1

## Evaluates a Condition's expression against the node played on, as [result, problem]. True
## unless it says otherwise; an expression that does not parse or fails counts as true, and
## `problem` says why. The game's walk and the editor's Test both ask here.
static func evaluate_condition(data: JuiceeGraphNodeData, context: Node) -> Array:
	var expr_str := str(data.properties.get("expression", "true"))
	var expr := Expression.new()
	if expr.parse(expr_str, ["context"]) != OK:
		return [true, "Condition expression parse error: " + expr_str]
	# show_error off: the problem says what failed, once, instead of the engine as well.
	var val: Variant = expr.execute([context], context, false)
	if expr.has_execute_failed():
		return [true, "Condition expression failed (%s): %s" % [expr.get_error_text(), expr_str]]
	return [bool(val) if typeof(val) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] else val != null, ""]

## The block a Condition goes on to: the first one wired to its True output, port 0, or to its
## False, port 1. Null when that output has nothing wired, whatever the other one has.
static func condition_next(resource: JuiceeGraphResource, data: JuiceeGraphNodeData,
		result: bool) -> JuiceeGraphNodeData:
	var on: Array = resource.get_next_by_port(data.id).get(0 if result else 1, [])
	return on[0] if not on.is_empty() else null

## The block a Random goes on to: one of its wired outputs, each as likely as its own port's weight
## says, or all alike when the weights do not cover every port. An output left unwired is never
## picked.
static func random_next(resource: JuiceeGraphResource, data: JuiceeGraphNodeData) -> JuiceeGraphNodeData:
	var by_port := resource.get_next_by_port(data.id)
	if by_port.is_empty():
		return null
	var ports: Array = by_port.keys()
	ports.sort()
	var given: Variant = data.properties.get("weights", [])
	var port_count: Variant = data.properties.get("port_count", 0)
	var stated := 0
	if typeof(port_count) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(port_count)):
		stated = int(clampf(float(port_count), 0.0, 1024.0))
	var covered := maxi(int(ports.back()) + 1, stated)
	var weights: Array = []
	if given is Array and (given as Array).size() >= covered:
		for p in ports:
			weights.append(given[p])
	return (by_port[ports[_weighted_random_index(weights, ports.size())]] as Array)[0]

# Runs one Split branch to completion, then marks it done (remaining is a 1-element
# array used as a shared mutable counter so the Split can join on all branches).
func _run_branch(data: JuiceeGraphNodeData, resource: JuiceeGraphResource, remaining: Array) -> void:
	_branches += 1
	await _chain(data, resource)
	_branches -= 1
	remaining[0] -= 1

## Fires one block: an effect plays to its end, a flow block is pure topology. The live debugger is
## told which block fires so the editor can light it up.
func _fire(data: JuiceeGraphNodeData, resource: JuiceeGraphResource) -> void:
	var live := EngineDebugger.is_active() and not resource.resource_path.is_empty()
	if live:
		EngineDebugger.send_message("juicee:block_fire", [resource.resource_path, data.id])
	_tell("fire", data)
	if not data.effect:
		return
	if live:
		EngineDebugger.send_message("juicee:block_start", [resource.resource_path, data.id])
	var refused := JuiceeEffect.start_nested(data.effect, _context, {})
	if not refused.is_empty() and _first_time(refused):
		push_warning("JuiceeGraphPlayer: " + refused)
	# Polled, not awaited: an effect stopped from outside, or one whose node left the tree, never
	# returns from apply(), and awaiting it held the walk up for good.
	while data.effect.is_busy() and _alive():
		await _tree.process_frame
	if live:
		EngineDebugger.send_message("juicee:block_end", [resource.resource_path, data.id])
	_tell("end", data)

## Picks an index in [0, fallback_size) using `weights` as relative probabilities.
## Used by both the runtime walker and the editor's debug Test runner so the
## preview honors weights the same way a real play would. A weight that is not a
## number, or is not finite, counts as 0.
static func _weighted_random_index(weights: Array, fallback_size: int) -> int:
	if weights.is_empty() or weights.size() < fallback_size:
		return randi() % fallback_size
	var usable: Array[float] = []
	var total: float = 0.0
	for w in weights.slice(0, fallback_size):
		var v: float = float(w) if typeof(w) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(w)) else 0.0
		usable.append(maxf(0.0, v))
		total += usable[-1]
	if total <= 0.0:
		return randi() % fallback_size
	# A weight of 0 is never picked, even on a roll of exactly 0 or exactly the total.
	var roll := randf() * total
	var acc: float = 0.0
	var last := 0
	for i in fallback_size:
		if usable[i] <= 0.0:
			continue
		last = i
		acc += usable[i]
		if roll < acc:
			return i
	return last
