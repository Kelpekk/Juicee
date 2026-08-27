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

func get_category_name() -> String: return "Flow"

func _apply(context: Node, intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if not effect:
		push_warning("JuiceeBeatSyncEffect: no child effect assigned")
		return
	var tree := context.get_tree()
	var beat_interval := (60.0 / bpm) * beats_per_trigger
	var total_dur := duration if duration > 0.0 else beat_interval

	# Clock mode: connect to JuiceeBeatClock signal for musically-tight sync.
	var clock: JuiceeBeatClock = null
	if not clock_path.is_empty():
		clock = context.get_node_or_null(clock_path) as JuiceeBeatClock

	if clock:
		var elapsed := 0.0
		var on_beat := func(beat_num: int) -> void:
			if not _cancelled and (beat_num % beats_per_trigger) == 0:
				effect.apply(context)
		clock.beat.connect(on_beat)
		while elapsed < total_dur and not _cancelled:
			await tree.process_frame
			elapsed += tree.root.get_process_delta_time()
		if clock.beat.is_connected(on_beat):
			clock.beat.disconnect(on_beat)
	else:
		# Standalone mode: fire at the computed interval using real timers.
		var elapsed := 0.0
		while elapsed < total_dur and not _cancelled:
			effect.apply(context)
			if duration <= 0.0:
				break
			await tree.create_timer(beat_interval, true, false, false).timeout
			elapsed += beat_interval
