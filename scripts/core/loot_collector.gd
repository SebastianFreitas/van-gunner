extends Node

## Hopper for street-kill loot. Floor drops stay walkable; REST vacuums
## pickups still sitting outside the hull into this queue.

signal queue_changed

const _PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")
const _WEAPON_PICKUP_SCENE := preload("res://scenes/items/weapon_pickup.tscn")
const _PLAYER_OUTSIDE_EPS := 0.15
const _POPUP_RISE := 0.85
const _POPUP_SECS := 0.7

var _hopper: Array[LootCatch] = []
var _window: Node3D
var _eject_point: Marker3D
var _eject_parent: Node3D


func _ready() -> void:
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.session_loaded.connect(clear)


func bind_machine(machine: Node3D, hopper_window: Node3D, eject_point: Marker3D) -> void:
	_window = hopper_window
	_eject_point = eject_point
	_eject_parent = machine.get_parent() as Node3D
	_refresh_window()


func queue_size() -> int:
	return _hopper.size()


func clear() -> void:
	_hopper.clear()
	queue_changed.emit()
	_refresh_window()


func enqueue(catch: LootCatch) -> void:
	if catch == null:
		return
	_hopper.append(catch)
	queue_changed.emit()
	_refresh_window()


func unregister(_pickup: Node3D) -> void:
	pass


func try_eject() -> bool:
	if _hopper.is_empty():
		return false
	var catch: LootCatch = _hopper.pop_front()
	queue_changed.emit()
	_refresh_window()
	_spawn_catch_in_world(catch, _eject_world_position(), _eject_parent, 0, true)
	return true


func deliver_item(
	item: ItemDefinition,
	world_position: Vector3,
	container: Node,
	enemy: Node = null
) -> void:
	if item == null:
		return
	var catches: Array[LootCatch] = []
	catches.append(LootCatch.from_item(item))
	deliver_catches(catches, world_position, container, enemy)


func deliver_catches(
	catches: Array[LootCatch],
	world_position: Vector3,
	container: Node,
	enemy: Node = null
) -> void:
	if catches.is_empty() or not is_instance_valid(container):
		return
	_spawn_popup(world_position, container, catches)
	if should_drop_on_floor(enemy):
		for i in catches.size():
			_spawn_catch_in_world(catches[i], world_position, container, i, false)
	else:
		for catch in catches:
			enqueue(catch)


func should_drop_on_floor(enemy: Node) -> bool:
	if is_player_outside():
		return true
	if enemy and enemy.has_method(&"is_inside_cabin"):
		return bool(enemy.call(&"is_inside_cabin"))
	return false


func is_player_outside() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var player := tree.get_first_node_in_group(&"player") as Node3D
	var containment := _containment()
	if player == null or containment == null:
		return false
	return containment.horizontal_clearance(player.global_position) > _PLAYER_OUTSIDE_EPS


func is_world_pos_outside_van(world_pos: Vector3) -> bool:
	var containment := _containment()
	if containment == null:
		return true
	return containment.horizontal_clearance(world_pos) > _PLAYER_OUTSIDE_EPS


func absorb_world_pickup(pickup: Pickup) -> void:
	if pickup == null or pickup._used:
		return
	var catch: LootCatch = null
	if pickup is WeaponPickup:
		var gun := pickup as WeaponPickup
		if gun.weapon_instance:
			catch = LootCatch.from_weapon(gun.weapon_instance)
			gun.weapon_instance = null
	elif pickup.item:
		catch = LootCatch.from_item(pickup.item)
	pickup._used = true
	pickup.set_deferred("monitoring", false)
	if catch:
		enqueue(catch)
	pickup.queue_free()


func _on_phase_changed(next_phase: GameSession.RunPhase) -> void:
	if next_phase != GameSession.RunPhase.REST and next_phase != GameSession.RunPhase.ROUTE_CHOICE:
		return
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(&"pickup"):
		var pickup := node as Pickup
		if pickup == null or pickup._used or pickup._stashed:
			continue
		if is_world_pos_outside_van(pickup.global_position):
			pickup.force_collect()


func _spawn_catch_in_world(
	catch: LootCatch,
	world_position: Vector3,
	container: Node,
	index: int,
	from_eject: bool
) -> void:
	if catch == null or not is_instance_valid(container):
		return
	var offset := Vector3(float(index) * 0.35, 0.12, 0.0)
	if not from_eject:
		var angle := randf() * TAU
		var radius := randf() * 0.4
		offset += Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	if catch.weapon:
		var pickup = _WEAPON_PICKUP_SCENE.instantiate()
		if pickup.has_method("setup"):
			pickup.call("setup", catch.weapon)
		container.add_child(pickup)
		if pickup is Node3D:
			(pickup as Node3D).global_position = world_position + offset
		return
	if catch.item == null:
		return
	var item_pickup := _PICKUP_SCENE.instantiate() as Pickup
	if item_pickup == null:
		return
	item_pickup.item = catch.item
	container.add_child(item_pickup)
	item_pickup.global_position = world_position + offset
	if from_eject and catch.item.kind == ItemDefinition.ItemKind.MONEY:
		item_pickup.call_deferred(&"_auto_collect_instant")


func _eject_world_position() -> Vector3:
	if is_instance_valid(_eject_point):
		return _eject_point.global_position
	return Vector3.ZERO


func _spawn_popup(world_position: Vector3, container: Node, catches: Array[LootCatch]) -> void:
	var root := Node3D.new()
	container.add_child(root)
	root.global_position = world_position + Vector3(0.0, 1.45, 0.0)
	var spacing := 0.32
	var start_x := -spacing * 0.5 * float(catches.size() - 1)
	var sprites: Array[Sprite3D] = []
	for i in catches.size():
		var catch := catches[i]
		var spr := Sprite3D.new()
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.pixel_size = 0.0045
		spr.texture = catch.get_icon()
		spr.modulate = catch.get_modulate()
		spr.position = Vector3(start_x + spacing * float(i), 0.0, 0.0)
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		root.add_child(spr)
		sprites.append(spr)
		var coins := catch.coin_amount()
		if coins > 0:
			var lab := Label3D.new()
			lab.text = "+%d" % coins
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.pixel_size = 0.012
			lab.modulate = Color(1.0, 0.85, 0.35, 1.0)
			lab.position = Vector3(start_x + spacing * float(i), 0.22, 0.0)
			root.add_child(lab)
	var tween := root.create_tween()
	tween.set_parallel()
	tween.tween_property(root, "position:y", root.position.y + _POPUP_RISE, _POPUP_SECS)
	for spr in sprites:
		tween.tween_property(spr, "modulate:a", 0.0, _POPUP_SECS)
	tween.chain().tween_callback(root.queue_free)


func _refresh_window() -> void:
	if not is_instance_valid(_window):
		return
	for child in _window.get_children():
		child.queue_free()
	var shown := mini(_hopper.size(), 8)
	for i in shown:
		var catch := _hopper[i]
		var spr := Sprite3D.new()
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.pixel_size = 0.0032
		spr.texture = catch.get_icon()
		spr.modulate = catch.get_modulate()
		spr.position = Vector3(0.0, 0.09 * float(i), 0.02)
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_window.add_child(spr)


func _containment() -> VanPlayerContainment:
	var tree := get_tree()
	if tree == null:
		return null
	var van := tree.get_first_node_in_group(&"van_run")
	if van == null:
		return null
	return van.get("player_containment") as VanPlayerContainment
