## A NodePath field you can drag a node onto, the way you can in the Inspector.
## Drop a node from the Scene dock and the path fills itself in, relative to the
## scene root. Typing still works.
@tool
class_name JuiceeNodePathField
extends LineEdit

## Emitted when the path changes, by typing or by a drop.
signal path_changed(path: NodePath)

## Node types this field will accept, e.g. ["Light3D"]. Empty accepts anything.
var accepted_types: PackedStringArray = PackedStringArray()

var _normal_border: Color = Color(0, 0, 0, 0)

func _init() -> void:
	placeholder_text = "drag a node here, or type a path"
	text_submitted.connect(func(_t: String) -> void: _commit())
	focus_exited.connect(_commit)

func _commit() -> void:
	path_changed.emit(NodePath(text))

# --- Drag and drop ------------------------------------------------------------

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return _node_from_drag(data) != null

func _drop_data(_at: Vector2, data: Variant) -> void:
	var node := _node_from_drag(data)
	if not node:
		return
	text = String(_path_to(node))
	_commit()

## The Scene dock hands over {"type": "nodes", "nodes": [NodePath, ...]} where the
## paths are absolute within the edited scene. Resolve the first one, and only
## accept it if it is a type this effect can actually use.
func _node_from_drag(data: Variant) -> Node:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = data
	if d.get("type", "") != "nodes":
		return null
	var paths: Array = d.get("nodes", [])
	if paths.is_empty():
		return null

	var root := _scene_root()
	if not root:
		return null
	var node := root.get_node_or_null(paths[0])
	if not node:
		return null
	if accepted_types.is_empty():
		return node
	for t in accepted_types:
		if ClassDB.is_parent_class(node.get_class(), t):
			return node
	return null

func _scene_root() -> Node:
	if not Engine.is_editor_hint():
		return null
	return EditorInterface.get_edited_scene_root()

## Effects resolve their NodePath against the node the sequence is played on,
## which at test time is the scene root. So store the path relative to the root.
func _path_to(node: Node) -> NodePath:
	var root := _scene_root()
	if not root:
		return NodePath(node.name)
	if node == root:
		return NodePath(".")
	return root.get_path_to(node)

# --- Drop highlight -----------------------------------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			if _node_from_drag(get_viewport().gui_get_drag_data()):
				_set_highlight(true)
		NOTIFICATION_DRAG_END:
			_set_highlight(false)

func _set_highlight(on: bool) -> void:
	if on:
		add_theme_color_override("font_color", Color(0.55, 0.9, 0.55))
	else:
		remove_theme_color_override("font_color")
