## Base class for all Juicee effects.
##
## Subclasses override `_apply(context, intensity_mult)` to do work.
## All effects get for free: randomization (chance, intensity_min/max), pre-delay,
## cooldown, runtime params, stop() / is_playing() state queries, and tween tracking
## (so stop() actually kills tween-driven effects mid-flight).
@tool
class_name JuiceeEffect
extends Resource

signal started
signal finished
signal stopped
## Fires once the apply() call enters its pre-delay wait. The graph editor's
## debug walker uses it to draw a fill bar showing the countdown.
signal delay_started(seconds: float)
## Fires whenever the effect bails out on a bad setup - wrong target type, an empty
## resource, a missing node. Every such case already calls _warn() (below) instead of
## push_warning() directly, so the editor's Preview and graph Test can flash the exact
## thing that went wrong instead of it only ever reaching the Output panel.
signal warning(message: String)

## Turns this effect off without deleting it. A muted effect is skipped by apply(),
## by sequences and by the graph, so you can A/B a step while tuning and put it back
## with one click instead of rebuilding it.
@export var enabled: bool = true

@export_group("Randomization")
## Probability (0-1) that this effect actually fires when triggered.
## 1.0 = always fires, 0.5 = fires half the time, 0.0 = never fires.
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
## Pre-delay in seconds before the effect starts. Useful for chaining timing within a sequence.
@export_range(0.0, 10.0, 0.01) var delay: float = 0.0
## Lower bound of a random multiplier applied to the effect's intensity each play.
## Set both intensity_min and intensity_max to 1.0 to disable randomization.
@export_range(0.1, 5.0, 0.01) var intensity_min: float = 1.0
## Upper bound of the random intensity multiplier.
@export_range(0.1, 5.0, 0.01) var intensity_max: float = 1.0

@export_group("Cooldown")
## Minimum seconds between successive apply() calls on this effect resource.
## 0 = no cooldown. Useful for spam-prevention without wrapping in a JuiceePlayer.
@export_range(0.0, 10.0, 0.01) var cooldown: float = 0.0

## Position of this effect's block in the visual graph editor. Saved, but kept out of the
## Inspector: it is the graph's bookkeeping, and moving the block is how you change it.
@export_storage var graph_position: Vector2 = Vector2.ZERO

## Global accessibility settings - set by the Juicee autoload in _ready().
## Automatically consulted in apply() so subclasses need zero extra code.
static var accessibility: JuiceeAccessibility = JuiceeAccessibility.new()

## The rumble mixer, set by the Juicee autoload. Null when the addon is used without
## its autoload, in which case rumble falls back to calling Input directly - the old
## behaviour, overlap bug and all, but at least it still buzzes.
static var haptics: JuiceeHaptics = null

## Live tuning bridge, set by the Juicee autoload in a debug build with the editor
## attached. Null everywhere else, including every exported game, so the note_context()
## call in apply() costs one null check and nothing more.
static var live_tune: JuiceeLiveTune = null

## Project Settings > Juicee > Preview. The editor-preview hint is the coloured border
## and label that wrap the viewport when you preview a full-screen effect in the editor
## (Test / Preview Effect). These let a project hide that overlay or recolour its border.
const PREVIEW_HINT_SETTING := "juicee/preview/editor_hint_visible"
const PREVIEW_BORDER_COLOR_SETTING := "juicee/preview/editor_border_color"
const PREVIEW_BORDER_COLOR_DEFAULT := Color(1.0, 0.78, 0.30, 0.85)

## Project Settings > Juicee > Pixel Scale. One multiplier for every pixel-distance an
## effect moves or spawns over (shake in px, hop height, particle speed and spread,
## damage-number rise, etc.). A 32px pixel-art game and a 1080p game want very different
## absolute distances - set this once and the pixel-based effects scale to match. Scale,
## rotation, colour and full-screen shader effects ignore it: they are already
## resolution-independent. Wrap a pixel value in _px() to opt an effect in.
const PIXEL_SCALE_SETTING := "juicee/pixel_scale"
static var pixel_scale: float = float(ProjectSettings.get_setting(PIXEL_SCALE_SETTING, 1.0))

## Scale a pixel distance by the project's pixel_scale.
func _px(value: float) -> float:
	return value * pixel_scale

## Project Settings > Juicee > Advanced Properties. Off by default so every effect shows a
## small, curated parameter set with strong defaults. Turn it on to reveal the advanced
## knobs on the effects that have them (extra modes, presets, fine controls) - full power
## without cluttering the inspector for everyone. Effects gate their advanced @export vars
## by name with _gate_advanced() inside _validate_property(); the values still work and
## persist at runtime, only their editor visibility is gated.
const ADVANCED_SETTING := "juicee/advanced_properties"

## Extra folders the editor scans for effects, on top of the addon's own.
##
## Keeping a custom effect in `addons/juicee/effects/` is what the docs used to say,
## and it loses the file: the Asset Library refuses to overwrite conflicting files, so
## the standard way to update an addon is to delete its folder and install again.
## Anything of yours in there goes with it. Point this at a folder of your own and the
## picker in the Inspector and the graph's add-node popup both list what is in it.
const EFFECT_FOLDERS_SETTING := "juicee/effect_folders"

static func advanced_enabled() -> bool:
	return bool(ProjectSettings.get_setting(ADVANCED_SETTING, false))

## Hide the named @export properties from the inspector unless Advanced Properties is on.
## Call from a subclass's _validate_property() with that effect's list of advanced vars.
func _gate_advanced(property: Dictionary, advanced_names: PackedStringArray) -> void:
	if not advanced_enabled() and advanced_names.has(property.name):
		property.usage &= ~PROPERTY_USAGE_EDITOR

## What every effect calls instead of push_warning() directly when apply() bails out on
## a bad setup. Still reaches the Output panel exactly as before - this only adds the
## warning signal on top, so the editor can show the same message on the card or block
## that caused it instead of it only ever showing up in a place most people don't watch.
## Seconds before the same message from this effect reaches the Output again. The signal is
## never held back; this is only about one misconfigured step on a fast trigger filling the log
## with one line over and over.
const WARN_REPEAT_AFTER := 5.0
var _warned_at: Dictionary = {}

## Whether this message is due to be printed again. Split out so it can be tested: nothing in
## GDScript can see what push_warning did.
func _should_log(message: String) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_warned_at.get(message, -WARN_REPEAT_AFTER - 1.0)) < WARN_REPEAT_AFTER:
		return false
	# A message that names a spawned node can be new on every play. Forgetting the ones old enough
	# to print again changes nothing, and keeps the list from growing for as long as the game runs.
	if _warned_at.size() >= 32:
		for old in _warned_at.keys():
			if now - float(_warned_at[old]) >= WARN_REPEAT_AFTER:
				_warned_at.erase(old)
	_warned_at[message] = now
	return true

func _warn(message: String) -> void:
	if _should_log(message):
		push_warning(message)
	warning.emit(message)

## Seconds of game time that Engine.time_scale and pausing leave alone, counted the way the engine
## counts frames, so it keeps step with --fixed-fps and Movie Maker where a wall clock does not.
## The clock is one long timer that ignores the time scale, which the engine steps by the unscaled
## time of each frame.
static func unscaled_seconds() -> float:
	if _clock == null or _clock.time_left <= 0.0:
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return Time.get_ticks_msec() / 1000.0
		_clock = tree.create_timer(_CLOCK_SPAN, true, false, true)
	return _CLOCK_SPAN - _clock.time_left

const _CLOCK_SPAN := 1.0e7
static var _clock: SceneTreeTimer = null

## Per script, the exported settings checked before every play: [name, the enum's values or null].
static var _checked_settings: Dictionary = {}

## The first exported setting no play could make sense of, described for a warning, or "".
func _invalid_setting() -> String:
	var script := get_script() as Script
	if not _checked_settings.has(script):
		var list: Array = []
		for p in get_property_list():
			var usage := int(p["usage"])
			if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (usage & PROPERTY_USAGE_STORAGE) \
					or str(p["name"]) == "graph_position":
				continue
			if int(p["type"]) == TYPE_INT and int(p["hint"]) == PROPERTY_HINT_ENUM:
				list.append([p["name"], _enum_values(str(p["hint_string"]))])
			elif int(p["type"]) in _CHECKED_TYPES:
				list.append([p["name"], null])
		_checked_settings[script] = list
	for entry in _checked_settings[script]:
		var value: Variant = get(entry[0])
		if entry[1] != null:
			if not (entry[1] as Array).has(int(value)):
				return "'%s' is %s, which is none of its choices" % [entry[0], value]
		elif not _all_finite(value):
			return "'%s' is %s" % [entry[0], str(value).substr(0, 40)]
	return ""

const _CHECKED_TYPES := [TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_COLOR,
	TYPE_RECT2, TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY,
	TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY]

## The values an enum's hint string allows: "A,B,C" counts from 0, "A:4,B" from what it says.
static func _enum_values(hint: String) -> Array:
	var out: Array = []
	var next := 0
	for item in hint.split(","):
		var value := item.get_slice(":", item.get_slice_count(":") - 1).strip_edges()
		if item.contains(":") and value.is_valid_int():
			next = int(value)
		out.append(next)
		next += 1
	return out

## False for NaN or infinity anywhere in a number, vector, colour or array of them.
static func _all_finite(value: Variant) -> bool:
	match typeof(value):
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_VECTOR2:
			return (value as Vector2).is_finite()
		TYPE_VECTOR3:
			return (value as Vector3).is_finite()
		TYPE_VECTOR4:
			return (value as Vector4).is_finite()
		TYPE_RECT2:
			return (value as Rect2).is_finite()
		TYPE_COLOR:
			var c: Color = value
			return is_finite(c.r) and is_finite(c.g) and is_finite(c.b) and is_finite(c.a)
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, \
				TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			for item in value:
				if not _all_finite(item):
					return false
	return true

## The most an 'intensity' passed to apply() counts for.
const MAX_INTENSITY := 10

## A runtime parameter of this play, when it is of the type `fallback` is, the type the effect
## uses; `fallback` when it is missing. A number stands in for the other kind of number, a
## Vector2i for a Vector2, a colour name or code for a Color. Anything else, a string where a
## direction goes, is left out with a warning: one wrong value at the call site should not stop
## the whole play with a script error.
func _param(key: String, fallback: Variant) -> Variant:
	if not _runtime_params.has(key):
		return fallback
	var value: Variant = _runtime_params[key]
	var have := typeof(value)
	var want := typeof(fallback)
	if have == want:
		return value
	match want:
		TYPE_FLOAT:
			if have == TYPE_INT:
				return float(value)
		TYPE_INT:
			if have == TYPE_FLOAT:
				return int(value)
		TYPE_BOOL:
			if have == TYPE_INT:
				return value != 0
		TYPE_VECTOR2:
			if have == TYPE_VECTOR2I:
				return Vector2(value)
		TYPE_COLOR:
			if have == TYPE_STRING or have == TYPE_STRING_NAME:
				# A code or a name it knows reads the same whatever the default is.
				var text := String(value)
				var read := Color.from_string(text, Color.BLACK)
				if read == Color.from_string(text, Color.WHITE):
					return read
	_warn("%s: '%s' passed to apply() is %s, where a %s goes, so this play leaves it out"
			% [_class_label(), key, type_string(have), type_string(want)])
	return fallback

## The params of one play without what no play could use. A NaN or an infinity is left out, so
## the effect does what it would with that key missing. The caller's dictionary is not touched.
func _usable_params(params: Dictionary) -> Dictionary:
	var unusable: Array = []
	for key in params:
		if not _all_finite(params[key]):
			unusable.append(key)
	if unusable.is_empty():
		return params
	var out := params.duplicate()
	for key in unusable:
		_warn("%s: '%s' passed to apply() is %s, so this play leaves it out"
				% [_class_label(), key, str(params[key]).substr(0, 40)])
		out.erase(key)
	return out

## The Environment the context actually renders through, for the effects that punch a
## WorldEnvironment property. Lived in two effects as a copied pair of functions, and
## the copies drifted: one learned to look in the context's own viewport and the other
## never did, so Tonemap quietly found nothing anywhere Bloom worked fine.
##
## Viewport first, because that is the environment that affects how the context
## renders. It also keeps an effect fired inside a SubViewport (the editor's hover
## preview) from reaching into another scene, and it is the right answer for
## split-screen. The current scene is the fallback for the ordinary single-viewport
## case, and the context itself when there is no current scene, which is what an
## autoload or a node added straight to the root gets.
func _find_active_environment(context: Node) -> Environment:
	if not context:
		return null
	var vp := context.get_viewport()
	if vp:
		var in_viewport := _scan_for_env(vp)
		if in_viewport:
			return in_viewport
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree else context
	if not root:
		root = context
	return _scan_for_env(root)

func _scan_for_env(node: Node) -> Environment:
	if node == null:
		return null
	if node is WorldEnvironment:
		var we := node as WorldEnvironment
		if we.environment:
			return we.environment
	for child in node.get_children():
		var found := _scan_for_env(child)
		if found:
			return found
	return null

## Property names that hold an audio bus, across the audio effects.
const BUS_PROPERTIES := ["bus", "bus_name", "pitch_bus"]

## Turns a bus-name property into a dropdown of the project's actual buses, read live
## from AudioServer. Typing a bus name by hand is a silent failure: the effect routes
## to a bus that isn't there and you hear nothing, with no error to follow. Call from a
## subclass's _validate_property(). Pass allow_empty for properties where blank means
## "leave the audio alone" rather than a bus.
func _hint_audio_bus(property: Dictionary, allow_empty: bool = false) -> void:
	if not BUS_PROPERTIES.has(String(property.name)):
		return
	var names := PackedStringArray()
	if allow_empty:
		names.append("")
	for i in AudioServer.bus_count:
		names.append(String(AudioServer.get_bus_name(i)))
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(names)

## Turns an InputMap action-name property into a dropdown of the project's actual
## actions, read live from InputMap. The same silent failure as an unknown bus: type it
## wrong and Input.is_action_just_pressed() just returns false forever, so a "wait for
## input" step can hang a sequence with nothing to say why. Every project also carries
## roughly 90 built-in "ui_*" actions for text fields, dialogs and the editor itself;
## those are filtered out (keeping the handful actually meant for gameplay - accept,
## select, cancel) so the list is project actions plus a short useful default, not a
## wall of ui_text_caret_up entries.
func _hint_input_action(property: Dictionary, prop_name: String = "action") -> void:
	if String(property.name) != prop_name:
		return
	var names := PackedStringArray()
	for a in InputMap.get_actions():
		var s := String(a)
		if s.begins_with("ui_") and not (s in ["ui_accept", "ui_select", "ui_cancel"]):
			continue
		names.append(s)
	var sorted_names := Array(names)
	sorted_names.sort()
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(PackedStringArray(sorted_names))


## Runtime parameters passed by the caller (e.g., {"hit_direction": Vector2.LEFT}).
var _runtime_params: Dictionary = {}

## True between started/finished - query via is_playing(). Manual-loop effects also
## should check this and break early so stop() works.
var _active: bool = false
## True if stop() was called during the current play - manual loops bail out on this.
var _cancelled: bool = false
## Time of last apply() (in seconds, from unscaled_seconds()). Used by cooldown.
var _last_apply_time: float = -1e9
## Tweens created during the current play - killed by stop(). Subclasses MUST wrap
## their `create_tween()` calls with `_track()` for stop() to work on them.
var _active_tweens: Array[Tween] = []
## JuiceeStateStack captures for this play. Populated by _capture_state().
## stop() releases all entries so tween-killed effects still restore properties.
var _state_captures: Array = []
## True between the start of apply() and when the effect either starts playing or
## is blocked (cooldown, chance). _play_parallel uses this to avoid exiting the
## polling loop prematurely when all effects have a non-zero delay.
var _pending_start: bool = false
## Monotonic counter bumped by every apply() and every stop(). Each coroutine
## captures its own snapshot and bails out (without emitting finished or touching
## state) once the global counter has moved past it - that's how spam-clicking
## play during a delay yields ONE effect run instead of N queued ones.
var _gen: int = 0

## Entry point used by JuiceeSequence - handles cooldown/chance/delay/intensity,
## then calls _apply() and emits signals. Do NOT override; override `_apply()`.
## Fire-and-forget callers (the Juicee.* singleton) drop their local reference the
## moment apply() suspends. Tween-based effects survive (the tween lives on the
## target node), but coroutine-loop effects (jiggle, screen overlays) animate
## manually and would be garbage-collected mid-play. Holding a strong ref here for
## the duration of the play keeps them alive.
static var _alive: Array = []
func _alive_keep() -> void:
	if not _alive.has(self):
		_alive.append(self)
func _alive_drop() -> void:
	_alive.erase(self)

## The node this play is animating, watched so the effect can stop itself when the
## node goes away (scene change, queue_free) instead of running on against a corpse.
var _watched_context: Node = null

func _watch_context(context: Node) -> void:
	_unwatch_context()
	if context == null or not is_instance_valid(context):
		return
	_watched_context = context
	context.tree_exiting.connect(_on_context_exiting, CONNECT_ONE_SHOT)

func _unwatch_context() -> void:
	if _watched_context and is_instance_valid(_watched_context) \
			and _watched_context.tree_exiting.is_connected(_on_context_exiting):
		_watched_context.tree_exiting.disconnect(_on_context_exiting)
	_watched_context = null

func _on_context_exiting() -> void:
	# Fires while the node is still valid, so stop() can restore properties and run
	# its cleanup callbacks before the node is actually freed.
	_watched_context = null   # the one-shot connection is already gone
	if _active or _pending_start:
		stop()

## Takes an audio effect this play added back off its bus. Found by identity, not slot,
## since slots shift when another effect on the bus comes off first.
static func _remove_bus_effect(bus_name: String, fx: AudioEffect) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0 or fx == null:
		return
	for i in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i) == fx:
			AudioServer.remove_bus_effect(idx, i)
			return

## Cleanup callbacks run by stop(). A killed tween never resumes `await
## tween.finished`, so any cleanup an effect does AFTER that await (freeing a
## spawned overlay, removing an audio-bus effect) is skipped on stop(). Effects
## that hold such non-state-stack resources register a callback here; stop() runs
## them. State-stack restores are handled separately by stop() and need no callback.
var _stop_cleanup: Array[Callable] = []
## Cleanup a restart leaves alone, for what a play spawns to outlive the next play of the same
## effect: Floating Text's labels stack when it is fired again, and only stop() clears them all.
var _stop_only_cleanup: Array[Callable] = []
## A new apply() runs the callbacks too, for the play it replaces, unless `outlives_restart`.
func _on_stop(cb: Callable, outlives_restart: bool = false) -> void:
	if outlives_restart:
		_stop_only_cleanup.append(cb)
	else:
		_stop_cleanup.append(cb)

## Frees `node` on stop() if it is still there by then. Bound to the node's id rather than a
## lambda that captures the node: a lambda whose captured node has been freed reports an error
## when it is called, whatever its body checks, and spawned nodes are often freed before stop().
## A node that outlives a restart is kept track of until it is gone, past the end of its own play
## too, so a stop() after later plays still takes it down.
func _free_on_stop(node: Node, outlives_restart: bool = false) -> void:
	if outlives_restart:
		_outlive(node, _free_by_id.bind(node.get_instance_id()))
	else:
		_on_stop(_free_by_id.bind(node.get_instance_id()))

## Stops a sound player this play started at the next stop(), however many plays later. Firing
## again leaves it ringing out under the next shot.
func _end_sound_on_stop(player: Node) -> void:
	_outlive(player, _end_sound_by_id.bind(player.get_instance_id()))

## What plays spawned that outlives them and their restarts, a sound ringing out or a label still
## floating, as [id, callback]: run by stop() for whatever is still there. Dropped as each thing
## goes, so an effect fired all game long does not pile them up.
var _outliving: Array = []

func _outlive(node: Node, cb: Callable) -> void:
	_outliving = _outliving.filter(func(entry: Array) -> bool: return is_instance_id_valid(entry[0]))
	_outliving.append([node.get_instance_id(), cb])

## What a play that ended holding something on purpose gives back: an overlay left up by
## fade_out off, a hold, a duration of 0. Kept past the end of the play and run by the next
## stop() or the next play of this effect. Before, nothing could take such a state away again.
var _hold_cleanup: Array[Callable] = []
## The same, left alone by the next play: a sound that rings out while the next shot fires.
var _hold_stop_only: Array[Callable] = []

func _hold_until_stop(cb: Callable, outlives_restart: bool = false) -> void:
	if outlives_restart:
		_hold_stop_only.append(cb)
	else:
		_hold_cleanup.append(cb)

## Frees `node`, which this play is leaving in place when it ends, at the next stop() or play.
func _free_when_released(node: Node) -> void:
	_hold_until_stop(_free_by_id.bind(node.get_instance_id()))

## True when a play has ended but left something in place that stop() gives back: an overlay it
## holds, a property still held on the stack (fade_out off, hold_at_end), or a sound still ringing.
func is_holding() -> bool:
	return not _active and not _pending_start and (not _hold_cleanup.is_empty() \
			or not _hold_stop_only.is_empty() or not _state_captures.is_empty() or _outlived())

## Whether something a play spawned to outlive it, a sound still ringing, is still there.
func _outlived() -> bool:
	for entry in _outliving:
		if is_instance_id_valid(entry[0]):
			return true
	return false

## A copy of `res`, an effect or a JuiceeSequence, with every effect and sequence inside it copied
## as well and everything else (curves, textures, sounds) shared. An effect plays one play at a
## time, so two nodes playing one resource take it from each other mid-play; a copy each keeps them
## apart. A resource reached twice stays one copy, so a chain that loops back still does. A copy of
## an effect saved in a file follows live tuning of that file.
static func own_copy(res: Resource, copies: Dictionary = {}) -> Resource:
	if res == null:
		return null
	if copies.has(res):
		return copies[res]
	var copy := res.duplicate(false)
	copies[res] = copy
	# A sequence answers to its file name when it has no resource name, and a copy has no file.
	if copy.resource_name.is_empty() and not res.resource_path.is_empty():
		copy.resource_name = res.resource_path.get_file().get_basename()
	if not res.resource_path.is_empty():
		copy.set_meta(&"_juicee_path", res.resource_path)
		if live_tune:
			live_tune.track_copy(res.resource_path, copy)
	for p in res.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = copy.get(p["name"])
		if value is JuiceeEffect or value is JuiceeSequence:
			copy.set(p["name"], own_copy(value, copies))
		elif value is Array:
			# A shallow duplicate shares its arrays with the original, so a sound added to the
			# copy's list would be added to the original's too.
			var items: Array = (value as Array).duplicate()
			for i in items.size():
				if items[i] is JuiceeEffect or items[i] is JuiceeSequence:
					items[i] = own_copy(items[i], copies)
			copy.set(p["name"], items)
		elif value is Dictionary:
			copy.set(p["name"], (value as Dictionary).duplicate())
	return copy

## The path live tuning knows this effect by: its own, or the one it was copied from.
func _tuning_path() -> String:
	if not resource_path.is_empty():
		return resource_path
	return str(get_meta(&"_juicee_path", ""))

## The play running now, to keep and check with _still_playing() after every await in _apply().
## A new apply() replaces the play and resets _cancelled for the one it starts, so a loop that
## only checks _cancelled carries on beside the new play, and what it releases at its end is the
## newer play's hold.
## [codeblock]
## var play := _play_id()
## while elapsed < duration and _still_playing(play):
##     ...
##     await ...
## if not _still_playing(play):
##     return
## _release_state(target, "position")
## [/codeblock]
func _play_id() -> int:
	return _gen

## False once the play `play_id` came from has been replaced by a new apply() or ended by stop().
func _still_playing(play_id: int) -> bool:
	return play_id == _gen

## How deep effects are starting effects within one frame: a Chain starting a Chain starting a
## Sequence and so on. Composites start their children through _start_child(), which cuts at
## MAX_NESTING: deeper than that, the children lead back to their parent and would start each other
## until the script stack ran out, which took the GDScript VM down with it.
static var _nesting := 0
static var _nesting_frame := -1
const MAX_NESTING := 64

## Starts `child` for a composite effect (Chain, Sequence, Beat Sync). False when it was not
## started: a child that is the composite itself, or a nesting too deep to be anything but a loop.
func _start_child(child: JuiceeEffect, context: Node, params: Dictionary) -> bool:
	if child == self:
		_warn("%s: it holds itself among its own effects, which was skipped" % _class_label())
		return false
	if _leads_to(child, self):
		_warn("%s: one of its effects leads back to it, and would start it again play after play for good, so it was skipped" % _class_label())
		return false
	var refused := start_nested(child, context, params)
	if not refused.is_empty():
		_warn("%s: %s" % [_class_label(), refused])
		return false
	# Stopping the composite stops what it started: a stopped Chain used to leave its shake going.
	if not _stop_cleanup.has(child.stop):
		_on_stop(child.stop)
	return true

## Whether `to` can be reached from `from` through the effects and sequences held inside it. A
## composite started from inside itself starts itself again, and when a step in between takes
## time, nothing in one frame is deep enough to cut it: it plays on for good.
static func _leads_to(from: Resource, to: Resource) -> bool:
	var stack: Array = [from]
	var seen := {}
	while not stack.is_empty():
		var res: Variant = stack.pop_back()
		if res == to:
			return true
		if not (res is Resource) or seen.has(res):
			continue
		seen[res] = true
		for p in (res as Resource).get_property_list():
			if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE):
				continue
			var value: Variant = (res as Resource).get(p["name"])
			if value is JuiceeEffect or value is JuiceeSequence:
				stack.append(value)
			elif value is Array:
				for item in value:
					if item is JuiceeEffect or item is JuiceeSequence:
						stack.append(item)
	return false

## _start_child() for a caller that is not an effect, like JuiceeSequence. Why the child was not
## started, or "" when it was.
static func start_nested(child: JuiceeEffect, context: Node, params: Dictionary) -> String:
	# The depth only ever builds up inside one frame's calls. A new frame starting from a stale
	# count, after a script error skipped a decrement, would refuse everything after it.
	var frame := Engine.get_process_frames()
	if frame != _nesting_frame:
		_nesting_frame = frame
		_nesting = 0
	if _nesting >= MAX_NESTING:
		return "its effects lead back to it, or nest more than %d deep, so that loop was cut" % MAX_NESTING
	_nesting += 1
	child.apply(context, params)
	_nesting -= 1
	return ""

## `value`, or `cap` with a warning when it is more than a play should make at once. For counts
## of things built in one frame (particles, lines, copies, tween steps), where a million froze the
## game for minutes. Every cap sits far above the top of its slider.
func _capped(value: int, cap: int, what: String) -> int:
	if value <= cap:
		return value
	_warn("%s: %s is %d, more than one play makes at once, so it makes %d" % [_class_label(), what, value, cap])
	return cap

## Advances a damped spring by `dt` and returns [displacement, velocity], for floats and Vector2s
## alike. The same update Jiggle Physics and Spring always used, which a spring too stiff or too
## damped for one step turned into NaN: such a spring is split into substeps now, and one beyond
## even those is at rest at once. Negative stiffness, damping and mass mean nothing and count as 0.
static func _spring_step(x: Variant, v: Variant, stiffness: float, damping: float, mass: float,
		dt: float) -> Array:
	var m := maxf(mass, 0.0001)
	var k := maxf(stiffness, 0.0) / m
	var c := maxf(damping, 0.0) / m
	var steps := clampi(ceili(maxf(sqrt(k) * dt, c * dt)), 1, 64)
	var h := dt / steps
	if sqrt(k) * h >= 1.9 or c * h >= 1.9:
		return [x * 0.0, v * 0.0]
	for i in steps:
		v = v + (x * -k - v * c) * h
		x = x + v * h
	return [x, v]

## A zoom a Camera2D accepts: it refuses 0 on either axis, so those become a hair from 0.
static func _camera_zoom(z: Vector2) -> Vector2:
	return Vector2(z.x if absf(z.x) >= 0.001 else 0.001, z.y if absf(z.y) >= 0.001 else 0.001)

## Stops a sound this play started, if it is still there, and wakes whatever waits for it to
## finish, which a freed player never would.
static func _end_sound_by_id(id: int) -> void:
	var player := instance_from_id(id) as Node
	if not player:
		return
	player.call("stop")
	player.emit_signal("finished")
	player.queue_free()

static func _free_by_id(id: int) -> void:
	var node := instance_from_id(id) as Node
	if node:
		node.queue_free()

## Sets a property on an object by id if it still exists. For stop() callbacks, for the same
## reason as _free_on_stop().
static func _set_by_id(id: int, property: StringName, value: Variant) -> void:
	var obj := instance_from_id(id)
	if obj:
		obj.set(property, value)

## An audio bus's volume as a property, so the state stack holds it as it holds a node's: effects
## that duck or wobble one bus together all come back to its volume from before the first of them.
## By name, so a bus moved or removed mid-play is never mistaken for another.
class BusVolume extends RefCounted:
	var bus: String
	var volume_db: float:
		get:
			var i := AudioServer.get_bus_index(bus)
			return AudioServer.get_bus_volume_db(i) if i >= 0 else 0.0
		set(value):
			var i := AudioServer.get_bus_index(bus)
			if i >= 0:
				AudioServer.set_bus_volume_db(i, value)

static var _bus_volumes: Dictionary = {}

## The one BusVolume for `bus`, so every effect holds the same one.
static func _bus_volume(bus: String) -> BusVolume:
	if not _bus_volumes.has(bus):
		var level := BusVolume.new()
		level.bus = bus
		_bus_volumes[bus] = level
	return _bus_volumes[bus]

## Waits for a tween left out of _track(): one on a node the play spawned, or one stop() lets run.
## Polled, since a tween whose node is freed is dropped without sending finished, and a coroutine
## awaiting that signal would wait, and stay in memory, for good.
static func _tween_done(tween: Tween) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	while tree and tween and tween.is_valid():
		await tree.process_frame

func apply(context: Node, params: Dictionary = {}) -> void:
	# A muted effect does nothing at all: no state captured, no signals, no cooldown
	# consumed - so muting a step leaves the rest of a sequence exactly as it was.
	if not enabled:
		return
	# Cooldown and chance decide whether this call plays at all, so they come before anything
	# happens to a play already running: a call they drop leaves that play to finish.
	if cooldown > 0.0:
		var now := unscaled_seconds()
		if now - _last_apply_time < cooldown:
			return
		_last_apply_time = now
	if chance < 1.0 and randf() > chance:
		return

	# Bump generation FIRST so any in-flight coroutine (mid-delay or mid-_apply)
	# will see a stale snapshot and bail out without finishing.
	_gen += 1
	var my_gen: int = _gen
	# The play this one replaces is put away as stop() would, without the signal, since a new
	# play is a restart. Its cleanup has to run as well, or whatever it spawned (an overlay, an
	# effect on a bus) stays for good. _cancelled is up while it goes, so a coroutine it wakes
	# that checks only that flag, as the docs once taught, ends too.
	_cancelled = true
	_end_play(true)
	_active = false
	_pending_start = true
	_cancelled = false

	# From here on the coroutine may suspend (delay / _apply) after the caller has
	# returned - keep this effect alive across the play so the GC can't reap it.
	_alive_keep()

	# A node that is not in the scene yet is the other way a play does nothing, and every _apply
	# used to check for itself and return without a word.
	if not context or not context.is_inside_tree():
		_warn("%s: the node it played on is not in the scene tree" % _class_label())
		_pending_start = false
		_alive_drop()
		return
	# No play can make anything of NaN or infinity, which reach the node as NaN, or of an enum
	# value that is none of its choices, which the engine reports as an error on every frame.
	var bad := _invalid_setting()
	if not bad.is_empty():
		_warn("%s: %s, so it did not play" % [_class_label(), bad])
		_pending_start = false
		_alive_drop()
		return
	params = _usable_params(params)

	if delay > 0.0:
		delay_started.emit(delay)
		await context.get_tree().create_timer(delay, true, false, false).timeout
		if my_gen != _gen:
			_pending_start = false
			_alive_drop()
			return  # superseded by a later apply() or stop()
		# The node went during the delay, freed with an enemy that died or a scene that changed:
		# the play never starts, as it would not on a node handed over gone.
		if not is_instance_valid(context) or not context.is_inside_tree():
			_pending_start = false
			_alive_drop()
			return
	var mult: float = 1.0
	if intensity_min != 1.0 or intensity_max != 1.0:
		mult = randf_range(intensity_min, intensity_max)
	# One play scaled by the caller, without a second copy of the resource: a light
	# hit and a heavy one fire the same sequence and read differently. Multiplies with
	# the randomization above rather than replacing it, so an effect that already
	# varies still varies. Zero skips the play, the same as a failed chance roll.
	if params.has("intensity"):
		var given: Variant = params["intensity"]
		if typeof(given) == TYPE_FLOAT or typeof(given) == TYPE_INT:
			# Ten times the hit is far past anything a game means. Beyond it a stutter froze time
			# for good and a zoom lost its precision and reached 0.
			if float(given) > MAX_INTENSITY:
				_warn("%s: 'intensity' passed to apply() is %s, more than %d, so it plays at %d"
						% [_class_label(), given, MAX_INTENSITY, MAX_INTENSITY])
			mult *= clampf(float(given), 0.0, MAX_INTENSITY)
		else:
			_warn("%s: 'intensity' passed to apply() is %s, not a number, so it was left out"
					% [_class_label(), type_string(typeof(given))])
	# Accessibility gate - scales or silences effects based on player preferences.
	mult *= accessibility.effective_multiplier(get_accessibility_tag())
	if not is_finite(mult):
		_warn("%s: its strength came out as %s, so it did not play" % [_class_label(), mult])
	if not is_finite(mult) or mult <= 0.0:
		_pending_start = false
		_alive_drop()
		return

	# A play aimed at the wrong kind of node moves to the right one where there is one.
	context = _retarget(context)
	_pending_start = false
	_runtime_params = params
	_active = true
	# Remember where this ran, so the editor's live tuning can replay it here after a
	# parameter change. Debug-only: live_tune is null in an exported game.
	if live_tune:
		live_tune.note_context(self, context)
	started.emit()
	# A fire-and-forget effect has no node of its own, so nothing tells it when the
	# thing it is animating goes away. Watch the context: if it leaves the tree (a
	# scene change frees it, or someone queue_free()s it), stop and clean up now,
	# while the target is still valid enough to restore. Without this the coroutine
	# keeps running against a freed node.
	_watch_context(context)
	# The base _apply is not a coroutine; the subclass that overrides it usually is.
	@warning_ignore("redundant_await")
	await _apply(context, mult)
	# Superseded by a later apply() or ended by stop(), which own everything now. This comes
	# first: the watch, the keep-alive and the cleanup list below belong to whichever play is
	# current, and a play resuming late would otherwise take them from the newer one.
	if my_gen != _gen:
		return
	_unwatch_context()
	_alive_drop()
	# _apply finished naturally, so it already ran its own cleanup - drop the stop
	# callbacks so a later stray stop() can't double-free.
	_stop_cleanup.clear()
	_stop_only_cleanup.clear()
	_active = false
	_runtime_params = {}
	_active_tweens.clear()
	finished.emit()

## Override this in subclasses. `intensity_mult` is 1.0 unless randomization is enabled.
@warning_ignore("unused_parameter")
func _apply(context: Node, intensity_mult: float) -> void:
	pass

## Override to declare which accessibility category this effect belongs to.
## The accessibility layer uses this to silence or scale the effect based on player prefs.
## Return one of JuiceeAccessibility.TAG_* (default TAG_NONE = always plays at full intensity).
func get_accessibility_tag() -> int:
	return JuiceeAccessibility.TAG_NONE

## Register a tween for cleanup-on-stop. Subclasses MUST use this for every Tween
## they create - otherwise stop() can't kill them. Usage:
## [codeblock]
## var tween := _track(target.create_tween())
## [/codeblock]
func _track(tween: Tween) -> Tween:
	if not tween:
		return tween
	if _waking:
		_late_tweens.append(tween)
	else:
		_active_tweens.append(tween)
		_watch_tweens()
	return tween

## A tween whose node is freed is dropped by the engine without sending finished, and a play
## awaiting it would stay playing for good: a zoom whose camera was freed, a sequence waiting on
## that zoom. Once a frame, while anything plays, such tweens are found and finished is sent for
## them, so the play wakes and finds its node gone. One connection for every effect.
static var _watching_tweens := false

static func _watch_tweens() -> void:
	if _watching_tweens:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		_watching_tweens = true
		tree.process_frame.connect(_wake_dropped_tweens)

static func _wake_dropped_tweens() -> void:
	for effect in _alive.duplicate():
		(effect as JuiceeEffect)._wake_dropped()

func _wake_dropped() -> void:
	var dropped: Array[Tween] = []
	for t in _active_tweens:
		# Still running but no longer valid: dropped with its node. A tween that finished or was
		# killed is not running.
		if is_instance_valid(t) and not t.is_valid() and t.is_running():
			dropped.append(t)
	for t in dropped:
		_active_tweens.erase(t)
		t.finished.emit()

## Capture a property for state-restore, registering it for cleanup-on-stop().
## Use instead of JuiceeStateStack.capture() in tween-based effects so stop()
## can restore the property even when the tween's finished signal never fires.
func _capture_state(target: Object, property: String) -> Variant:
	return _capture(target, property, false)

## _capture_state() for a loop that moves the property by an offset around its original. Write it
## with _write_offset(), and other loops doing the same to the property add up with this one.
func _capture_offset(target: Object, property: String) -> Variant:
	return _capture(target, property, true)

func _capture(target: Object, property: String, adds: bool) -> Variant:
	# A custom effect that adds an offset writes from a loop too, though the catalog does not list
	# it, and a tween on the same property hides it all the same. Kept with the capture, so the
	# release takes off what the capture put on.
	var from_loop := adds or _writes_in_loop()
	var original = JuiceeStateStack.capture(target, property, from_loop)
	_state_captures.append([target, property, from_loop])
	if adds:
		JuiceeStateStack._join_offset(target, property, get_instance_id())
	_warn_if_overwritten(target, property)
	return original

## Sets a property taken with _capture_offset() to `original` + `offset`, plus what other loops on
## it add. `reach` is how far the offset goes at the moment, its amplitude rather than this sample.
func _write_offset(target: Object, property: String, original: Variant, offset: Variant,
		reach: float) -> void:
	JuiceeStateStack._write_offset(target, property, get_instance_id(), original, offset, reach)

## Whether this effect drives its target from a manual loop rather than a tween. A
## property of the script, so worked out once and kept: -1 unknown, 0 no, 1 yes.
var _loop_writer: int = -1

func _writes_in_loop() -> bool:
	if _loop_writer < 0:
		var s := get_script() as Script
		var basename := "" if not s else s.resource_path.get_file().trim_suffix(".gd")
		_loop_writer = 1 if JuiceeEffectCatalog.writes_in_loop(basename) else 0
	return _loop_writer == 1

## Two effects on one property is fine when both use tweens: the later one picks the
## value up from where it is and carries on. It is not fine when one of them writes
## from a loop, because a tween writes later in the frame and overwrites it outright -
## measured at a Wiggle contributing 0.000 px of its 6 px amplitude. That failure is
## silent, and an effect that does nothing with nothing said is the worst kind, so say
## it here rather than leaving it to be discovered. Loops that all move the property by an
## offset are fine too: they add up (_capture_offset()). The message names no counts, so the
## same pair met again is the same message and is not printed again for a while.
func _warn_if_overwritten(target: Object, property: String) -> void:
	var counts := JuiceeStateStack.hold_counts(target, property)
	if counts.x < 2 or counts.y < 1 or JuiceeStateStack._offset_holders(target, property) >= counts.x:
		return
	_warn("%s: '%s' on %s is driven by a loop and by another effect at once. "
			% [_class_label(), property, _target_label(target)]
			+ "Each sets the whole value every frame and the later one wins, so one of them "
			+ "will not be visible. Put them on different nodes.")

## The name a user knows the effect by, matching every other warning in the library.
func _class_label() -> String:
	var s := get_script() as Script
	if not s:
		return "JuiceeEffect"
	var global_name := String(s.get_global_name())
	if not global_name.is_empty():
		return global_name
	return s.resource_path.get_file().trim_suffix(".gd")

func _target_label(target: Object) -> String:
	if target is Node:
		return (target as Node).name
	if target is BusVolume:
		return "the %s bus" % (target as BusVolume).bus
	return target.get_class() if is_instance_valid(target) else "a freed object"

## Release a previously captured property. Removes the entry from _state_captures
## so stop() doesn't double-release it - loop-based effects MUST use this instead
## of calling JuiceeStateStack.release() directly.
## Pass restore=false to keep the property at its current value instead of restoring
## the captured original - for effects that intentionally leave a permanent change.
func _release_state(target: Variant, property: String, restore: bool = true) -> void:
	# Variant, not Object. The end of a play calls this whether or not its node survived the
	# play, and GDScript refuses a freed instance passed to an Object parameter before this
	# body runs, so the "stop() already released it" path below never got the case it is for.
	for i in _state_captures.size():
		if _state_captures[i][0] == target and _state_captures[i][1] == property:
			var from_loop: bool = _state_captures[i][2]
			_state_captures.remove_at(i)
			JuiceeStateStack._leave_offset(target, property, get_instance_id())
			JuiceeStateStack.release(target, property, restore, from_loop)
			return
	# Entry not found - stop() already released it. No-op is correct.

## Lets go of a property this play changed for good, leaving it at `value`: effects still holding
## it come back to `value` when they end, not to what it was before this play. Name the value
## when another effect may be writing the property this frame, as a flash does a fade's modulate.
func _keep_state(target: Variant, property: String, value: Variant) -> void:
	for i in _state_captures.size():
		if _state_captures[i][0] == target and _state_captures[i][1] == property:
			var from_loop: bool = _state_captures[i][2]
			_state_captures.remove_at(i)
			JuiceeStateStack._leave_offset(target, property, get_instance_id())
			JuiceeStateStack.keep(target, property, value, from_loop)
			return

## Curve-based property tween - animates `prop_name` on `target` from
## `from_value` to `to_value` over `duration`, sampling the curve to derive the
## per-frame ratio. Works on any lerp-able type (float, Vector2, Vector3, Color).
## If `curve` is null, falls back to a regular `tween_property` so the caller
## can chain `set_trans`/`set_ease` as usual.
##
## Curves give designers full control over the easing shape: punch, bounce,
## squash-stretch-overshoot, or any custom feel - without touching effect code.
## [codeblock]
## # In an effect:
## @export var amplitude_curve: Curve
## ...
## _tween_curved(tween, target, "scale", original, original * 1.5, 0.4, amplitude_curve)
## [/codeblock]
func _tween_curved(tween: Tween, target: Object, prop_name: String, from_value: Variant,
		to_value: Variant, duration: float, curve: Curve = null) -> Tweener:
	if curve and is_instance_valid(target):
		var setter := func(t: float) -> void:
			if not is_instance_valid(target):
				return
			target.set(prop_name, lerp(from_value, to_value, curve.sample(t)))
		# Force linear transition - curve drives the easing, set_trans on the
		# returned tweener would double-apply.
		return tween.tween_method(setter, 0.0, 1.0, duration).set_trans(Tween.TRANS_LINEAR)
	# Fall back to native tween_property so caller can set_trans/set_ease normally.
	return tween.tween_property(target, prop_name, to_value, duration)

## Builds a self-contained screen-overlay tree:
##   CanvasLayer (layer=z)
##   ├── BackBufferCopy (COPY_MODE_VIEWPORT)   <- captures viewport
##   └── ColorRect (sibling, full viewport)    <- samples back buffer
## Siblings (BackBufferCopy -> ColorRect) is the classic Godot pattern - back
## buffer is captured when BackBufferCopy renders, then the next sibling can
## read it via SCREEN_TEXTURE in a shader. Gives the shader its own isolated
## snapshot so Juicee's effects don't fight with user post-process shaders or
## stack with each other. Returns [layer, rect].
func _spawn_screen_shader_overlay(context: Node, layer_name: StringName, z: int = 128) -> Array:
	if not context or not context.is_inside_tree():
		return []
	_sweep_overlay_layers(context, layer_name)

	var layer := CanvasLayer.new()
	layer.name = layer_name
	layer.layer = z
	context.add_child(layer)
	# One common marker so an editor preview can wipe every leftover overlay at once,
	# even one left by a different effect (see clear_editor_overlays).
	layer.set_meta("_juicee_overlay", true)
	# Freed by stop() - without this a killed tween leaves the overlay stuck on screen.
	_free_on_stop(layer)

	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(bb)

	var rect := ColorRect.new()
	rect.color = Color.TRANSPARENT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	_size_to_viewport(rect, context)
	_add_editor_preview_hint(layer, context)
	return [layer, rect]

## Solid-color overlay (no shader, no back buffer) - for tint/wipe effects that
## only need a colored ColorRect on top of the scene.
func _spawn_screen_solid_overlay(context: Node, layer_name: StringName, z: int = 128) -> Array:
	if not context or not context.is_inside_tree():
		return []
	_sweep_overlay_layers(context, layer_name)

	var layer := CanvasLayer.new()
	layer.name = layer_name
	layer.layer = z
	context.add_child(layer)
	# One common marker so an editor preview can wipe every leftover overlay at once,
	# even one left by a different effect (see clear_editor_overlays).
	layer.set_meta("_juicee_overlay", true)
	# Freed by stop() - without this a killed tween leaves the overlay stuck on screen.
	_free_on_stop(layer)

	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	_size_to_viewport(rect, context)
	_add_editor_preview_hint(layer, context)
	return [layer, rect]

## In editor preview (Inspector ▶ Preview, JuiceeGraph ▶ Test), the project
## viewport is smaller than the editor's 2D canvas - shader effects render
## inside that smaller rect, which looks like "broken" full-screen coverage.
## This helper draws a soft outline + label that explicitly marks the area
## the effect actually covers, so the user understands the boundary instead
## of thinking the addon shipped a bug. In runtime (F6, exported game) the
## viewport IS the window, so we skip the hint there.
func _add_editor_preview_hint(layer: CanvasLayer, context: Node) -> void:
	if not Engine.is_editor_hint():
		return
	if not context or not context.is_inside_tree():
		return
	# Skip inside the hover panel's mini SubViewport - the hint would fill most of the
	# 118 px preview area with instructional text that makes no sense at that scale.
	var n := context
	while n:
		if n.has_meta("_juicee_hover_preview"):
			return
		n = n.get_parent()

	# Project Settings > Juicee > Preview can hide this overlay or recolour its border.
	if not bool(ProjectSettings.get_setting(PREVIEW_HINT_SETTING, true)):
		return
	var border_col: Color = ProjectSettings.get_setting(PREVIEW_BORDER_COLOR_SETTING, PREVIEW_BORDER_COLOR_DEFAULT)

	var hint_panel := Panel.new()
	hint_panel.name = &"_juicee_preview_hint"
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = border_col
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	hint_panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(hint_panel)
	_size_to_viewport(hint_panel, context)

	# Floating label - top-left corner, pill style.
	var label_wrap := PanelContainer.new()
	label_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label_sb := StyleBoxFlat.new()
	label_sb.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	label_sb.border_color = border_col
	label_sb.border_width_left = 1
	label_sb.border_width_right = 1
	label_sb.border_width_top = 1
	label_sb.border_width_bottom = 1
	label_sb.corner_radius_top_left = 4
	label_sb.corner_radius_top_right = 4
	label_sb.corner_radius_bottom_left = 4
	label_sb.corner_radius_bottom_right = 4
	label_sb.content_margin_left = 8
	label_sb.content_margin_right = 8
	label_sb.content_margin_top = 4
	label_sb.content_margin_bottom = 4
	label_wrap.add_theme_stylebox_override("panel", label_sb)
	label_wrap.position = Vector2(8, 8)
	hint_panel.add_child(label_wrap)

	var label := Label.new()
	label.text = "Editor preview · effects render inside this rect.\nRun the project (F5 / F6) for full-window coverage."
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	label.add_theme_font_size_override("font_size", 10)
	label_wrap.add_child(label)

# Sets the rect to fill the viewport explicitly. Belt-and-suspenders - anchors
# alone (PRESET_FULL_RECT) don't always resolve when the Control's parent is a
# CanvasLayer (not a Control), especially in editor preview. Combines both for
# reliability, plus reacts to viewport resizes and auto-disconnects when the
# rect is freed (so spamming play doesn't leak signal handlers).
func _size_to_viewport(rect: Control, context: Node) -> void:
	# TOP_LEFT anchors (equal opposite, all 0) so the explicit size set below is
	# honored - FULL_RECT's non-equal anchors would override it and warn on every
	# screen effect. The resize listener keeps it filling the viewport.
	rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rect.position = Vector2.ZERO
	if not context:
		return
	var vp := context.get_viewport()
	if not vp:
		return
	var vp_size := vp.get_visible_rect().size
	if vp_size.x > 0.0 and vp_size.y > 0.0:
		rect.position = Vector2.ZERO
		rect.size = vp_size

	# Per-rect viewport resize listener. Stored as a Callable bound to this
	# specific rect+viewport so we can disconnect it cleanly when the rect dies.
	var resize_cb := func() -> void:
		if is_instance_valid(rect) and is_instance_valid(vp):
			rect.size = vp.get_visible_rect().size
	vp.size_changed.connect(resize_cb)
	rect.tree_exiting.connect(func() -> void:
		if is_instance_valid(vp) and vp.size_changed.is_connected(resize_cb):
			vp.size_changed.disconnect(resize_cb)
	)

## Removes ALL screen-overlay layers under `context` whose name starts with the
## given prefix - including auto-renamed siblings (e.g. "_juicee_blur_overlay2")
## that Godot creates when a queue_free'd node still occupies the canonical
## name. Without this sweep, spam-running an effect leaves stale layers stacked
## (each renamed to dodge the previous, none of them cleaned up because their
## owning apply() coroutine was superseded mid-await). Call this at the very
## start of every screen effect's _apply().
func _sweep_overlay_layers(context: Node, layer_name: StringName) -> void:
	if not context:
		return
	var prefix := String(layer_name)
	for child in context.get_children():
		var n := String(child.name)
		if n.begins_with(prefix):
			# Rename first so add_child(new) below can take the canonical name
			# immediately without a collision-rename.
			child.name = StringName("_juicee_dying_%d" % randi())
			child.queue_free()

## Frees every Juicee screen-overlay layer in `root`'s subtree (and the editor-preview
## hint border each one carries). The per-effect sweep above only runs when that same
## effect fires again, so switching effects - or a fade_out=false blur that stays at peak
## - would otherwise leave an overlay stuck on screen. An editor preview calls this first
## so nothing survives a switch or a spammed Preview button.
static func clear_editor_overlays(root: Node) -> void:
	if not root:
		return
	for child in root.get_children():
		if child.has_meta("_juicee_overlay"):
			child.queue_free()
		else:
			clear_editor_overlays(child)

## The paths an effect can name a target with. A NodePath is measured from the context, so an
## effect that sets one of these is pointing somewhere on purpose and is left alone.
const OWN_TARGET_PROPERTIES := ["target", "target_path", "light_path", "mesh_path", "camera_path",
	"particle_path", "player_path", "tree_path", "origin", "property_path", "parent_path"]

## The node this effect should act on. Effects need a particular kind of node, and a JuiceePlayer
## hands over whatever it is parented to, often a plain Node with the sprite next to it. So a
## wrong kind is looked past: under the node first, since the player's siblings are there, then up
## the parents, stopping short of the scene root so an effect never grabs the whole game. One that
## names its own target keeps it, since a NodePath is measured from the context.
func _retarget(context: Node) -> Node:
	if context == null:
		return context
	var want := get_required_nodes()
	if want.is_empty() or _matches_any(context, want):
		return context
	for own in OWN_TARGET_PROPERTIES:
		if own in self:
			var named: Variant = get(own)
			if named is NodePath and not (named as NodePath).is_empty():
				return context
			if named is String and not (named as String).is_empty():
				return context
	var found := _nearest_node(context, func(n: Node) -> bool: return _matches_any(n, want))
	return found if found else context

## Whether a play on `context` would find a node to work on: the node itself, or one the search
## would move to. False means the effect would warn and do nothing. An effect that names its own
## target is taken at its word, since the path is the answer.
func can_play_on(context: Node) -> bool:
	var want := get_required_nodes()
	if want.is_empty() or context == null:
		return true
	for own in OWN_TARGET_PROPERTIES:
		if own in self and not str(get(own)).is_empty():
			return true
	return _matches_any(_retarget(context), want)

## How many of the nearest nodes below the context the search looks at before giving up. A
## character is a few dozen nodes; a level can be tens of thousands, and looking at all of them
## on every play cost 8.9 ms a play at 5000 with nothing suitable among them.
const SEARCH_LIMIT := 256

## The nearest node `ok` accepts: this one, then below it breadth first so a sprite the character
## holds wins over something deeper, then up its parents, stopping short of the scene root. Juicee's
## own spawned nodes are named _juicee* and are not candidates.
func _nearest_node(context: Node, ok: Callable) -> Node:
	if context == null:
		return null
	if ok.call(context):
		return context
	var queue: Array[Node] = context.get_children()
	var i := 0
	while i < queue.size() and i < SEARCH_LIMIT:
		var n: Node = queue[i]
		i += 1
		if String(n.name).begins_with("_juicee"):
			continue
		if ok.call(n):
			return n
		# No point queueing nodes the limit will never reach.
		if queue.size() < SEARCH_LIMIT:
			queue.append_array(n.get_children())
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree else null
	var above := context.get_parent()
	while above and above != root and not (above is Viewport):
		if ok.call(above):
			return above
		above = above.get_parent()
	return null

func _matches_any(node: Node, want: PackedStringArray) -> bool:
	for w in want:
		if w.begins_with("property:"):
			if w.substr(9) in node:
				return true
		elif node.is_class(w):
			return true
	return false

## The node to parent a spawned effect node under. Prefers the current scene, so the
## spawned node sits in world space the same way it would in a running game. When there
## is no current scene (autoload boot, the editor's hover preview), it falls back to the
## context's viewport rather than the context itself, so the node isn't glued to a
## moving or dying target. Set global_position AFTER add_child, since only then does the
## parent transform apply.
func _spawn_parent(context: Node) -> Node:
	var tree := context.get_tree()
	var scene: Node = tree.current_scene if tree else null
	# current_scene only if the context is actually in it. A character inside a SubViewport
	# is not: split screen, a minimap, a render-to-texture portrait, and every pixel-art
	# game that renders small and upscales the frame. Spawning its dust into the scene above
	# put the particles outside the viewport entirely, at coordinates that mean nothing
	# there, so they turned up as stray pixels in the corner of the window.
	# The test is the viewport, not ancestry: a SubViewport's contents are still descendants
	# of the scene that holds the container, so an ancestry check passes and the effect is
	# spawned outside the picture it belongs to anyway.
	if scene and context.get_viewport() == scene.get_viewport():
		return scene
	var vp := context.get_viewport()
	if vp:
		return vp
	return context

## Adds a copy of `source` to `parent` so it draws just behind the source and above whatever
## the source is drawn over. Same z as the source, and placed in tree order ahead of the branch
## the source sits in. One z below it, which is how ghosts were placed, is below a background
## at the source's z too, a TileMapLayer or a backdrop sprite, so the whole trail was hidden.
func _add_behind(copy: CanvasItem, parent: Node, source: CanvasItem) -> void:
	var z := 0
	var n: Node = source
	while n is CanvasItem:
		z += (n as CanvasItem).z_index
		if not (n as CanvasItem).z_as_relative:
			break
		n = n.get_parent()
	var branch: Node = source
	while branch and branch.get_parent() != parent:
		branch = branch.get_parent()
	copy.z_as_relative = false
	parent.add_child(copy)
	if branch:
		copy.z_index = clampi(z, RenderingServer.CANVAS_ITEM_Z_MIN, RenderingServer.CANVAS_ITEM_Z_MAX)
		parent.move_child(copy, branch.get_index())
	else:
		# Not under the parent at all, so tree order cannot put it behind; fall back to a z below.
		copy.z_index = clampi(z - 1, RenderingServer.CANVAS_ITEM_Z_MIN, RenderingServer.CANVAS_ITEM_Z_MAX)

## The node a ghost-copying effect should photograph: the node itself if it draws a
## sprite, otherwise the first one under it that does. Depth first, so a character with
## its sprite as a direct child is found before anything deeper.
##
## Both kinds count. An animated character in Godot is an AnimatedSprite2D far more often
## than a Sprite2D, and an effect that only knew the second one was useless on the node
## people actually have.
func _find_sprite_node(node: Node2D) -> Node2D:
	if node is Sprite2D or node is AnimatedSprite2D:
		return node
	for child in node.get_children():
		if child is Node2D:
			var found := _find_sprite_node(child as Node2D)
			if found:
				return found
	return null

## Copy what a sprite currently looks like onto a plain Sprite2D used as a ghost. A
## Sprite2D hands over its sheet plus which cell of it to draw; an AnimatedSprite2D hands
## over the texture of the frame showing right now, which is already one frame.
##
## Every field is written on every call: ghosts come from a pool, so anything left unset
## keeps whatever the last user of that ghost put there.
func _copy_sprite_look(from: Node2D, ghost: Sprite2D) -> bool:
	if from is Sprite2D:
		var s := from as Sprite2D
		ghost.texture = s.texture
		ghost.hframes = s.hframes
		ghost.vframes = s.vframes
		ghost.frame = s.frame
		ghost.region_enabled = s.region_enabled
		ghost.region_rect = s.region_rect
	elif from is AnimatedSprite2D:
		var a := from as AnimatedSprite2D
		var frames := a.sprite_frames
		if not frames or not frames.has_animation(a.animation):
			return false
		if a.frame >= frames.get_frame_count(a.animation):
			return false
		ghost.texture = frames.get_frame_texture(a.animation, a.frame)
		ghost.hframes = 1
		ghost.vframes = 1
		ghost.frame = 0
		ghost.region_enabled = false
	else:
		return false
	if not ghost.texture:
		return false
	# Shared by both node types, and the pair that decides whether the ghost lands on the
	# original or half a sprite away from it.
	ghost.centered = from.get("centered")
	ghost.offset = from.get("offset")
	ghost.flip_h = from.get("flip_h")
	ghost.flip_v = from.get("flip_v")
	return true

## Smooth noise for the camera shakes (Shake, Shake 3D, Directional Shake), one lane per axis.
##
## Until this existed each shake built its own FastNoiseLite at Godot's default frequency of
## 0.01 and walked it about 10 units a second, so a 0.3s shake covered 3% of one wave of
## noise, and it started on a lattice point, where Perlin is exactly zero. Measured at 60fps
## over a second with no decay: a default 8px Shake moved the camera 0.07 to 0.38px and
## crossed its rest position once, while the random mode next to it moved 7.6px and crossed
## it seven times. The noise mode is the default, so out of the box the shakes barely moved.
##
## This is plain Perlin, one cell per unit, so how fast it moves is how far it walks.
## Measured, Godot's Perlin crosses zero 1.4 times a cell and peaks near 0.7, so a shake
## walks frequency / 2.8 cells a second, which crosses zero half `frequency` times a second
## the way the random mode does, and the value is scaled by 1.4 to reach the same maximum.
## Turning use_noise on changes how a shake moves, not how fast or how far.
static func _shake_noise() -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	n.frequency = 1.0
	n.seed = randi()
	return n

## One lane of `_shake_noise()` in -1..1, `elapsed` seconds into a shake at `frequency`.
## `start` is picked once per play, so a shake does not begin on a zero.
static func _shake_noise_at(noise: FastNoiseLite, start: float, lane: int,
		elapsed: float, frequency: float) -> float:
	var x := start + lane * 1013.37 + elapsed * frequency / 2.8
	return clampf(noise.get_noise_1d(x) * 1.4, -1.0, 1.0)

## How often a noise shake writes: every frame, up to 120fps. Stepping it at `frequency`, as
## the random mode steps, would hold each value for frames at a time and throw away the
## smoothness the noise is there for.
const SHAKE_NOISE_STEP := 1.0 / 120.0

## Wait `step` seconds and report how much time that actually took.
##
## A loop that waits on `create_timer(step)` and then adds `step` to its own clock runs
## slow, because a SceneTreeTimer cannot fire in the middle of a frame: it rounds up to the
## next one. At 30fps a step of 1/24 of a second waits two frames, 0.0667s, while the loop
## credits itself 0.0417. Measured before this existed, at 30fps: a Shake asking for 0.34s
## held its camera 0.60s, a Wobble Rotation asking for 0.5s ran 1.03s, a Jelly Wobble asking
## for 0.6s ran 1.20s. Duration is the number a person fits an effect into a beat with, and
## everything timed against it came apart, including effects landing on top of each other.
##
## The wait itself is unchanged, deliberately. Awaiting frames instead would move the write
## to after the tweens in the frame, which silently reverses which one wins when a tween and
## a loop hold the same property, and that is a documented behaviour with a warning built on
## it. So the timer stays and only the arithmetic is corrected: credit the frames the wait
## actually took.
##
## Counted, not predicted. This used to credit the step rounded up to whole frames, which is
## right until the step is a whole number of frames, and at 60fps the usual ones are: 1/15,
## 1/20 and 1/10 of a second are 4, 3 and 6 frames. There the float left over in the timer
## fires it a frame late more often than not (measured at 60fps: a 4 frame step took 5
## frames 11 times in 12, a 3 frame step took 4 every time, a 2 frame step took 2), so a one
## second Shake at the default frequency ran for 1.33s.
##
## The nanosecond on the end is for the loops that add these up: thirty 1 frame steps at
## 30fps come to 0.9999999999999999 in floating point, which is less than a duration of 1.0,
## and would run a thirty-first. A nanosecond a step is far below anything a frame can show
## and always enough to carry the sum over.
func _wait_step(tree: SceneTree, step: float) -> float:
	var frame: float = maxf(tree.root.get_process_delta_time(), 0.0001)
	var before := Engine.get_process_frames()
	await tree.create_timer(step, true, false, false).timeout
	return maxi(Engine.get_process_frames() - before, 1) * frame + 1e-9

## Cancel the currently-running effect.
## - Kills all tweens started via _track().
## - Manual-loop effects check `_cancelled` flag and exit on next iteration.
## - Bumps the generation counter so any coroutine waiting on a delay timer
##   also bails out (won't reach the actual _apply() step).
## After stop(), the next apply() can fire normally.
func stop() -> void:
	var was_running := _active
	_gen += 1
	_cancelled = true
	_active = false
	_pending_start = false
	_end_play()
	# Drop the strong ref that kept this effect alive across the (now-killed) play, so
	# the zombie coroutine left hanging on the dead tween's `finished` doesn't pin the
	# effect + its captured context in the static _alive array forever.
	_alive_drop()
	# Last, with everything put back, since a listener may well start something new. Only for
	# a play that had started: one stopped in its delay never sent started either.
	if was_running:
		stopped.emit()

## Puts the current play away, for stop() and for a new apply() that replaces it (`restart`).
func _end_play(restart: bool = false) -> void:
	_unwatch_context()
	var killed: Array[Tween] = []
	for t in _active_tweens:
		if is_instance_valid(t) and t.is_valid():
			t.kill()
			killed.append(t)
	_active_tweens.clear()
	# Release any StateStack entries captured this play. The play's coroutine finds its play over
	# when it wakes and leaves them alone, so this is what gives the properties back.
	for entry in _state_captures:
		JuiceeStateStack._leave_offset(entry[0], entry[1], get_instance_id())
		JuiceeStateStack.release(entry[0], entry[1], true, entry[2])
	_state_captures.clear()
	# Run resource-cleanup callbacks (free spawned overlays, remove bus effects) that the effect's
	# own code after its awaits does not run for a play that is over. Run from a copy, so a
	# callback that registers another cannot change the list underneath it.
	var cleanup := _stop_cleanup.duplicate()
	_stop_cleanup.clear()
	if not restart:
		cleanup.append_array(_stop_only_cleanup)
		_stop_only_cleanup.clear()
		for entry in _outliving:
			if is_instance_id_valid(entry[0]):
				cleanup.append(entry[1])
		_outliving.clear()
	# A held state goes too, on a restart as well: the new play starts from the node as it was.
	cleanup.append_array(_hold_cleanup)
	_hold_cleanup.clear()
	if not restart:
		cleanup.append_array(_hold_stop_only)
		_hold_stop_only.clear()
	for cb in cleanup:
		if cb.is_valid():
			cb.call()
	# Last, with everything back: wake whatever waits on the tweens killed above. Each finds its
	# play over and ends. Left waiting, a coroutine and the tween it waits on held each other in
	# memory for good, a few objects for every play stop() or a restart cut short. A coroutine
	# that checks nothing and goes on to a tween of its next stage, as effects written before
	# _still_playing() may, has that tween ended at once as well, round after round, so nothing
	# of the old play runs beside the new one.
	_waking = true
	var rounds := 0
	while not killed.is_empty() and rounds < MAX_NESTING:
		rounds += 1
		for t in killed:
			t.finished.emit()
		killed = _late_tweens.duplicate()
		_late_tweens.clear()
		for t in killed:
			if is_instance_valid(t) and t.is_valid():
				t.kill()
	_late_tweens.clear()
	_waking = false

## True while _end_play() wakes the coroutines of a play that is over: a tween one of them starts
## then belongs to no play, and goes in _late_tweens to be ended at once.
var _waking := false
var _late_tweens: Array[Tween] = []

## Returns true if this effect is currently mid-apply (between started/finished).
func is_playing() -> bool:
	return _active

## True if the effect is playing OR still pending (in its pre-delay / pre-start window).
## Distinct from is_playing() which is false during the delay. Composite effects use
## this to tell "still going" from "bailed synchronously (chance/cooldown/silenced)".
func is_busy() -> bool:
	return _active or _pending_start

## Time remaining (in seconds) before the cooldown expires, or 0.0 if ready to fire.
func cooldown_remaining() -> float:
	if cooldown <= 0.0:
		return 0.0
	return maxf(0.0, cooldown - (unscaled_seconds() - _last_apply_time))

## What capitalize() gets wrong, longest first so "Fov 3d" is fixed before " 3d".
const NAME_FIXES := {
	"Fov 3d": "FOV 3D",
	"Depth Of Field": "Depth of Field",
	" 3d": " 3D",
	" 2d": " 2D",
}

func get_display_name() -> String:
	var script_path: String = (get_script() as Script).resource_path
	var file_name: String = script_path.get_file().get_basename()
	var words := file_name.replace("_effect", "").replace("_", " ").capitalize()
	# capitalize() lowercases what it does not know, so "shake_3d" comes back "Shake 3d".
	for wrong in NAME_FIXES:
		words = words.replace(wrong, NAME_FIXES[wrong])
	return words

## Colour of the block titlebar in the graph and the card stripe in the Inspector.
## Derived from the effect's category, or from the dimensions it works in, depending
## on Project Settings > Juicee > Graph > Effect Color Mode. Override only if a
## custom effect wants a colour of its own.
func get_category_color() -> Color:
	return JuiceeEffectCatalog.effect_color(_resolved_category(), _resolved_dimensions())

## The effect's category: its own override if it has one, otherwise the central map.
func _resolved_category() -> String:
	var own := get_category_name()
	if not own.is_empty():
		return own
	return JuiceeEffectCatalog.EFFECT_CATEGORIES.get(_basename(), "")

## Which dimensions this effect works in, e.g. ["2d"] or ["2d", "3d"].
func _resolved_dimensions() -> Array:
	return JuiceeEffectCatalog.EFFECT_DIMENSIONS.get(_basename(), [])

func _basename() -> String:
	var script := get_script() as Script
	if not script:
		return ""
	return script.resource_path.get_file().get_basename()

func get_icon_path() -> String:
	return ""

## The kinds of node this effect can act on, as class names or "property:name", so a play on
## the wrong kind can move to the right one. Empty means it takes any node. The built-ins are
## in the catalog; override this in an effect of your own.
func get_required_nodes() -> PackedStringArray:
	return JuiceeEffectCatalog.required_nodes(_basename())

## Category for grouping in the JuiceeGraph popup. Override to set custom group
## (e.g., "Screen", "Camera", "Object", "Time", "Audio", "UI", "Flow", "Physics").
## If returns "" the graph editor falls back to its built-in category map.
func get_category_name() -> String:
	return ""

## Short description shown as a tooltip when hovering this effect in the popup.
## If returns "" the graph editor falls back to its built-in description map.
func get_description() -> String:
	return ""
