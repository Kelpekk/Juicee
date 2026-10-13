# Juicee in a multiplayer game

[Juicee](../README.md) / [Docs](../README.md#docs)

Juicee has no networking code in it anywhere - no `rpc`, no `MultiplayerSynchronizer`,
no awareness of `multiplayer` at all. That is deliberate, not a gap: game feel is
almost always something each player experiences locally, and baking replication into
every effect would make the common case (a purely local game) pay for a feature it
never uses. This page is about the pattern to use instead, and the two places where
"just call it" is not quite enough.

## Most effects: call them locally, decide who sees them yourself

Shake, flash, hit-stop, screen effects, particles, damage numbers, audio - these are
cosmetic. Player A getting hit should not shake player B's camera. The right pattern is
an RPC around the *event*, with each peer firing its own local Juicee call in response:

```gdscript
@rpc("authority", "call_local", "reliable")
func _on_took_damage(amount: int, is_crit: bool) -> void:
    Juicee.damage_number(self, amount, is_crit)
    Juicee.flash(sprite, Color.RED)
    if is_multiplayer_authority():
        # Only the hit player's own camera shakes - not everyone's.
        Juicee.shake_camera(self, 12.0, 0.3)
```

The `is_multiplayer_authority()` check in that example is what keeps the shake local to
the player it happened to, rather than every observer's camera shaking too. Whether you
want that split (local-only shake, but a flash and a damage number everyone sees) is a
game design call Juicee has no opinion on - it will happily fire on every peer that
calls it, exactly as told.

## The physics effects need authority, or they will fight your networking

Knockback, Add Force, Impulse, Explosion Push and Gravity Shift write straight to
`RigidBody2D`/`RigidBody3D`: `apply_central_impulse()`, `apply_impulse()`,
`constant_force` and `gravity_scale`. Those calls are exactly as authoritative (or not) as the code that
made them. If two peers both call `Juicee.knockback()` on the same body because both
ran the hit-detection logic, you get two impulses and a body position that disagrees
between clients - the same desync you would get calling `apply_impulse()` directly
without going through Juicee at all.

The fix is the same one you would already be using for any physics call in a networked
game: only the peer with authority over that body applies the impulse, and lets
replication (`MultiplayerSynchronizer`, or your own state sync) carry the result to
everyone else.

```gdscript
func _on_hit(body: RigidBody2D, direction: Vector2) -> void:
    if not body.is_multiplayer_authority():
        return
    Juicee.knockback(body, direction, 400.0)
```

## Engine.time_scale is process-wide, not per-peer

Hit Stop, Time Scale Ramp, Freeze Frame and Stutter all work by moving
`Engine.time_scale`, which is a single value for the whole running process - not a
per-scene or per-viewport setting. Across a real network (separate machines, separate
processes) this is exactly what you want: freezing time on your own screen when you
land a hit has no way to reach anyone else's process, because it *is* a different
process.

The case this bites is same-process multiplayer that people build for other reasons -
split-screen, or several `SubViewport`s in one window for local co-op or testing.
There, `Engine.time_scale` is shared by every viewport, so a Hit Stop triggered by one
player's action freezes the whole screen, not just their pane. If that is not what you
want, either keep hit-stop reactions to genuinely global moments (a shared "you both
got it" beat reads fine frozen for everyone), or skip Juicee's time-scale effects for
that mode and drive per-viewport slow-motion some other way (`Tween` on a per-camera
or per-viewport parameter your gameplay code already reads).

## What this does not need to be

None of this calls for the effects themselves to grow multiplayer awareness. Juicee's
job stops at "make the moment feel good on the screen it runs on" - deciding which
screens that is belongs in your game's own networking code, the same way it already
decides who takes damage or whose turn it is.
