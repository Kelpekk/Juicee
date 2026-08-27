<!-- 
Thanks for contributing! For NEW effects, see CONTRIBUTING.md "Option A - PR" first.
Fill in whichever sections apply (delete the rest).
-->

## What this PR does

<!-- One sentence summary -->

## Type

- [ ] New effect
- [ ] Bug fix
- [ ] Graph editor / Inspector improvement
- [ ] Documentation
- [ ] Refactor / cleanup

## Demo (required for new effects)

<!-- 
Drag-drop a GIF or screenshot showing the effect in action.
For a non-visual change (refactor / bug fix), describe before / after instead.
-->

## Checklist for new effects

- [ ] File at `addons/juicee/effects/<name>_effect.gd`
- [ ] `class_name JuiceeXxxEffect` (Juicee prefix to avoid collisions)
- [ ] `extends JuiceeEffect`
- [ ] `## docstring` on every `@export` property
- [ ] Uses `_track()` for every `create_tween()` call
- [ ] Uses `JuiceeStateStack.capture` / `release` for any property restored at the end
- [ ] Manual loops check `_cancelled` flag
- [ ] `is_instance_valid(target)` guards on async paths
- [ ] Sensible default parameters - `Effect.new().apply(ctx)` produces a visible result
- [ ] Previews OK via JuiceeGraph ▶ Test (or noted as runtime-only with reason)
- [ ] Cleans up after `stop()` is called mid-effect

## Notes

<!-- Anything else reviewers should know? Trade-offs, related issues, follow-up tasks. -->
