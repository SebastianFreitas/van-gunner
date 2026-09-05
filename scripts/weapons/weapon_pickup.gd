class_name WeaponPickup
extends Pickup

## World gun loot — walk to collect into WeaponInventory.

var weapon_instance: WeaponInstance


func setup(instance: WeaponInstance) -> void:
	weapon_instance = instance
	item = null
	_apply_visual()


func _ready() -> void:
	add_to_group(&"pickup")
	add_to_group(&"weapon_pickup")
	_apply_pickup_radius()
	_apply_shot_hit_radius()
	body_entered.connect(_on_body_entered)
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_expired)
	_apply_visual()


func _apply_visual() -> void:
	if sprite == null or weapon_instance == null:
		return
	## Placeholder tinted glyph until real weapon icons exist.
	sprite.texture = placeholder_texture()
	sprite.modulate = _color_for_family(weapon_instance)
	sprite.pixel_size = 0.006


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


static var _placeholder_tex: ImageTexture


static func placeholder_texture() -> Texture2D:
	if _placeholder_tex != null:
		return _placeholder_tex
	## Simple gun silhouette on a soft plate so Sprite3D has something to draw.
	var img := Image.create(48, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(6, 26):
		for x in range(6, 42):
			var on_plate := x >= 8 and x <= 40 and y >= 8 and y <= 24
			var on_barrel := y >= 12 and y <= 16 and x >= 18 and x <= 40
			var on_body := y >= 11 and y <= 20 and x >= 10 and x <= 22
			var on_grip := y >= 16 and y <= 24 and x >= 12 and x <= 17
			if on_barrel or on_body or on_grip:
				img.set_pixel(x, y, Color.WHITE)
			elif on_plate:
				img.set_pixel(x, y, Color(1, 1, 1, 0.22))
	_placeholder_tex = ImageTexture.create_from_image(img)
	return _placeholder_tex


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
