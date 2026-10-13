## Motion trail: a capped string of fading sprite copies following the node, like a
## comet tail. Vs JuiceeAfterimageEffect (independent ghosts that each linger and fade
## on their own), this holds a fixed ghost count and fades them by age, so the tail
## stays a constant length behind fast movers.
@tool
class_name JuiceeTrailEffect
extends JuiceeEffect

## How long to keep spawning ghost copies. The tail then drains from its oldest end.
@export_range(0.05, 10.0, 0.05) var duration: float = 1.0
## Time between ghost spawns. Lower = denser trail.
@export_range(0.01, 0.5, 0.01) var interval: float = 0.05
## Cap on simultaneous ghosts on screen (oldest get queued for deletion).
@export_range(1, 50, 1) var max_ghosts: int = 10
## Color/alpha applied to each ghost (semi-transparent by default).
@export var ghost_modulate: Color = Color(1.0, 1.0, 1.0, 0.4)
## If true, older ghosts get progressively more transparent.
@export var fade_ghosts: bool = true

@export_group("Advanced")
## Colour the oldest ghosts fade toward, so a trail can cool from white to a tint
## instead of only losing alpha.
@export var fade_to: Color = Color(1.0, 1.0, 1.0, 0.0)
## Size of the oldest ghost as a fraction of the sprite, growing back to full size toward the newest. 1 = no taper.
@export_range(0.5, 1.0, 0.01) var taper: float = 1.0
## Leave ghosts in world space instead of following the node, so the tail stays where
## it was drawn (a proper motion trail rather than a shadow stack).
@export var world_space: bool = true

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["fade_to", "taper", "world_space"]))

func get_category_name() -> String:
	return "Object"

func _apply(context: Node, intensity_mult: float) -> void:
	var target: Node2D = context as Node2D
	if not target:
		_warn("JuiceeTrailEffect: context is not a Node2D")
		return
	var source := _find_sprite_node(target)
	if not source:
		_warn("JuiceeTrailEffect: no Sprite2D or AnimatedSprite2D on %s" % _target_label(target))
		return

	var play := _gen
	var tree := target.get_tree()
	var scene_root: Node = _spawn_parent(target)
	var ghosts: Array[Sprite2D] = []
	var base_mod: Color = ghost_modulate
	base_mod.a = clampf(ghost_modulate.a * intensity_mult, 0.0, 1.0)
	var elapsed: float = 0.0

	# A newer play takes the trail over: this one stops laying ghosts and lets its own fade.
	while elapsed < duration and is_instance_valid(target) and is_instance_valid(source) and _gen == play:
		var ghost := Sprite2D.new()
		ghost.name = StringName("_juicee_trail_%d" % randi())
		# Copies centered and offset as well as the frame, which this used to skip: a
		# sprite with centered off drew its whole trail half a sprite away from itself.
		if not _copy_sprite_look(source, ghost):
			ghost.free()
			elapsed += await _wait_step(tree, interval)
			continue
		ghost.modulate = base_mod
		# Advanced world_space leaves ghosts where they were drawn (a real motion
		# trail); off parents them to the node so they ride along with it.
		if world_space:
			_add_behind(ghost, scene_root, source)
		else:
			# Behind the node and its children, at their z, for the same reason as _add_behind.
			ghost.show_behind_parent = true
			target.add_child(ghost)
		# Match the source's WORLD transform AFTER parenting: setting global_* before
		# add_child treats them as local (no parent yet), which doubles the offset when
		# scene_root isn't at the world origin (the fallback parents under the target).
		ghost.global_position = source.global_position
		ghost.global_rotation = source.global_rotation
		ghost.global_scale = source.global_scale
		ghosts.append(ghost)

		if ghosts.size() > mini(max_ghosts, 512):
			var old: Variant = ghosts.pop_front()
			if is_instance_valid(old):
				old.queue_free()

		if fade_ghosts:
			for i in ghosts.size():
				if not is_instance_valid(ghosts[i]):
					continue
				# Age from 0 (oldest) to 1 (newest), used for both fade and taper.
				var age: float = float(i + 1) / float(ghosts.size())
				# Advanced fade_to lets the tail cool toward a colour, not just go clear.
				if fade_to != Color(1.0, 1.0, 1.0, 0.0):
					ghosts[i].modulate = fade_to.lerp(base_mod, age)
				else:
					ghosts[i].modulate.a = base_mod.a * age
				# Advanced taper narrows the tail toward its oldest end.
				if taper < 1.0:
					ghosts[i].scale = source.global_scale * lerpf(taper, 1.0, age)

		elapsed += await _wait_step(tree, interval)

	# Each ghost fades over a time in step with its place in the tail, so the faint old end
	# goes first and the newest last, over the time the tail took to build. Freeing them all
	# at once made the whole tail blink out in one frame. stop() still takes them at once.
	var was_stopped := _cancelled
	var drain := interval * float(maxi(1, ghosts.size()))
	for i in ghosts.size():
		if not is_instance_valid(ghosts[i]):
			continue
		var g: Sprite2D = ghosts[i]
		if was_stopped:
			g.queue_free()
			continue
		var age := float(i + 1) / float(ghosts.size())
		var gone := Color(g.modulate.r, g.modulate.g, g.modulate.b, 0.0)
		var tw := g.create_tween()
		tw.tween_property(g, "modulate", gone, drain * age)
		tw.tween_callback(g.queue_free)
