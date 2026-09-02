class_name Grenade
extends Node3D

## Hand-integrated ballistics instead of a RigidBody3D.
##
## The van drives through world space, so a rigid body dropped inside it is
## immediately left behind on the road. The grenade instead simulates in its
## parent's local space (the van rig) and only converts to world space for the
## collision sweep, so it rides along with the van the way the player expects.

signal exploded(world_position: Vector3)

const SURFACE_OFFSET := 0.01
## Below this a bounce is treated as the grenade coming to rest.
const REST_SPEED := 0.45

@export var radius := 0.12
@export var gravity_scale := 1.4
## Share of speed kept when it slaps into a wall or the floor.
@export_range(0.0, 1.0, 0.01) var bounce_retention := 0.4
## How quickly it scrubs off speed while sliding along a surface.
@export var surface_friction := 3.0

var _velocity := Vector3.ZERO
var _fuse_remaining := 1.0
var _explosion_damage := 20.0
var _explosion_radius := 3.5
var _armed := false
var _resting := false
var _spin := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var _mesh: MeshInstance3D

@onready var _reference: Node3D = get_parent_node_3d()


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.28, 0.18, 1.0)
	material.metallic = 0.4
	material.roughness = 0.6
	sphere.material = material
	_mesh.mesh = sphere
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


## `direction` is a world-space aim vector; it gets folded into the van's frame.
func launch(
	direction: Vector3,
	speed: float,
	fuse_time: float,
	damage: float,
	blast_radius: float
) -> void:
	_explosion_damage = damage
	_explosion_radius = blast_radius
	_fuse_remaining = fuse_time
	_armed = true
	var local_direction := _to_reference_direction(direction).normalized()
	_velocity = local_direction * speed + Vector3.UP * 2.5
	_spin = Vector3(
		randf_range(-9.0, 9.0),
		randf_range(-9.0, 9.0),
		randf_range(-9.0, 9.0)
	)


func _physics_process(delta: float) -> void:
	if not _armed:
		return
	_integrate(delta)
	_mesh.rotation += _spin * delta
	_fuse_remaining -= delta
	if _fuse_remaining <= 0.0:
		_explode()


func _integrate(delta: float) -> void:
	if _resting:
		return
	_velocity.y -= _gravity * gravity_scale * delta
	var from := position
	var to := from + _velocity * delta
	var hit := _sweep(from, to)
	if hit.is_empty():
		position = to
		return

	var normal: Vector3 = hit.normal
	position = (hit.position as Vector3) + normal * (radius + SURFACE_OFFSET)
	# Only the part of the throw driving into the surface is lost to the impact.
	# Whatever runs along the surface just scrubs off against friction, so a
	# shallow throw skids down the van instead of stopping dead.
	var into_surface := _velocity.project(normal)
	var along_surface := _velocity - into_surface
	_velocity = (
		along_surface.lerp(Vector3.ZERO, clampf(surface_friction * delta, 0.0, 1.0))
		- into_surface * bounce_retention
	)
	_spin *= bounce_retention
	if _velocity.length() < REST_SPEED:
		_velocity = Vector3.ZERO
		_spin = Vector3.ZERO
		_resting = true


## Sweeps in world space but builds both endpoints from the *current* reference
## transform, so the van's own movement this frame is not mistaken for motion of
## the grenade.
func _sweep(from_local: Vector3, end_local: Vector3) -> Dictionary:
	if not is_instance_valid(_reference):
		return {}
	var frame := _reference.global_transform
	var query := PhysicsRayQueryParameters3D.create(
		frame * from_local,
		frame * end_local,
		DamageResolver.WORLD_MASK
	)
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	var inverse := frame.affine_inverse()
	return {
		"position": inverse * (result.position as Vector3),
		"normal": (inverse.basis * (result.normal as Vector3)).normalized(),
	}


func _explode() -> void:
	if not _armed:
		return
	_armed = false
	var center := global_position
	var info := DamageInfo.create(_explosion_damage, DamageType.Type.EXPLOSIVE)
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node3D
		if not is_instance_valid(enemy) or not enemy.has_method(&"take_damage"):
			continue
		var distance := center.distance_to(enemy.global_position)
		if distance > _explosion_radius:
			continue
		var falloff := 1.0 - clampf(distance / _explosion_radius, 0.0, 1.0)
		var blast := info.duplicate_info()
		blast.amount = _explosion_damage * falloff
		blast.hit_position = enemy.global_position + Vector3(0, 1.2, 0)
		blast.explosion_radius = _explosion_radius
		enemy.take_damage(blast)
	_spawn_blast_fx(center)
	exploded.emit(center)
	queue_free()


func _spawn_blast_fx(center: Vector3) -> void:
	var host := _reference if is_instance_valid(_reference) else get_tree().current_scene
	if not host:
		return

	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.66, 0.28, 1.0)
	flash.light_energy = 9.0
	flash.omni_range = _explosion_radius * 2.0
	host.add_child(flash)
	flash.global_position = center

	var sparks := CPUParticles3D.new()
	sparks.amount = 48
	sparks.lifetime = 0.5
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.spread = 180.0
	sparks.initial_velocity_min = _explosion_radius * 1.5
	sparks.initial_velocity_max = _explosion_radius * 4.0
	sparks.gravity = Vector3(0.0, -6.0, 0.0)
	sparks.scale_amount_min = 0.06
	sparks.scale_amount_max = 0.16
	sparks.color = Color(1.0, 0.72, 0.3, 1.0)
	host.add_child(sparks)
	sparks.global_position = center
	sparks.finished.connect(sparks.queue_free)
	sparks.emitting = true

	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.28)
	tween.tween_callback(flash.queue_free)


func _to_reference_direction(world_direction: Vector3) -> Vector3:
	if not is_instance_valid(_reference):
		return world_direction
	return _reference.global_transform.basis.orthonormalized().inverse() * world_direction
