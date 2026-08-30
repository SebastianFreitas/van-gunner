class_name ThrowGrenadeEffect
extends ItemEffect

## Throws an explosive grenade from the player's view direction.

@export var throw_speed := 16.0
@export var fuse_time := 1.35
@export var explosion_damage := 30.0
@export var explosion_radius := 4.5


func apply(player: Node3D) -> void:
	var head := player.get_node_or_null("Head") as Node3D
	if not head:
		return
	var forward := -head.global_transform.basis.z.normalized()
	var spawn_pos := head.global_position + forward * 0.55 + Vector3(0.0, -0.15, 0.0)
	var container := _find_spawn_container(player)
	if not container:
		return
	var grenade := Grenade.new()
	container.add_child(grenade)
	grenade.global_position = spawn_pos
	grenade.launch(forward, throw_speed, fuse_time, explosion_damage, explosion_radius)


func _find_spawn_container(player: Node3D) -> Node:
	var van_rig := player.get_parent()
	if van_rig:
		return van_rig
	return player.get_tree().current_scene
