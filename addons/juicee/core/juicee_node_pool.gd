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

## Returns a parked node if one is free, otherwise builds a fresh one via `factory`
## (a Callable returning a Node). The node is detached from any parent either way.
func acquire(factory: Callable) -> Node:
	while not _free.is_empty():
		var n: Node = _free.pop_back()
		if is_instance_valid(n):
			return n
	return factory.call()

## Parks `node` for reuse: detaches it from its parent and stores it, unless the pool
## is already at `cap` (then it's freed). Safe to call with a freed/invalid node.
func release(node: Node) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	var parent := node.get_parent()
	if parent:
		parent.remove_child(node)
	if _free.size() < cap:
		_free.append(node)
	else:
		node.queue_free()

## Number of nodes currently parked and ready to reuse.
func free_count() -> int:
	return _free.size()

## Frees every parked node and empties the pool.
func clear() -> void:
	for n in _free:
		if is_instance_valid(n):
			n.queue_free()
	_free.clear()
