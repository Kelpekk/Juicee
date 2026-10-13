@tool
## Reuses spawned nodes instead of new + queue_free on every hit, so firing lots of
## damage numbers / floating text / bursts at once (50+ enemies) doesn't churn the
## allocator. Idle nodes are detached from the tree and parked here; the next spawn
## hands one back out. The caller owns re-parenting into the scene and resetting the
## node's state on acquire (the pool stays generic and node-type agnostic).
class_name JuiceeNodePool
extends RefCounted

## Hard cap on parked nodes. Past this, released nodes are freed instead of kept, so
## a one-off burst of 500 numbers doesn't pin 500 nodes in memory forever.
var cap: int = 64

var _free: Array[Node] = []

## Every pool ever made, so something can empty all of them when the game shuts down.
##
## A parked node is detached from the tree on purpose, and a node outside the tree with
## nothing else holding it is exactly what Godot counts as an orphan on the way out. Five
## effects park nodes here (Afterimage, Crack, Hit Spark, Slash Arc, Sparkle), each in a
## `static var` that outlives the scene, so a game shipping any of them printed a leak
## warning every time it quit. Measured on one afterimage: six leaked ObjectDB instances
## and four leaked CanvasItem RIDs, against none for the same run without it.
##
## Weak references, so a pool nobody else holds is not kept alive by this list.
static var _live: Array[WeakRef] = []

func _init() -> void:
	# The five that matter are made once and never go away, so this list is normally five
	# entries long for the life of the process. A game that builds a pool per enemy would
	# otherwise grow it forever with references to pools that have already gone.
	if _live.size() > 64:
		_forget_dead()
	_live.append(weakref(self))

## A pool is RefCounted and its parked nodes are not: an Array holding a Node does not own
## it, so a pool that goes away while holding some would strand them with nothing left
## pointing at them. The five shipped pools are static and never go away, but a pool built
## for one job should not have to be emptied by hand to be safe.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for node in _free:
			if is_instance_valid(node):
				node.free()
		_free.clear()

## Empties every pool and forgets the ones that have gone away. Called by the Juicee
## autoload as the tree shuts down.
##
## Frees rather than queue_frees: these nodes are already out of the tree, and at shutdown
## there is no guarantee of another frame to flush a deletion queue in.
static func free_all() -> void:
	for ref in _live:
		var pool: JuiceeNodePool = ref.get_ref()
		if not pool:
			continue
		for node in pool._free:
			if is_instance_valid(node):
				node.free()
		pool._free.clear()
	_forget_dead()

static func _forget_dead() -> void:
	var still_live: Array[WeakRef] = []
	for ref in _live:
		if ref.get_ref():
			still_live.append(ref)
	_live = still_live

## Returns a parked node if one is free, otherwise builds a fresh one via `factory`
## (a Callable returning a Node). The node is detached from any parent either way.
func acquire(factory: Callable) -> Node:
	while not _free.is_empty():
		# Untyped on purpose. A parked node freed behind the pool's back leaves a
		# dangling entry here, and assigning that to a typed Node throws before the
		# validity check below can catch it - which made this guard unreachable in the
		# one case it exists for.
		var candidate: Variant = _free.pop_back()
		if is_instance_valid(candidate):
			return candidate
	return factory.call()

## Parks `node` for reuse: detaches it from its parent and stores it, unless the pool
## is already at `cap` (then it's freed). Safe to call with a freed/invalid node.
## Variant, not Node: Godot 4.3 refuses a freed instance at a typed parameter with a script error
## before the check below can say it is gone.
func release(node: Variant) -> void:
	if not is_instance_valid(node) or not (node is Node):
		return
	var parked := node as Node
	if parked.is_queued_for_deletion():
		return
	# Parking the same node twice hands it to two callers on the next two acquires,
	# and then two effects animate one ghost. Reachable in ordinary use: an effect
	# that is stopped runs its cleanup, and its coroutine can still complete and
	# release again.
	if _free.has(parked):
		return
	var parent := parked.get_parent()
	if parent:
		parent.remove_child(parked)
	if _free.size() < cap:
		_free.append(parked)
	else:
		parked.queue_free()

## Number of nodes currently parked and ready to reuse.
func free_count() -> int:
	return _free.size()

## Frees every parked node and empties the pool.
func clear() -> void:
	for n in _free:
		if is_instance_valid(n):
			n.queue_free()
	_free.clear()
