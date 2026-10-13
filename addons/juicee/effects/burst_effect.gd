@tool
class_name JuiceeBurstEffect
extends JuiceeEffect

enum ParticleShape { DOT, SQUARE, STAR, STREAK }

## Number of particles to emit.
@export_range(1, 128, 1) var amount: int = 12
## Average particle speed (actual is randomized 0.7×-1.3× this).
@export_range(0.0, 500.0, 1.0) var speed: float = 260.0
## Spread angle in degrees either side of the direction (180 = full circle, 90 = half circle).
@export_range(0.0, 180.0, 1.0) var spread: float = 180.0
## How long particles live before disappearing.
@export_range(0.05, 5.0, 0.05) var lifetime: float = 0.5
## Particle color.
@export var color: Color = Color(1.0, 0.8, 0.3, 1.0)
## Gravity applied per second to particles (e.g., Vector2(0, 980) for falling).
@export var gravity: Vector2 = Vector2.ZERO
## Visual size of each particle. Without this the engine draws 1px dots that are
## nearly invisible - this scales the built-in particle texture (see Particle Shape).
@export_range(0.3, 12.0, 0.1) var particle_scale: float = 2.4

@export_group("Advanced")
## Shape of each particle: a round DOT, a chunky SQUARE (debris), a 4-point STAR, or a STREAK that
## faces the way it flies.
@export var particle_shape: ParticleShape = ParticleShape.DOT
## Colour each particle fades toward as it dies. Default is transparent white (a plain
## fade). Set a tint (e.g. deep red, alpha 0) for embers that cool as they fly out.
@export var fade_to: Color = Color(1.0, 1.0, 1.0, 0.0)
## Air resistance. Particles shoot out then slow, instead of flying ballistic. 0 = none.
@export_range(0.0, 200.0, 1.0) var air_drag: float = 0.0
## Degrees per second each particle spins. 0 = no spin (best for round dots).
@export_range(-720.0, 720.0, 5.0) var spin_degrees: float = 0.0
## If true, particles shrink to nothing over their life instead of holding their size.
@export var shrink: bool = true

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["particle_shape", "fade_to", "air_drag", "spin_degrees", "shrink"]))

func _apply(context: Node, intensity_mult: float) -> void:
	# Particles render in editor preview - no global side effects on the editor.
	var origin: Node2D = context as Node2D
	if not origin:
		_warn("JuiceeBurstEffect: context is not a Node2D")
		return
	if not origin.is_inside_tree():
		return

	var effective_amount := _capped(maxi(1, int(amount * intensity_mult * accessibility.density_scale())), 4096, "amount")
	var effective_speed := _px(speed) * intensity_mult
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = effective_amount
	# A particle node refuses a lifetime of 0 or less.
	p.lifetime = maxf(lifetime, 0.01)
	p.initial_velocity_min = effective_speed * 0.7
	p.initial_velocity_max = effective_speed * 1.3
	p.spread = spread
	p.gravity = gravity
	p.color = color
	# Fade out over each particle's lifetime so the burst dissolves instead of
	# every particle popping out of existence at the same instant. fade_to (advanced)
	# lets the colour cool toward a tint (embers) rather than a plain transparent fade.
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, fade_to)
	fade.add_point(0.55, Color(1, 1, 1, 1))
	p.color_ramp = fade
	# A crisp texture + scale so particles are actually visible (a textureless
	# CPUParticles2D draws ~1px dots). Nearest keeps them sharp instead of blurring
	# back into a soft blob when scaled up.
	p.texture = _shape_tex(particle_shape)
	p.particle_flag_align_y = particle_shape == ParticleShape.STREAK
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.scale_amount_min = particle_scale * 0.7
	p.scale_amount_max = particle_scale * 1.3
	# Advanced: drag, spin and shrink-over-life.
	if air_drag > 0.0:
		p.damping_min = air_drag * 0.7
		p.damping_max = air_drag * 1.3
	if spin_degrees != 0.0:
		p.angular_velocity_min = -spin_degrees
		p.angular_velocity_max = spin_degrees
	if shrink:
		var sc := Curve.new()
		sc.add_point(Vector2(0.0, 1.0))
		sc.add_point(Vector2(1.0, 0.2))
		p.scale_amount_curve = sc
	var spawn_parent: Node = _spawn_parent(origin)
	p.name = StringName("_juicee_burst_%d" % randi())
	spawn_parent.add_child(p)
	# Set global_position AFTER add_child: before it's in the tree it has no parent
	# transform, so if spawn_parent is offset (e.g. the target itself) the position
	# would double. Placing it once parented lands the burst exactly on the target.
	p.global_position = origin.global_position
	p.emitting = true
	await origin.get_tree().create_timer(p.lifetime + 0.15, true, false, false).timeout
	if is_instance_valid(p):
		p.queue_free()

## Picks the particle texture for a shape. STAR reuses the sparkle effect's star so
## there is one shared star texture across the library.
static var _square_tex_cache: Texture2D = null
static func _shape_tex(shape: ParticleShape) -> Texture2D:
	match shape:
		ParticleShape.SQUARE:
			if _square_tex_cache == null:
				var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
				img.fill(Color.WHITE)
				_square_tex_cache = ImageTexture.create_from_image(img)
			return _square_tex_cache
		ParticleShape.STAR:
			return JuiceeSparkleEffect._sparkle_tex(4)
		ParticleShape.STREAK:
			return _particle_streak()
		_:
			return _particle_dot()

## A thin bright capsule, long on Y, for particles that face the way they fly. Drawn with
## particle_flag_align_y on, which turns each particle so its Y axis follows its velocity.
static var _streak_tex: Texture2D = null
static func _particle_streak() -> Texture2D:
	if _streak_tex == null:
		var w := 4
		var h := 16
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			# Full in the middle, thinning towards both ends, so the streak has a point.
			var along := 1.0 - absf((float(y) + 0.5) / float(h) * 2.0 - 1.0)
			for x in w:
				var across := 1.0 - absf((float(x) + 0.5) / float(w) * 2.0 - 1.0)
				var a := clampf(minf(along * 2.2, 1.0) * clampf(across * 1.6, 0.0, 1.0), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_streak_tex = ImageTexture.create_from_image(img)
	return _streak_tex

## Built-in crisp round particle texture, generated once. A hard-edged disc (1px
## feather) instead of a soft radial gradient, so a burst reads as distinct flying
## bits rather than one overlapping fuzzy cloud. Paired with a nearest filter at the
## call site to stay sharp when scaled up.
static var _dot_tex: Texture2D = null
static func _particle_dot() -> Texture2D:
	if _dot_tex == null:
		var size := 12
		var c: float = (size - 1) * 0.5
		var rad: float = c - 0.5
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var d := Vector2(x, y).distance_to(Vector2(c, c))
				var a := clampf(rad - d + 0.5, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex
