class_name MachineDamage
extends Node3D
## Maps a VanVital's HP to healthy, hurt or dying, and drives its machine's motion speed, flicker, smoke puffs and sparks.

enum State { HEALTHY, HURT, DYING }

signal state_changed(state: int)

## Where puffs and sparks start, machine-local.
@export var smoke_offset := Vector3(0.0, 0.5, 0.0)

var state: int = State.HEALTHY
var motion: MachineMotion
var _smoke: GPUParticles3D
var _sparks: GPUParticles3D


static func state_for(ratio: float) -> int:
	if ratio > 0.6:
		return State.HEALTHY
	if ratio > 0.25:
		return State.HURT
	return State.DYING


func bind(vital: VanVital, motion_node: MachineMotion) -> void:
	motion = motion_node
	if not vital.health_changed.is_connected(_on_health_changed):
		vital.health_changed.connect(_on_health_changed)
	_on_health_changed(vital.health, vital.max_health)


func _ready() -> void:
	_ensure_particles()


func _ensure_particles() -> void:
	if _smoke != null and _sparks != null:
		return
	if _smoke == null:
		_smoke = _build_smoke()
		_smoke.layers = 2
		_smoke.emitting = false
		add_child(_smoke)
	if _sparks == null:
		_sparks = _build_sparks()
		_sparks.layers = 2
		_sparks.emitting = false
		add_child(_sparks)


func _on_health_changed(current: float, maximum: float) -> void:
	var ratio := current / maximum if maximum > 0.0 else 0.0
	_apply(state_for(ratio))


func _apply(new_state: int) -> void:
	var changed := new_state != state
	state = new_state
	if changed:
		state_changed.emit(state)

	_ensure_particles()
	match state:
		State.HEALTHY:
			if motion != null:
				motion.speed_scale = 1.0
				motion.flicker_amount = 0.0
			_smoke.emitting = false
			_sparks.emitting = false
		State.HURT:
			if motion != null:
				motion.speed_scale = 0.65
				motion.flicker_amount = 0.25
			_smoke.amount_ratio = 0.4
			_smoke.emitting = true
			_sparks.emitting = false
		State.DYING:
			if motion != null:
				motion.speed_scale = 0.3
				motion.flicker_amount = 0.7
			_smoke.amount_ratio = 1.0
			_smoke.emitting = true
			_sparks.emitting = true


func _build_smoke() -> GPUParticles3D:
	var puff := GPUParticles3D.new()
	puff.name = "Smoke"
	puff.position = smoke_offset
	puff.amount = 24
	puff.lifetime = 2.5
	puff.local_coords = false
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	mesh.radial_segments = 4
	mesh.rings = 2

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.95
	material.albedo_color = Color.WHITE
	mesh.material = material
	puff.draw_pass_1 = mesh

	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.0, 1.0, 0.0)
	process_material.spread = 15.0
	process_material.initial_velocity_min = 0.3
	process_material.initial_velocity_max = 0.6
	process_material.gravity = Vector3(0.0, 0.15, 0.0)
	process_material.scale_min = 0.6
	process_material.scale_max = 1.6
	process_material.angular_velocity_min = -40.0
	process_material.angular_velocity_max = 40.0

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.28, 0.27, 0.26, 0.55))
	gradient.set_color(1, Color(0.18, 0.18, 0.18, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process_material.color_ramp = ramp

	puff.process_material = process_material
	return puff


func _build_sparks() -> GPUParticles3D:
	var sparks := GPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.position = smoke_offset
	sparks.amount = 12
	sparks.lifetime = 0.5
	sparks.explosiveness = 0.8
	sparks.local_coords = false
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.015, 0.015, 0.015)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color.BLACK
	material.emission_enabled = true
	material.emission = Color(1.0, 0.55, 0.2)
	material.emission_energy_multiplier = 4.0
	mesh.material = material
	sparks.draw_pass_1 = mesh

	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.0, 1.0, 0.0)
	process_material.spread = 60.0
	process_material.initial_velocity_min = 1.5
	process_material.initial_velocity_max = 3.0
	process_material.gravity = Vector3(0.0, -6.0, 0.0)
	sparks.process_material = process_material

	return sparks
