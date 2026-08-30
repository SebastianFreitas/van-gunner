class_name CraftingTable
extends Interactable

signal inspected(message: String)

@onready var loot_anchor: Marker3D = $"../LootAnchor"


func _ready() -> void:
	LootCollector.set_collection_anchor(loot_anchor)


func interact(_actor: Node3D) -> void:
	inspected.emit("CRAFTING BENCH — RECIPES UNAVAILABLE IN THIS PROTOTYPE")
