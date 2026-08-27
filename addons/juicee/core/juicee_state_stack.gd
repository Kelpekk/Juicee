## Ref-counted "original state" manager - fixes the concurrent restore bug.
##
## Problem this solves:
## [codeblock]
##   Effect A starts: original = cam.offset  # = (0, 0)
##   ... shake in progress, cam.offset = (5, -3) ...
##   Effect B starts: original = cam.offset  # WRONG! captured mid-shake (5, -3)
##   Effect A finishes: cam.offset = (0, 0)  # correct
##   Effect B finishes: cam.offset = (5, -3)  # camera now stuck at shake mid-frame
## [/codeblock]
##
## With this stack:
## - First effect to touch (target, property) captures the TRUE original.
## - Subsequent effects increment a ref count and get back the true original.
## - When the LAST effect releases, the true original is restored.
##
## Usage pattern in an effect:
## [codeblock]
## var original = JuiceeStateStack.capture(target, "modulate")
## # ... modify target.modulate freely ...
## JuiceeStateStack.release(target, "modulate")
## [/codeblock]
@tool
class_name JuiceeStateStack
extends RefCounted

static var _state: Dictionary = {}

## Captures the original value of `target.<property>` and increments the ref count.
## If another effect already captured it, returns the same original value (the FIRST capture).
## Property may be a sub-path like "modulate:a" - Object.get_indexed handles those.
static func capture(target: Object, property: String) -> Variant:
	if not is_instance_valid(target):
		return null
	var key: String = "%d:%s" % [target.get_instance_id(), property]
	if _state.has(key):
		_state[key]["refs"] = (_state[key]["refs"] as int) + 1
		return _state[key]["original"]
	var original: Variant = target.get_indexed(property)
	_state[key] = {"original": original, "refs": 1}
	return original

## Decrements the ref count. When it reaches 0, restores the original and clears state.
## Safe to call even if target was freed - stale entries are pruned automatically.
## Pass restore=false to drop the capture WITHOUT restoring - for effects that
## intentionally leave a permanent change (return_to_original=false / hold_at_end).
static func release(target: Object, property: String, restore: bool = true) -> void:
	if not is_instance_valid(target):
		# Target gone mid-effect - sweep any stale entries referencing dead instances.
		_prune_stale()
		return
	var key: String = "%d:%s" % [target.get_instance_id(), property]
	if not _state.has(key):
		return
	var entry: Dictionary = _state[key]
	entry["refs"] = (entry["refs"] as int) - 1
	if entry["refs"] <= 0:
		if restore:
			target.set_indexed(property, entry["original"])
		_state.erase(key)

## Removes entries whose target object is no longer valid (freed mid-effect).
## Called automatically on release(invalid_target). Safe to call manually.
static func _prune_stale() -> void:
	var stale_keys: Array = []
	for k in _state.keys():
		var parts: PackedStringArray = (k as String).split(":", true, 1)
		if parts.size() < 1:
			continue
		var iid: int = int(parts[0])
		if instance_from_id(iid) == null:
			stale_keys.append(k)
	for k in stale_keys:
		_state.erase(k)

## For debugging - returns number of entries currently held.
static func active_count() -> int:
	return _state.size()

## Force-clear all state. Mainly for editor reloads / test resets.
static func reset() -> void:
	_state.clear()
