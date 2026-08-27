# Juicee philosophy - when to use what

Juicee gives you **three ways** to fire the same set of effects. They're not duplicates - each fits a different stage of development.

## The 3 workflows

### 1. `Juicee` singleton - rapid prototyping

```gdscript
Juicee.shake_camera(self, 12.0, 0.3)
Juicee.flash(my_sprite, Color.RED)
Juicee.burst(self, 20, Color.YELLOW)
```

**Use when:**
- You're prototyping a feature and want juicee now
- The effect is one-off (e.g., critical hit explosion at hit position)
- You'd rather write code than wire up nodes

**Pros:** instant, no setup, no `.tres` file.

**Cons:** parameters live in code - designer can't tweak. No way to reuse the same sequence elsewhere without duplicating code.

### 2. Inspector - designer-friendly

```gdscript
@onready var hit_juicee: JuiceePlayer = $HitJuicee
func _on_hit(): hit_juicee.play()
```

Add a `JuiceePlayer` node, build a `JuiceeSequence` in the Inspector with the custom card UI. Tweak sliders, click **▶ Preview**.

**Use when:**
- The same juicee fires from multiple places
- A designer/artist (not the programmer) needs to tune it
- You want versioned, diff-able `.tres` files

**Pros:** designer-tweakable, reusable, version-controlled, in-editor preview.

**Cons:** for sequential / non-trivial flow (loops, branches, parallel groups) the array UI gets cramped.

### 3. Graph editor - complex flow

When your juicee needs **flow control** - "shake -> wait 0.1s -> flash 3 times -> 50% chance to confetti" - the linear array doesn't cut it. Open the JuiceeGraph bottom panel and wire it visually:

- **Trigger** = entry point
- **Split** = fan out (parallel)
- **Loop** = repeat N times
- **Random** = pick one branch
- effect nodes inline

**Use when:**
- You need branches, loops, or staged timing
- You want to see the whole flow at once
- You're designing a complex juicee sequence (boss intro, combo finisher)

**Pros:** branching / looping / random / parallel as first-class. Visual debugger highlights blocks as they fire.

**Cons:** for a 1-effect "just shake" call, the graph is overkill.

## Decision tree

```
need juicee now, one-off, code path?           -> Juicee singleton
need it reusable across N call sites?         -> Inspector (JuiceePlayer)
need branches / loops / random / parallel?    -> Graph editor
need to share a sequence across projects?     -> Save it as .tres and commit alongside your scenes
```

## Why all three coexist

A real game uses all three:

- **Singleton** for level-up confetti from one place - no need for a node.
- **Inspector** for the hit-reaction sequence used by every enemy class - designer tweaks it once, all enemies pick up the change.
- **Graph** for the boss intro sequence - 8 staged effects with loops and parallel branches.

Forcing one workflow to do everything is the FEEL/Sparkle mistake - they only have Inspector, so every quick prototype turns into a node-setup chore, and complex sequences become a wall of sub-resources.

## The same `.tres` everywhere

Whatever workflow you use, the persistence target is always a `JuiceeSequence` resource. The graph editor exports to one; the Inspector builds one inline; the singleton creates a transient one. This means:

- You can prototype with the singleton, then save the sequence to `.tres` and switch to Inspector
- A saved `.tres` works in all three contexts - load it from code, drop it on a JuiceePlayer, or open it in the graph editor

## What Juicee deliberately does NOT do

- **Movement juicee** (coyote time, jump buffering, etc.) - that's input/character-controller territory, not feedback territory
- **Animation system** - Godot's `AnimationPlayer` already handles keyframed animations; we focus on procedural, parametric effects
- **Full state machines for combat** - use Limbo AI or Beehave for that, then fire Juicee from state callbacks

We do **one thing**: trigger-based reactive feedback. The same niche FEEL and Sparkle occupy, plus the visual graph layer they don't have.

## Performance notes

- Screen-overlay shaders **cache the loaded `Shader`** via `preload` (no per-apply I/O)
- Each overlay effect uses a **named CanvasLayer** - second call replaces the first, no exponential GPU cost from stacked screen-reads
- Tweens are bound to short-lived nodes (the overlay, the target) and auto-killed when those nodes free - no orphaned animations
- `stop()` kills all in-flight tweens immediately (Phase 1 tween-tracking) - useful for "skip animation" buttons / scene transitions
- The `JuiceeStateStack` (Phase 2) makes overlapping effects safe - no stuck camera offsets after rapid shake-shake-shake
