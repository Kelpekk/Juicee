# Live tuning

[Juicee](../README.md) / [Docs](../README.md#docs)

Change a parameter while the game is running and feel the difference immediately,
instead of quitting, editing and relaunching. Game feel is judged by feel, and the
usual loop puts several seconds and a context switch between the change and the
judgement.

## How to use it

1. Run the project the normal way (F5).
2. Select the `JuiceePlayer` whose sequence you want to tune.
3. A small green **live** appears in the effects header. Every value you change from
   here on is pushed into the running game as you change it.
4. Trigger the effect in game. It plays with the new value.

Turn on **Re-fire** next to it and you do not even have to trigger it: every
change replays the effect immediately on whatever node it last played on.

The graph panel pushes the same way. Edit a block's parameters while the game runs and
the change lands live, exactly as it does from the Inspector, and its toolbar shows the
same green **live** while a game is attached. Re-fire lives on the Inspector side only.

## What it can and cannot reach

Addressing is the effect's own resource path, so what matters is whether the effect
exists as a saved resource:

| Where the effect lives | Tunable |
|---|---|
| A `.tres` sequence on a `JuiceePlayer` | yes |
| An effect saved as its own `.tres` | yes |
| Built in code, e.g. `Juicee.shake_camera(self, 12.0)` | no |

The one-liners build a fresh effect object every call, so there is nothing on disk to
address and nothing persistent to change. Nothing breaks if you try; the push is simply
skipped.

## Where the changes end up

The editor is the source of truth. A change goes into the resource you are editing
exactly as it always did, with full undo, and is mirrored into the running game as a
side effect. So:

- **Stopping the game keeps your changes.** They were never only in the game.
- **Ctrl+Z works normally.** Undo in the graph panel is mirrored live like any other
  change. Undo in the Inspector is not, so the next value you push resyncs the game.
- **Saving is unchanged.** Ctrl+S on the scene or resource, as usual.

## Why this only exists while you are developing

The channel is Godot's editor debugger, which only exists in a debug build with the
editor attached. In an exported game nothing registers, `Juicee.live_tune` stays null,
and the only trace is one null check per effect play. There is no runtime cost to ship
and no way for this to be reachable in a released game.

## Limits worth knowing

- An effect is addressed by its resource path, so a graph you have never saved pushes
  nothing at all. Save it once and it starts working.
- A value pushed while an effect is mid-play lands on the resource straight away, but
  what is already running keeps the values it started with, unless Re-fire replays it.
- Re-fire replays on the node the effect last ran against. If that node is gone (the
  scene changed, the enemy died), the replay is skipped rather than retargeted.
