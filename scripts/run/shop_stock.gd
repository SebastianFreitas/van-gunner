extends Node3D

## Rolls 3 unique items from the shop pool and places them on the counter.
## Always stocks a generated weapon in the last counter slot.

@export var offer_count := 3
@export var pool_key := "shop"
## Chance [0,1] to stock a weapon in the last counter slot (1 = always).
@export_range(0.0, 1.0, 0.01) var weapon_offer_chance := 1.0

const _OFFER_SCENE := preload("res://scenes/shop/shop_offer.tscn")
const _WEAPON_OFFER_SCENE := preload("res://scenes/shop/weapon_shop_offer.tscn")

## World slots on the counter lip (booth at x=15.85; lip top ≈ 1.10).
const _SLOT_POSITIONS: Array[Vector3] = [
	Vector3(14.64, 1.52, -2.0),
	Vector3(14.64, 1.52, 0.0),
	Vector3(14.64, 1.52, 2.0),
]


func _ready() -> void:
	_stock_offers()


func _stock_offers() -> void:
	var items := ItemPoolRegistry.pick_items_from(pool_key, offer_count)
	var slot_count := mini(maxi(items.size(), 1), _SLOT_POSITIONS.size())
	var weapon_slot := -1
	if slot_count > 0 and randf() <= weapon_offer_chance:
		weapon_slot = slot_count - 1
	for i in range(slot_count):
		if i == weapon_slot:
			var offer: Node = _WEAPON_OFFER_SCENE.instantiate()
			offer.position = _SLOT_POSITIONS[i]
			add_child(offer)
			var level := maxi(GameSession.route_step, 1)
			if offer.has_method("setup_weapon"):
				offer.call("setup_weapon", WeaponGenerator.create_weapon(level))
		elif i < items.size():
			var offer2 := _OFFER_SCENE.instantiate() as ShopOffer
			offer2.position = _SLOT_POSITIONS[i]
			add_child(offer2)
			offer2.setup(items[i])
