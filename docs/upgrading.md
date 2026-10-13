# Upgrading from 1.x

[Juicee](../README.md) / [Docs](../README.md#docs)

Nothing a 1.x project uses was removed or renamed. Every effect class, every exported
property and every signal is still there, so a project opens and runs without edits.

What changed is how some effects look and how long some of them last, and in a game-feel
addon that is the part you will notice. This page lists all of it, checked against the
1.5.0 code rather than written from memory.

## Before you replace the folder

**Move your own effects out of `addons/juicee/effects/` first.** The 1.x docs said to put
custom effects there, and the usual way to update an addon is to delete its folder and
install the new one, which deletes them along with it. Put them in a folder of your own,
add that folder to **Project Settings > Juicee > Effect Folders**, and they show up in
both effect pickers as before.

Nothing else needs doing. There is no new autoload and no setting to migrate.

## Defaults that changed

Godot does not save a property that was left at its default, so every effect you placed
without touching one of these picks up the new value. To keep the old look, set the old
value on that effect.

| Effect | Property | 1.5.0 | Now |
|---|---|---|---|
| Ambient Flash | `flash_color` | `Color(1.0, 0.2, 0.2, 0.5)` | `Color(1.0, 0.3, 0.3, 1.0)` |
| Burst | `speed` | `120.0` | `260.0` |
| Burst | `spread` | `120.0` | `180.0` |
| Burst | `particle_scale` | `2.5` | `2.4` |
| Flicker | `off_color` | `Color(0.1, 0.1, 0.1, 1.0)` | `Color(1.0, 1.0, 1.0, 0.0)` |
| Hit Spark | `spark_scale` | `1.4` | `2.2` |
| Impact Ring | `ring_width` | `5.0` | `6.0` |
| Impact Ring | `spike_length` | `26.0` | `34.0` |
| Impact Ring | `duration` | `0.36` | `0.45` |
| Radial Blur | `strength` | `0.03` | `0.05` |
| Shake | `roll_degrees` | `0.0` | `1.2` |
| Shake 3D | `intensity` | `0.25` | `0.06` |
| Slash Arc | `thickness` | `14.0` | `22.0` |
| Slash Arc | `duration` | `0.22` | `0.26` |
| Slash Arc | `color` | `Color(1.0, 1.0, 1.0, 0.9)` | `Color(1.0, 1.0, 1.0, 1.0)` |
| Sparkle | `count` | `6` | `9` |
| Sparkle | `spread` | `36.0` | `64.0` |
| Spring | `impulse` | `Vector2(0.5, 0.5)` | `Vector2(4.0, 4.0)` |
| Text Wobble | `amplitude` | `4.0` | `8.0` |

Six settings are new and their defaults change the look as well. The last column is the
value that gives you 1.5.0's behaviour back. The four marked Advanced only show in the
inspector with [Advanced Properties](advanced-properties.md) turned on, but they apply
either way.

| Effect | Property | Default | For 1.5.0's look |
|---|---|---|---|
| Shake 3D | `tilt_degrees` | `1.6` | `0.0` |
| Shake 3D | `roll_degrees` | `0.9` | `0.0` |
| Burst | `shrink` (Advanced) | `true` | `false` |
| Impact Ring | `spike_variance` (Advanced) | `0.35` | `0.0` |
| Slash Arc | `sweep_degrees` (Advanced) | `55.0` | `0.0` |
| Hit Spark | `spark_shape` (Advanced) | `STREAK` | `DOT` |

Most were effects too faint, too slow or too uniform to read at their defaults; the
[changelog](../CHANGELOG.md) names the larger ones.

## Durations that mean what they say

Eighteen effects drive themselves from a loop instead of a tween: Afterimage, Beat Sync,
Breathe, Camera Follow, Directional Shake, Flicker, Heartbeat, Jelly Wobble, Jiggle
Physics, Pulse, Shake, Shake 3D, Shake Control, Text Scramble, Trail, Wiggle, Wobble
Rotation and Zoom Pulse. In 1.x every wait in that loop rounded up to the next frame while
the loop counted only the time it had asked for, so these ran longer than their
`duration`. Measured at 30 fps, Wobble Rotation ran 2.07 times its duration, Jelly Wobble
2.00, Shake 1.76 and Wiggle 1.20. They now last as long as `duration` says, give or take the
last step of their loop.

If you tuned one of these by eye in 1.x, it will end sooner than you are used to. Lengthen
its `duration`. The old stretch depended on the effect's frequency and on the frame rate,
so there is no single factor to multiply by.

## Effects that look different

These changed in the code rather than in a default, so there is no value to set back:

- **Shake**, **Shake 3D** and **Directional Shake** shake in their default noise mode. In 1.x
  the noise barely moved: a default 8px Shake moved the camera under half a pixel. If you
  raised `intensity` to make a 1.x shake visible, bring it back down; the number now means
  what it says. A shake with `use_noise` off moves as it did.
- **Lens Distortion** fills the screen. A barrel (positive `strength`, the default) shrank the
  picture inside black corners; now the corners stay put and the middle bulges, so the same
  strength reads as a stronger punch in the centre. A pincushion looks as it did.
- **Shockwave** is round. In 1.x its ring was about three times wider than tall on a 16:9
  screen and ran off the sides almost at once; it now spreads the same distance in every
  direction, the distance it always covered up and down.
- **Shake 3D** shakes mostly by turning the camera now, with only a small movement. Moving a
  3D camera to shake it reads as the whole world jumping; turning it reads as an impact.
  The values in the tables above get you close to the 1.x version.
- **Impact Ring** thins as it spreads instead of thickening, its spikes vary in length and
  angle, and a white core flashes on contact.
- **Burst** fires in a full circle instead of a wedge with a bare patch on one side, and its
  particles stay solid for longer before they shrink and fade.
- **Sparkle** twinkles vary in size and ring the target instead of piling up on it.
- **Damage Number** punches its scale on every hit, not only on crits; a crit punches harder.
- **Hit Spark** sparks spread into a spray instead of travelling as one clump.
- **Squash Land** holds the flattened pose for a moment instead of leaving it within three
  frames at the default duration.
- **Flicker** blinks instead of dimming, and **Ambient Flash** flashes instead of fading.
- **Camera Bob** and **Directional Shake** move the camera's `offset` instead of its
  `position`, so they no longer drag a camera that follows something back to where it
  stood when they started.
- **Depth of Field** fades its blur in and out instead of switching it on and off, and puts
  the camera's focus distances back afterwards. Its strength is the new `blur_amount`
  (0.1, Godot's own default) rather than the Blur Amount set on the camera, so if you had
  raised that, set `blur_amount` to the same value.
- **Color Grade**, **Afterimage**, **Trail**, **Stutter** and **Audio Source 3D** follow
  `intensity` and reduced motion now: at half strength they grade half way, draw fainter
  ghosts, freeze for half as long and play quieter. At the default intensity of 1 they are
  unchanged.
- **Delay**, **Typewriter**, **Number Count** and **Animation Player** keep their timing under
  reduced motion and a scaled play. In 1.x reduced motion cut every Delay to a quarter and
  made typing, counting and animations four times slower. If you varied a Delay with
  `intensity_min` / `intensity_max`, use its `variance` instead.
- **Time Scale Ramp** lasts the real time its `ramp_in`, `hold` and `ramp_out` add up to. Its
  ramps ran on slowed time in 1.x, so a 0.85 s slow motion lasted about 1.6 s. If you tuned one
  by eye, lengthen the ramps.
- **Screen Tint** is silenced by `no_flash` and **Lens Distortion** by `no_screenshake`. The
  presets that tint the screen (level up, damage taken, boss intro, victory) lose the tint
  when a player turns flashing off.

## Things that failed quietly and now work

If you set these up in 1.x and saw nothing happen, they will do something now:

- **A `JuiceePlayer` parked next to the node the effects were meant for.** The player hands effects
  the node it is parented to, and each effect needs a kind of node: a `Node2D` to move, a
  `CanvasItem` to tint, a `Light2D` to flash. A player under a plain `Node` next to the sprite
  therefore warned once per effect and did nothing, and 1.x left you to point `target_path` at the
  sprite yourself. An effect now looks for the kind of node it needs, under the node it was handed
  first, then up the parents, stopping short of the scene root. On a host with a sprite, a label, a
  light, a body, an animation player and an emitter beside the player, 39 of the 117 effects used to
  do something and 96 do now. A `target_path` you have already set still says where to start, and
  an effect's own `target`, `light_path` or `camera_path` is still taken exactly as it reads.
- **A player with `auto_play` on, playing an effect that puts something on screen.** The play went
  out from `_ready()`, where the node it plays on is still entering the tree and cannot take a
  child, so the screen shaders, Screen Tint, Freeze Frame, Cinematic Bars, Screen Wipe, Sound,
  Procedural Sound and Typewriter's keystroke sound got "Parent node is busy setting up children"
  and did nothing on that one play. It now goes out at the end of the frame, one frame later than it
  used to.
- **Depth of Field on a camera you had not given a `CameraAttributesPractical`.** It warned, because
  that resource holds the blur. It makes one when the slot is empty and takes it back off with the
  rest of the camera's settings.
- **Particle Control on a `CPUParticles3D` or `GPUParticles3D`.** It only recognised the 2D emitters.
- **Afterimage** and **Trail** on an `AnimatedSprite2D`. In 1.x they only looked for a
  `Sprite2D`, warned once and drew nothing.
- **Material 3D** on a mesh with a `material_override`. It used to animate a surface
  override that the override was hiding. On a mesh with a `ShaderMaterial` it used to crash
  the game; it now drives the shader parameter of that name.
- **Set Active** with an empty `target_path`. It used to do nothing; like everywhere else in
  Juicee, an empty path now means the node the effect was played on.
- **Spawning effects inside a `SubViewport`**: damage numbers, floating text, bursts,
  sparkles, confetti, impact rings, cracks, slash arcs, hit sparks and afterimage ghosts.
  They used to appear in the main window at coordinates that meant nothing there.
- **Tonemap** inside a `SubViewport`, or with no current scene. It used to warn and do
  nothing where Bloom worked.
- **Shader Parameter** on a uniform that was never set in the inspector. It used to error out;
  it now starts from the default the shader declares.
- **Explosion Push** with `include_partial_overlap` on, the default. A body whose shape
  reached into the blast but whose centre was outside it got a push of zero; it gets a light
  push from the edge now.
- **Rumble** with `fade_out` and a single pulse, the default. The fade only worked between
  pulses.
- **Impulse** with `{"impulse": Vector2}` passed to the play. The value was never read.
- **Beat Sync**'s `accent_every` with a Beat Clock. Every trigger counted as the first, so
  every trigger was accented.
- A **Sequence** step passing runtime params such as `hit_direction` on to the sequence
  inside it.
- Two audio-bus effects overlapping on one bus (Reverb, Pitch Shift, Low-Pass, Distortion,
  Time Scale Ramp's `pitch_bus`). The one that finished second could be left on the bus for
  good, or take a different effect off it.
- Two shakes, wobbles or bobs at once on one camera or node. The one that ran last each frame
  hid the other, so a strong shake under a weak one that landed after it all but vanished, and
  each overlap printed a warning. They add up now, scaled back when many pile up: a second
  hit shakes the screen a little harder, not softer.
- **Outline** on a node with a sprite under it. It drew nothing; it outlines the sprite now. On a
  Label or a Button, where it turned the letters into blocks, it warns and does nothing.

## In the editor

- **The Transition dropdown on Scale and Shader Parameter shows the curve you actually get.**
  Five of its twelve entries were mislabelled: Bounce gave Cubic, Back gave Circ, Spring gave
  Bounce, Cubic gave Back and Circ gave Spring. The stored number has not changed, so nothing
  plays differently. A field that said Bounce and has been playing Cubic all along now says
  Cubic.
- **Advanced Properties** is a new project setting, off by default, that hides 289 extra
  parameters. It only shows and hides them: a value set while they are visible still applies
  once they are hidden again.
- **Three static helpers on the editor-only `JuiceeGraphEditor` are gone**: `category_color()`,
  `color_mode()` and `effect_color()`, along with the category colour wash they drew. Nothing
  outside the graph editor used them.
- **Pulse** and **Shake Control** are listed under Object, where the README and the reference
  always had them, instead of under Text. Eighteen effects, most of them from 1.5.0, drew in a
  fixed blue whatever their category, so Tremolo looked like an Object effect in the Audio
  section; they take their category's colour now and follow the Effect Color Mode setting.

## Stopping, playing again, and sharing a sequence

What a 1.x game might notice from the robustness pass:

- **`stopped` fires.** An effect's and a sequence's `stopped` signal never reached anyone in
  1.x. It comes from `stop()` now, once everything is back, for a run that had started.
- **A play dropped by `cooldown` or `chance` leaves a running play alone.** In 1.x such a call
  still cut the running play short. A call that does play replaces the running one cleanly,
  the old play's cleanup included, so an audio effect no longer piles up on its bus.
- **`stop()` takes down what an effect left in place on purpose**: an overlay with `fade_out`
  off, Screen Wipe's `hold`, Ambient Flash's `hold_at_end`, a Rich Text Emphasis with no
  duration. In 1.x nothing but playing the effect again did. It also stops a sound the effect
  started, and stopping a Chain or a Sequence step stops the effects they started.
- **Each JuiceePlayer plays copies of the sequences in its scene.** Instances of a scene share
  their sub-resources, and in 1.x hitting a second enemy cut the first one's effects short. The
  copies are made when the player is ready, so `get_sequence()` and `player.sequence` are the
  player's copy from then on; a reference to the `.tres` taken elsewhere is not what plays. A
  sequence you assign from code after that is played as it is.
- **Nonsense values are refused or brought into range.** NaN, an infinity or an enum value
  outside its list stops the play with a warning; a value the engine would refuse (a lifetime
  or pitch of 0, a negative radius) is brought into range; counts in the millions are capped.
  Nothing a slider can reach is affected.
- **Beat Sync's accent** rides on the play's intensity instead of raising the child effect's
  intensity range for the length of the call. It sounds and looks the same.
- **Cooldowns, Tremolo and Time Scale Ramp count engine time.** In a live game that is the
  same as the wall clock they used; under Movie Maker it is what the recording shows.
- **`stop()` in the middle of a play undoes it.** The node goes back to how it was before the
  play, also for the effects that leave a change in place when they run their course: a Fade or
  Spin with its restore off, Flip, Size Delta, Typewriter, Text Scramble and Number Count. In 1.x
  most of them stopped where they were, half faded or half typed. A play that has ended keeps what
  it left. To show a Typewriter's whole line on a skip, set the label's `visible_ratio` to 1 after
  `stop()`, or the text itself when the line came in `params`.
- **A change meant to stay survives an effect beside it.** In 1.x a Shake or a Flash on the same
  property, ending after a permanent move, fade or scale, put the property back to before the
  change.
- **A runtime param of the wrong type is left out with a warning**, where 1.x stopped the play
  with a script error, and an `intensity` above 10 plays at 10.
- **Custom effects keep working, and wake up now.** A coroutine waiting on a tween that `stop()` or
  a new `apply()` killed used to stay asleep for good; it wakes, so code after an `await` runs for
  a play that is over. An effect that checks `_still_playing()` (or `_cancelled`, after a stop)
  returns there. One that checks nothing gets any tween it starts next ended at once, so it runs
  to its end in the same frame; anything else it does after the `await`, like writing a property
  directly, happens then.

## Godot versions

Still Godot 4.3 or newer. The full test sweep passes on 4.3, 4.4.1, 4.6.1 and 4.7, and so does a
fresh install with nothing in the project but `addons/juicee`.

On 4.3 that first import prints one parse error, `Could not find base class
"EditorContextMenuPlugin"`. That class arrived in 4.4, and the file it names is the right-click
**Add JuiceePlayer** shortcut in the Scene dock, which is the one feature 4.3 does not get. Godot
parses every script in the project when it imports, which is where the line comes from; the addon
itself never loads that file on 4.3 and everything else works. It does not come back on later
opens.
