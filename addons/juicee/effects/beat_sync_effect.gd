## Fire a child effect synchronized to a BPM beat.
##
## Use for: rhythm-game impact, music-reactive juiciness, beat-synced particle
## bursts, bass-drop screen flash, metronome-timed dialogue pop-in.
##
## Two modes:
## - **Clock mode**: set `clock_path` to a JuiceeBeatClock in your scene.
##   The effect fires exactly on each beat signal -> tight musical sync.
## - **Standalone mode**: no clock required. The effect fires at `bpm` internally.
##   Good for prototyping or scenes without a master clock.
@tool
class_name JuiceeBeatSyncEffect
extends JuiceeEffect

## The effect to fire on each beat. Can be any JuiceeEffect resource.
@export var effect: JuiceeEffect
## Beats per minute used in standalone mode (and shown in graph editor).
@export_range(20.0, 300.0, 0.5) var bpm: float = 120.0
## Fire every N beats (1 = every beat, 2 = every other beat, 4 = every bar).
@export_range(1, 16, 1) var beats_per_trigger: int = 1
## How long to keep running in seconds (0 = fire exactly once then stop).
@export_range(0.0, 120.0, 0.5) var duration: float = 8.0
## Optional path to a JuiceeBeatClock node in the scene for tight sync.
## Leave empty to use standalone BPM mode.
@export var clock_path: NodePath = NodePath()

@export_group("Advanced")
## Wait this many beats before the first trigger, so a layer can enter on the second bar.
@export_range(0, 32, 1) var start_offset_beats: int = 0
## Fire on off-beats instead of the beat itself (a swung, syncopated feel).
@export var offbeat: bool = false
## Multiply the effect's intensity on every Nth trigger, so a bar lands with an accent.
## 1 = every trigger identical.
@export_range(1, 16, 1) var accent_every: int = 1
## How much stronger an accented trigger is.
@export_range(1.0, 4.0, 0.1) var accent_multiplier: float = 1.6

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["start_offset_beats", "offbeat", "accent_every", "accent_multiplier"]))

func get_category_name() -> String: return "Flow"

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not effect:
		_warn("JuiceeBeatSyncEffect: no child effect assigned")
		return
	var tree := context.get_tree()
	var play := _gen
	var beat_interval := (60.0 / bpm) * beats_per_trigger
	var total_dur := duration if duration > 0.0 else beat_interval
	# Counts triggers so accent_every can push a stronger hit on the downbeat.
	# An array, so the clock lambda below can advance it.
	var trigger_index := [0]
	# Advanced start_offset_beats lets a layer enter later (e.g. on the second bar),
	# and offbeat shifts everything half a beat for a syncopated feel.
	var lead_in: float = (60.0 / bpm) * float(start_offset_beats)
	if offbeat:
		lead_in += (60.0 / bpm) * 0.5
	if lead_in > 0.0:
		await tree.create_timer(lead_in, true, false, false).timeout
		if _gen != play:
			return

	# Clock mode: connect to JuiceeBeatClock signal for musically-tight sync.
	var clock: JuiceeBeatClock = null
	if not clock_path.is_empty():
		clock = context.get_node_or_null(clock_path) as JuiceeBeatClock

	if clock:
		var elapsed := 0.0
		# The node through a weak reference: a lambda that captured it would report an error when
		# the clock beats after the node was freed, whatever its body checks.
		var context_ref: WeakRef = weakref(context)
		var on_beat := func(beat_num: int) -> void:
			var ctx := context_ref.get_ref() as Node
			if ctx and _gen == play and (beat_num % beats_per_trigger) == 0:
				_fire(ctx, trigger_index[0])
				trigger_index[0] += 1
		clock.beat.connect(on_beat)
		# A stop() or a newer play ends the loop too, and this one still has to let go of the clock.
		while elapsed < total_dur and _gen == play:
			await tree.process_frame
			elapsed += tree.root.get_process_delta_time()
		# The clock may be freed by now, e.g. stopped during a scene change.
		if is_instance_valid(clock) and clock.beat.is_connected(on_beat):
			clock.beat.disconnect(on_beat)
	else:
		# Standalone mode: fire at the computed interval using real timers.
		var elapsed := 0.0
		while elapsed < total_dur and _gen == play and is_instance_valid(context):
			_fire(context, trigger_index[0])
			trigger_index[0] += 1
			if duration <= 0.0:
				break
			elapsed += await _wait_step(tree, beat_interval)

## Fires the child effect for one trigger, applying the advanced accent so every
## Nth hit lands harder than the ones between it.
func _fire(context: Node, index: int) -> void:
	if not effect:
		return
	# The accent rides on the play's own intensity, which the child keeps through a delay of its
	# own. Raising its intensity range for the length of the call did not, and changed the
	# resource under anything else playing it.
	var params := _runtime_params.duplicate()
	if accent_every > 1 and index % accent_every == 0:
		params["intensity"] = float(params.get("intensity", 1.0)) * accent_multiplier
	_start_child(effect, context, params)
