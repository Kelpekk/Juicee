## Live tuning, game side: applies parameter changes pushed from the editor while the
## game is running, so you can feel a change as you make it instead of quitting,
## editing and relaunching.
##
## Addressing is the effect's own resource_path. An effect saved inside a sequence carries a
## sub-resource path like "res://juice/hit.tres::Resource_mrew3", and load() on that path returns
## the instance the running game holds, while it holds one. The copies a JuiceePlayer plays are
## tracked by the path they were copied from (track_copy), and a set reaches them as well.
##
## The channel is the editor debugger, which only exists in a debug build with the
## editor attached. In an exported game none of this registers and nothing runs.
class_name JuiceeLiveTune
extends RefCounted

## Effects created in code (Juicee.shake_camera(...) and friends) have no
## resource_path, so they cannot be addressed. Tracked only to answer honestly in the
## editor rather than failing silently.
signal tune_rejected(reason: String)

const CAPTURE_PREFIX := &"juicee_tune"

## Set by the editor's "re-fire on change" toggle. When on, a set is followed by
## replaying the effect on the last context it ran against, so the change is felt
## immediately rather than at the next natural trigger.
var refire_on_change: bool = false

## The node each effect last ran against, keyed by the effect's resource_path. Populated
## by JuiceeEffect.apply(); used only to replay for tuning.
var _last_context: Dictionary = {}
## The effect that last ran there, which for a JuiceePlayer is its own copy of the saved one.
var _last_effect: Dictionary = {}
## Copies of saved effects and sequences, by the path of the one they were copied from: every
## JuiceePlayer plays copies of its own, and a value tuned on the saved one has to reach them.
var _copies: Dictionary = {}

func track_copy(resource_path: String, copy: Resource) -> void:
	if not _copies.has(resource_path):
		_copies[resource_path] = []
	var list: Array = _copies[resource_path]
	for i in range(list.size() - 1, -1, -1):
		if (list[i] as WeakRef).get_ref() == null:
			list.remove_at(i)
	list.append(weakref(copy))

func _init() -> void:
	if not EngineDebugger.is_active():
		return
	EngineDebugger.register_message_capture(CAPTURE_PREFIX, _on_editor_message)

## Remembers where an effect last played, so a tuning change can replay it there.
## Called from JuiceeEffect.apply() and cheap enough to be unconditional in debug.
func note_context(effect: JuiceeEffect, context: Node) -> void:
	if not effect or not is_instance_valid(context):
		return
	var path := effect._tuning_path()
	if path.is_empty():
		return
	_last_context[path] = context
	_last_effect[path] = weakref(effect)

func _on_editor_message(message: String, data: Array) -> bool:
	match message:
		"set":
			if data.size() >= 3:
				_apply_set(str(data[0]), str(data[1]), data[2])
			return true
		"refire":
			if data.size() >= 1:
				refire_on_change = bool(data[0])
			return true
		"fire":
			if data.size() >= 1:
				_replay(str(data[0]))
			return true
	return false

func _apply_set(resource_path: String, property: String, value: Variant) -> void:
	if resource_path.is_empty():
		tune_rejected.emit("effect has no resource path (built in code, not saved)")
		return
	var targets := _instances(resource_path)
	if targets.is_empty():
		tune_rejected.emit("resource not loaded in the running game: %s" % resource_path)
		return
	var took := false
	for target in targets:
		if property in target:
			target.set(property, value)
			took = true
	if not took:
		tune_rejected.emit("no property '%s' on %s" % [property, targets[0].get_class()])
		return
	if refire_on_change:
		_replay(resource_path)

## Everything in the running game that is the saved resource at `resource_path`: the resource
## itself while something still holds it, and every copy made of it. A JuiceePlayer swaps its
## sequences for copies of its own when it is ready, and then nothing holds the saved one, so
## load() on its sub-resource path found nothing and the set stopped there, before the copies
## the game was playing. Only the cache is asked: a sub-resource path is no file to load.
func _instances(resource_path: String) -> Array[Object]:
	var out: Array[Object] = []
	if ResourceLoader.has_cached(resource_path):
		var saved := load(resource_path)
		if saved:
			out.append(saved)
	for ref in _copies.get(resource_path, []):
		var copy: Object = (ref as WeakRef).get_ref()
		if copy and not out.has(copy):
			out.append(copy)
	return out

func _replay(resource_path: String) -> void:
	var res: Variant = load(resource_path) if ResourceLoader.has_cached(resource_path) else null
	# The copy that last ran there, which is the one the game is actually playing.
	var last: Variant = (_last_effect[resource_path] as WeakRef).get_ref() if _last_effect.has(resource_path) else null
	if last is JuiceeEffect:
		res = last
	if not (res is JuiceeEffect):
		return
	var context: Node = _last_context.get(resource_path, null)
	if not is_instance_valid(context) or not context.is_inside_tree():
		return
	var effect := res as JuiceeEffect
	# stop() first so a held effect (a loop, a long ramp) restarts cleanly rather than
	# stacking a second run on top of the one being tuned.
	if effect.is_playing():
		effect.stop()
	effect.apply(context)
