class_name WeaponPickup
extends Pickup

## World gun loot — shoot to stash, walk to collect into WeaponInventory.

var weapon_instance: WeaponInstance


func setup(instance: WeaponInstance) -> void:
	weapon_instance = instance
	item = null
	if sprite:
		## Placeholder tinted quad until weapon icons exist.
		sprite.modulate = _color_for_family(instance)
		sprite.pixel_size = 0.006


func _ready() -> void:
	add_to_group(&"pickup")
	add_to_group(&"weapon_pickup")
	_apply_pickup_radius()
	_apply_shot_hit_radius()
	body_entered.connect(_on_body_entered)
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_expired)
	if weapon_instance and sprite:
		sprite.modulate = _color_for_family(weapon_instance)


func _use(player: Node3D) -> void:
	if _used:
		return
	if not _collector:
		_collector = player
	## Resolve collect before marking used — full inventory must keep the pickup.
	if weapon_instance == null:
		return
	var inventory := player.get_node_or_null("WeaponInventory") as WeaponInventory
	if inventory == null:
		return
	var result := inventory.try_add(weapon_instance)
	if result == WeaponInventory.AddResult.STORED:
		_used = true
		set_deferred("monitoring", false)
		_set_shot_hit_active(false)
		LootCollector.unregister(self)
		_toast(player, "Picked up %s" % weapon_instance.display_name())
		weapon_instance = null
		_consume()
		return
	## Full — stash state for replace prompt without freeing.
	_stashed = true
	set_deferred("monitoring", true)
	_set_shot_hit_active(false)
	LootCollector.unregister(self)
	var prompt_script = load("res://scripts/ui/weapon_replace_prompt.gd")
	if prompt_script:
		prompt_script.request(player, weapon_instance, self)


func _on_collected(_player: Node3D) -> void:
	## Handled in _use for weapons.
	pass


func _toast(player: Node3D, text: String) -> void:
	if player.has_signal("interaction_prompt_changed"):
		player.interaction_prompt_changed.emit(text)


static func _color_for_family(instance: WeaponInstance) -> Color:
	if instance == null:
		return Color(0.75, 0.75, 0.7)
	var def := instance.get_definition()
	if def == null:
		return Color(0.75, 0.75, 0.7)
	match def.family:
		WeaponDefinition.Family.SHOTGUN:
			return Color(0.85, 0.55, 0.35)
		WeaponDefinition.Family.MACHINEGUN:
			return Color(0.55, 0.75, 0.45)
		WeaponDefinition.Family.SNIPER:
			return Color(0.45, 0.65, 0.9)
		_:
			return Color(0.85, 0.8, 0.5)


static func spawn_at(
	instance: WeaponInstance,
	world_position: Vector3,
	container: Node
) -> Node:
	var scene := load("res://scenes/items/weapon_pickup.tscn") as PackedScene
	var pickup := scene.instantiate()
	if pickup.has_method("setup"):
		pickup.call("setup", instance)
	container.add_child(pickup)
	if pickup is Node3D:
		(pickup as Node3D).global_position = world_position
	return pickup
