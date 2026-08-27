@tool
class_name JuiceePlayer
extends Node

signal started
signal finished
signal blocked_by_cooldown

## The JuiceeSequence resource this player will fire. Drop a .tres here or build
## a new one inline via the "+ Add Effect" Inspector button.
@export var sequence: JuiceeSequence
## If true, automatically calls play() when the scene loads.
@export var auto_play: bool = false
## Optional override for the "context" node passed to effects.
## If empty, the parent node is used. Set this when you want effects to target
## a specific child (e.g., flash a sprite while the player is the parent).
@export var target_path: NodePath

@export_group("Signal Trigger")
## Node that emits the trigger signal. JuiceePlayer auto-fires play() when the signal hits.
## Eliminates boilerplate ("on hit -> call juicee.play()") for common cases.
@export var trigger_source: NodePath
## Name of the signal on trigger_source to listen for (e.g. "area_entered", "pressed").
@export var trigger_signal: StringName = &""

@export_group("Cooldown")
## Minimum seconds between successive play() calls. 0 = no cooldown (can spam).
## Prevents juicee from stacking on rapid-fire actions like machine guns.
@export_range(0.0, 10.0, 0.01) var cooldown: float = 0.0
## If true, play() calls during cooldown are queued and fired once cooldown expires.
## If false (default), they're silently dropped - typical for spam-prevention.
@export var queue_during_cooldown: bool = false

var _last_play_time: float = -1e9
var _queued: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_connect_trigger_signal()
	if auto_play:
		play()

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
	# Wrap play() to ignore signal arguments (signals often pass args we don't need).
	source.connect(trigger_signal, _on_trigger_signal)

func _on_trigger_signal(_a = null, _b = null, _c = null, _d = null) -> void:
	play()

## Fires the sequence. Optional `params` dict is forwarded to effects so they can
## react to runtime data (e.g. juicee_player.play({"hit_direction": Vector2.LEFT})).
func play(params: Dictionary = {}) -> void:
	if not sequence:
		push_warning("JuiceePlayer: no sequence assigned")
		return
	var now := _now()
	if cooldown > 0.0 and now - _last_play_time < cooldown:
		blocked_by_cooldown.emit()
		if queue_during_cooldown and not _queued:
			_queued = true
			var remaining := cooldown - (now - _last_play_time)
			get_tree().create_timer(remaining, true, false, false).timeout.connect(func() -> void:
				_queued = false
				play(params)
			, CONNECT_ONE_SHOT)
		return

	var ctx: Node = _resolve_context()
	if not ctx:
		push_warning("JuiceePlayer: no valid context node")
		return
	_last_play_time = now
	started.emit()
	# Always reconnect - CONNECT_ONE_SHOT removes the connection after first fire,
	# so if play() is called again before the previous run ends the player's
	# `finished` signal would never fire for the new run without this disconnect.
	if sequence.finished.is_connected(_on_sequence_finished):
		sequence.finished.disconnect(_on_sequence_finished)
	sequence.finished.connect(_on_sequence_finished, CONNECT_ONE_SHOT)
	sequence.play(ctx, params)

func is_on_cooldown() -> bool:
	return cooldown > 0.0 and (_now() - _last_play_time) < cooldown

func cooldown_remaining() -> float:
	if cooldown <= 0.0:
		return 0.0
	return max(0.0, cooldown - (_now() - _last_play_time))

## Cancels the currently-playing sequence. Kills tweens on in-flight effects
## and bails out any pending delays. Safe to call when nothing is playing.
func stop() -> void:
	if sequence:
		sequence.stop()
	_queued = false

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _resolve_context() -> Node:
	if not target_path.is_empty():
		var n := get_node_or_null(target_path)
		if n:
			return n
	var p := get_parent()
	return p if p else self

func _on_sequence_finished() -> void:
	finished.emit()

func _editor_preview() -> void:
	if not sequence:
		push_warning("JuiceePlayer: no sequence assigned")
		return
	# Wipe any overlay a previous (possibly spammed) preview left behind, so nothing
	# stacks up or lingers after you switch effects. edited_scene_root is null at
	# runtime, so this never touches a shipped game (and avoids an EditorInterface ref).
	if Engine.is_editor_hint():
		var tree := get_tree()
		if tree:
			JuiceeEffect.clear_editor_overlays(tree.edited_scene_root)
	_last_play_time = -1e9  # bypass cooldown in editor
	play()
