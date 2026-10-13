@tool
class_name JuiceePlayer
extends Node

signal started
signal finished
signal blocked_by_cooldown
## Same as `started` / `finished`, but says which sequence it was. Both of the
## older signals still fire exactly as before, so nothing connected to them breaks.
signal sequence_started(sequence_name: StringName)
signal sequence_finished(sequence_name: StringName)

## The JuiceeSequence resource this player will fire. Drop a .tres here or build
## a new one inline via the "+ Add Effect" Inspector button.
@export var sequence: JuiceeSequence
## More sequences on the same node, fired by name: `play("crash")`, the way
## AnimationPlayer works. One node per reaction adds up fast in a scene, and every
## one of them is another place to keep a target and a cooldown in step.
##
## A sequence answers to its resource name, falling back to its file name, so one
## saved as crash.tres is `play("crash")` with nothing else to set up. `sequence`
## above stays the default: bare `play()` fires it, and it answers to its own name
## as well.
@export var sequences: Array[JuiceeSequence] = []
## If true, automatically calls play() when the scene loads, at the end of that frame.
@export var auto_play: bool = false
## Optional override for the "context" node passed to effects.
## Effects start from this node, or from the parent when it is empty, and one that needs another
## kind of node (a Node2D to move, a Light2D to flash) looks for the nearest one from there.
@export var target_path: NodePath

@export_group("Signal Trigger")
## Node that emits the trigger signal. JuiceePlayer auto-fires play() when the signal hits.
## Eliminates boilerplate ("on hit -> call juicee.play()") for common cases.
@export var trigger_source: NodePath:
	set(v):
		trigger_source = v
		# trigger_signal's dropdown is built from this node's actual signals, so it has
		# to be rebuilt the moment the source changes - otherwise it keeps offering the
		# previous node's signals (or none) until something else happens to refresh
		# the inspector, like reselecting the node.
		notify_property_list_changed()
## Name of the signal on trigger_source to listen for. A dropdown of that node's real
## signals once trigger_source is set - "(none)" leaves the trigger disconnected.
@export var trigger_signal: StringName = &""

@export_group("Cooldown")
## Minimum seconds between successive play() calls. 0 = no cooldown (can spam).
## Prevents juicee from stacking on rapid-fire actions like machine guns.
@export_range(0.0, 10.0, 0.01) var cooldown: float = 0.0
## If true, play() calls during cooldown are queued and fired once cooldown expires.
## If false (default), they're silently dropped - typical for spam-prevention.
@export var queue_during_cooldown: bool = false

# Cooldown is tracked per sequence name. Shared across all of them, a crash would
# be swallowed because a boost had just fired, which is not what a spam guard is
# meant to do.
var _last_play_time: Dictionary = {}
var _queued: Dictionary = {}
var _finish_hooks: Dictionary = {}

## What is wrong with a sequence as far as it can be told without running the game. The editor shows
## these under the node in the Scene dock; it is a static function so a test can read them too.
static func problems_with(seq: JuiceeSequence, context: Node, label: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	if seq == null:
		return out
	var prefix: String = "" if label.is_empty() else "%s: " % label
	if seq.effects.is_empty():
		out.append("%sthe sequence has no effects" % prefix)
	for i in seq.effects.size():
		var effect: JuiceeEffect = seq.effects[i]
		var step: String = "%sstep %d" % [prefix, i + 1]
		if effect == null:
			out.append("%s is empty" % step)
			continue
		# A muted step is deliberate, so it is not a problem.
		if not effect.enabled:
			continue
		var shown: String = effect.get_display_name()
		var script := effect.get_script() as Script
		var basename: String = script.resource_path.get_file().get_basename() if script else ""
		var needed: String = JuiceeEffectCatalog.required_param(basename)
		if not needed.is_empty() and needed in effect and _is_unset(effect.get(needed)):
			out.append("%s (%s) has no %s" % [step, shown, needed])
		if context == null:
			continue
		for own in JuiceeEffect.OWN_TARGET_PROPERTIES:
			if not (own in effect):
				continue
			var named: Variant = effect.get(own)
			if named is NodePath and not (named as NodePath).is_empty() \
					and context.get_node_or_null(named) == null:
				out.append("%s (%s): %s points at nothing" % [step, shown, own])
		if not effect.can_play_on(context):
			out.append("%s (%s) has no %s to play on, on or near %s"
					% [step, shown, " or ".join(effect.get_required_nodes()), context.name])
	return out

## Blank in the sense the effects themselves refuse to run on: no text, no array entries, no scene.
static func _is_unset(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return true
		TYPE_STRING, TYPE_STRING_NAME:
			return str(v).is_empty()
		TYPE_ARRAY:
			return (v as Array).is_empty()
		_:
			return false

func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if not target_path.is_empty() and get_node_or_null(target_path) == null:
		out.append("target_path points at nothing")
	if sequence == null and sequences.is_empty():
		out.append("no sequence to play")
	var context := _resolve_context()
	out.append_array(problems_with(sequence, context))
	for s in sequences:
		if s:
			out.append_array(problems_with(s, context, str(name_of(s))))
	return out

## Effects play one play at a time each, so two players playing one sequence took its effects from
## each other mid-play: instances of a scene share their sub-resources, and hitting a second enemy
## cut the first one's effects short. In the game each player plays copies of the sequences the
## scene gave it, made when it is ready. One assigned from code later is played as it is, so code
## holding its effects still hears their signals; the editor works on the real ones.
func _own_copies() -> void:
	var copies := {}
	if sequence:
		sequence = JuiceeEffect.own_copy(sequence, copies) as JuiceeSequence
	var mine: Array[JuiceeSequence] = []
	for s in sequences:
		mine.append(JuiceeEffect.own_copy(s, copies) as JuiceeSequence if s else null)
	sequences = mine

func _ready() -> void:
	if not Engine.is_editor_hint():
		_own_copies()
	if Engine.is_editor_hint():
		# Editing a step changes what is wrong with it, so the triangle in the Scene dock follows
		# along instead of waiting for the node to be reselected.
		for s in _all_sequences():
			if not s.changed.is_connected(update_configuration_warnings):
				s.changed.connect(update_configuration_warnings)
		return
	_connect_trigger_signal()
	if auto_play:
		# Not straight from _ready: the tree is mid-propagation there, and a node cannot take a
		# child while it is, so every effect that spawns something would fail on the first play.
		play.call_deferred()

## Turns trigger_signal into a dropdown of trigger_source's actual signals, once a
## source is set - the same "read the live options instead of typing a name" fix
## already applied to audio buses and input actions elsewhere in the addon.
func _validate_property(property: Dictionary) -> void:
	if property.name != "trigger_signal":
		return
	if not is_inside_tree() or trigger_source.is_empty():
		return
	var source := get_node_or_null(trigger_source)
	if not source:
		return
	var names := PackedStringArray([""])  # "" = disconnected; drawn as "(none)"
	for s in source.get_signal_list():
		var n := String(s["name"])
		if not names.has(n):
			names.append(n)
	# Keep the current value even if the source no longer has it (source changed,
	# signal renamed) - opening the inspector should never silently blank it out.
	if trigger_signal != &"" and not names.has(String(trigger_signal)):
		names.append(String(trigger_signal))
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(names)

func _connect_trigger_signal() -> void:
	if trigger_source.is_empty() or trigger_signal == &"":
		return
	var source := get_node_or_null(trigger_source)
	if not source:
		push_warning("JuiceePlayer: trigger_source node not found: %s" % trigger_source)
		return
	if not source.has_signal(trigger_signal):
		push_warning("JuiceePlayer: signal '%s' not found on %s" % [trigger_signal, source])
		return
	# The signal's arguments are dropped, however many it sends: play() wants none of them.
	var args := 0
	for s in source.get_signal_list():
		if StringName(s["name"]) == trigger_signal:
			args = (s["args"] as Array).size()
	source.connect(trigger_signal, _on_trigger_signal.unbind(args) if args > 0 else _on_trigger_signal)

func _on_trigger_signal() -> void:
	play()

## The name a sequence answers to: its resource name, falling back to its file
## name. Saving one as crash.tres is therefore enough to make play("crash") work.
static func name_of(seq: JuiceeSequence) -> StringName:
	if not seq:
		return &""
	if not seq.resource_name.is_empty():
		return StringName(seq.resource_name)
	if not seq.resource_path.is_empty():
		return StringName(seq.resource_path.get_file().get_basename())
	return &""

## The sequence with this name. An empty name means the default `sequence` slot.
func get_sequence(sequence_name: StringName = &"") -> JuiceeSequence:
	if sequence_name.is_empty():
		return sequence
	for s in sequences:
		if s and name_of(s) == sequence_name:
			return s
	# The default slot answers to its own name too, so a player holding a default
	# plus extras can address every one of them the same way.
	if sequence and name_of(sequence) == sequence_name:
		return sequence
	return null

## Every name this player will answer to.
func sequence_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for s in [sequence] + sequences:
		var n := name_of(s)
		if not n.is_empty() and not names.has(n):
			names.append(n)
	return names

## Fires a sequence.
## [codeblock]
## player.play()                          # the default sequence
## player.play({"hit_direction": LEFT})   # the default, with runtime params
## player.play("crash")                   # one of `sequences`, by name
## player.play("crash", {"force": 12.0})
## [/codeblock]
## `params` is forwarded to the effects so they can react to runtime data.
func play(name_or_params: Variant = null, params: Dictionary = {}) -> void:
	var sequence_name: StringName = &""
	var runtime: Dictionary = params
	# The first argument used to be the params dict, and calls written that way have
	# to keep working, so the name and the params share the slot by type.
	if name_or_params is Dictionary:
		runtime = name_or_params
	elif name_or_params is StringName or name_or_params is String:
		sequence_name = StringName(name_or_params)
	elif name_or_params != null:
		push_warning("JuiceePlayer.play(): expected a sequence name or a params Dictionary")
		return

	# Effects play on nodes in the scene, and a cooldown counts on the scene's clock.
	if not is_inside_tree():
		push_warning("JuiceePlayer: not in the scene tree, so it has nothing to play on")
		return
	var seq := get_sequence(sequence_name)
	if not seq:
		if sequence_name.is_empty():
			push_warning("JuiceePlayer: no sequence assigned")
		else:
			push_warning("JuiceePlayer: no sequence named '%s' (has: %s)" % [
				sequence_name, sequence_names()])
		return

	var key := name_of(seq)
	var now := _now()
	var last: float = _last_play_time.get(key, -1e9)
	var wait := _cooldown_for(seq)
	if wait > 0.0 and now - last < wait:
		blocked_by_cooldown.emit()
		if queue_during_cooldown and not _queued.get(key, false):
			_queued[key] = true
			var remaining := wait - (now - last)
			# A method of the player rather than a lambda: the engine drops the call if the player
			# is gone by the time the cooldown runs out.
			get_tree().create_timer(remaining, true, false, false).timeout.connect(
					_play_queued.bind(key, sequence_name, runtime), CONNECT_ONE_SHOT)
		return

	var ctx: Node = _resolve_context()
	if not ctx:
		push_warning("JuiceePlayer: no valid context node")
		return
	_last_play_time[key] = now
	started.emit()
	sequence_started.emit(key)
	# Always reconnect - CONNECT_ONE_SHOT removes the connection after first fire,
	# so if play() is called again before the previous run ends the player's
	# `finished` signal would never fire for the new run without this disconnect.
	# The hook is kept per sequence because it carries the name as a bound argument.
	var previous: Callable = _finish_hooks.get(seq, Callable())
	if previous.is_valid() and seq.finished.is_connected(previous):
		seq.finished.disconnect(previous)
	var hook := _on_sequence_finished.bind(key)
	_finish_hooks[seq] = hook
	seq.finished.connect(hook, CONNECT_ONE_SHOT)
	seq.play(ctx, runtime)

func _play_queued(key: StringName, sequence_name: StringName, runtime: Dictionary) -> void:
	_queued[key] = false
	play(sequence_name, runtime)

## A sequence with its own cooldown uses it; otherwise the player's applies. That
## way one node can hold a pickup that never waits next to a bullet-time reaction
## that waits a second and a half.
func _cooldown_for(seq: JuiceeSequence) -> float:
	if seq and seq.cooldown > 0.0:
		return seq.cooldown
	return cooldown

func is_on_cooldown(sequence_name: StringName = &"") -> bool:
	var wait := _cooldown_for(get_sequence(sequence_name))
	if wait <= 0.0:
		return false
	return (_now() - _cooldown_start(sequence_name)) < wait

func cooldown_remaining(sequence_name: StringName = &"") -> float:
	var wait := _cooldown_for(get_sequence(sequence_name))
	if wait <= 0.0:
		return 0.0
	return max(0.0, wait - (_now() - _cooldown_start(sequence_name)))

func _cooldown_start(sequence_name: StringName) -> float:
	return _last_play_time.get(name_of(get_sequence(sequence_name)), -1e9)

## Cancels whatever is playing, across every sequence on this player. Kills tweens
## on in-flight effects and bails out any pending delays. Safe to call when
## nothing is playing.
func stop() -> void:
	if sequence:
		sequence.stop()
	for s in sequences:
		if s:
			s.stop()
	_queued.clear()

## The default sequence and the named ones, skipping the empty slots.
func _all_sequences() -> Array[JuiceeSequence]:
	var out: Array[JuiceeSequence] = []
	if sequence:
		out.append(sequence)
	for s in sequences:
		if s and not out.has(s):
			out.append(s)
	return out

func _now() -> float:
	return JuiceeEffect.unscaled_seconds()

func _resolve_context() -> Node:
	if not target_path.is_empty():
		var n := get_node_or_null(target_path)
		if n:
			return n
	var p := get_parent()
	return p if p else self

func _on_sequence_finished(sequence_name: StringName) -> void:
	finished.emit()
	sequence_finished.emit(sequence_name)

## Plays one sequence in the editor, the default when none is given, on this player's target.
func _editor_preview(which: JuiceeSequence = null) -> void:
	var seq: JuiceeSequence = which if which else sequence
	if not seq:
		push_warning("JuiceePlayer: no sequence assigned")
		return
	# Wipe any overlay a previous (possibly spammed) preview left behind, so nothing
	# stacks up or lingers after you switch effects. edited_scene_root is null at
	# runtime, so this never touches a shipped game (and avoids an EditorInterface ref).
	if Engine.is_editor_hint():
		var tree := get_tree()
		if tree:
			JuiceeEffect.clear_editor_overlays(tree.edited_scene_root)
	# Straight to the sequence: no cooldown in the editor, and a sequence without a name
	# previews as well as one with.
	seq.play(_resolve_context())
