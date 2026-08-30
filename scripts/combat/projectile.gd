class_name Projectile
extends Area3D

signal hit_target(target: Node)

var velocity := Vector3.ZERO
var gravity_scale := 1.0
var damage_info: DamageInfo
var owner_rid: RID
var max_distance := 80.0
var explosion_radius := 1.8

var _spawn_position := Vector3.ZERO
var _has_hit := false
var _collision_mask := 7

@onready var _bullet_mesh: MeshInstance3D = $BulletMesh
@onready var _trail: CPUParticles3D = $Trail
@onready var _trail_line: MeshInstance3D = $TrailLine


func setup(
	direction: Vector3,
	speed: float,
	weight: float,
	size: float,
	info: DamageInfo,
	shooter: CollisionObject3D,
	range_limit: float,
	blast_radius: float
) -> void:
	velocity = direction.normalized() * speed
	gravity_scale = weight
	damage_info = info
	if shooter:
		owner_rid = shooter.get_rid()
	max_distance = range_limit
	explosion_radius = blast_radius
	_spawn_position = global_position
	_apply_size(size)
	var trail_line := get_node_or_null("TrailLine")
	if trail_line and trail_line.has_method("add_point"):
		trail_line.add_point(global_position)
	if _trail:
		_trail.emitting = true
		_trail.direction = -direction.normalized()


func _ready() -> void:
	_collision_mask = collision_mask
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	var from := global_position
	velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * gravity_scale * delta
	var motion := velocity * delta
	var to := from + motion

	var hit := _sweep_for_hit(from, to)
	if hit:
		global_position = hit.position
		_update_trail()
		_resolve_hit(hit.collider)
		return

	global_position = to
	_update_trail()
	_orient_to_velocity()

	if global_position.distance_to(_spawn_position) >= max_distance:
		queue_free()


func _sweep_for_hit(from: Vector3, to: Vector3) -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, _collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if owner_rid.is_valid():
		query.exclude = [owner_rid]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	return result


func _update_trail() -> void:
	if _trail_line and _trail_line.has_method("add_point"):
		_trail_line.call("add_point", global_position)


func _orient_to_velocity() -> void:
	if velocity.length_squared() < 0.001:
		return
	look_at(global_position + velocity.normalized(), Vector3.UP)


func _apply_size(size: float) -> void:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node:
		var sphere := SphereShape3D.new()
		sphere.radius = size
		shape_node.shape = sphere
	if _bullet_mesh and _bullet_mesh.mesh is SphereMesh:
		(_bullet_mesh.mesh as SphereMesh).radius = size * 1.6
		(_bullet_mesh.mesh as SphereMesh).height = size * 3.2
		_bullet_mesh.scale = Vector3.ONE * maxf(size * 22.0, 1.0)


func _on_body_entered(body: Node3D) -> void:
	_resolve_hit(body)


func _on_area_entered(area: Area3D) -> void:
	_resolve_hit(area)


func _resolve_hit(collider: Node) -> void:
	if _has_hit:
		return
	if collider is CollisionObject3D and (collider as CollisionObject3D).get_rid() == owner_rid:
		return
	_has_hit = true
	monitoring = false
	monitorable = false
	if _trail:
		_trail.emitting = false
	if damage_info:
		damage_info.is_headshot = DamageResolver.is_headshot(collider)
		damage_info.hit_position = global_position
		damage_info.explosion_radius = explosion_radius
		DamageResolver.apply_hit(damage_info, collider)
		DamageResolver.apply_status_from_hit(damage_info, collider)
		if damage_info.damage_type == DamageType.Type.EXPLOSIVE:
			var space_state := get_world_3d().direct_space_state
			var exclude: Array[RID] = []
			if owner_rid.is_valid():
				exclude.append(owner_rid)
			DamageResolver.apply_explosion(
				global_position,
				explosion_radius,
				damage_info,
				space_state,
				exclude
			)
		hit_target.emit(collider)
	queue_free()
