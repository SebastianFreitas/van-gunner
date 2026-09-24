class_name CraftingTable
extends Interactable
## Interactable crafting table in the van; E opens the bench screen.

signal opened


func interact(_actor: Node3D) -> void:
	opened.emit()
