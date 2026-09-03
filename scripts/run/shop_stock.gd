extends Node3D

## Rolls 3 unique items from the shop pool and places them on the counter.

@export var offer_count := 3
@export var pool_key := "shop"

const _OFFER_SCENE := preload("res://scenes/shop/shop_offer.tscn")

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
	var slot_count := mini(items.size(), _SLOT_POSITIONS.size())
	for i in range(slot_count):
		var offer := _OFFER_SCENE.instantiate() as ShopOffer
		offer.position = _SLOT_POSITIONS[i]
		add_child(offer)
		offer.setup(items[i])
