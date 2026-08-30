class_name Grenade
extends RigidBody3D

var _fuse_remaining := 1.0
var _explosion_damage := 20.0
var _explosion_radius := 3.5
var _armed := false


func _ready() -> void:
	gravity_scale = 1.4
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = 0.35
	angular_damp = 0.8
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.28, 0.18, 1.0)
	sphere.material = material
	mesh.mesh = sphere
	add_child(mesh)
	var shape := CollisionShape3D.new()
	var collision := SphereShape3D.new()
	collision.radius = 0.12
	shape.shape = collision
	add_child(shape)
	collision_layer = 0
	collision_mask = 1


func launch(
	direction: Vector3,
	speed: float,
	fuse_time: float,
	damage: float,
	radius: float
) -> void:
	_explosion_damage = damage
	_explosion_radius = radius
	_fuse_remaining = fuse_time
	_armed = true
	linear_velocity = direction.normalized() * speed + Vector3.UP * 2.5
	angular_velocity = Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))


func _physics_process(delta: float) -> void:
	if not _armed:
		return
	_fuse_remaining -= delta
	if _fuse_remaining <= 0.0:
		_explode()


func _explode() -> void:
	if not _armed:
		return
	_armed = false
	var info := DamageInfo.create(_explosion_damage, DamageType.Type.EXPLOSIVE)
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if not is_instance_valid(node) or not node.has_method(&"take_damage"):
			continue
		var enemy := node as Node3D
		var distance := global_position.distance_to(enemy.global_position)
		if distance > _explosion_radius:
			continue
		var falloff := 1.0 - clampf(distance / _explosion_radius, 0.0, 1.0)
		var blast := info.duplicate_info()
		blast.amount = _explosion_damage * falloff
		enemy.take_damage(blast)
	queue_free()
