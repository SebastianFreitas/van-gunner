extends Interactable
## Layer-2 hit target in front of a side door's gun port; E slides the port's plate open or shut.


func get_interaction_prompt() -> String:
	var port := get_parent() as VanGunPort
	if port == null:
		return ""
	return port.get_port_prompt()


func interact(_actor: Node3D) -> void:
	var port := get_parent() as VanGunPort
	if port:
		port.toggle()
