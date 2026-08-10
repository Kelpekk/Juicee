## Multi-color particle burst for celebrations / level-ups.
## Like JuiceeBurstEffect but with randomized colors per-particle.
@tool
class_name JuiceeConfettiEffect
extends JuiceeEffect

## Number of confetti particles.
@export_range(8, 256, 1) var amount: int = 40
## Average particle speed (randomized 0.5×–1.5×).
@export_range(0.0, 800.0, 5.0) var speed: float = 200.0
## Spread angle in degrees (360 = burst in all directions, 180 = hemisphere).
@export_range(0.0, 360.0, 1.0) var spread: float = 180.0
## Particle lifetime in seconds.
@export_range(0.1, 5.0, 0.05) var lifetime: float = 1.2
## Gravity per second. Default falls down for celebratory rain.
@export var gravity: Vector2 = Vector2(0, 250)
## Air resistance. Pieces shoot out, then slow and drift down like paper instead of
## flying ballistic. Try 40. 0 = no drag.
@export_range(0.0, 200.0, 1.0) var air_drag: float = 0.0
## Color palette — each particle picks a color along this gradient.
@export var colors: PackedColorArray = PackedColorArray([
	Color(1.0, 0.3, 0.3),
	Color(1.0, 0.8, 0.3),
	Color(0.3, 1.0, 0.4),
	Color(0.3, 0.6, 1.0),
	Color(0.9, 0.4, 1.0),
])

func get_category_color() -> Color:
	return Color(0.22, 0.58, 1.00)

func _apply(context: Node, intensity_mult: float) -> void:
	# Particles render in editor preview — no global side effects on the editor.
	var origin: Node2D = context as Node2D
	if not origin or not origin.is_inside_tree():
		push_warning("JuiceeConfettiEffect: context is not a Node2D")
		return

	var effective_amount := max(1, int(amount * intensity_mult))

	# Per-particle colour: color_initial_ramp picks a colour per piece from a random
	# offset. Stepped (constant) so each piece is one solid palette colour. Plain
	# color_ramp colours over a particle's LIFETIME, which made every piece run the
	# same hue sequence instead of the crowd being multi-coloured.
	var palette_ramp := Gradient.new()
	palette_ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	if colors.size() > 0:
		palette_ramp.colors = colors
		var band := PackedFloat32Array()
		for i in colors.size():
			band.append(float(i) / colors.size())
		palette_ramp.offsets = band
	# Fade each piece out over its life so confetti dissolves instead of blinking off.
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))

	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = effective_amount
	p.lifetime = lifetime
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed * 1.5
	p.spread = spread
	p.gravity = gravity
	p.damping_min = air_drag * 0.7
	p.damping_max = air_drag * 1.3
	# A paper-piece texture, else CPUParticles2D draws ~1px dots that all but vanish.
	p.texture = _piece_tex()
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	if colors.size() > 0:
		p.color_initial_ramp = palette_ramp
	p.color_ramp = fade
	# current_scene is null in autoload / added-to-root contexts — fall back to origin.
	var spawn_parent: Node = origin.get_tree().current_scene
	if not spawn_parent:
		spawn_parent = origin
	spawn_parent.add_child(p)
	# Set global_position AFTER add_child: before it's parented it has no parent
	# transform, so an offset spawn parent (the preview target) doubles the offset.
	p.global_position = origin.global_position
	p.emitting = true
	await origin.get_tree().create_timer(lifetime + 0.2, true, false, false).timeout
	if is_instance_valid(p):
		p.queue_free()

## Small white paper-piece texture, tinted per particle by the colour ramp. Generated
## once. Without a texture CPUParticles2D draws ~1px dots that are nearly invisible.
static var _piece: Texture2D = null
static func _piece_tex() -> Texture2D:
	if _piece == null:
		var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_piece = ImageTexture.create_from_image(img)
	return _piece
