@tool
class_name JuiceeGraphResource
extends Resource

## Editor-side representation of a graph.
## On Save -> exported as JuiceeSequence (effects array + connections).

@export var nodes: Array[JuiceeGraphNodeData] = []
## Stored as "from_id:from_port:to_id:to_port"
@export var connections: PackedStringArray = []

func add_node(data: JuiceeGraphNodeData) -> void:
	nodes.append(data)

func remove_node(id: String) -> void:
	for i in range(nodes.size() - 1, -1, -1):
		if nodes[i].id == id:
			nodes.remove_at(i)
			break
	var kept: PackedStringArray = []
	for c in connections:
		var p := c.split(":")
		if p[0] != id and p[2] != id:
			kept.append(c)
	connections = kept

func add_connection(from_id: String, from_port: int, to_id: String, to_port: int) -> void:
	var key := "%s:%d:%s:%d" % [from_id, from_port, to_id, to_port]
	if key not in connections:
		connections.append(key)

func remove_connection(from_id: String, from_port: int, to_id: String, to_port: int) -> void:
	var key := "%s:%d:%s:%d" % [from_id, from_port, to_id, to_port]
	var idx := connections.find(key)
	if idx >= 0:
		connections.remove_at(idx)

func find_node(id: String) -> JuiceeGraphNodeData:
	for n in nodes:
		if n.id == id:
			return n
	return null

func find_trigger() -> JuiceeGraphNodeData:
	for n in nodes:
		if n.type == "trigger":
			return n
	return null

## Next nodes wired from from_id, ORDERED BY OUTPUT PORT (not connection-insertion
## order). Condition maps port 0 = true / port 1 = false, and Random's weights are
## indexed per port, so the result must be port-ordered or those branch the wrong way.
func get_next(from_id: String) -> Array[JuiceeGraphNodeData]:
	var matches: Array = []  # [from_port:int, node]
	for c in connections:
		var p := c.split(":")
		if p.size() >= 3 and p[0] == from_id:
			var next := find_node(p[2])
			if next:
				matches.append([int(p[1]), next])
	matches.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var result: Array[JuiceeGraphNodeData] = []
	for m in matches:
		result.append(m[1])
	return result

## Walks the graph from Trigger and produces a JuiceeSequence.
## - Sequential by default.
## - Split nodes mark a parallel boundary (we just flatten in MVP).
func to_sequence() -> JuiceeSequence:
	var seq := JuiceeSequence.new()
	seq.graph_connections = connections
	var trigger := find_trigger()
	if not trigger:
		for n in nodes:
			if n.effect:
				seq.effects.append(n.effect)
		return seq
	var visited: Dictionary = {}
	_walk(trigger, seq, visited)
	return seq

func _walk(data: JuiceeGraphNodeData, seq: JuiceeSequence, visited: Dictionary) -> void:
	if visited.has(data.id):
		return
	visited[data.id] = true
	if data.effect:
		seq.effects.append(data.effect)
	for next in get_next(data.id):
		_walk(next, seq, visited)
