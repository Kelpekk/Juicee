# Contributing to Juicee

Welcome! Juicee is intentionally **easy to extend** - adding a new effect is a single `.gd` file. No central registry, no enum to bump, no editor changes.

Two ways to share what you build, depending on where you want it to land:

## Option A - Pull Request (official inclusion)

For effects that fit the **core philosophy** (reactive, triggered-feedback juice - see [`docs/philosophy.md`](docs/philosophy.md)) and look generally useful to other devs.

1. Fork the repo and create a branch: `git checkout -b add-my-cool-effect`
2. Add your effect file: `addons/juicee/effects/my_cool_effect.gd`
   - Follow the 30-line template in [`docs/how-to-write-effect.md`](docs/how-to-write-effect.md)
   - `## docstring` on every `@export` property
   - Use `_track()` for tweens, `JuiceeStateStack` for restorable properties, `_cancelled` checks in manual loops
   - Sensible defaults - `EffectName.new().apply(some_context)` should produce a visible result with zero tweaking
3. Open a PR against `main` with:
   - A short description of what the effect does and when to use it
   - A GIF / screenshot showing the effect in action (drag-drop into the PR body)
   - Confirm: does it preview correctly in editor? does it stop cleanly via `stop()`?
4. We'll review, suggest tweaks if needed, and merge.

Once merged, your effect ships in the next release. Updater pulls it down for everyone.

### What gets merged vs. rejected

✅ **Likely merged**
- Visual-feedback effects (screen / camera / object / particle / time / audio)
- Effects with `@export`-tweakable parameters
- Effects that work in both 2D and 3D (or are clearly named `_3d`)
- Effects with clean cleanup paths

❌ **Better as a Discussion post (not merged)**
- Game-specific logic (combat hit reactions, dialog systems, etc.) - too narrow
- Effects requiring scene-tree restructuring of user's project (e.g., must add a SubViewport)
- Effects that depend on external addons / assets
- Stylistic variants of existing effects (skin them via parameters instead)

## Option B - Discussions (community share)

For:
- **Presets** - your `JuiceeSequence.tres` for a specific game-feel (e.g., "Vampire Survivors-style enemy hit reaction")
- **Niche effects** - game-specific logic you wouldn't want shipped in core but think others might fork
- **Experimental** - work-in-progress, asking for feedback before turning into a PR
- **Show-and-tell** - "here's how I used Juicee in my game" with video/GIF

How:
1. Go to the repo's **Discussions** tab
2. Pick the right category:
   - **🎬 Show & Tell** - your finished work in action
   - **💬 Q&A** - questions about API, workflow, integration
   - **💡 Effect ideas** - pitches before you implement, get community input first
   - **🎨 Custom effects & presets** - paste your `.gd` or `.tres` content for others to copy
3. Use a clear title (`[Preset] Vampire Survivors hit reaction` or `[Effect] Outline pulse on damage`)
4. Paste the code in a fenced block, add a short description + GIF

No review needed - post and share. Community can star, comment, or fork your snippet.

## Reporting bugs / requesting features

Use **Issues**, not Discussions, for:
- Bugs (effect crashes, leak, wrong behavior)
- Feature requests with clear scope ("Add `Camera3D shake support`", "Add undo/redo to graph editor")
- Documentation gaps you spotted

Use the issue templates if available - they prompt for the info we need to act on it.

## Code style

- **Indentation**: tabs (Godot's default - keep editor settings as-is)
- **`class_name JuiceeXxxEffect`** prefix on every new effect (avoids collisions with other addons / user code)
- **`## docstring`** on every `@export` property (becomes the tooltip in the JuiceeGraph popup)
- **No `print()` in production code** - use `push_warning()` / `push_error()` for real problems

## License

By contributing you agree your work is released under the MIT license, same as the rest of the addon.
