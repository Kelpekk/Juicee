## Right-click a node in the Scene dock -> "Add JuiceePlayer". Saves the usual detour
## through the Create New Node dialog for the node you reach for constantly - every hit
## reaction, every pickup, every UI screen tends to want one.
##
## Registered from plugin.gd only when EditorContextMenuPlugin exists (added after this
## addon's stated Godot 4.3 floor), so an older editor just never sees the menu item
## instead of failing to load the whole addon.
@tool
extends EditorContextMenuPlugin

const ICON_PATH := "res://addons/juicee/icons/juicee_player.svg"

func _popup_menu(paths: PackedStringArray) -> void:
	if paths.is_empty():
		return
	var icon := JuiceeEditorUtil.addon_icon(ICON_PATH)
	add_context_menu_item("Add JuiceePlayer", _on_add_juicee_player.bind(paths), icon)

func _on_add_juicee_player(paths: PackedStringArray) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if not root:
		return
	# Resolve first so an empty batch never opens an undo action with nothing in it.
	var parents: Array[Node] = []
	for path in paths:
		var parent := root.get_node_or_null(NodePath(path))
		if parent:
			parents.append(parent)
	if parents.is_empty():
		return

	# One JuiceePlayer per selected node - selecting several enemies and adding a
	# reaction node to each at once is the actual time-saver, not just the single case.
	# One undo action for the whole batch, so Ctrl+Z removes everything this click
	# added in one press, matching how Godot's own multi-node operations undo.
	var ur := EditorInterface.get_editor_undo_redo()
	var action_name := "Add JuiceePlayer" if parents.size() == 1 else "Add %d JuiceePlayers" % parents.size()
	ur.create_action(action_name)
	var created: Array[Node] = []
	for parent in parents:
		var player := JuiceePlayer.new()
		player.name = "JuiceePlayer"
		created.append(player)
		# add_child before set_owner: an unowned node in the tree does not get saved
		# with the scene, and set_owner on a node not yet parented does nothing useful.
		ur.add_do_method(parent, "add_child", player, true)
		ur.add_do_method(player, "set_owner", root)
		ur.add_do_reference(player)
		ur.add_undo_method(parent, "remove_child", player)
	ur.commit_action()
	# Select what was just added, the same courtesy Godot's own "Add Child Node" gives -
	# the Inspector opens on it immediately instead of leaving the old selection in place.
	var selection := EditorInterface.get_selection()
	selection.clear()
	for player in created:
		selection.add_node(player)
