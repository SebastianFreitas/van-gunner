extends RefCounted

## Target picking, cabin/breach queries and status math for WindowRaider. No await.

var raider: Node3D  # the WindowRaider; reads/writes its fields when called


func _init(owner: Node3D) -> void:
	raider = owner


func wants_player_target() -> bool:
	var target_player := player()
	if target_player == null:
		return false
	var marker := vital_marker(living_assigned_vital())
	if marker == null:
		marker = vital_marker(pick_vital())
	if marker == null:
		return true
	var d_player := horizontal_xz(raider.global_position, target_player.global_position)
	var d_vital := horizontal_xz(raider.global_position, marker.global_position)
	return d_player * raider._BENCH_BIAS < d_vital * raider._PLAYER_BIAS


func in_player_melee() -> bool:
	var target_player := player()
	if target_player == null:
		return false
	var dist := horizontal_xz(raider.global_position, target_player.global_position)
	return dist <= raider._MELEE_RANGE + 0.15


func pick_vital() -> Node:
	var controller: BreachController = raider._breach_controller()
	if controller and controller.has_method("pick_vital_near"):
		var picked: Node = controller.pick_vital_near(raider.global_position, raider)
		if picked:
			return picked
	return null


func living_assigned_vital() -> Node:
	if raider._assigned_vital and is_instance_valid(raider._assigned_vital):
		if raider._assigned_vital.has_method("is_alive") and raider._assigned_vital.is_alive():
			return raider._assigned_vital
	return null


func vital_marker(vital: Node) -> Node3D:
	if vital == null or not is_instance_valid(vital):
		return null
	if vital.has_method("get_attack_marker"):
		return vital.get_attack_marker() as Node3D
	return vital as Node3D


func path_to_dest(dest_local: Vector3) -> Array[Vector3]:
	var nav := cabin_nav()
	if nav:
		return nav.path_to(raider.position, dest_local)
	var pts: Array[Vector3] = []
	pts.append(dest_local)
	return pts


func parent_local(node: Node3D) -> Vector3:
	var parent_3d := raider.get_parent() as Node3D
	if parent_3d == null or node == null:
		return raider.position
	return parent_3d.to_local(node.global_position)


func player() -> Node3D:
	return raider.get_tree().get_first_node_in_group(&"player") as Node3D


static func horizontal_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func next_attack_wait() -> float:
	var speed_multiplier: float = (
		raider.status_effects.get_attack_speed_multiplier() if raider.status_effects else 1.0
	)
	return raider.attack_interval / maxf(speed_multiplier, 0.2)


func release_nav() -> void:
	var nav := cabin_nav()
	if nav:
		nav.release_all(raider)


func cabin_nav() -> CabinNav:
	if raider.get_tree() == null:
		return null
	return raider.get_tree().get_first_node_in_group(&"cabin_nav") as CabinNav


func request_breach() -> BreachPoint:
	var controller: BreachController = raider._breach_controller()
	if controller == null:
		return null
	return controller.assign_breach_point(raider)


func flash_hit() -> void:
	raider.sprite.modulate = Color(1.0, 0.32, 0.26, 1.0)
	var tween := raider.create_tween()
	tween.tween_property(raider.sprite, "modulate", raider._base_modulate, 0.12)
