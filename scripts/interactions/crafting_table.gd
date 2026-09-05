class_name CraftingTable
extends Interactable

signal opened


func interact(_actor: Node3D) -> void:
	opened.emit()
