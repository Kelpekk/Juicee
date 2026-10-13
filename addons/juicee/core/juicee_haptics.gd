@tool
class_name JuiceeHaptics
## The only thing in Juicee that calls Input.start_joy_vibration.
##
## Godot's rumble API replaces rather than mixes, and one stop_joy_vibration
## silences everything. Measured on an XInput pad: a rumble running at 0.9 that is
## overlapped by a 0.1 one drops to 0.1, and stays at 0.1 after the short one has
## finished. So a landing thump lands on top of a crash and takes 89% of it away,
## then leaves the wrong value on the controller.
##
## There is no way to fix that from the calling side, because two writers to a
## replacing API is the bug. One writer is the fix: effects hand their rumble here,
## this holds them all, and issues one call per device per frame.
##
## Kept deliberately small. Godot exposes two motor magnitudes and a duration, with
## no frequency channel of any kind, so there is no richer model to build - anything
## with a `frequency` parameter would be a lie in the signature.
extends Node

## How the overlapping rumbles combine. Max rather than sum: two medium hits
## summing to 1.0 reads as a bug, while "the strongest thing happening right now"
## is what a player expects a controller to convey.
const MIX_MAX := true

## Each frame's call asks for slightly more than a frame, so the motors never
## outlive this node's control of them. Refreshed every frame while anything plays.
const FRAME_LEASE := 0.12

class Rumble extends RefCounted:
	var device: int
	var weak: float
	var strong: float
	var duration: float
	var elapsed: float = 0.0
	var fade_out: bool = false
	var cancelled: bool = false

	func level() -> Vector2:
		if cancelled or elapsed >= duration:
			return Vector2.ZERO
		var k := 1.0
		if fade_out and duration > 0.0:
			k = 1.0 - (elapsed / duration)
		return Vector2(weak * k, strong * k)

var _active: Array[Rumble] = []
## Devices this wrote to last frame, so a device that just went quiet gets one
## explicit stop instead of being left buzzing on its lease.
var _touched: Dictionary = {}
## When the last frame was, on the clock Engine.time_scale leaves alone.
var _last := -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # a hit-stop must not freeze the motors

func _process(_delta: float) -> void:
	# Real time, not the frame's delta, which Engine.time_scale scales: the player's hands are
	# not in slow motion, and a 0.25 s rumble under a ramp to 0.2 lasted 1.2 s, under a hit-stop
	# for as long as the stop.
	var now := JuiceeEffect.unscaled_seconds()
	var delta := 0.0 if _last < 0.0 else maxf(now - _last, 0.0)
	_last = now
	if _active.is_empty():
		if not _touched.is_empty():
			_silence_untouched({})
		return

	var per_device: Dictionary = {}
	for i in range(_active.size() - 1, -1, -1):
		var r := _active[i]
		r.elapsed += delta
		var lvl := r.level()
		if lvl == Vector2.ZERO:
			_active.remove_at(i)
			continue
		var current: Vector2 = per_device.get(r.device, Vector2.ZERO)
		per_device[r.device] = Vector2(maxf(current.x, lvl.x), maxf(current.y, lvl.y))

	for device in per_device:
		var lvl: Vector2 = per_device[device]
		Input.start_joy_vibration(int(device), lvl.x, lvl.y, FRAME_LEASE)
	_silence_untouched(per_device)
	_touched = per_device

## A device that had rumble last frame and none this frame is stopped once, rather
## than left to run out its lease.
func _silence_untouched(now: Dictionary) -> void:
	for device in _touched:
		if not now.has(device):
			Input.stop_joy_vibration(int(device))
	if now.is_empty():
		_touched = {}

# --- API ---------------------------------------------------------------------

## Add a rumble to the mix. The handle it returns can be stopped early; ignoring it
## is fine, the rumble expires on its own.
func play(device: int, weak: float, strong: float, duration: float,
		fade_out: bool = false) -> Rumble:
	var r := Rumble.new()
	r.device = device
	# NaN slips through a clamp and on to the motors; a magnitude that is no number is none.
	r.weak = clampf(weak, 0.0, 1.0) if is_finite(weak) or weak > 1.0 else 0.0
	r.strong = clampf(strong, 0.0, 1.0) if is_finite(strong) or strong > 1.0 else 0.0
	# An infinite duration rumbles until stopped, which is what it asks for; NaN is no time at all.
	r.duration = maxf(duration, 0.0) if not is_nan(duration) else 0.0
	r.fade_out = fade_out
	_active.append(r)
	return r

## Ends one rumble without touching the others.
func stop(handle: Rumble) -> void:
	if handle:
		handle.cancelled = true

## Ends everything, on one device or on all of them.
func stop_all(device: int = -1) -> void:
	for r in _active:
		if device < 0 or r.device == device:
			r.cancelled = true

## How many rumbles are currently in the mix. For tests and debug overlays.
func active_count() -> int:
	return _active.size()
