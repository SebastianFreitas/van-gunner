extends Area3D

## Breakable window pane (rear doors or side openings). Any solid hit
## shatters it; surrounding metal stays. Uses the enemy hit layer (same as
## pickups/raiders) so projectiles apply damage instead of ricocheting.

signal shattered

@export var glass_mesh_path: NodePath = ^"../WindowGlass"

var _broken := false
var _glass_visual: Node3D
var _collision: CollisionShape3D


func _ready() -> void:
	# Layer 3 / bit 4 — enemy/pickup hits. Projectiles and aim both see this.
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	_glass_visual = get_parent().get_node_or_null("WindowGlass") as Node3D
	if _glass_visual == null:
		_glass_visual = get_node_or_null(glass_mesh_path) as Node3D
	_collision = get_node_or_null("Collision") as CollisionShape3D


func is_intact() -> bool:
	return not _broken


func take_damage(_amount = null) -> void:
	if _broken:
		return
	_shatter()


func _shatter() -> void:
	_broken = true
	if _collision:
		_collision.set_deferred("disabled", true)
	if _glass_visual:
		_glass_visual.hide()
	_spawn_shatter_fx()
	shattered.emit()


func _spawn_shatter_fx() -> void:
	var host := get_tree().current_scene
	if not host:
		host = self
	var origin := global_position

	var shards := CPUParticles3D.new()
	shards.amount = 36
	shards.lifetime = 0.55
	shards.one_shot = true
	shards.explosiveness = 1.0
	shards.spread = 180.0
	shards.initial_velocity_min = 2.5
	shards.initial_velocity_max = 7.0
	shards.gravity = Vector3(0.0, -14.0, 0.0)
	shards.scale_amount_min = 0.04
	shards.scale_amount_max = 0.12
	shards.color = Color(0.55, 0.72, 0.78, 0.85)
	host.add_child(shards)
	shards.global_position = origin
	shards.finished.connect(shards.queue_free)
	shards.emitting = true

	var dust := CPUParticles3D.new()
	dust.amount = 18
	dust.lifetime = 0.35
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.spread = 160.0
	dust.initial_velocity_min = 0.8
	dust.initial_velocity_max = 2.4
	dust.gravity = Vector3(0.0, -2.0, 0.0)
	dust.scale_amount_min = 0.08
	dust.scale_amount_max = 0.2
	dust.color = Color(0.75, 0.82, 0.86, 0.45)
	host.add_child(dust)
	dust.global_position = origin
	dust.finished.connect(dust.queue_free)
	dust.emitting = true
