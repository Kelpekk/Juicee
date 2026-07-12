## Control an existing CPUParticles2D or GPUParticles2D node in the scene.
##
## Unlike BurstEffect (which spawns a temporary particle system), this controls
## a pre-configured particle node already in your scene tree — emit a burst,
## stop emission, or restart it from the beginning.
##
## Use for: reuse carefully tuned particle systems, trigger existing effects
## (muzzle flash, footstep dust, impact sparks) from a Juicee sequence.
@tool
class_name JuiceeParticleEffect
extends JuiceeEffect

enum Action {
	EMIT,    ## One-shot burst: set one_shot=true, restart=true.
	STOP,    ## Stop emission immediately.
	RESTART, ## Restart the particle system (set emitting=true, restart).
	TOGGLE,  ## Toggle emitting on/off.
}

## Path to the CPUParticles2D or GPUParticles2D node.
@export_node_path("Node2D") var particle_path: NodePath = NodePath()
## What to do with the particle node.
@export var action: Action = Action.EMIT
## If true and action=EMIT, wait until all particles have died before continuing.
@export var wait_for_finish: bool = false

func get_category_color() -> Color: return Color(0.22, 0.58, 1.00)
func get_category_name() -> String: return "Object"

func _apply(context: Node, _intensity_mult: float) -> void:
	if not context or not context.is_inside_tree():
		return
	if particle_path.is_empty():
		push_warning("JuiceeParticleEffect: particle_path is empty")
		return
	var ps: Node = context.get_node_or_null(particle_path)
	if not ps:
		push_warning("JuiceeParticleEffect: particle node not found at: %s" % particle_path)
		return

	var is_cpu := ps is CPUParticles2D
	var is_gpu := ps is GPUParticles2D
	if not is_cpu and not is_gpu:
		push_warning("JuiceeParticleEffect: node is not CPUParticles2D or GPUParticles2D")
		return

	match action:
		Action.EMIT:
			if is_cpu:
				(ps as CPUParticles2D).restart()
			else:
				(ps as GPUParticles2D).restart()
		Action.STOP:
			ps.set("emitting", false)
		Action.RESTART:
			ps.set("emitting", true)
			if is_cpu: (ps as CPUParticles2D).restart()
			else: (ps as GPUParticles2D).restart()
		Action.TOGGLE:
			ps.set("emitting", not ps.get("emitting"))

	if wait_for_finish and (action == Action.EMIT or action == Action.RESTART):
		var lifetime: float = ps.get("lifetime") if ps.has_method("get") else 1.0
		var tree := context.get_tree()
		await tree.create_timer(lifetime + 0.1, true, false, false).timeout
