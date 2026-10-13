## Floating damage numbers - the classic action-game hit feedback.
##
## Spawns a `Label` at the target's world position, floats it upward with
## fade-out, and supports crit styling (bigger font + alt color + scale punch).
##
## Caller passes the damage value (and optional crit flag) via runtime params:
## [codeblock]
## # Plain hit
## juice.play({"damage": 42})
## # Critical hit
## juice.play({"damage": 999, "is_crit": true})
## [/codeblock]
## If no `damage` key is passed, `default_damage` is used.
@tool
class_name JuiceeDamageNumberEffect
extends JuiceeEffect

## Default damage value when the caller doesn't pass `damage` via runtime params.
@export var default_damage: int = 10
## Color for normal damage hits.
@export var color: Color = Color.WHITE
## Color override for critical hits (when `is_crit` is true in params).
@export var crit_color: Color = Color(1.0, 0.85, 0.20, 1.0)
## How far up the number floats (pixels) before fading away.
@export_range(0.0, 300.0, 1.0) var rise_distance: float = 80.0
## Horizontal weave amplitude (px) while floating, so the number drifts gently
## instead of sliding straight up. 0 = dead-straight rise.
@export_range(0.0, 40.0, 0.5) var float_sway: float = 5.0
## Random horizontal offset spread so overlapping hits don't stack perfectly.
@export_range(0.0, 100.0, 1.0) var spread: float = 40.0
## Font size in pixels for normal hits.
@export_range(8, 128, 1) var font_size: int = 28
## Multiplier for crit font_size (so crits feel bigger).
@export_range(1.0, 3.0, 0.1) var crit_size_multiplier: float = 1.5
## Rotation shake amplitude (degrees) on crit spawn - makes big hits feel violent.
## Decays to zero over a few quick wobbles. 0 = off. Only applies to crits.
@export_range(0.0, 30.0, 0.5) var crit_shake: float = 9.0
## Optional custom font. Leave null to use the project's default UI font.
@export var font: Font
## Total animation duration (rise + fade).
@export_range(0.1, 5.0, 0.05) var duration: float = 0.8
## Optional prefix text (e.g. "-" for damage, "+" for healing, "✦" for special).
@export var prefix: String = ""
## Black outline around the digits - keeps numbers readable on any background.
@export var outline_width: int = 2

@export_group("Advanced")
## Group the digits with this separator, so 12345 reads as 12,345. Empty = no grouping.
@export var thousands_separator: String = ""
## Toss the number sideways in an arc (pixels) instead of floating straight up, the way
## loot numbers pop out of an enemy. 0 = a straight rise.
@export_range(0.0, 200.0, 5.0) var arc_distance: float = 0.0
## Text appended after the number (e.g. "!", " dmg"). Pairs with Prefix.
@export var suffix: String = ""

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["thousands_separator", "arc_distance", "suffix"]))

func get_category_name() -> String:
	return "Text"

## Digits with the advanced thousands grouping applied.
func _format_damage(value: int) -> String:
	var body := str(absi(value))
	if not thousands_separator.is_empty() and body.length() > 3:
		var grouped := ""
		var count := 0
		for i in range(body.length() - 1, -1, -1):
			grouped = body[i] + grouped
			count += 1
			if count % 3 == 0 and i > 0:
				grouped = thousands_separator + grouped
		body = grouped
	return ("-" if value < 0 else "") + body

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		_warn("JuiceeDamageNumberEffect: context is not a Node2D")
		return

	# Pull damage + crit flag from runtime params, fall back to defaults.
	var damage_value: int = _param("damage", default_damage)
	var is_crit: bool = _param("is_crit", false)

	var label := Label.new()
	label.name = StringName("_juicee_damage_%d" % randi())
	label.text = prefix + _format_damage(damage_value) + suffix
	label.add_theme_color_override("font_color", crit_color if is_crit else color)
	if outline_width > 0:
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", outline_width)
	# A glyph a million pixels tall is rendered, not refused.
	var effective_size: int = clampi(int(font_size * (crit_size_multiplier if is_crit else 1.0)), 1, 1024)
	label.add_theme_font_size_override("font_size", effective_size)
	if font:
		label.add_theme_font_override("font", font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hidden until positioned: a Control spawns at (0,0) and we only know its size
	# (needed to center it) after one frame - without this it flashes in the
	# top-left corner for a frame before snapping to the target.
	label.visible = false

	# Parent into the active scene so the label exists in world space.
	# Spawning under the target itself would inherit any local transforms we
	# don't want (e.g., the target's flash/squash animation).
	var spawn_parent: Node = _spawn_parent(target)
	spawn_parent.add_child(label)
	# The label lives in the scene, not under the target, so the target leaving takes nothing of
	# it: a play is stopped when its node goes, which made the number of every killing blow vanish.
	# An explicit stop() still takes it down.
	_unwatch_context()

	# One frame to let the Label compute its content size before we center it. The hit may free its
	# target in that frame, and the killing blow's number is the one most worth showing, so it rises
	# from where the target was.
	var anchor := target.global_position
	var st := target.get_tree()
	await st.process_frame
	if not is_instance_valid(label):
		return
	if is_instance_valid(target):
		anchor = target.global_position

	var spread_offset := randf_range(-spread, spread) * 0.5
	var start_pos := anchor + Vector2(spread_offset, 0) - label.size * 0.5
	label.global_position = start_pos
	label.visible = true

	var end_y := start_pos.y - rise_distance * intensity_mult

	# Every number gets a punch, not only a crit. A number that slides up at a fixed size
	# is the difference between a hit registering and a label appearing; the crit just
	# punches harder and shakes on top.
	label.pivot_offset = label.size * 0.5
	var from_scale: float = 0.5 if is_crit else 0.65
	var peak_scale: float = 1.35 if is_crit else 1.15
	label.scale = Vector2.ONE * from_scale
	# Label-owned (untracked) tweens: each spawned number animates independently, so
	# re-triggering the effect mid-flight doesn't kill a previous number's punch
	# (issue #4 - they must stack as separate instances, not cancel each other).
	var punch := label.create_tween()
	punch.tween_property(label, "scale", Vector2.ONE * peak_scale, 0.11)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(label, "scale", Vector2.ONE, 0.14)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if is_crit:
		# Rotation shake - a few quick alternating wobbles that decay to zero. Runs
		# in parallel with the punch/rise; rotation pivots around the centre.
		if crit_shake > 0.0:
			var shake := label.create_tween()
			var amp: float = deg_to_rad(crit_shake)
			for i in 5:
				var dir: float = 1.0 if i % 2 == 0 else -1.0
				shake.tween_property(label, "rotation", amp * dir * (1.0 - i / 5.0), 0.045)\
					.set_trans(Tween.TRANS_SINE)
			shake.tween_property(label, "rotation", 0.0, 0.045).set_trans(Tween.TRANS_SINE)

	# Float upward with a gentle horizontal weave + fade, driven per-frame rather than
	# a straight position tween - otherwise the number slides up in a dead straight line
	# and looks lifeless while it hangs. Scale/rotation stay free for the crit punch.
	var phase := randf() * TAU
	# Advanced arc: throw the number sideways and let it fall back, like popped loot.
	var arc_dir: float = (1.0 if randf() < 0.5 else -1.0) * arc_distance
	var t := 0.0
	while t < duration and is_instance_valid(label) and not _cancelled:
		var k: float = t / duration
		var rise_k: float = 1.0 - pow(1.0 - k, 4.0)                       # quart ease-out
		var weave: float = sin(phase + k * TAU * 2.5) * float_sway * (1.0 - 0.4 * k)
		var px: float = start_pos.x + weave + arc_dir * k
		var py: float = lerpf(start_pos.y, end_y, rise_k)
		if arc_distance > 0.0:
			# Parabola: up then back down, on top of the eased rise.
			py += (4.0 * k * k - 4.0 * k) * -rise_distance * 0.35 * intensity_mult
		label.global_position = Vector2(px, py)
		if k > 0.3:
			label.modulate.a = clampf(1.0 - (k - 0.3) / 0.7, 0.0, 1.0)
		await st.process_frame
		t += st.root.get_process_delta_time()

	if is_instance_valid(label):
		label.queue_free()
