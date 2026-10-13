# Graph editor

[Juicee](../README.md) / [Docs](../README.md#docs)

The **JuiceeGraph** bottom panel is a visual node graph for building sequences with branching, looping, and parallel execution. Open it from the bottom dock in the Godot editor.

<p align="center"><img src="screenshots/graph-editor1.png" alt="The JuiceeGraph panel: a Trigger into a Split whose three paths lead to a Hit Stop and Shake chain, a Loop and a Random pick, with effect blocks coloured by category" width="720"></p>

---

## Overview

The graph editor saves a `JuiceeGraphResource` (`.tres`) that `JuiceeGraphPlayer.play(graph, node)` walks at play-time. **Export Sequence** turns it into a flat `JuiceeSequence.tres` for a `JuiceePlayer`, losing any branching (see [Saving and loading](#saving-and-loading)), and **Open** takes either kind of file, turning a sequence into a straight graph.

The graph and `JuiceeSequence` share the same effect instances - all three workflows (singleton, Inspector, graph) are interoperable.

---

## Toolbar

| Button | Action |
|---|---|
| **New** | Clear the canvas and start a new graph. Asks first when the graph has unsaved changes. |
| **Open** | Load a `.tres` graph, or a `JuiceeSequence`, which opens as a straight graph holding copies of its effects. Asks first when the graph has unsaved changes. |
| **Save** | Save the graph to a `.tres` file. Once it has a file, the editor's own save (`Ctrl+S`) saves it too, and closing the editor with unsaved changes asks the way an unsaved scene does. |
| **Test** | Run the graph on the root of the scene you are editing. Blocks pulse as they fire. Press it again, now **Stop**, to end the run. |
| **Export Sequence** | Save the graph as a flat `JuiceeSequence.tres`, see [Saving and loading](#saving-and-loading). |
| **Fit** | Fit all blocks into view, down to half size; a graph too big for that is centred instead. |
| Hand tool | Pan by dragging with the left mouse button while it is on. A middle-mouse drag always pans. |
| Minimap | Toggle GraphEdit's corner overview. Handy once a graph outgrows the screen. |
| **Align** | Line the selected blocks up in a row and space them evenly. Hold `Shift` for a vertical column. One undo step. |
| **Advanced** | Toggle Project Settings > Juicee > Advanced Properties, see [advanced-properties.md](advanced-properties.md). |
| **Rescan** | Look again for effect scripts, in the addon and in your effect folders. |
| **Update** | Check GitHub releases for a newer version of Juicee. |

---

## Canvas interactions

| Action | How |
|---|---|
| **Add node** | Right-click on empty canvas -> searchable popup |
| **Add node from wire** | Drag a wire to empty space -> popup opens, auto-connects on selection |
| **Connect nodes** | Drag from an output port to an input port |
| **Disconnect** | Drag the wire off the input port it ends at |
| **Select** | Click a block or drag-select |
| **Multi-select** | `Shift`+click or `Ctrl`+click |
| **Move** | Drag selected blocks |
| **Copy, cut, paste, duplicate** | `Ctrl+C`, `Ctrl+X`, `Ctrl+V`, `Ctrl+D` |
| **Select all** | `Ctrl+A` |
| **Deselect** | `Esc` |
| **Delete** | `Delete` on selected blocks (removes connections too) |
| **Undo/Redo** | `Ctrl+Z` / `Ctrl+Y` - registered with Godot's `EditorUndoRedoManager` |
| **Find a block** | `Ctrl+F` - filters blocks by title as you type, then selects and centres the match. `Up`/`Down` to move through results, `Enter` to jump, `Esc` to close |
| **Mute a block** | Right-click a block > Mute. A muted effect is skipped when the graph runs, without consuming its cooldown. The block dims and its title says `(muted)`. Use it to A/B a step while tuning |
| **Zoom** | Mouse wheel |
| **Pan** | Middle-click drag, or left-drag with the hand tool on |
| **Show or hide the panel** | `Alt+G`, which works while the panel is hidden too |
| **Block preview** | Click **▶** on any effect block to preview that single effect |

---

## Node types

### Trigger

Entry point. Every graph needs exactly one. Execution begins here when `JuiceeGraphPlayer.play()` is called. The add-node popup will not add a second, and copying a Trigger pastes everything else you copied.

- No input port.
- One output port -> connects to the first effect or flow node.

---

### Effect nodes

One block per effect. The block title shows the effect's display name; the subtitle shows its category ("Camera", "Screen", etc.) and how long the effect runs.

**Selecting a block** opens its property panel on the right side of the graph editor. Properties match the effect's `@export` fields - same sliders and pickers as the Inspector.

**▶ (preview button)** in the titlebar fires just this effect on the root of the scene you are editing. Screen shader effects render in the editor preview viewport with an amber outline hint.

**Dimension tags** (small `2D` / `3D` icons) in the titlebar mark an effect that works in one dimension only, and only when that is not the dimension of the scene you are editing: a 3D-only effect in a 2D scene is tagged, a 2D-only one is not. Most blocks carry no tag, so an untagged block is the ordinary case rather than a missing label. The Inspector marks its rows by the same rule.

---

### Split

Parallel fan-out. All connected outputs fire at the same time without `await`. Use for simultaneous effects (shake + flash + chromatic all at once).

- Adjustable port count via **+** / **−** buttons (2-8 outputs).
- All ports fire concurrently - execution continues down each path independently.

---

### Loop

Repeat a chain N times sequentially. Each iteration waits for the previous to finish.

- Single output port -> the chain to repeat.
- `count` property controls repetitions.
- Subtitle shows "Repeat × N" live as you type.

---

### Random

Pick exactly one output at random (weighted) and run that branch only.

- Adjustable port count (2-8).
- `weights` property: array of relative weights, one per port. `[1, 2, 1]` gives the middle option 2× probability.
- If `weights` is empty or shorter than the port count, equal probability is used.
- An output left unwired is never picked, and the others keep their own port's weight.

---

### Condition

Evaluate a GDScript expression against `context`. Branch on the result.

- **Port 0** -> True branch.
- **Port 1** -> False branch.
- Wire only one of them and the other result ends the walk at the Condition.
- `expression` property: a GDScript expression string evaluated via `Expression`. Has access to the `context` variable.
- Fixed 2-output ports - no +/− controls.

**Expression examples:**

```gdscript
context.health < 20
context.is_in_group("player")
context.visible
context.get_meta("invincible", false) == false
context.velocity.length() > 200.0
```

The expression is evaluated by both the runtime player (`JuiceeGraphPlayer`) and the editor's **Test** runner - both paths are consistent.

If expression parsing or execution fails, it defaults to `true` (True branch) and emits a `push_warning`.

---

## Properties panel

Selecting a block opens a scrollable panel on the right side of the graph editor. It shows all `@export` properties of the effect, each with the line from its docstring under the name:

- **float / int** with a range -> slider with the value and both ends of the range; without one, a spin box
- **Enum** -> dropdown
- **bool** -> checkbox
- **Color** -> colour picker button; a list of colours -> a row of swatches you can add to and remove from
- **String / StringName** -> text field, or a dropdown when the value is one of a fixed set, such as an audio bus
- **Vector2 / Vector3** -> one field per axis
- **NodePath** -> path input you can drag a node onto (see below)
- **Anything else** (an array of sounds or effects, a Curve, a scene, a font, a nested effect or sequence, a value of any type) -> a button showing what the field holds. It opens the effect in the Inspector at that field, where Godot's own editors handle it, and an edit made there marks the graph unsaved.

Every change is registered with `EditorUndoRedoManager`, so `Ctrl+Z` reverts it.

### NodePath fields

Effects that act on a specific node rather than on the one the sequence plays on (Light 3D, Material 3D, Particle Control, Animation Player, Impulse, and the rest) expose a `NodePath`.

**Drag the node out of the Scene dock and drop it on the field.** The path fills itself in, relative to the scene root, which is what the effect resolves against when you press **▶ Test**. Typing a path by hand still works.

Each of these fields declares the class it accepts, so dropping the wrong kind of node is refused, and Godot's own node picker filters to the right type. An empty path means the node the sequence plays on, and where that is the wrong kind the effect looks for the nearest right one, children first and then parents (see [api-reference.md](api-reference.md#what-an-effect-plays-on)). When there is nothing suitable anywhere near, it warns in the Output panel and does nothing, which is the usual reason **▶ Test** appears to do nothing at all.

For **Loop** nodes: the `count` field updates the block's subtitle live.  
For **Random** nodes: the `weights` array and `port_count` drive the port layout.  
For **Condition** nodes: a `LineEdit` with expression examples shown as a hint label.

---

## Debug Test (▶ Test)

Pressing **Test** in the toolbar runs the full graph on the root of the scene you are editing, in real time:

1. The editor walks the graph from the Trigger node by the same rules as `JuiceeGraphPlayer`.
2. As each block's effect starts, its graph block **pulses** (brightness flash).
3. If an effect has a `delay > 0`, a **progress bar** fills at the bottom of its block while waiting.
4. If an effect bails out on a bad setup (wrong target type, an empty resource, a missing node), its block **flashes red/amber and holds the reason as its tooltip** for a couple of seconds - the same message that goes to the Output panel, but on the block that caused it instead of only there. A Condition whose expression fails does the same, and takes the True branch as it would in the game.
5. The graph honors actual flow control - `Loop` repeats N times, or until you stop it when it loops forever, `Random` picks a branch, `Condition` evaluates live, and `Split` runs its branches together and finishes when the last one does.

While it runs the button reads **Stop**. Pressing it ends the run where it is: every effect in the graph stops and puts back what it changed, and any screen overlay goes with it. A new run also clears any overlay an earlier one left behind.

> Screen shader effects preview at editor viewport size. The amber outline hint marks the preview rect. F5/F6 to see true full-screen coverage.

---

## Saving and loading

Graphs save as `JuiceeGraphResource` (`.tres`). The resource contains:
- An array of `JuiceeGraphNodeData` entries (each holds the effect instance + flow properties + position)
- A `PackedStringArray connections` in `"from_id:from_port:to_id:to_port"` format

Effect instances are embedded in the `.tres` as inline sub-resources. Their `@export` properties are diff-able in version control.

**Export Sequence** produces a `JuiceeSequence.tres` holding the graph's effects in order, walked from the Trigger, for a `JuiceePlayer.sequence`. A sequence is a flat list and cannot branch, so a graph with flow control is flattened, and the editor asks first: Random and Condition run every branch, Loop runs once, and Split runs its branches one after another. The exported sequence holds the same effect resources as the graph, not copies. To keep the branching, save the graph and play it with `JuiceeGraphPlayer.play(graph, node)`.

---

## Add-node popup

Right-clicking the canvas opens the add-node popup. Effects are grouped by category:

- Screen, Camera, Object, Text, Time, Audio, Physics, Flow, Misc
- Flow control nodes (Trigger, Split, Loop, Random, Condition, Comment) appear at the top in a dedicated section

### Browse by collapsible category

Each category is a **click-to-fold header** with a `▸` (collapsed) / `▾` (expanded) arrow and the number of entries under it, so expand just the one you want instead of scrolling the whole list. The Inspector's "+ Add Effect" picker uses the same headers. *Flow control* starts expanded and the effect categories start collapsed; the expanded state persists for the rest of the editor session.

### Or fuzzy-search

Type in the **search field** to filter across every effect at once (label, description, and category are all searched). Results are ranked best-first - prefix matches beat substring matches beat loose typo-matches - and the matched characters are **bolded** so you can see why each one matched. `shke` finds Shake, `filmgr` finds Film Grain. Searching overrides the folds (matches show regardless of which categories are collapsed); clearing the box returns to the folded category view.

Full keyboard flow: type to filter, **↑/↓** to move the highlight (only over visible rows), **Enter** to drop the top match - no mouse needed.

Effects that override `get_category_name()` in their script appear under their own custom category. Unknown effects fall through to the "Misc" section.

---

## Auto-connect from wire drag

Dragging a wire to empty space opens the popup. When you select an effect, the new block is:

1. Placed at the cursor position.
2. Automatically connected to the wire you dragged.

This is the fastest way to build a chain - just keep dragging from the last block's output port.

---

## Built-in updater

The **Update** toolbar button:

1. Fetches the GitHub releases API for the latest version.
2. Shows a dialog with the release tag, publish date, and release notes.
3. **Continue** opens a second confirmation. A new version can add effect parameters and change their defaults, so effects you already tuned may feel different afterwards, and any local edits inside `addons/juicee/` are overwritten. Saved `.tres` sequences and graphs, and the code that calls Juicee, are untouched.
4. **Update Now** downloads the archive and extracts `addons/juicee/` over the current installation.
5. Restart the editor afterwards so the new scripts load.

No manual file management needed. Requires an internet connection and write access to `addons/juicee/`.
