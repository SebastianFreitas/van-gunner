extends Interactable

## Wall board where the run's class is picked. Only IDLE lets it change; for the
## rest of the run the prompt just names the equipped class and E does nothing.

signal opened


func get_interaction_prompt() -> String:
	var def := ClassCatalog.load_or_basic(GameSession.class_id)
	var class_label := def.display_name if def else "Basic"
	if GameSession.phase == GameSession.RunPhase.IDLE:
		return "Change class (%s)" % class_label
	return "Class: %s" % class_label


func interact(_actor: Node3D) -> void:
	if GameSession.phase != GameSession.RunPhase.IDLE:
		return
	opened.emit()
