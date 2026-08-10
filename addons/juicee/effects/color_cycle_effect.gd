## Cycle a CanvasItem's modulate through the HSV color wheel, or through a palette
## of your own colors.
##
## Use for: powerup glow ("RAINBOW MODE"), party/celebration sequences,
## boss "phase 2" warning, victory screens, easter eggs. Combine with
## a `JuiceeFlashEffect` at the start to sell the moment.
@tool
class_name JuiceeColorCycleEffect
extends JuiceeEffect

## Number of full revolutions across the duration (one revolution = the whole hue
## wheel, or one full pass through `colors` if you set some).
@export_range(0.5, 16.0, 0.5) var cycles: float = 2.0
## Total duration of the cycling.
@export_range(0.1, 30.0, 0.1) var duration: float = 1.5
## Optional custom colors to cycle through instead of the rainbow. Leave it empty for
## the HSV wheel; add colors and the effect sweeps through them. `saturation` and
## `value` below only apply to the rainbow.
@export var colors: PackedColorArray = PackedColorArray()
## Palette only: blend smoothly between colors (a gradient sweep), or turn it off to
## hold each color then hard-switch to the next, the way police lights or a strobe flash.
@export var smooth: bool = true
## Palette only: bounce back and forth through the colors (first to last and back)
## instead of looping (where the last color wraps around to the first).
@export var bounce: bool = false
## Saturation of the cycled hue (0 = grayscale, 1 = full color). Rainbow only.
@export_range(0.0, 1.0, 0.01) var saturation: float = 1.0
## Value/brightness of the cycled hue (1 = full bright). Rainbow only.
@export_range(0.0, 2.0, 0.01) var value: float = 1.0
## If true, alpha is preserved from the original modulate. If false, fully opaque.
@export var preserve_alpha: bool = true
## If true, cycle forever (until stop()). `duration` still sets the cycle SPEED
## (cycles per duration), it just no longer ends the effect. Great for a persistent
## "RAINBOW MODE" glow on a title, powerup, or victory banner.
@export var loop: bool = false

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func get_category_name() -> String:
	return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: CanvasItem = context as CanvasItem
	if not target or not target.is_inside_tree():
		push_warning("JuiceeColorCycleEffect: context is not a CanvasItem")
		return

	var original_modulate: Color = _capture_state(target, "modulate")
	var tree := target.get_tree()
	if not tree:
		_release_state(target, "modulate")
		return

	var elapsed := 0.0
	var use_palette: bool = colors.size() > 0
	var effective_sat: float = clamp(saturation * intensity_mult, 0.0, 1.0)
	while (loop or elapsed < duration) and not _cancelled and is_instance_valid(target):
		var pos: float = fposmod(elapsed / duration * cycles, 1.0)
		var c: Color
		if use_palette:
			# Sample the custom colors, and dampen toward the original under reduced
			# motion so the accessibility multiplier still softens the effect.
			c = original_modulate.lerp(_sample_colors(pos), intensity_mult)
		else:
			c = Color.from_hsv(pos, effective_sat, value, 1.0)
		if preserve_alpha:
			c.a = original_modulate.a
		target.modulate = c
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()

	if is_instance_valid(target):
		target.modulate = original_modulate
	_release_state(target, "modulate")

## Sample `colors` at phase t in [0, 1). `bounce` folds the phase into a there-and-back
## triangle so the colors reverse at the ends; otherwise it loops, with the last color
## wrapping back to the first. `smooth` blends between colors; off, it holds each color
## across its segment and hard-switches to the next.
func _sample_colors(t01: float) -> Color:
	var n := colors.size()
	if n == 1:
		return colors[0]
	var scaled: float = t01 * n
	if bounce:
		var tri: float = 1.0 - absf(2.0 * t01 - 1.0)   # 0 -> 1 -> 0 across the cycle
		scaled = tri * (n - 1)
	var i: int = int(scaled)
	var frac: float = scaled - i
	var lo: Color = colors[i % n]
	if not smooth:
		return lo
	var hi: Color = colors[mini(i + 1, n - 1)] if bounce else colors[(i + 1) % n]
	return lo.lerp(hi, frac)
