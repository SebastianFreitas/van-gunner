extends Node

## Reuses Projectile nodes to avoid instantiate/free churn during heavy fire.

const _PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")

const INITIAL_POOL_SIZE := 96
const MAX_POOL_SIZE := 1024

var _pool: Array[Projectile] = []
var _holder: Node3D


func _ready() -> void:
	_holder = Node3D.new()
	_holder.name = "PooledProjectiles"
	add_child(_holder)

	for _i in INITIAL_POOL_SIZE:
		_pool.append(_create_projectile())


func acquire(
	spawn_parent: Node,
	origin: Vector3,
	direction: Vector3,
	stats: GunStats,
	info: DamageInfo,
	shooter: CollisionObject3D,
	visual_origin = null,
	inherited_velocity: Vector3 = Vector3.ZERO,
	aim_point = null
) -> Projectile:
	var projectile: Projectile = null
	while not _pool.is_empty():
		var candidate: Projectile = _pool.pop_back()
		if is_instance_valid(candidate):
			projectile = candidate
			break
	if projectile == null:
		projectile = _create_projectile()

	if spawn_parent and projectile.get_parent() != spawn_parent:
		projectile.reparent(spawn_parent)

	projectile.global_position = origin
	projectile.setup(direction, stats, info, shooter, visual_origin, inherited_velocity, aim_point)
	return projectile


func release(projectile: Projectile) -> void:
	if not is_instance_valid(projectile):
		return
	if projectile.is_pooled():
		return
	projectile.reset_for_pool()
	if projectile.get_parent() != _holder:
		projectile.reparent(_holder)
	if _pool.size() < MAX_POOL_SIZE:
		_pool.append(projectile)
	else:
		projectile.queue_free()


func _create_projectile() -> Projectile:
	var projectile := _PROJECTILE_SCENE.instantiate() as Projectile
	_holder.add_child(projectile)
	projectile.reset_for_pool()
	return projectile
