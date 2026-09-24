extends Interactable
## Interactable request board in the van; E opens the van schematic (skill tree HUD).

signal opened


func interact(_actor: Node3D) -> void:
	opened.emit()
