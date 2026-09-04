class_name WeaponShopOffer
extends ShopOffer

## Shop counter offer that sells a generated WeaponInstance for gold.

var weapon_instance: WeaponInstance


func setup_weapon(instance: WeaponInstance, price: int = -1) -> void:
	weapon_instance = instance
	item = null
	_sold = false
	visible = true
	if _collision:
		_collision.disabled = false
	_price = price if price >= 0 else WeaponPricing.shop_price(instance)
	if _sprite:
		_sprite.texture = WeaponPickup.placeholder_texture()
		_sprite.modulate = WeaponPickup._color_for_family(instance)
		_sprite.pixel_size = 0.007
		_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_sprite.render_priority = 2
	_base_y = position.y
	_bob_initialized = true


func get_interaction_prompt() -> String:
	if _sold or weapon_instance == null:
		return ""
	var name_text := weapon_instance.display_name()
	if GameSession.coins < _price:
		return "E  %s — %d GOLD (need %d)" % [name_text, _price, _price - GameSession.coins]
	return "E  BUY %s — %d GOLD" % [name_text, _price]


func interact(actor: Node3D) -> void:
	if _sold or weapon_instance == null:
		return
	var inventory := actor.get_node_or_null("WeaponInventory") as WeaponInventory
	if inventory == null:
		return
	if not GameSession.spend_coins(_price):
		return
	var result := inventory.try_add(weapon_instance)
	if result == WeaponInventory.AddResult.STORED:
		_mark_weapon_sold()
		return
	## Full inventory: put gun in active slot, drop the old one.
	var old := inventory.replace_slot(inventory.active_index, weapon_instance)
	if old:
		var container: Node = get_tree().current_scene
		var travel := get_tree().get_first_node_in_group(&"travel_controller")
		if travel != null and travel.get("van_rig") != null:
			container = travel.get("van_rig") as Node
		var pickup_script = load("res://scripts/weapons/weapon_pickup.gd")
		if pickup_script:
			pickup_script.spawn_at(old, global_position + Vector3(0.0, 0.3, 0.6), container)
	_mark_weapon_sold()


func _mark_weapon_sold() -> void:
	_sold = true
	weapon_instance = null
	item = null
	prompt = ""
	if _collision:
		_collision.disabled = true
	if _sprite:
		var tween := create_tween()
		tween.set_parallel()
		tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.2).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "position:y", position.y + 0.2, 0.2)
		tween.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	if _sold or weapon_instance == null:
		return
	if not _bob_initialized:
		_base_y = position.y
		_bob_initialized = true
	_time += delta
	position.y = _base_y + sin(_time * bob_speed) * bob_height
	rotate_y(spin_speed * delta)
