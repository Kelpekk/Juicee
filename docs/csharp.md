# Using Juicee from C#

Juicee is written in GDScript, but the **entire singleton API** is callable from
C# / .NET Godot projects through a thin bridge that ships with the addon:
[`addons/juicee/csharp/Juicee.cs`](../addons/juicee/csharp/Juicee.cs).

The bridge forwards every call to the GDScript `Juicee` autoload at runtime, so
there is **one shared implementation** — C# and GDScript run the exact same
effect code.

## Requirements

- The **.NET / Mono build** of Godot 4 (the one that supports C#).
- The Juicee plugin enabled: *Project → Project Settings → Plugins → Juicee*.
  This registers the `Juicee` autoload that the bridge talks to.

That's it — no extra setup. Your project's `.csproj` already globs every `.cs`
file under the project, so `Juicee.cs` is picked up automatically. In a
GDScript-only project the file is simply ignored (a loose `.cs` is inert without
a .NET SDK), so shipping it harms nothing.

## Quick start

```csharp
using Godot;
using JuiceeFX;

public partial class Player : CharacterBody2D
{
    public void TakeHit(int damage, bool crit)
    {
        // One-liners, fire-and-forget — same as GDScript's Juicee.*
        Juicee.HitStop(this, 0.08f);
        Juicee.ShakeCamera(this, 14f, 0.3f);
        Juicee.Flash(GetNode<Sprite2D>("Sprite"), Colors.Red);
        Juicee.DamageNumber(this, damage, crit);

        // Battle-tested presets
        if (crit) Juicee.PresetHitCrit(this);
        else      Juicee.PresetHit(this);
    }
}
```

## Naming

| GDScript                                   | C#                                      |
|--------------------------------------------|-----------------------------------------|
| `Juicee.shake_camera(self, 15.0, 0.3)`     | `Juicee.ShakeCamera(this, 15f, 0.3f)`   |
| `Juicee.hit_stop(self, 0.08)`              | `Juicee.HitStop(this, 0.08f)`           |
| `Juicee.preset_level_up(self)`             | `Juicee.PresetLevelUp(this)`            |
| `Juicee.flip(spr, ..., SET_TRUE)`          | `Juicee.Flip(spr, Juicee.FlipMode.SetTrue)` |

Method names are PascalCase; everything else matches the GDScript signature
(same parameter order and defaults).

## Enums

GDScript effect enums are mirrored as nested C# enums:

- `Juicee.FlipMode` — `Toggle`, `SetTrue`, `SetFalse`
- `Juicee.ForceMode` — `Impulse`, `ConstantForce`, `TorqueImpulse`
- `Juicee.ParticleAction` — `Emit`, `Stop`, `Restart`, `Toggle`
- `Juicee.SetActiveAction` — `Show`, `Hide`, `Toggle`
- `Juicee.LogLevel` — `Print`, `PushWarning`, `PushError`
- `Juicee.AnimTreeMode` — `Travel`, `SetParameter`

```csharp
Juicee.AddForce(rigid, new Vector2(0, -400), Juicee.ForceMode.Impulse);
Juicee.ParticleEmit(this, "Sparks", Juicee.ParticleAction.Restart);
```

## Sequences and `.tres` resources

Build sequences visually in the JuiceeGraph editor (or the Inspector), export a
`JuiceeSequence.tres`, then play it from C#:

```csharp
var seq = GD.Load<Resource>("res://fx/big_hit.tres");
Juicee.PlaySequence(seq, this);

// Optional runtime params forwarded to every effect:
var p = new Godot.Collections.Dictionary { { "hit_direction", Vector2.Left } };
Juicee.PlaySequence(seq, this, p);
```

For one-off composition, the `JuiceePlayer` node also works from C# — add it to
a scene, assign a sequence, and call `player.Call("play")`.

## Audio effects

Audio pools are typed Godot arrays:

```csharp
var streams = new Godot.Collections.Array<AudioStream>
{
    GD.Load<AudioStream>("res://sfx/hit1.wav"),
    GD.Load<AudioStream>("res://sfx/hit2.wav"),
};
Juicee.PlaySound(this, streams);
Juicee.Audio3D(this, streams, maxDistance: 30f);
```

## Stoppable effects

A few helpers return the running effect so you can stop it later
(`CinematicBars`, `PresetLowHealthPulse`):

```csharp
GodotObject pulse = Juicee.PresetLowHealthPulse(GetNode<Sprite2D>("Sprite"));
// later, when health recovers:
pulse.Call("stop");
```

## Accessibility

```csharp
Juicee.SetReducedMotion(true);   // silences shake / wobble
Juicee.SetNoFlash(true);         // disables flash / strobe
Juicee.SetNoScreenshake(true);   // disables camera shake only
```

## Troubleshooting

- **"Juicee: singleton not found at /root/Juicee"** — the plugin isn't enabled,
  or you called before the autoload was ready. Enable it in Project Settings.
- **`using JuiceeFX;` not found** — make sure the project built at least once
  (`Build` button) so the new file is compiled into the assembly.
