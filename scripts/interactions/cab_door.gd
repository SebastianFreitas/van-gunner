extends Interactable


func get_interaction_prompt() -> String:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return "THE DRIVER DOESN'T ANSWER"
	if GameSession.phase == GameSession.RunPhase.SHOP:
		return "E  TELL DRIVER TO CONTINUE"
	return "E  TALK TO THE DRIVER"


func interact(_actor: Node3D) -> void:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return
	if GameSession.phase == GameSession.RunPhase.SHOP:
		var travel := get_tree().get_first_node_in_group(&"travel_controller")
		if travel and travel.has_method(&"leave_shop"):
			travel.leave_shop()
		return
	var host := owner
	if host and host.has_method(&"open_driver_talk"):
		host.open_driver_talk()
