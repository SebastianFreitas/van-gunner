class_name CraftingTable
extends Interactable

signal inspected(message: String)


func interact(_actor: Node3D) -> void:
	inspected.emit("CRAFTING BENCH — RECIPES UNAVAILABLE IN THIS PROTOTYPE")
