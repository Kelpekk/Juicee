# Core API reference

[Juicee](../README.md) / [Docs](../README.md#docs)

Complete reference for every class in the Juicee framework. For effect params, see [effects-reference.md](effects-reference.md). For the singleton API, see [singleton-api.md](singleton-api.md).

Classes: [JuiceeEffect](#juiceeeffect), [JuiceeSequence](#juiceesequence), [JuiceePlayer](#juiceeplayer), [JuiceeStateStack](#juiceestatestack), [JuiceeHaptics](#juiceehaptics), [JuiceeNodePool](#juiceenodepool), [JuiceeAccessibility](#juiceeaccessibility), [JuiceeBeatClock](#juiceebeatclock), [JuiceeGraphPlayer](#juiceegraphplayer), [JuiceeGraphResource](#juiceegraphresource), [JuiceeGraphNodeData](#juiceegraphnodedata).

---

## JuiceeEffect

`class_name JuiceeEffect extends Resource` - Base class for all effects.

Every effect extends this class, the built-in ones and any in your own effect folders. It handles the full apply lifecycle: mute check -> cooldown gate -> chance roll -> the play before it put away -> settings checked -> pre-delay -> intensity multiplication -> accessibility gate -> `_apply()` -> signals.

### Exported properties (inherited by every effect)

| Property | Type | Default | Description |
|---|---|---|---|
| `chance` | `float` | `1.0` | Probability (0-1) this effect fires. `1.0` = always, `0.5` = 50% chance. |
| `delay` | `float` | `0.0` | Pre-delay in seconds before `_apply()` runs. It waits on game time, so `Engine.time_scale` slows it. |
| `intensity_min` | `float` | `1.0` | Lower bound of the per-play intensity multiplier. |
| `intensity_max` | `float` | `1.0` | Upper bound of the per-play intensity multiplier. Both `1.0` = no randomization. |
| `cooldown` | `float` | `0.0` | Minimum seconds between `apply()` calls on this resource. |
| `enabled` | `bool` | `true` | `false` mutes the effect: `apply()`, sequences and the graph skip it, and its cooldown is not used up. |
| `graph_position` | `Vector2` | `Vector2.ZERO` | Block position in the visual graph editor. Don't edit manually. |

A setting no play can make anything of stops the play, with a warning, instead of reaching the node: NaN or an infinity in any exported number, vector, colour or array of them, or an enum value that is none of its choices. The same values passed to `apply()` in `params` are left out of that play, and an `intensity` that is not a number is ignored.

### Signals

| Signal | Args | When |
|---|---|---|
| `started` | - | `_apply()` is about to run (after delay and gates) |
| `finished` | - | `_apply()` returned normally |
| `stopped` | - | `stop()` was called during a run. Sent by `stop()` itself, once everything is put back. A play stopped in its delay never started and sends nothing |
| `delay_started` | `seconds: float` | The pre-delay timer started (used by graph debug bar) |
| `warning` | `message: String` | A bad setup made the effect bail out. The graph and the Inspector flash the block or card with it. The signal fires on every play; the same message reaches the Output at most once every five seconds, so one bad step on a fast trigger cannot bury the log |

### Public methods

```gdscript
func apply(context: Node, params: Dictionary = {}) -> void
```
Entry point. Runs the full pipeline: cooldown -> chance -> delay -> intensity -> accessibility -> `_apply()`. **Do not override.** Pass runtime params like `{"hit_direction": Vector2.LEFT}`.

An effect plays one play at a time. A call dropped by `cooldown` or `chance` leaves a play already running alone; one that goes ahead replaces it, and the running play is put away the way `stop()` would put it away, cleanup included, without the `stopped` signal. Playing one effect resource on two nodes at once is the same thing: the second play takes it over. `JuiceePlayer` keeps copies of its own for that reason, and `own_copy()` below makes one for code that needs it.

`intensity` scales a single play: `apply(node, {"intensity": 1.8})` so a heavy hit and a light one can share a sequence and still read differently. It multiplies with the effect's own `intensity_min`/`intensity_max` randomization rather than replacing it, `0.0` skips the play, and anything above `10` plays at `10`, with a warning.

A param of the wrong type, like `{"hit_direction": "left"}`, is left out with a warning saying what was expected, and the play goes on as if it had not been passed. A number stands in for the other kind of number, a `Vector2i` for a `Vector2`, and a colour name or code like `"red"` or `"#ff8800"` for a `Color`. Effects that switch or time something rather than having a strength (Flip, Instantiate, Particle Control, Screen Wipe, Text Scramble, Camera Follow, the property, shader and material tweens, and the Flow steps) play the same at any intensity.

```gdscript
func stop() -> void
```
Cancels the current run immediately and undoes it: the scene goes back to how it was before the play, whatever the play would have left behind had it run its course. Kills all `_tracked` tweens, gives back what the play holds on the state stack, runs the cleanup it registered (an overlay, an effect on a bus, a sound), and sends `stopped` if the play had started. Bumps the generation counter so pending delays abort without reaching `_apply()`. A play that ended holding something on purpose, like an overlay left up by `fade_out` off or a value held by `hold_at_end`, is given back as well; what a play that ended left in place for good (a permanent move, a typed-out line) stays. Three things are let finish past the stop: Cinematic Bars slide out, an Auto Destruct already dissolving its node still frees it, and the pieces a burst has already thrown (Burst, Confetti, Hit Spark, Sparkle, Crack, Slash Arc, Afterimage) live out their short life and go by themselves.

```gdscript
func is_playing() -> bool
func is_busy() -> bool
func is_holding() -> bool
```
`is_playing()` is `true` between `started` and `finished`/`stopped`. `is_busy()` is that, or waiting out the pre-delay. `is_holding()` is `true` after a play ended holding something only `stop()` or the next play gives back (`fade_out` off, `hold_at_end`, a Rich Text Emphasis with no duration), or a sound it started that is still ringing.

```gdscript
static func unscaled_seconds() -> float
```
Seconds of game time that `Engine.time_scale` and pausing leave alone, counted the way the engine counts frames, so it keeps step with `--fixed-fps` and Movie Maker where a wall clock does not. Cooldowns, Tremolo, Time Scale Ramp and Typewriter's cursor count on it.

```gdscript
static func own_copy(res: Resource, copies: Dictionary = {}) -> Resource
```
A copy of an effect or a `JuiceeSequence` with every effect and sequence inside it copied too, and everything else (curves, textures, sounds) shared. For code that plays one resource on several nodes at once. A resource reached twice stays one copy, and a copy of an effect saved in a file follows live tuning of that file.

```gdscript
static func start_nested(child: JuiceeEffect, context: Node, params: Dictionary) -> String
```
Starts an effect from inside another play and returns why it did not start, or `""`. Chain, Sequence, Beat Sync, `JuiceeSequence` and the graph start their steps through it: past 64 levels of effects starting effects within one frame, the steps lead back to their own parent, and it cuts the loop with that reason instead of running the script stack out.

```gdscript
func can_play_on(context: Node) -> bool
```
Whether a play on that node would find something to work on: the node itself, or one the search
would move to (see [What an effect plays on](#what-an-effect-plays-on)). `false` means it would
warn and do nothing. An effect that names its own target is taken at its word. This is what
`JuiceePlayer` uses to warn in the Scene dock before you ever press play.

```gdscript
func cooldown_remaining() -> float
```
Seconds until the cooldown expires. `0.0` if ready.

### Virtual methods (override in subclasses)

```gdscript
func _apply(context: Node, intensity_mult: float) -> void
```
**The only method you override.** `intensity_mult` is `randf_range(intensity_min, intensity_max)`, times the caller's `intensity` param when there is one, times the accessibility multiplier (`intensity_scale`, and a quarter of that under reduced motion). If it comes to zero, because accessibility blocks the effect or the caller passed 0, `apply()` never calls `_apply()`.

```gdscript
func get_display_name() -> String          # "My Cool" - defaults to parsed script name
func get_category_name() -> String         # "Camera", "Screen", etc. - graph popup grouping
func get_category_color() -> Color         # colored titlebar stripe on graph blocks
func get_icon_path() -> String             # SVG icon path for graph block titlebar
func get_description() -> String           # tooltip in graph popup
func get_accessibility_tag() -> int        # one of JuiceeAccessibility.TAG_*
func get_required_nodes() -> PackedStringArray  # kinds of node this effect can act on
```

`get_required_nodes()` is what the search above reads: class names, or `"property:name"` for an
effect that drives a named property. The built-ins answer from the catalog; a custom effect that
returns, say, `PackedStringArray(["Node2D"])` gets the same treatment, and one that returns nothing
is played on whatever node it is given.

### Protected methods (use in subclasses)

```gdscript
func _track(tween: Tween) -> Tween
```
Register a tween for cleanup. **Every `create_tween()` call must be wrapped.** Otherwise `stop()` can't kill it.
```gdscript
var tween := _track(target.create_tween())
```

```gdscript
func _capture_state(target: Object, property: String) -> Variant
func _release_state(target: Variant, property: String, restore: bool = true) -> void
```
Take a property's true original through `JuiceeStateStack` before changing it, and give it back when done. `stop()` releases whatever is still held, so an effect stopped mid-play still restores. Use these rather than the stack directly. Capture even a change you mean to keep, and let it go with `restore = false` at the end: the stack then knows the original if the play is stopped half way, and effects still holding the property come back to the kept value rather than undoing it.

```gdscript
func _capture_offset(target: Object, property: String) -> Variant
func _write_offset(target: Object, property: String, original: Variant, offset: Variant, reach: float) -> void
```
`_capture_state()` for a manual loop that moves a property by an offset around its original, as a shake or a bob does. Write the property with `_write_offset()` instead of assigning it, and every such loop on the property adds up instead of the last to run each frame hiding the rest: the property gets `original` plus all their offsets, scaled back when many pile up so together they reach about one and a half times as far as the widest. `reach` is how far your offset goes at the moment, its amplitude rather than this frame's sample. Alone on the property, it sets `original + offset` and nothing else. Released by `_release_state()` like any capture.

```gdscript
func _keep_state(target: Variant, property: String, value: Variant) -> void
```
`_release_state()` with `restore = false`, naming the value to keep. Other effects holding the property come back to `value` when they end. Use it when another effect may be writing the property this very frame, as a Flash writes the `modulate` a Fade is keeping, so reading it back would keep the Flash's colour.

```gdscript
func _param(key: String, fallback: Variant) -> Variant
```
A param passed to `apply()`, when it has the type of `fallback`, the type your effect uses. Otherwise `fallback`, with a warning. Read params through it rather than `_runtime_params` directly, and one wrong value at the call site will not stop the play with a script error.

```gdscript
static func _tween_done(tween: Tween) -> void
```
Waits for a tween left out of `_track()`, on a node the play spawned or one `stop()` is meant to let run. A tween whose node is freed never sends `finished`, so `await tween.finished` on such a tween can wait for good; this returns once the tween is over either way. Tracked tweens need nothing: a tracked tween dropped with its node gets `finished` sent for it.

```gdscript
func _wait_step(tree: SceneTree, step: float) -> float
```
Wait `step` seconds inside a manual loop and return how long the wait really took, in whole frames. Add that to the loop's clock, not `step`: a timer can only fire on a frame, so the wait is usually longer than asked.

```gdscript
func _play_id() -> int
func _still_playing(play_id: int) -> bool
```
Keep `_play_id()` at the start of `_apply()` and check `_still_playing()` after every `await`. A new `apply()` replaces the play and resets `_cancelled` for the one it starts, so a loop that checks only `_cancelled` carries on beside the new play, and what it releases at its end is the newer play's hold.

```gdscript
func _on_stop(cb: Callable, outlives_restart: bool = false) -> void
func _free_on_stop(node: Node, outlives_restart: bool = false) -> void
```
Cleanup that `stop()` runs, for what the state stack does not cover: a node the play spawned, an effect it put on a bus. A new `apply()` runs it too, for the play it replaces, unless `outlives_restart`: Floating Text's labels stack when it is fired again. A node given to `_free_on_stop()` with `outlives_restart` is kept track of until it is gone, past the end of its own play as well, so a `stop()` after later plays still takes it down. `_free_on_stop()` binds the node's id; a lambda that captures a node reports an error when called after the node was freed, whatever its body checks.

```gdscript
func _hold_until_stop(cb: Callable) -> void
func _free_when_released(node: Node) -> void
```
For a state the play leaves in place on purpose when it ends (an overlay with `fade_out` off): kept past the end and run by the next `stop()` or play.

```gdscript
func _capped(value: int, cap: int, what: String) -> int
func _start_child(child: JuiceeEffect, context: Node, params: Dictionary) -> bool
static func _spring_step(x, v, stiffness: float, damping: float, mass: float, dt: float) -> Array
```
`_capped()` limits a count of things built in one frame, with a warning. `_start_child()` is `start_nested()` for a composite effect, which also skips a child that is the composite itself or leads back to it, and stops the child when the composite is stopped. `_spring_step()` advances a damped spring and cannot diverge, whatever the stiffness, damping and mass.

```gdscript
func _warn(message: String) -> void
```
Report a bad setup (wrong target type, empty resource, missing node). Pushes the warning and emits `warning`, which the graph and the Inspector show on the block or card.

```gdscript
func _tween_curved(tween, target, prop_name, from_value, to_value, duration, curve) -> Tweener
```
Curve-aware property tween. If `curve` is `null`, falls back to `tween_property` (caller sets `set_trans`/`set_ease`). If `curve` is set, samples it per-frame - gives designers custom easing shapes without touching code.

```gdscript
func _spawn_screen_shader_overlay(context, layer_name, z=128) -> Array  # [CanvasLayer, ColorRect]
func _spawn_screen_solid_overlay(context, layer_name, z=128) -> Array   # [CanvasLayer, ColorRect]
func _sweep_overlay_layers(context, layer_name) -> void
```
Screen overlay helpers. `_spawn_screen_shader_overlay` creates a `BackBufferCopy` + `ColorRect` pair - necessary for effects that read `SCREEN_TEXTURE` in their shader. `_spawn_screen_solid_overlay` creates just a `ColorRect` (for tints, bars, flash overlays). `_sweep_overlay_layers` cleans up any stale layers from a previous run; both spawn helpers call it for you.

### Static variables

```gdscript
static var accessibility: JuiceeAccessibility
```
Set by `Juicee` autoload in `_ready()`. All effects read this automatically - zero per-effect code needed.

### Internal variables (read-only in subclasses)

```gdscript
var _runtime_params: Dictionary   # params passed to apply()
var _cancelled: bool              # set by stop(), reset by the next apply() - loops check _still_playing()
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
| `cooldown` | `float` | `0.0` | Minimum seconds between plays of this sequence when a `JuiceePlayer` fires it. `0` falls back to the player's own cooldown. |
| `graph_connections` | `PackedStringArray` | `[]` | Graph editor wire data. Auto-managed. Format: `"from_id:from_port:to_id:to_port"`. |

### Methods

```gdscript
func play(context: Node, params: Dictionary = {}) -> void
```
Plays the sequence. `await`able - returns when all effects finish (or are stopped/cancelled). `params` is forwarded to every effect's `_apply()` via `_runtime_params`. A play started while another is running replaces it. A step stopped from outside, or whose node leaves the tree, does not hold the sequence up: it moves on, and stops once the node it plays on is gone.

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
| `stopped` | - | `stop()` was called during a play. Sent by `stop()` itself |
| `effect_started` | `effect: JuiceeEffect` | Just before an effect's `_apply()` runs |
| `effect_finished` | `effect: JuiceeEffect` | After an effect's `_apply()` returns |

---

## JuiceePlayer

`class_name JuiceePlayer extends Node` - Scene node that owns and fires a `JuiceeSequence`.

### Exported properties

| Property | Type | Default | Description |
|---|---|---|---|
| `sequence` | `JuiceeSequence` | `null` | The default sequence. Bare `play()` fires this one. Build inline or load a `.tres`. |
| `sequences` | `Array[JuiceeSequence]` | `[]` | More sequences on the same node, fired by name: `play("crash")`. |
| `auto_play` | `bool` | `false` | Call `play()` automatically when the node enters the tree, at the end of that frame: a node cannot take a child while its subtree is still entering, so an effect spawning an overlay from `_ready` would lose it. |
| `target_path` | `NodePath` | `""` | The node effects start from. Empty = the parent. Either way, an effect needing another kind of node looks for the nearest one from there (see below). |
| `trigger_source` | `NodePath` | `""` | Node that emits the auto-trigger signal. |
| `trigger_signal` | `StringName` | `""` | Signal name on `trigger_source` - auto-fires `play()` when received. Accepts any arity. A dropdown of that node's actual signals once `trigger_source` is set. |
| `cooldown` | `float` | `0.0` | Minimum seconds between `play()` calls. |
| `queue_during_cooldown` | `bool` | `false` | Queue one pending `play()` during cooldown instead of dropping it. |

### Methods

```gdscript
func play(name_or_params: Variant = null, params: Dictionary = {}) -> void
func stop() -> void
func get_sequence(sequence_name: StringName = &"") -> JuiceeSequence
func sequence_names() -> Array[StringName]
func is_on_cooldown(sequence_name: StringName = &"") -> bool
func cooldown_remaining(sequence_name: StringName = &"") -> float
static func name_of(seq: JuiceeSequence) -> StringName
static func problems_with(seq: JuiceeSequence, context: Node, label: String = "") -> PackedStringArray
```

`stop()` stops every sequence on the player, not just the one that is playing.

In the game, a player plays copies of the sequences the scene gave it, made when it is ready. Instances of a scene share their sub-resources, and effects play one play at a time, so without the copies a second enemy being hit took the first one's effects from it mid-play. `get_sequence()` returns the player's copy, whose signals fire and whose values belong to this player alone; live tuning reaches the copies. A sequence assigned from code after that is played as it is.

### What the editor tells you before you press play

The player reports three kinds of problem under the node in the Scene dock, and refreshes them as
you edit: a step that is empty or has the one parameter it cannot do without left blank (an
Animation Player with no `animation_name`, a Sound with no streams), a path that points at nothing,
and an effect that has no node of the kind it needs on or near this player. A muted step is never
reported, because muting it was the point. `problems_with()` is the same check as a function, for a
tool or a test of your own.

### What an effect plays on

Effects need a particular kind of node: a `Node2D` to move or scale, a `CanvasItem` to tint, a `Control` to punch, a `Light2D` to flash. The player hands over `target_path`, or the node it is parented to, and where that is the wrong kind the effect looks for the right one: under that node first, so a player parked beside the sprite finds it, then up the parents, stopping before the scene root so an effect never grabs the whole game. The search downwards is breadth first and looks at the 256 nearest nodes, so the nearest match wins and a level with twenty thousand nodes costs a play no more than a character with twenty, and it steps over the nodes Juicee spawns for itself (ghosts, overlays, spawned labels and audio players, all named `_juicee*`), so one effect never lands on another one's ghost or overlay.

An effect that names its own node keeps it: `target`, `light_path`, `mesh_path`, `camera_path`, `particle_path`, `player_path`, `tree_path`, `origin`, `property_path` and `parent_path` are all measured from the context, so moving the context would point them somewhere else. Effects driving a named property or a shader uniform look for a node that carries it rather than for a class. When nothing suitable is anywhere near, the effect warns in the output and does nothing, as it always did.

### Several sequences on one node

A node per reaction adds up fast, and each one is another place to keep a target and a cooldown in step. Put the extras in `sequences` and fire them by name, the way `AnimationPlayer` works:

```gdscript
$JuiceePlayer.play()                          # the default `sequence`
$JuiceePlayer.play({"hit_direction": LEFT})   # the default, with runtime params
$JuiceePlayer.play("crash")                   # one of `sequences`
$JuiceePlayer.play("crash", {"force": 12.0})
```

A sequence answers to its **resource name**, falling back to its **file name**. One saved as `crash.tres` is `play("crash")` with nothing else to set up. The `sequence` slot stays the default and answers to its own name as well.

Cooldown is tracked per name, so a crash is never swallowed because a boost just fired. When several reactions share a node and want different cooldowns, set `JuiceeSequence.cooldown` on each one; the player's own `cooldown` applies to any sequence that leaves it at 0.

The context node (`target_path`) is per player, so a sequence that has to animate a *different* node still needs its own player.

### Signals

| Signal | When |
|---|---|
| `started` | `play()` passed cooldown and started a sequence |
| `finished` | A sequence completed normally |
| `sequence_started(name)` | Same as `started`, but says which one |
| `sequence_finished(name)` | Same as `finished`, but says which one |
| `blocked_by_cooldown` | `play()` was called during cooldown |

### Signal trigger

Set `trigger_source` + `trigger_signal` to wire effects without code. Example: an `Area2D` with `body_entered` - when a body enters, `play()` fires automatically. The trigger fires the default `sequence`; named ones are called from code.

---

## JuiceeStateStack

`class_name JuiceeStateStack extends RefCounted` - Concurrent-safe property restore.

**Static class** - all methods are `static`. No instance needed.

### Problem it solves

Without this, two simultaneous shakes both capture `cam.offset`. The first to finish restores to the mid-shake snapshot of the second, leaving the camera stuck. With the stack, only the first capture stores the TRUE original; all subsequent captures get the same original back and increment a ref count. The property is only restored when the LAST effect releases it.

### Methods

```gdscript
static func capture(target: Variant, property: String, from_loop: bool = false) -> Variant
```
Captures `target[property]` if not already captured, increments ref count, returns the original value; a freed or null `target` captures nothing and returns `null`. Property can be a sub-path: `"modulate:a"`, `"scale:x"`. Pass `from_loop` when the caller writes the property from a manual loop rather than a tween; the stack only counts it, so that an effect about to be silently overwritten can be told.

```gdscript
static func release(target: Variant, property: String, restore: bool = true,
		from_loop: bool = false) -> void
```
Decrements ref count. At zero, restores original and removes the entry. Safe to call on a freed target - stale entries are pruned automatically. `from_loop` must match what was passed to `capture()` so the loop count stays balanced. With `restore = false` the change stays, and holders that remain come back to the value the property has now rather than to the one before.

```gdscript
static func keep(target: Variant, property: String, value: Variant, from_loop: bool = false) -> void
```
`release()` with `restore = false`, naming the value holders that remain come back to. For a change meant to stay while another effect may be writing the property this frame.

The target is a `Variant` in all four, not an `Object`: Godot 4.3 refuses a freed instance at a typed parameter with a script error before the function can see it is gone.

```gdscript
static func hold_counts(target: Variant, property: String) -> Vector2i
```
How many effects hold this property (`x`) and how many of those write it from a loop (`y`). More than one holder with at least one loop among them is the combination where a loop-driven effect can go invisible, unless every holder adds an offset (`_capture_offset()`); `JuiceeEffect` checks this on capture and warns. See [what two effects on one property actually do](architecture.md#what-actually-happens-when-two-effects-share-a-property).

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

## JuiceeHaptics

`class_name JuiceeHaptics extends Node` - The only thing in Juicee that calls `Input.start_joy_vibration`.

Created by the `Juicee` autoload and reachable as `JuiceeEffect.haptics`.

### Problem it solves

Godot's rumble API replaces rather than mixes, and one `stop_joy_vibration()` silences every motor. Measured on an XInput pad: a rumble running at 0.9 that a 0.1 one overlaps drops to 0.1, and stays at 0.1 after the short one has finished. A landing thump landing on top of a crash takes 89% of it away and then leaves the wrong value on the controller. There is no fixing that from the calling side, because two writers to a replacing API is the bug. One writer is the fix.

### Methods

```gdscript
func play(device: int, weak: float, strong: float, duration: float,
		fade_out: bool = false) -> Rumble
```
Adds a rumble to the mix and hands back a handle. Ignoring the handle is fine; the rumble expires on its own. Its `duration` is real time, untouched by `Engine.time_scale` and pausing, since the player's hands are not in slow motion; an infinite one runs until stopped. Magnitudes are clamped to 0..1, and one that is NaN counts as 0.

```gdscript
func stop(handle: Rumble) -> void      # ends one rumble, leaves the others running
func stop_all(device: int = -1) -> void  # ends everything, on one device or all
func active_count() -> int             # how many rumbles are in the mix
```

Overlapping rumbles combine by max rather than by sum: two medium hits summing to 1.0 reads as a bug, while "the strongest thing happening right now" is what a player expects a controller to convey. One `Input` call goes out per device per frame.

Deliberately small. Godot exposes two motor magnitudes and a duration with no frequency channel of any kind, so there is no richer model to build - anything taking a `frequency` would be a lie in the signature.

Vibration reaches the player physically, so it sits behind `Juicee.accessibility.no_haptics` like flashing and screen shake do.

---

## JuiceeNodePool

`class_name JuiceeNodePool extends RefCounted` - Node reuse for effects that spawn a lot of them.

Afterimage, Crack, Hit Spark, Slash Arc and Sparkle each keep one as a `static var`, so fifty sparks at once do not churn the allocator. Idle nodes are detached from the tree and parked; the next spawn hands one back. The caller owns re-parenting and resetting the node's state on acquire, which keeps the pool node-type agnostic.

### Methods

```gdscript
func acquire(factory: Callable) -> Node
```
Returns a parked node if one is free, otherwise calls `factory` (a `Callable` returning a `Node`). Detached from any parent either way. A node freed behind the pool's back is skipped rather than handed out.

```gdscript
func release(node: Variant) -> void
```
Parks `node` for reuse, detaching it from its parent, unless the pool is at `cap` (then it is freed). Safe with a freed or already-parked node: releasing the same node twice does not park it twice, which would otherwise hand one node to two callers on the next two acquires.

```gdscript
var cap: int = 64                  # parked-node ceiling; past it, released nodes are freed
func free_count() -> int           # how many are parked and ready
func clear() -> void               # free every parked node and empty the pool
```

---

## JuiceeAccessibility

`class_name JuiceeAccessibility extends RefCounted` - Global motion/flash control.

Accessed via `Juicee.accessibility` (the autoload singleton). Set flags from your game's settings screen.

### Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `reduced_motion` | `bool` | `false` | Effects play at a quarter of their strength. The game stays alive but calmer. Durations do not change, and effects with no strength to scale (see `intensity` above) play as usual. |
| `no_flash` | `bool` | `false` | Silences TAG_FLASH effects (Flash, Strobe Light, Flicker, Glow Pulse, Ambient Flash, Screen Tint). |
| `no_screenshake` | `bool` | `false` | Silences TAG_SCREENSHAKE effects (Shake, Shake 3D, Directional Shake, Recoil, Camera Bob, Camera Rotation, Wobble Rotation, Lens Distortion). |
| `no_chromatic` | `bool` | `false` | Silences TAG_CHROMATIC effects (Chromatic, Glitch). |
| `no_haptics` | `bool` | `false` | Silences TAG_HAPTIC effects (Rumble). Vibration reaches the player physically, so it gets a switch like flashing and shake do. |
| `intensity_scale` | `float` | `1.0` | Master multiplier (0-1), multiplied with the quarter from `reduced_motion`. |
| `quality` | `Quality` | `HIGH` | How much the particle-heavy effects spawn: `LOW` gives Burst, Confetti, Hit Spark and Sparkle four pieces in ten, `MEDIUM` seven. Nothing else reads it, so the same effects still play. |

### Signal

```gdscript
signal changed   # emitted when any flag changes - connect to HUD icons/tooltips
```

### Methods

```gdscript
func to_dict() -> Dictionary    # serialize to your save system (quality included)
func from_dict(d: Dictionary)   # restore from save
func density_scale() -> float   # 0.4 / 0.7 / 1.0 by quality; what the four spawners multiply by
```

### The settings panel

`addons/juicee/ui/accessibility_settings.tscn` is a `VBoxContainer` you can instance straight into
an options menu: five toggles, the intensity slider and the quality dropdown, each wired to this
object, so a change reaches every effect at once. Save it yourself with `to_dict()` / `from_dict()`.
Its script is `JuiceeAccessibilityPanel` if you would rather build your own container.

### Tag constants (used in `get_accessibility_tag()`)

```gdscript
JuiceeAccessibility.TAG_NONE        # 0 - no switch of its own (audio, time, flow); reduced_motion still scales it
JuiceeAccessibility.TAG_FLASH       # 1 - Flash, StrobeLight, Flicker, GlowPulse, AmbientFlash, ScreenTint
JuiceeAccessibility.TAG_SCREENSHAKE # 2 - Shake, Shake3D, DirectionalShake, Recoil, CameraBob, CameraRotation, WobbleRotation, LensDistortion
JuiceeAccessibility.TAG_CHROMATIC   # 3 - Chromatic, Glitch
JuiceeAccessibility.TAG_MOTION      # 4 - CinematicBars; no switch of its own, reduced_motion scales it
JuiceeAccessibility.TAG_HAPTIC      # 5 - Rumble
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

Add to your scene tree as a regular node. Point `JuiceeBeatSyncEffect.clock_path` at it for musically tight beat sync.

### Exported properties

| Property | Type | Default | Description |
|---|---|---|---|
| `bpm` | `float` | `120.0` | Beats per minute (20-300 in the Inspector). A bpm of 0, negative, NaN or infinite beats not at all, and one faster than the frame rate can show fires at most 16 beats a frame. |
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

This is how a saved graph plays: call it with the graph and the node to run it on. `JuiceePlayer` plays sequences, not graphs, so a graph whose branching you want to keep goes through here.

```gdscript
static func play(resource: JuiceeGraphResource, context: Node) -> void
```
Walks the graph from its Trigger node, executing effects and honoring flow control (Split, Loop, Random, Condition). `await`able. A graph with no Trigger, or a node not in the scene tree, gets a warning and plays nothing. The walk ends once the node it plays on leaves the tree.

```gdscript
static func run(resource: JuiceeGraphResource, context: Node, observer := Callable(), keep_going := Callable()) -> void
```
`play()` for code that watches the walk, which is how the editor's Test lights blocks up. `observer` is called with `("fire", block, "")` when the walk reaches a block, `("end", block, "")` once its effect is done, and `("warn", block, message)` for a Condition that could not be read. The walk ends at its next step once `keep_going` returns `false`.

### Graph execution semantics

| Node type | Behavior |
|---|---|
| `trigger` | Entry point - execution starts here |
| `effect` | Starts `effect.apply(context)` and waits until the effect is no longer busy, so one stopped from outside does not hold the walk up |
| `split` | All outputs run at once, and the walk waits for every branch before it goes on |
| `loop` | Runs the connected chain `count` times sequentially, or until the node leaves the tree with `infinite`. A count that is not a number is one pass |
| `random` | Picks one of its wired outputs, each weighted by its own port's entry in `properties.weights`, or all alike when the list is shorter than the port count. A weight that is not a finite number counts as 0, and an output left unwired is never picked |
| `condition` | Evaluates `properties.expression` via `Expression`; port 0 = true, port 1 = false, whichever of them is wired, and the walk ends there when the port it takes has nothing wired. One that does not parse or fails says why and takes port 0 |

Graphs that loop back on themselves play rather than crash. The walk goes block by block in a loop, not a call per block, so its length is not limited by the script stack; it passes at most 256 blocks in one frame, so a cycle of blocks that take no time cannot freeze the game; and a Split wired back into itself runs at most 1024 branches at once.

---

## JuiceeGraphResource

`class_name JuiceeGraphResource extends Resource` - Serialized graph.

Saved as `.tres`. You rarely interact with this directly - the graph editor and player manage it.

### Properties

| Property | Type | Description |
|---|---|---|
| `nodes` | `Array[JuiceeGraphNodeData]` | Every block in the graph |
| `connections` | `PackedStringArray` | One `"from_id:from_port:to_id:to_port"` per wire |
| `positions_at_100` | `bool` | Whether the positions are at 100% editor scale. The graph editor saves them that way; a graph from 1.5.0 or earlier has `false`, and its positions are converted when the editor opens it |

### Methods

```gdscript
func find_trigger() -> JuiceeGraphNodeData     # returns the single Trigger node
func get_next(id: String) -> Array             # returns ordered list of next nodes
func get_next_by_port(id: String) -> Dictionary  # {output port: [next nodes]}
func to_sequence() -> JuiceeSequence           # the graph flattened into a sequence, as Export Sequence does
```

---

## JuiceeGraphNodeData

`class_name JuiceeGraphNodeData extends Resource` - Single node in a graph.

### Properties

| Property | Type | Description |
|---|---|---|
| `id` | `String` | Unique node ID (UUID-style) |
| `type` | `String` | `"trigger"`, `"effect"`, `"split"`, `"loop"`, `"random"`, `"condition"`, `"comment"` |
| `effect` | `JuiceeEffect` | The effect instance (only for `type == "effect"`) |
| `properties` | `Dictionary` | Flow-control params (`count`, `expression`, `weights`, `port_count`) |
| `graph_position` | `Vector2` | Position in the graph editor, at 100% editor scale |
