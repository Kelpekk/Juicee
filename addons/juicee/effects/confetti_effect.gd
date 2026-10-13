## Multi-color particle burst for celebrations / level-ups.
## Like JuiceeBurstEffect but with randomized colors per-particle.
@tool
class_name JuiceeConfettiEffect
extends JuiceeEffect

enum PieceShape { SQUARE, RECT, CIRCLE, STAR }

## Number of confetti particles.
@export_range(8, 256, 1) var amount: int = 40
## Average particle speed (randomized 0.5×-1.5×).
@export_range(0.0, 800.0, 5.0) var speed: float = 200.0
## Spread angle in degrees either side of Direction (180 = every direction, 90 = half circle).
@export_range(0.0, 360.0, 1.0) var spread: float = 180.0
## Which way the pieces fly, Spread either side of it. Up with a spread of 30-60 pours a fountain.
@export var direction: Vector2 = Vector2.RIGHT
## Particle lifetime in seconds.
@export_range(0.1, 5.0, 0.05) var lifetime: float = 1.2
## Gravity per second. Default falls down for celebratory rain.
@export var gravity: Vector2 = Vector2(0, 250)
## Air resistance. Pieces shoot out, then slow and drift down like paper instead of
## flying ballistic. Try 40. 0 = no drag.
@export_range(0.0, 200.0, 1.0) var air_drag: float = 0.0
## Color palette - each piece takes one of these colours at random.
@export var colors: PackedColorArray = PackedColorArray([
	Color(1.0, 0.3, 0.3),
	Color(1.0, 0.8, 0.3),
	Color(0.3, 1.0, 0.4),
	Color(0.3, 0.6, 1.0),
	Color(0.9, 0.4, 1.0),
])

@export_group("Advanced")
## Piece shape: SQUARE confetti, RECT paper strips, round CIRCLE dots, or STAR sparkle.
@export var piece_shape: PieceShape = PieceShape.SQUARE
## Average visual size of each piece (randomized around it).
@export_range(0.3, 8.0, 0.05) var piece_scale: float = 1.75
## Max spin speed in degrees/sec (each piece spins a random amount up to this). 0 = flat.
@export_range(0.0, 1440.0, 10.0) var spin_speed: float = 360.0

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["piece_shape", "piece_scale", "spin_speed"]))

func _apply(context: Node, intensity_mult: float) -> void:
	# Particles render in editor preview - no global side effects on the editor.
	var origin: Node2D = context as Node2D
	if not origin or not origin.is_inside_tree():
		_warn("JuiceeConfettiEffect: context is not a Node2D")
		return

	var effective_amount := _capped(maxi(1, int(amount * intensity_mult * accessibility.density_scale())), 4096, "amount")

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
	# A particle node refuses a lifetime of 0 or less.
	p.lifetime = maxf(lifetime, 0.01)
	p.initial_velocity_min = _px(speed) * 0.5
	p.initial_velocity_max = _px(speed) * 1.5
	p.spread = spread
	p.direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	p.gravity = gravity
	p.damping_min = air_drag * 0.7
	p.damping_max = air_drag * 1.3
	# A paper-piece texture, else CPUParticles2D draws ~1px dots that all but vanish.
	p.texture = _piece_shape_tex(piece_shape)
	p.scale_amount_min = piece_scale * 0.57
	p.scale_amount_max = piece_scale * 1.43
	p.angular_velocity_min = -spin_speed
	p.angular_velocity_max = spin_speed
	if colors.size() > 0:
		p.color_initial_ramp = palette_ramp
	p.color_ramp = fade
	var spawn_parent: Node = _spawn_parent(origin)
	p.name = StringName("_juicee_confetti_%d" % randi())
	spawn_parent.add_child(p)
	# Set global_position AFTER add_child: before it's parented it has no parent
	# transform, so an offset spawn parent (the preview target) doubles the offset.
	p.global_position = origin.global_position
	p.emitting = true
	await origin.get_tree().create_timer(p.lifetime + 0.2, true, false, false).timeout
	if is_instance_valid(p):
		p.queue_free()

## White piece textures per shape, tinted per particle by the colour ramp and cached.
## Without a texture CPUParticles2D draws ~1px dots that are nearly invisible.
static var _piece_cache: Dictionary = {}
static func _piece_shape_tex(shape: PieceShape) -> Texture2D:
	if _piece_cache.has(shape):
		return _piece_cache[shape]
	var tex: Texture2D
	match shape:
		PieceShape.RECT:
			var img := Image.create(4, 10, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			tex = ImageTexture.create_from_image(img)
		PieceShape.CIRCLE:
			tex = JuiceeBurstEffect._particle_dot()
		PieceShape.STAR:
			tex = JuiceeSparkleEffect._sparkle_tex(5)
		_:
			var sq := Image.create(6, 6, false, Image.FORMAT_RGBA8)
			sq.fill(Color.WHITE)
			tex = ImageTexture.create_from_image(sq)
	_piece_cache[shape] = tex
	return tex
