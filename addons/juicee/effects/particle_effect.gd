## Control an existing particle node in the scene, 2D or 3D.
##
## Unlike BurstEffect (which spawns a temporary particle system), this controls
## a pre-configured particle node already in your scene tree - emit a burst,
## stop emission, or restart it from the beginning.
##
## Use for: reuse carefully tuned particle systems, trigger existing effects
## (muzzle flash, footstep dust, impact sparks) from a Juicee sequence.
@tool
class_name JuiceeParticleEffect
extends JuiceeEffect

enum Action {
	EMIT,    ## Restart the emitter for a fresh burst (its own one_shot setting applies).
	STOP,    ## Stop emission immediately.
	RESTART, ## Restart the particle system (set emitting=true, restart).
	TOGGLE,  ## Toggle emitting on/off.
}

## Path to the particle node. Empty = the node this plays on.
@export_node_path("CPUParticles2D", "GPUParticles2D", "CPUParticles3D", "GPUParticles3D")
var particle_path: NodePath = NodePath()
## What to do with the particle node.
@export var action: Action = Action.EMIT
## If true and the action is EMIT or RESTART, wait until the particles have died before continuing.
@export var wait_for_finish: bool = false

@export_group("Advanced")
## Override the node's particle amount for this play, so one emitter can do a small
## puff and a big blast. 0 = keep whatever the node is set to.
@export_range(0, 1024, 1) var amount_override: int = 0
## Scale the emitter's lifetime for this play. 1 = unchanged.
@export_range(0.1, 5.0, 0.05) var lifetime_scale: float = 1.0
## Restore the overridden amount and lifetime when the effect finishes.
@export var restore_overrides: bool = true

func _validate_property(property: Dictionary) -> void:
	_gate_advanced(property, PackedStringArray(["amount_override", "lifetime_scale", "restore_overrides"]))

func get_category_name() -> String: return "Object"

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	# An empty path means the context, which is where _retarget leaves an emitter it found.
	var ps: Node = context if particle_path.is_empty() else context.get_node_or_null(particle_path)
	if not ps:
		_warn("JuiceeParticleEffect: particle node not found at: %s" % particle_path)
		return

	if not (ps is CPUParticles2D or ps is GPUParticles2D or ps is CPUParticles3D or ps is GPUParticles3D):
		_warn("JuiceeParticleEffect: node is not a particle emitter")
		return

	# Advanced overrides let one emitter cover both a small puff and a big blast. They are held on
	# the state stack, so a play that starts while another's are on still scales the emitter's own
	# values, and those come back when the last play holding them is done.
	var play := _gen
	var new_amount := amount_override > 0
	var new_lifetime := not is_equal_approx(lifetime_scale, 1.0)
	if restore_overrides:
		if new_amount:
			_capture_state(ps, "amount")
		if new_lifetime:
			# A particle node refuses a lifetime of 0 or less, which a scale of 0 or below makes.
			ps.set("lifetime", maxf(float(_capture_state(ps, "lifetime")) * lifetime_scale, 0.01))
	elif new_lifetime:
		_scale_kept_lifetime(ps)
	if new_amount:
		ps.set("amount", amount_override)
	# The emitter through a weak reference: the timer below can fire after it was freed, and a
	# lambda that captured it would report an error then, whatever its body checks.
	var ps_ref: WeakRef = weakref(ps)
	var put_back := func() -> void:
		# A later play of this effect, or stop(), has put them back already.
		if play == _gen:
			_release_state(ps_ref.get_ref(), "amount")
			_release_state(ps_ref.get_ref(), "lifetime")

	# A burst the play waits out is held on the stack, so stop() before its end stops the emitter.
	var waiting := wait_for_finish and (action == Action.EMIT or action == Action.RESTART)
	if waiting:
		_capture_state(ps, "emitting")

	match action:
		Action.EMIT:
			ps.call("restart")
		Action.STOP:
			ps.set("emitting", false)
		Action.RESTART:
			ps.set("emitting", true)
			ps.call("restart")
		Action.TOGGLE:
			ps.set("emitting", not ps.get("emitting"))

	if waiting:
		var lifetime: float = ps.get("lifetime") if ps.has_method("get") else 1.0
		var tree := context.get_tree()
		await tree.create_timer(lifetime + 0.1, true, false, false).timeout
		if _gen != play:
			return
		_release_state(ps, "emitting", false)

	# After the burst's lifetime, not straight away: setting amount restarts the emitter.
	if restore_overrides and (new_amount or new_lifetime):
		if waiting:
			put_back.call()
		else:
			context.get_tree().create_timer(float(ps.get("lifetime")) + 0.1, true, false, false).timeout.connect(put_back)

## Per emitter, its own lifetime and the one a play that keeps its overrides left on it. Without
## this the next such play scaled the lifetime the last one left, so it grew on every play.
var _kept_lifetimes: Dictionary = {}

func _scale_kept_lifetime(ps: Node) -> void:
	var own: float = float(ps.get("lifetime"))
	var id := ps.get_instance_id()
	var kept: Array = _kept_lifetimes.get(id, [])
	# Unless something else has set it since, which makes that the emitter's own.
	if kept.size() == 2 and is_equal_approx(own, float(kept[1])):
		own = float(kept[0])
	ps.set("lifetime", maxf(own * lifetime_scale, 0.01))
	if not _kept_lifetimes.has(id):
		for old in _kept_lifetimes.keys():
			if not is_instance_id_valid(old):
				_kept_lifetimes.erase(old)
	_kept_lifetimes[id] = [own, float(ps.get("lifetime"))]
