@tool
class_name JuiceeGraphResource
extends Resource

## Editor-side representation of a graph.
## On Save -> exported as JuiceeSequence (effects array + connections).

@export var nodes: Array[JuiceeGraphNodeData] = []
## Stored as "from_id:from_port:to_id:to_port"
@export var connections: PackedStringArray = []
## Whether every graph_position is at 100% editor scale, which is how the graph editor saves them.
## Graphs saved by 1.5.0 and earlier have canvas pixels at the scale of the editor that saved them.
@export_storage var positions_at_100: bool = false

## Converts the positions of a graph saved by 1.5.0 or earlier to 100%, once. The scale of the
## editor opening it stands in for the one that saved it, which is usually the same editor.
func convert_old_positions(editor_scale: float) -> void:
	if positions_at_100:
		return
	positions_at_100 = true
	if editor_scale <= 0.0 or is_equal_approx(editor_scale, 1.0):
		return
	for n in nodes:
		n.graph_position /= editor_scale
		if n.effect:
			n.effect.graph_position = n.graph_position

func add_node(data: JuiceeGraphNodeData) -> void:
	nodes.append(data)

func remove_node(id: String) -> void:
	for i in range(nodes.size() - 1, -1, -1):
		if nodes[i] and nodes[i].id == id:
			nodes.remove_at(i)
			break
	var kept: PackedStringArray = []
	for c in connections:
		var p := c.split(":")
		if p.size() < 3 or (p[0] != id and p[2] != id):
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
		if n and n.id == id:
			return n
	return null

func find_trigger() -> JuiceeGraphNodeData:
	for n in nodes:
		if n and n.type == "trigger":
			return n
	return null

## A port number from a wire, or -1 for anything that is not a small whole number: a hand-edited
## or broken file can say anything there, and int() on twenty digits reports an error.
static func _port(text: String) -> int:
	return int(text) if text.is_valid_int() and text.length() <= 6 else -1

## Next nodes wired from from_id, ORDERED BY OUTPUT PORT (not connection-insertion
## order). Condition maps port 0 = true / port 1 = false, and Random's weights are
## indexed per port, so the result must be port-ordered or those branch the wrong way.
func get_next(from_id: String) -> Array[JuiceeGraphNodeData]:
	var matches: Array = []  # [from_port:int, node]
	for c in connections:
		var p := c.split(":")
		if p.size() >= 3 and p[0] == from_id and _port(p[1]) >= 0:
			var next := find_node(p[2])
			if next:
				matches.append([_port(p[1]), next])
	matches.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var result: Array[JuiceeGraphNodeData] = []
	for m in matches:
		result.append(m[1])
	return result

## The blocks wired from each output of from_id, as {port: [blocks]}. A Condition's False is
## port 1 and a Random's weight belongs to its port whether or not the outputs before it are
## wired, which the flat list get_next() returns cannot tell.
func get_next_by_port(from_id: String) -> Dictionary:
	var out := {}
	for c in connections:
		var p := c.split(":")
		if p.size() >= 3 and p[0] == from_id and _port(p[1]) >= 0:
			var next := find_node(p[2])
			if next:
				var port := _port(p[1])
				if not out.has(port):
					out[port] = []
				(out[port] as Array).append(next)
	return out

## Walks the graph from Trigger and produces a JuiceeSequence.
## - Sequential by default.
## - Split nodes mark a parallel boundary (we just flatten in MVP).
func to_sequence() -> JuiceeSequence:
	var seq := JuiceeSequence.new()
	seq.graph_connections = connections
	var trigger := find_trigger()
	if not trigger:
		for n in nodes:
			if n and n.effect:
				seq.effects.append(n.effect)
		return seq
	var visited: Dictionary = {}
	_walk(trigger, seq, visited)
	return seq

## Depth first from `start`, each block once, in the order the wires leave it. With a stack of its
## own rather than a call per block: a graph a thousand blocks long ran the script stack out.
func _walk(start: JuiceeGraphNodeData, seq: JuiceeSequence, visited: Dictionary) -> void:
	var stack: Array = [start]
	while not stack.is_empty():
		var data: JuiceeGraphNodeData = stack.pop_back()
		if not data or visited.has(data.id):
			continue
		visited[data.id] = true
		if data.effect:
			seq.effects.append(data.effect)
		var nexts := get_next(data.id)
		for i in range(nexts.size() - 1, -1, -1):
			stack.append(nexts[i])
