extends Interactable


func get_interaction_prompt() -> String:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return "THE DRIVER DOESN'T ANSWER"
	return "E  TALK TO THE DRIVER"


func interact(_actor: Node3D) -> void:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return
	var host := owner
	if host and host.has_method(&"open_driver_talk"):
		host.open_driver_talk()
