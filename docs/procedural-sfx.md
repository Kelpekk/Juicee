# Procedural sound effects (sfxr)

> ⚠️ **Experimental.** This is a prototyping aid producing 8-bit / chiptune-quality
> sound. The API may change in a future release, and it's off by default. For
> shipping audio, prefer hand-crafted assets via `JuiceeSoundEffect`.

Juicee can **synthesize retro game sounds at runtime — no `.wav` files required.**
It ships a faithful GDScript port of DrPetter's [sfxr](https://www.drpetter.se/project_sfxr.html)
as [`JuiceeSfxr`](../addons/juicee/audio/juicee_sfxr.gd), exposed through three
layers depending on how much control you want.

Perfect for prototyping and game jams: drop juice into a scene and it *sounds*
like a game immediately, with nothing to import or license.

## Categories

| Category | Use for |
|---|---|
| `PICKUP_COIN` | coins, items, collectibles |
| `LASER_SHOOT` | lasers, projectiles, dashes |
| `EXPLOSION`   | explosions, deaths, impacts |
| `POWERUP`     | power-ups, level-ups, victory |
| `HIT_HURT`    | taking damage, hits, zaps |
| `JUMP`        | jumps, hops |
| `BLIP_SELECT` | UI clicks, menu navigation |
| `RANDOM`      | fully randomized one-off |

## 1. One-liner from the singleton

```gdscript
Juicee.sfx(self, JuiceeSfxr.Category.PICKUP_COIN)

# With variety + tuning:
Juicee.sfx(self, JuiceeSfxr.Category.LASER_SHOOT,
    0,        # seed: 0 = fresh random variation each call
    -3.0,     # volume_db
    0.95, 1.05) # pitch_min / pitch_max (randomized per play)
```

## 2. As an effect (graph editor / Inspector / sequences)

`JuiceeProcSoundEffect` is a normal Juicee effect, so it appears in the
**JuiceeGraph** popup under *Audio*, in the `JuiceePlayer` Inspector, and can be
nested in any `JuiceeSequence`. Exports: `category`, `seed`, `bus`, `volume_db`,
`pitch_min`, `pitch_max`.

```gdscript
var sfx := JuiceeProcSoundEffect.new()
sfx.category = JuiceeSfxr.Category.EXPLOSION
sfx.apply(self)
```

## 3. Make the presets audible (opt-in)

By default the built-in presets are silent (no bundled audio). Flip one switch
and they synthesize their signature sound:

```gdscript
Juicee.sfx_enabled = true

Juicee.preset_hit(enemy)        # → hit/hurt zap
Juicee.preset_pickup(coin)      # → coin blip
Juicee.preset_explosion(self)   # → explosion
Juicee.preset_level_up(self)    # → power-up
```

It's opt-in (default `false`) so existing projects keep their current behavior.

## Determinism, caching, and cost

- **`seed = 0`** → a different variation every call (alive, non-repetitive).
- **Fixed `seed`** → the exact same sound every time. Seeded streams are cached,
  so repeated plays don't re-synthesize.
- Generation takes a few milliseconds for a short sound; the result is a normal
  mono 16-bit `AudioStreamWAV` you can also keep and reuse.

## Direct generation

Need the raw stream (e.g. to assign to your own `AudioStreamPlayer`, or to bake
to disk)?

```gdscript
var coin := JuiceeSfxr.make(JuiceeSfxr.Category.PICKUP_COIN, 12345)
$AudioStreamPlayer.stream = coin
$AudioStreamPlayer.play()

# Bake to a .wav:
coin.save_to_wav("user://coin.wav")
```

## From C#

```csharp
using JuiceeFX;

Juicee.Sfx(this, Juicee.SfxCategory.Explosion);
Juicee.SetSfxEnabled(true);   // presets now make sound
Juicee.PresetHit(enemy);
```

## A note on fidelity

sfxr produces **8-bit / chiptune-style** sounds — ideal for prototyping, jams,
arcade, and pixel-art games. For a final commercial mix you'll likely still want
hand-crafted audio; procedural SFX gets you 90% of the feel with 0% of the asset
pipeline.
