# Juicee - Core API Reference

Complete reference for every class in the Juicee framework. For effect params, see [effects-reference.md](effects-reference.md). For the singleton API, see [singleton-api.md](singleton-api.md).

---

## JuiceeEffect

`class_name JuiceeEffect extends Resource` - Base class for all effects.

Every file in `addons/juicee/effects/` that ends with `_effect.gd` extends this class. It handles the full apply lifecycle: cooldown gate -> chance roll -> pre-delay -> intensity multiplication -> accessibility gate -> `_apply()` -> signals.

### Exported properties (inherited by every effect)

| Property | Type | Default | Description |
|---|---|---|---|
| `chance` | `float` | `1.0` | Probability (0-1) this effect fires. `1.0` = always, `0.5` = 50% chance. |
| `delay` | `float` | `0.0` | Pre-delay in seconds before `_apply()` runs. Uses real-time timer. |
| `intensity_min` | `float` | `1.0` | Lower bound of the per-play intensity multiplier. |
| `intensity_max` | `float` | `1.0` | Upper bound of the per-play intensity multiplier. Both `1.0` = no randomization. |
| `cooldown` | `float` | `0.0` | Minimum seconds between `apply()` calls on this resource. |
| `graph_position` | `Vector2` | `Vector2.ZERO` | Block position in the visual graph editor. Don't edit manually. |

### Signals

| Signal | Args | When |
|---|---|---|
| `started` | - | `_apply()` is about to run (after delay and gates) |
| `finished` | - | `_apply()` returned normally |
| `stopped` | - | `stop()` was called during a run |
| `delay_started` | `seconds: float` | The pre-delay timer started (used by graph debug bar) |

### Public methods

```gdscript
func apply(context: Node, params: Dictionary = {}) -> void
```
Entry point. Runs the full pipeline: cooldown -> chance -> delay -> intensity -> accessibility -> `_apply()`. **Do not override.** Pass runtime params like `{"hit_direction": Vector2.LEFT}`.

```gdscript
func stop() -> void
```
Cancels the current run immediately. Kills all `_tracked` tweens. Sets `_cancelled = true` so manual loops bail out. Bumps the generation counter so pending delays abort without reaching `_apply()`.

```gdscript
func is_playing() -> bool
```
`true` between `started` and `finished`/`stopped`.

```gdscript
func cooldown_remaining() -> float
```
Seconds until the cooldown expires. `0.0` if ready.

### Virtual methods (override in subclasses)

```gdscript
func _apply(context: Node, intensity_mult: float) -> void
```
**The only method you override.** `intensity_mult` is `randf_range(intensity_min, intensity_max)` scaled by `JuiceeAccessibility.intensity_scale`. If the accessibility layer blocks this effect, `apply()` never calls `_apply()`.

```gdscript
func get_display_name() -> String          # "My Cool" - defaults to parsed script name
func get_category_name() -> String         # "Camera", "Screen", etc. - graph popup grouping
func get_category_color() -> Color         # colored titlebar stripe on graph blocks
func get_icon_path() -> String             # SVG icon path for graph block titlebar
func get_description() -> String           # tooltip in graph popup
func get_accessibility_tag() -> int        # one of JuiceeAccessibility.TAG_*
```

### Protected methods (use in subclasses)

```gdscript
func _track(tween: Tween) -> Tween
```
Register a tween for cleanup. **Every `create_tween()` call must be wrapped.** Otherwise `stop()` can't kill it.
```gdscript
var tween := _track(target.create_tween())
```

```gdscript
func _tween_curved(tween, target, prop_name, from_value, to_value, duration, curve) -> Tweener
```
Curve-aware property tween. If `curve` is `null`, falls back to `tween_property` (caller sets `set_trans`/`set_ease`). If `curve` is set, samples it per-frame - gives designers custom easing shapes without touching code.

```gdscript
func _spawn_screen_shader_overlay(context, layer_name, z=128) -> Array  # [CanvasLayer, ColorRect]
func _spawn_screen_solid_overlay(context, layer_name, z=128) -> Array   # [CanvasLayer, ColorRect]
func _sweep_overlay_layers(context, layer_name) -> void
```
Screen overlay helpers. `_spawn_screen_shader_overlay` creates a `BackBufferCopy` + `ColorRect` pair - necessary for effects that read `SCREEN_TEXTURE` in their shader. `_spawn_screen_solid_overlay` creates just a `ColorRect` (for tints, bars, flash overlays). `_sweep_overlay_layers` cleans up any stale layers from a previous run (call at the top of every screen effect).

### Static variables

```gdscript
static var accessibility: JuiceeAccessibility
```
Set by `Juicee` autoload in `_ready()`. All effects read this automatically - zero per-effect code needed.

### Internal variables (read-only in subclasses)

```gdscript
var _runtime_params: Dictionary   # params passed to apply()
var _cancelled: bool              # set by stop() - check in manual loops
var _gen: int                     # generation counter - bumped by apply() and stop()
```

---

## JuiceeSequence

`class_name JuiceeSequence extends Resource` - Ordered container of effects.

The persistence unit. Created inline by the Inspector UI, exported by the graph editor, or built in code. Everything serializes to `.tres`.

### Exported properties

| Property | Type | Default | Description |
|---|---|---|---|
| `effects` | `Array[JuiceeEffect]` | `[]` | The effect list. Add via Inspector "+ Add Effect" or graph editor. |
| `parallel` | `bool` | `false` | `true` = all effects fire simultaneously. `false` = sequential (each awaits the previous). |
| `stagger_delay` | `float` | `0.0` | When `parallel=true`, seconds between each effect's start. `0` = all at once. |
| `graph_connections` | `PackedStringArray` | `[]` | Graph editor wire data. Auto-managed. Format: `"from_id:from_port:to_id:to_port"`. |

### Methods

```gdscript
func play(context: Node, params: Dictionary = {}) -> void
```
Plays the sequence. `await`able - returns when all effects finish (or are stopped/cancelled). `params` is forwarded to every effect's `_apply()` via `_runtime_params`.

```gdscript
func stop() -> void
```
Cancels every in-flight effect and terminates the sequence loop.

```gdscript
func is_playing() -> bool
func pause() -> void       # hold at the seam between effects
func resume() -> void      # resume a paused sequence
func is_paused() -> bool
```

**Pause semantics:** the currently running effect finishes naturally. The sequence then waits at the inter-effect gap until `resume()` is called. There is no mid-effect pause.

### Signals

| Signal | Args | When |
|---|---|---|
| `started` | - | `play()` called and execution begins |
| `finished` | - | All effects completed normally |
| `stopped` | - | `stop()` was called |
| `effect_started` | `effect: JuiceeEffect` | Just before an effect's `_apply()` runs |
| `effect_finished` | `effect: JuiceeEffect` | After an effect's `_apply()` returns |

---

## JuiceePlayer

`class_name JuiceePlayer extends Node` - Scene node that owns and fires a `JuiceeSequence`.

### Exported properties

| Property | Type | Default | Description |
|---|---|---|---|
| `sequence` | `JuiceeSequence` | `null` | The sequence to play. Build inline or load a `.tres`. |
| `auto_play` | `bool` | `false` | Call `play()` automatically when the node enters the tree. |
| `target_path` | `NodePath` | `""` | Override context node. Empty = use parent. |
| `trigger_source` | `NodePath` | `""` | Node that emits the auto-trigger signal. |
| `trigger_signal` | `StringName` | `""` | Signal name on `trigger_source` - auto-fires `play()` when received. Accepts any arity. |
| `cooldown` | `float` | `0.0` | Minimum seconds between `play()` calls. |
| `queue_during_cooldown` | `bool` | `false` | Queue one pending `play()` during cooldown instead of dropping it. |

### Methods

```gdscript
func play(params: Dictionary = {}) -> void
func stop() -> void
func is_on_cooldown() -> bool
func cooldown_remaining() -> float
```

### Signals

| Signal | When |
|---|---|
| `started` | `play()` passed cooldown and started the sequence |
| `finished` | Sequence completed normally |
| `blocked_by_cooldown` | `play()` was called during cooldown |

### Signal trigger

Set `trigger_source` + `trigger_signal` to wire effects without code. Example: an `Area2D` with `body_entered` - when a body enters, `play()` fires automatically.

---

## JuiceeStateStack

`class_name JuiceeStateStack extends RefCounted` - Concurrent-safe property restore.

**Static class** - all methods are `static`. No instance needed.

### Problem it solves

Without this, two simultaneous shakes both capture `cam.offset`. The first to finish restores to the mid-shake snapshot of the second, leaving the camera stuck. With the stack, only the first capture stores the TRUE original; all subsequent captures get the same original back and increment a ref count. The property is only restored when the LAST effect releases it.

### Methods

```gdscript
static func capture(target: Object, property: String) -> Variant
```
Captures `target[property]` if not already captured, increments ref count, returns the original value. Property can be a sub-path: `"modulate:a"`, `"scale:x"`.

```gdscript
static func release(target: Object, property: String) -> void
```
Decrements ref count. At zero, restores original and removes the entry. Safe to call on a freed target - stale entries are pruned automatically.

```gdscript
static func active_count() -> int   # debug: number of currently held entries
static func reset() -> void         # force-clear (editor reloads, test resets)
```

### Usage pattern

```gdscript
var original: Vector2 = JuiceeStateStack.capture(target, "position")
# ... modify target.position freely ...
JuiceeStateStack.release(target, "position")
```

---

## JuiceeAccessibility

`class_name JuiceeAccessibility extends RefCounted` - Global motion/flash control.

Accessed via `Juicee.accessibility` (the autoload singleton). Set flags from your game's settings screen.

### Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `reduced_motion` | `bool` | `false` | Halves ALL effect intensities. Game stays alive but calmer. |
| `no_flash` | `bool` | `false` | Silences TAG_FLASH effects (Flash, Strobe, AmbientFlash, ScreenTint). |
| `no_screenshake` | `bool` | `false` | Silences TAG_SCREENSHAKE effects (Shake, Recoil, etc.). |
| `no_chromatic` | `bool` | `false` | Silences TAG_CHROMATIC effects (Chromatic, Glitch, ColorGrade). |
| `intensity_scale` | `float` | `1.0` | Master multiplier (0-1). Applied after `reduced_motion`. |

### Signal

```gdscript
signal changed   # emitted when any flag changes - connect to HUD icons/tooltips
```

### Methods

```gdscript
func to_dict() -> Dictionary    # serialize to your save system
func from_dict(d: Dictionary)   # restore from save
```

### Tag constants (used in `get_accessibility_tag()`)

```gdscript
JuiceeAccessibility.TAG_NONE        # 0 - always plays at full intensity (audio, time, flow)
JuiceeAccessibility.TAG_FLASH       # 1 - Flash, StrobeLight, AmbientFlash
JuiceeAccessibility.TAG_SCREENSHAKE # 2 - Shake, Shake3D, DirectionalShake, Recoil
JuiceeAccessibility.TAG_CHROMATIC   # 3 - Chromatic, Glitch, ColorGrade
JuiceeAccessibility.TAG_MOTION      # 4 - Blur, Pixelate, Zoom (scaled by reduced_motion)
```

### Integration

```gdscript
# In your settings screen:
Juicee.accessibility.reduced_motion = settings.reduced_motion
Juicee.accessibility.no_flash       = settings.no_flash
Juicee.accessibility.no_screenshake = settings.no_screenshake

# Save/load:
save_data["accessibility"] = Juicee.accessibility.to_dict()
Juicee.accessibility.from_dict(save_data["accessibility"])
```

---

## JuiceeBeatClock

`class_name JuiceeBeatClock extends Node` - Accumulator-based BPM beat emitter.

Add to your scene tree as a regular node. Point `JuiceeBeatSyncEffect.clock_path` or `JuiceeZoomPulseEffect.clock_path` at it for musically tight beat sync.

### Exported properties

| Property | Type | Default | Description |
|---|---|---|---|
| `bpm` | `float` | `120.0` | Beats per minute (20-300). |
| `auto_start` | `bool` | `false` | Start the clock when `_ready()` fires. |

### Signal

```gdscript
signal beat(beat_number: int)
```
Fires on every beat. `beat_number` is 1-indexed and increments monotonically - use `beat_number % N == 0` to trigger every N beats.

### Methods

```gdscript
func start() -> void
func stop() -> void
func reset() -> void               # resets beat_number and accumulator to 0, keeps running
func get_beat_phase() -> float     # 0.0-1.0 position within the current beat interval
func get_beat_number() -> int      # current beat counter (0 = not started)
```

### Example

```gdscript
@onready var clock: JuiceeBeatClock = $BeatClock

func _ready() -> void:
    clock.bpm = 128.0
    clock.beat.connect(_on_beat)
    clock.start()

func _on_beat(n: int) -> void:
    if n % 4 == 0:  # every bar (4 beats)
        Juicee.zoom_pulse(self, 128.0, 0.12, 4.0)
```

---

## JuiceeGraphPlayer

`class_name JuiceeGraphPlayer extends Node` - Runtime graph executor.

**You don't need to use this directly.** The `Juicee` autoload and `JuiceePlayer` both delegate to it internally when playing a graph resource. Useful if you want to drive a graph purely from code.

```gdscript
static func play(resource: JuiceeGraphResource, context: Node) -> void
```
Walks the graph from its Trigger node, executing effects and honoring flow control (Split, Loop, Random, Condition). `await`able.

### Graph execution semantics

| Node type | Behavior |
|---|---|
| `trigger` | Entry point - execution starts here |
| `effect` | Calls `effect.apply(context)` and awaits it |
| `split` | All outputs fire concurrently (no await on any) |
| `loop` | Runs the connected chain `count` times sequentially |
| `random` | Picks one output weighted by `properties.weights` |
| `condition` | Evaluates `properties.expression` via `Expression`; port 0 = true, port 1 = false |

---

## JuiceeGraphResource

`class_name JuiceeGraphResource extends Resource` - Serialized graph.

Saved as `.tres`. Contains an array of `JuiceeGraphNodeData` and connection metadata. You rarely interact with this directly - the graph editor and player manage it.

### Methods

```gdscript
func find_trigger() -> JuiceeGraphNodeData     # returns the single Trigger node
func get_next(id: String) -> Array             # returns ordered list of next nodes
```

---

## JuiceeGraphNodeData

`class_name JuiceeGraphNodeData extends Resource` - Single node in a graph.

### Properties

| Property | Type | Description |
|---|---|---|
| `id` | `String` | Unique node ID (UUID-style) |
| `type` | `String` | `"trigger"`, `"effect"`, `"split"`, `"loop"`, `"random"`, `"condition"` |
| `effect` | `JuiceeEffect` | The effect instance (only for `type == "effect"`) |
| `properties` | `Dictionary` | Flow-control params (`count`, `expression`, `weights`, `port_count`) |
| `graph_position` | `Vector2` | Position in graph editor canvas |
