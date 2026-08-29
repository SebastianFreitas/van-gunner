extends Interactable


func get_interaction_prompt() -> String:
	if GameSession.phase == GameSession.RunPhase.IDLE:
		return "E  KNOCK TO START THE RUN"
	return "THE DRIVER DOESN'T ANSWER"


func interact(_actor: Node3D) -> void:
	if GameSession.phase == GameSession.RunPhase.IDLE:
		GameSession.begin_run()
