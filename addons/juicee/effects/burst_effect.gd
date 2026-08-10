@tool
class_name JuiceeBurstEffect
extends JuiceeEffect

## Number of particles to emit.
@export_range(1, 128, 1) var amount: int = 12
## Average particle speed (actual is randomized 0.7×–1.3× this).
@export_range(0.0, 500.0, 1.0) var speed: float = 120.0
## Spread angle in degrees (180 = full circle, 90 = quarter).
@export_range(0.0, 180.0, 1.0) var spread: float = 120.0
## How long particles live before disappearing.
@export_range(0.05, 5.0, 0.05) var lifetime: float = 0.5
## Particle color.
@export var color: Color = Color(1.0, 0.8, 0.3, 1.0)
## Gravity applied per second to particles (e.g., Vector2(0, 980) for falling).
@export var gravity: Vector2 = Vector2.ZERO
## Visual size of each particle. Without this the engine draws 1px dots that are
## nearly invisible — this scales a built-in soft round texture.
@export_range(0.3, 12.0, 0.1) var particle_scale: float = 2.5

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func _apply(context: Node, intensity_mult: float) -> void:
	# Particles render in editor preview — no global side effects on the editor.
	var origin: Node2D = context as Node2D
	if not origin:
		push_warning("JuiceeBurstEffect: context is not a Node2D")
		return
	if not origin.is_inside_tree():
		return

	var effective_amount := max(1, int(amount * intensity_mult))
	var effective_speed := speed * intensity_mult
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = effective_amount
	p.lifetime = lifetime
	p.initial_velocity_min = effective_speed * 0.7
	p.initial_velocity_max = effective_speed * 1.3
	p.spread = spread
	p.gravity = gravity
	p.color = color
	# Fade out over each particle's lifetime so the burst dissolves instead of
	# every particle popping out of existence at the same instant.
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	# A soft round texture + scale so particles are actually visible (a textureless
	# CPUParticles2D draws ~1px dots).
	p.texture = _soft_dot()
	p.scale_amount_min = particle_scale * 0.7
	p.scale_amount_max = particle_scale * 1.3
	# current_scene is null in autoload / added-to-root contexts — fall back to origin.
	var spawn_parent: Node = origin.get_tree().current_scene
	if not spawn_parent:
		spawn_parent = origin
	spawn_parent.add_child(p)
	# Set global_position AFTER add_child: before it's in the tree it has no parent
	# transform, so if spawn_parent is offset (e.g. the target itself) the position
	# would double. Placing it once parented lands the burst exactly on the target.
	p.global_position = origin.global_position
	p.emitting = true
	await origin.get_tree().create_timer(lifetime + 0.15, true, false, false).timeout
	if is_instance_valid(p):
		p.queue_free()

## Built-in soft round particle texture (radial white→transparent), generated once.
static var _dot_tex: Texture2D = null
static func _soft_dot() -> Texture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 24
		tex.height = 24
		_dot_tex = tex
	return _dot_tex
