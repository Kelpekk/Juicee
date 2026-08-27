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

func get_category_name() -> String:
	return "Text"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target or not target.is_inside_tree():
		push_warning("JuiceeDamageNumberEffect: context is not a Node2D")
		return

	# Pull damage + crit flag from runtime params, fall back to defaults.
	var damage_value: int = int(_runtime_params.get("damage", default_damage))
	var is_crit: bool = bool(_runtime_params.get("is_crit", false))

	var label := Label.new()
	label.name = StringName("_juicee_damage_%d" % randi())
	label.text = prefix + str(damage_value)
	label.add_theme_color_override("font_color", crit_color if is_crit else color)
	if outline_width > 0:
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", outline_width)
	var effective_size: int = int(font_size * (crit_size_multiplier if is_crit else 1.0))
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

	# One frame to let the Label compute its content size before we center it.
	await target.get_tree().process_frame
	if not is_instance_valid(label):
		return

	var spread_offset := randf_range(-spread, spread) * 0.5
	var start_pos := target.global_position + Vector2(spread_offset, 0) - label.size * 0.5
	label.global_position = start_pos
	label.visible = true

	var st := target.get_tree()
	var end_y := start_pos.y - rise_distance * intensity_mult

	# Crit scale-punch at the start so big hits feel weighty.
	if is_crit:
		label.pivot_offset = label.size * 0.5
		label.scale = Vector2(0.5, 0.5)
		# Label-owned (untracked) tweens: each spawned number animates independently, so
		# re-triggering the effect mid-flight doesn't kill a previous number's punch
		# (issue #4 - they must stack as separate instances, not cancel each other).
		var punch := label.create_tween()
		punch.tween_property(label, "scale", Vector2.ONE * 1.2, 0.12)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		punch.tween_property(label, "scale", Vector2.ONE, 0.15)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

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
	var t := 0.0
	while t < duration and is_instance_valid(label) and not _cancelled:
		var k: float = t / duration
		var rise_k: float = 1.0 - pow(1.0 - k, 4.0)                       # quart ease-out
		var weave: float = sin(phase + k * TAU * 2.5) * float_sway * (1.0 - 0.4 * k)
		label.global_position = Vector2(start_pos.x + weave, lerpf(start_pos.y, end_y, rise_k))
		if k > 0.3:
			label.modulate.a = clampf(1.0 - (k - 0.3) / 0.7, 0.0, 1.0)
		await st.process_frame
		t += st.root.get_process_delta_time()

	if is_instance_valid(label):
		label.queue_free()
