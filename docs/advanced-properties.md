# Advanced properties

[Juicee](../README.md) / [Docs](../README.md#docs)

Every Juicee effect ships with more range than its default inspector shows. Turn on
**Advanced Properties** and each one opens up: 289 extra parameters across all 117
effects.

The split exists because those two audiences want opposite things. Someone dropping
Shake on a hit wants three sliders and a result. Someone tuning the feel of a whole
game wants the curve, the preset, and the ability to shake a HUD panel instead of the
camera. Advanced Properties lets the same effect serve both without the first person
scrolling past forty fields to find `intensity`.

## Turning it on

Three places, all the same switch:

- **Project Settings > Juicee > Advanced Properties**
- the **Advanced** checkbox in the JuiceePlayer inspector header
- the **Advanced** button in the JuiceeGraph toolbar

It is a project setting, not a per-node one, so it applies to every effect everywhere
and it sticks between sessions.

## What it changes, and what it does not

It changes **visibility only**. Nothing about how an effect runs depends on the
setting. Turning it on does not alter a single existing scene, and turning it back off
does not throw away values you set: the properties are still there and still in
effect, just hidden from the inspector.

Every advanced property but four defaults to the behaviour the effect already had.
`ease_curve` empty means the built-in easing, `preset` on Custom means your sliders,
`target_path` empty means the camera. The four are Burst's `shrink`, Impact Ring's
`spike_variance`, Slash Arc's `sweep_degrees` and Hit Spark's `spark_shape`: their defaults
are the look those effects have now, and [upgrading.md](upgrading.md) gives the values that bring back
1.x's, alongside everything else that changed since then.

## Patterns you will see everywhere

A handful of these repeat across the library. Learn them once:

**`ease_curve`** (31 effects). A hand-drawn `Curve` resource that replaces the
Transition/Ease dropdowns for that effect's main animation. Sample range is 0 to 1 on
both axes. This is the FEEL-style knob: an overshoot, a hard snap with a slow settle,
a double bump, anything the built-in easings cannot express. Leave it empty to keep
using Transition/Ease.

**`hold_time`** (22 effects). Seconds to sit at the peak before coming back. The
built-in shape is usually go-out-and-return with no pause; a hold turns a punch into a
pose. Useful on anything that should read as deliberate rather than reflexive.

**`intensity_curve`** (10 effects). Shapes strength over the effect's life rather than
its position, so a shake can ramp in and fall off on a curve you draw instead of the
fixed exponential decay.

**`pulse_count`** (9 effects) and **`oscillations`** (5 effects). Repeat the effect's
motion N times inside the same duration instead of once. Two pulses on a Vignette is a
heartbeat at low health; six oscillations on a shader parameter is a throb.

**`target_path`**. Where present, it redirects the effect at a specific node instead of
its default target. The clearest case is Shake, which normally moves `Camera2D.offset`
and with a target path will shake a sprite, a weapon or a HUD panel on its own.

## Worth knowing

Not a full list, just the ones that change what an effect can be used for. The complete
per-effect tables are in [effects-reference.md](effects-reference.md).

**Shake** gained `preset`: Impact, Earthquake, Rumble and Handheld are tuned sets of
intensity, frequency, decay and roll. Handheld is a low, constant, never-settling
drift for a documentary camera feel, which the old parameters could not reach because
decay always pulled it back to rest.

**Sparkle** gained `star_points` (4 is a classic twinkle, 8 is a starburst),
`spawn_shape` (scatter, an even ring, or thrown outward from the centre), a `palette`
to draw colours from, plus `drift` and `spin`.

**Burst** gained `particle_shape`: round dots, chunky squares for debris, or stars.
With `air_drag` particles shoot out and slow instead of flying ballistic, `fade_to`
sets the colour they die into (embers cooling to deep red), and `shrink` takes them
down to nothing.

**Shockwave** gained `falloff`, which was previously hardcoded, plus `ripples` and
`ripple_spacing` for a repeating pulse instead of one ring.

**Typewriter** gained a real cursor: `cursor_char`, `cursor_blink_rate` and
`cursor_after_finish`. It also now accepts any Control with `visible_ratio`, so it
works on a RichTextLabel and not only a plain Label.

**Number Count** gained `thousands_separator` and `pad_digits`, so a score reads as
`1,234,567` or `00042` instead of a bare integer.

**Reverb** gained `predelay_msec`, `hipass` and `dry`, and **Low Pass** gained
`resonance` and `rolloff_db`. These are properties Godot's audio effects have always
had and Juicee simply never exposed.

**Spring** gained float support. Its own docstring used to flag that as a gap; it now
springs a float property as well as a vector, alongside `initial_offset` and
`max_displacement`.

**Sound** gained `avoid_repeats`, which skips whatever played last so a repeated hit
sound stops machine-gunning the same sample, plus `fade_in`, `fade_out` and
`random_delay`.

**Instantiate** gained `count`, `scatter_radius`, `random_rotation` and
`scale_variance`, which turns a single spawn into a scattered handful.

## Muting a step

Related but separate from the setting: every effect has an **enabled** flag, always
visible. A muted effect is skipped by `apply()`, by sequences and by the graph, and it
does not consume its cooldown, so the rest of a sequence behaves exactly as it did.

It is there for A/B while tuning. Mute a step, play, unmute, instead of deleting it and
rebuilding it afterwards. In the inspector it is the eye button in an open row, or Mute on
the row's right-click menu; in the graph it is in the block's context menu, and a muted
block dims and says so in its title.

## Is this the last of it

Yes. The intent behind this pass was to take every existing effect as far as it goes
and close it, rather than keep returning to the same effects with one more parameter
each release. If an effect is missing something it obviously should do, that is a bug
worth reporting, not a feature waiting for a future version.
