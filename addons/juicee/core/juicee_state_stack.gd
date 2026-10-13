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
## `from_loop` says the caller writes this property from a manual loop rather than a
## tween. The stack does not act on it; it counts it, so an effect that is about to be
## silently overwritten can be told. See hold_counts().
static func capture(target: Variant, property: String, from_loop: bool = false) -> Variant:
	# Variant, not Object, as in release(): Godot 4.3 refuses a freed instance at a typed parameter.
	if not is_instance_valid(target) or not (target is Object):
		return null
	var key: String = "%d:%s" % [target.get_instance_id(), property]
	if _state.has(key):
		_state[key]["refs"] = (_state[key]["refs"] as int) + 1
		if from_loop:
			_state[key]["loop_refs"] = (_state[key]["loop_refs"] as int) + 1
		return _state[key]["original"]
	var original: Variant = target.get_indexed(property)
	_state[key] = {"original": original, "refs": 1, "loop_refs": 1 if from_loop else 0}
	return original

## Decrements the ref count. When it reaches 0, restores the original and clears state.
## Safe to call even if target was freed - stale entries are pruned automatically.
## Pass restore=false to drop the capture WITHOUT restoring - for effects that
## intentionally leave a permanent change (return_to_original=false / hold_at_end).
## Effects still holding the property then come back to the value it has now, not to the
## one before: a shake that outlasts a permanent move must not undo the move. keep() names
## the value instead, for when another effect may be writing the property right now.
static func release(target: Variant, property: String, restore: bool = true,
		from_loop: bool = false) -> void:
	# Variant, not Object: a target freed mid-effect is exactly what the branch below is for,
	# and an Object parameter makes GDScript refuse a freed instance before it is reached.
	if not is_instance_valid(target):
		# Target gone mid-effect - sweep any stale entries referencing dead instances.
		_prune_stale()
		return
	var now: Variant = null if restore else target.get_indexed(property)
	_drop(target, property, restore, now, from_loop)

## Drops a capture for a change the effect leaves in place, at `value`: effects still holding
## the property come back to `value` when the last of them lets go.
static func keep(target: Variant, property: String, value: Variant, from_loop: bool = false) -> void:
	if not is_instance_valid(target):
		_prune_stale()
		return
	_drop(target, property, false, value, from_loop)

static func _drop(target: Object, property: String, restore: bool, kept: Variant,
		from_loop: bool) -> void:
	var key: String = "%d:%s" % [target.get_instance_id(), property]
	if not _state.has(key):
		return
	var entry: Dictionary = _state[key]
	entry["refs"] = (entry["refs"] as int) - 1
	if from_loop:
		entry["loop_refs"] = maxi(0, (entry.get("loop_refs", 0) as int) - 1)
	if entry["refs"] > 0:
		if not restore:
			entry["original"] = kept
		return
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

## How many effects hold this property right now, and how many of those write it from
## a manual loop: x is the total, y is the loop-driven share. More than one holder with
## at least one loop among them is the combination where something goes invisible.
static func hold_counts(target: Variant, property: String) -> Vector2i:
	if not is_instance_valid(target) or not (target is Object):
		return Vector2i.ZERO
	var key: String = "%d:%s" % [target.get_instance_id(), property]
	if not _state.has(key):
		return Vector2i.ZERO
	var entry: Dictionary = _state[key]
	return Vector2i(entry["refs"] as int, entry.get("loop_refs", 0) as int)

## Loops that move a property by an offset around its original (shakes, wiggles, bobs) share it:
## each joins here, and every write sets the original plus all their offsets. Each writing its own
## original + offset, the last to wake in a frame won outright, so a weak shake landing after a
## strong one hid it. Measured at 60 fps: an intensity 20 shake down to 1.4 px under an intensity 2 one.
static func _join_offset(target: Object, property: String, holder: int) -> void:
	var key: String = "%d:%s" % [target.get_instance_id(), property]
	if not _state.has(key):
		return
	var entry: Dictionary = _state[key]
	if not entry.has("offsets"):
		entry["offsets"] = {}
	entry["offsets"][holder] = [null, 0.0]

static func _leave_offset(target: Variant, property: String, holder: int) -> void:
	if not is_instance_valid(target) or not (target is Object):
		return
	var key: String = "%d:%s" % [target.get_instance_id(), property]
	if _state.has(key) and _state[key].has("offsets"):
		(_state[key]["offsets"] as Dictionary).erase(holder)
		_state[key]["frame"] = -1

## How many holders of this property joined with _join_offset().
static func _offset_holders(target: Object, property: String) -> int:
	var key: String = "%d:%s" % [target.get_instance_id(), property]
	if not _state.has(key) or not _state[key].has("offsets"):
		return 0
	return (_state[key]["offsets"] as Dictionary).size()

## How far offsets that add up may reach together, against the widest of them alone. Picked: two
## hits shake more than one, a crowd of them does not shake the screen apart.
const OFFSETS_REACH := 1.5

## Sets this holder's offset and writes `original` plus every joined offset. `reach` is how far
## this holder's offset goes at the moment (its amplitude, not this sample). The offsets add up in
## full until together they would reach past OFFSETS_REACH times the widest one, and are scaled
## down to it beyond that. Alone, it writes original + offset.
static func _write_offset(target: Object, property: String, holder: int, original: Variant,
		offset: Variant, reach: float) -> void:
	var key: String = "%d:%s" % [target.get_instance_id(), property]
	var entry: Dictionary = _state.get(key, {})
	var offsets: Dictionary = entry.get("offsets", {})
	if offsets.size() < 2 or not offsets.has(holder):
		if offsets.has(holder):
			offsets[holder] = [offset, absf(reach)]
		target.set_indexed(property, original + offset)
		return
	var before: Array = offsets[holder]
	offsets[holder] = [offset, absf(reach)]
	# The whole sum once a frame, and each later write that frame changes it by its own part: N
	# holders cost N a frame rather than N times N. Measured at 200 shakes on one camera, 81 ms a
	# frame summing on every write.
	var frame := Engine.get_process_frames()
	var patchable: bool = entry.get("frame", -1) == frame and before[0] != null
	patchable = patchable and typeof(before[0]) == typeof(offset) and typeof(entry.get("sum")) == typeof(offset)
	if not patchable:
		var sum: Variant = offset - offset
		var power := 0.0
		var widest := 0.0
		for held in offsets.values():
			if held[0] == null or typeof(held[0]) != typeof(offset):
				continue
			sum += held[0]
			power += held[1] * held[1]
			widest = maxf(widest, held[1])
		entry["sum"] = sum
		entry["power"] = power
		entry["widest"] = widest
		entry["frame"] = frame
	else:
		entry["sum"] += offset - before[0]
		entry["power"] += absf(reach) * absf(reach) - before[1] * before[1]
		entry["widest"] = maxf(entry["widest"], absf(reach))
	var total: Variant = entry["sum"]
	# Independent offsets add up to about the root of the sum of their squares.
	var together := sqrt(maxf(entry["power"], 0.0))
	if together > 0.0:
		total = total * minf(1.0, OFFSETS_REACH * (entry["widest"] as float) / together)
	target.set_indexed(property, original + total)

## For debugging - returns number of entries currently held.
static func active_count() -> int:
	return _state.size()

## Force-clear all state. Mainly for editor reloads / test resets.
static func reset() -> void:
	_state.clear()
