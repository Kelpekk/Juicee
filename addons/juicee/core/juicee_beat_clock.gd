## BPM-based beat clock. Add to your scene tree and call start() to begin.
##
## Emits [signal beat] on every beat interval. [signal beat] carries a
## monotonically increasing beat number so listeners can filter "every N beats"
## by checking [code]beat_number % N == 0[/code].
##
## Usage:
## [codeblock]
## # In your scene:
## $BeatClock.bpm = 128.0
## $BeatClock.start()
##
## # Respond to each beat:
## $BeatClock.beat.connect(func(n): print("beat ", n))
##
## # JuiceeBeatSyncEffect can reference this clock via clock_path for tight sync.
## [/codeblock]
class_name JuiceeBeatClock
extends Node

## Fires on every beat tick. beat_number starts at 1 and counts up.
signal beat(beat_number: int)

## Beats per minute.
@export_range(20.0, 300.0, 0.5) var bpm: float = 120.0
## Start the clock automatically when the node enters the scene tree.
@export var auto_start: bool = false

var _running: bool = false
var _beat_number: int = 0
var _accumulator: float = 0.0

func _ready() -> void:
	if auto_start:
		start()

func start() -> void:
	_running = true
	_beat_number = 0
	_accumulator = 0.0

func stop() -> void:
	_running = false

func reset() -> void:
	_beat_number = 0
	_accumulator = 0.0

## Current beat phase in [0.0, 1.0] - how far through the current beat interval we are.
func get_beat_phase() -> float:
	var interval := _interval()
	if interval <= 0.0:
		return 0.0
	return clampf(_accumulator / interval, 0.0, 1.0)

## Current beat number (1-indexed; 0 = clock not started yet).
func get_beat_number() -> int:
	return _beat_number

## Beats one frame fires at most. A tempo the frame rate cannot show drops the rest: a bpm of a
## billion fired close to three hundred thousand beats a frame, and a negative one never left the
## loop below.
const MAX_BEATS_PER_FRAME := 16

## Seconds per beat, or 0 for a bpm that is no tempo (0, negative, NaN, infinite): no beats then.
func _interval() -> float:
	if not is_finite(bpm) or bpm <= 0.0:
		return 0.0
	return 60.0 / bpm

func _process(delta: float) -> void:
	if not _running:
		return
	var beat_interval := _interval()
	if beat_interval <= 0.0:
		return
	_accumulator += delta
	var fired := 0
	while _accumulator >= beat_interval:
		if fired >= MAX_BEATS_PER_FRAME:
			_accumulator = fmod(_accumulator, beat_interval)
			break
		_accumulator -= beat_interval
		_beat_number += 1
		fired += 1
		beat.emit(_beat_number)
