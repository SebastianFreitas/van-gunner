extends RefCounted

## Spawns bosses/raiders for EncounterDirector and answers alive/approaching queries.

var director: Node  # the owning EncounterDirector; reads/writes its fields when called


func _init(owner: Node) -> void:
	director = owner


func spawn_boss() -> WindowRaider:
	const _SCENE := preload("res://scenes/enemies/biker_boss.tscn")
	var boss := _SCENE.instantiate() as WindowRaider
	if boss == null:
		return null
	director.enemy_container.add_child(boss)
	var ref_z: float = director.breach_controller.get_rear_outside_reference_z()
	var local_pos := Vector3(0.0, director.rear_spawn.position.y, ref_z + GameBalance.SPAWN_DISTANCE)
	boss.transform = Transform3D(director.rear_spawn.transform.basis, local_pos)
	var world_speed := GameBalance.get_mob_world_speed(GameSession.route_step)
	boss.begin_assault(null, world_speed)
	ActCardCombat.configure_enemy(boss)
	if boss.health_bar and boss.health_bar.has_method(&"update_ratio") and boss.max_health > 0.0:
		boss.health_bar.update_ratio(boss.health / boss.max_health)
	return boss


func spawn_raider(slot: int, count: int) -> WindowRaider:
	return spawn_from_definition(GameBalance.pick_spawn_enemy(), slot, count)


func spawn_from_definition(enemy_def: EnemyDefinition, slot: int, count: int) -> WindowRaider:
	if enemy_def == null or enemy_def.scene == null:
		return null
	var raider := enemy_def.scene.instantiate() as WindowRaider
	if raider == null:
		return null
	raider.is_agile = enemy_def.is_agile
	director.enemy_container.add_child(raider)
	# Place on the balance spawn line in EnemyContainer space (+Z = behind van).
	# Mob world speed is derived so that at the expected upgraded van speed,
	# rear-door paths take act_engagement_seconds. Live closing tracks travel_speed.
	var ref_z: float = director.breach_controller.get_rear_outside_reference_z()
	var jitter := GameBalance.spawn_offset_for_slot(slot, count)
	var local_pos := Vector3(
		jitter.x,
		director.rear_spawn.position.y,
		ref_z + GameBalance.SPAWN_DISTANCE + jitter.z
	)
	raider.transform = Transform3D(director.rear_spawn.transform.basis, local_pos)
	var world_speed := GameBalance.get_mob_world_speed(GameSession.route_step)
	var breach: BreachPoint = director.breach_controller.assign_breach_point(raider)
	raider.begin_assault(breach, world_speed)
	ActCardCombat.configure_enemy(raider)
	return raider


func any_alive(raiders: Array[WindowRaider]) -> bool:
	for raider in raiders:
		if is_instance_valid(raider) and not raider.is_defeated:
			return true
	return false


func any_approaching(raiders: Array[WindowRaider]) -> bool:
	for raider in raiders:
		if (
			is_instance_valid(raider)
			and not raider.is_defeated
			and raider.assault_phase == WindowRaider.AssaultPhase.APPROACH
		):
			return true
	return false


func despawn_raiders(raiders: Array[WindowRaider]) -> void:
	for raider in raiders:
		if is_instance_valid(raider):
			raider.queue_free()


func despawn_all_enemies() -> void:
	if not director.is_inside_tree():
		return
	for node in director.get_tree().get_nodes_in_group(&"enemy"):
		if is_instance_valid(node):
			node.queue_free()


func retreat_non_boss_enemies() -> void:
	if not director.is_inside_tree():
		return
	for node in director.get_tree().get_nodes_in_group(&"enemy"):
		if not is_instance_valid(node):
			continue
		if bool(node.get("is_boss")) or bool(node.get("is_defeated")):
			continue
		if node.has_method(&"retreat"):
			node.retreat()
		else:
			node.queue_free()


func apply_danger_bump(plan: Array[int]) -> Array[int]:
	var bumped: Array[int] = []
	for count in plan:
		bumped.append(maxi(1, ceili(float(count) * 1.35) + 1))
	return bumped
