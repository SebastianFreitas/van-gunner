class_name LootMachine
extends Interactable

## Left-wall hopper. Street-kill loot queues here; E on the cabinet ejects one item.

@onready var hopper_window: Node3D = $HopperWindow
@onready var eject_point: Marker3D = $EjectPoint


func _ready() -> void:
	collision_layer = 3
	LootCollector.bind_machine(self, hopper_window, eject_point)
	LootCollector.queue_changed.connect(_on_queue_changed)
	_on_queue_changed()


func get_interaction_prompt() -> String:
	var n := LootCollector.queue_size()
	if n <= 0:
		return "Hopper empty"
	return "Dispense loot (%d)" % n


func interact(_actor: Node3D) -> void:
	LootCollector.try_eject()
	_on_queue_changed()


func _on_queue_changed() -> void:
	prompt = get_interaction_prompt()
