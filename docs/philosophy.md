# Philosophy: when to use what

[Juicee](../README.md) / [Docs](../README.md#docs)

Juicee gives you **three ways** to fire the same set of effects. They're not duplicates - each fits a different stage of development.

## The 3 workflows

### 1. `Juicee` singleton: rapid prototyping

```gdscript
Juicee.shake_camera(self, 12.0, 0.3)
Juicee.flash(my_sprite, Color.RED)
Juicee.burst(self, 20, Color.YELLOW)
```

**Use when:**
- You're prototyping a feature and want juice now
- The effect is one-off (e.g., critical hit explosion at hit position)
- You'd rather write code than wire up nodes

**Pros:** instant, no setup, no `.tres` file.

**Cons:** parameters live in code - designer can't tweak. No way to reuse the same sequence elsewhere without duplicating code.

### 2. Inspector: designer-friendly

```gdscript
@onready var hit_juicee: JuiceePlayer = $HitJuicee
func _on_hit(): hit_juicee.play()
```

Add a `JuiceePlayer` node, build a `JuiceeSequence` in the Inspector with the custom card UI. Tweak sliders, click **Preview Effect**.

<p align="center"><img src="screenshots/inspector1.png" alt="A JuiceeSequence in the Inspector, one card per effect" width="300"></p>

**Use when:**
- The same juice fires from multiple places
- A designer/artist (not the programmer) needs to tune it
- You want versioned, diff-able `.tres` files

**Pros:** designer-tweakable, reusable, version-controlled, in-editor preview.

**Cons:** for sequential / non-trivial flow (loops, branches, parallel groups) the array UI gets cramped.

### 3. Graph editor: complex flow

<p align="center"><img src="screenshots/graph-editor1.png" alt="The same kind of effects wired as a graph, with Split, Loop and Random nodes" width="560"></p>

When your juice needs **flow control** - "shake -> wait 0.1s -> flash 3 times -> 50% chance to confetti" - the linear array doesn't cut it. Open the JuiceeGraph bottom panel and wire it visually:

- **Trigger** = entry point
- **Split** = fan out (parallel)
- **Loop** = repeat N times
- **Random** = pick one branch
- effect nodes inline

**Use when:**
- You need branches, loops, or staged timing
- You want to see the whole flow at once
- You're designing a complex sequence (boss intro, combo finisher)

**Pros:** branching / looping / random / parallel as first-class. Visual debugger highlights blocks as they fire.

**Cons:** for a 1-effect "just shake" call, the graph is overkill.

## Decision tree

```text
need juice now, one-off, code path?           -> Juicee singleton
need it reusable across N call sites?         -> Inspector (JuiceePlayer)
need branches / loops / random / parallel?    -> Graph editor
need to share a sequence across projects?     -> Save it as .tres and commit alongside your scenes
```

## Why all three coexist

A real game uses all three:

- **Singleton** for level-up confetti from one place - no need for a node.
- **Inspector** for the hit-reaction sequence used by every enemy class - designer tweaks it once, all enemies pick up the change.
- **Graph** for the boss intro sequence - 8 staged effects with loops and parallel branches.

Forcing one workflow to do everything makes the other two jobs worse: a quick prototype turns into node setup, and a long staged sequence into a wall of sub-resources.

## Two resources, three workflows

Everything you save is one of two resources:

- A **`JuiceeSequence`**, a flat list of effects. The Inspector builds one on a `JuiceePlayer`, and code plays one with `Juicee.play_sequence()`.
- A **`JuiceeGraphResource`**, what the graph editor saves, branches and loops included. `JuiceeGraphPlayer.play(graph, node)` runs it.

The graph editor opens either one, turning a sequence into a straight graph, and **Export Sequence** turns a graph back into a flat sequence, running every branch in order. The singleton builds a single effect in code and saves nothing, so keeping something you prototyped there means rebuilding it as a sequence.

## What Juicee deliberately does NOT do

- **Movement feel** (coyote time, jump buffering, etc.) - that's input/character-controller territory, not feedback territory
- **Animation system** - Godot's `AnimationPlayer` already handles keyframed animations; we focus on procedural, parametric effects
- **Full state machines for combat** - use Limbo AI or Beehave for that, then fire Juicee from state callbacks

We do **one thing**: trigger-based reactive feedback, the niche FEEL fills on Unity, with a visual graph on top.

## Performance notes

- Screen-overlay shaders **cache the loaded `Shader`** via `preload` (no per-apply I/O)
- Each overlay effect uses a **named CanvasLayer** - second call replaces the first, no exponential GPU cost from stacked screen-reads
- Tweens are bound to short-lived nodes (the overlay, the target) and auto-killed when those nodes free - no orphaned animations
- `stop()` kills all in-flight tweens and puts back what the play changed - useful before a scene transition
- The `JuiceeStateStack` makes overlapping effects safe - no stuck camera offsets after rapid shake-shake-shake
