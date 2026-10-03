class_name RearClimb
extends Interactable
## Prompt just outside the rear doors that lifts the player back onto the deck while the van is halted.

## VanRig frame (the player's parent frame): mid-aisle just inside the door plane at z 4.68,
## the deck stands at local y 0.05.
const DECK_LANDING := Vector3(0.0, 0.05, 4.1)
## A player whose local position.y is below this is on the road.
const _ROAD_SIDE_Y := -0.35
const BOX_SIZE := Vector3(3.8, 2.4, 1.5)

var _active := false


func _ready() -> void:
	add_to_group(&"rear_climb")
	collision_layer = 0
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = BOX_SIZE
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)


## Layer 2 only: the player's interaction ray uses mask 2 and the player body mask is 17,
## so the box never blocks the player.
func set_active(on: bool) -> void:
	_active = on
	collision_layer = 2 if on else 0


func get_interaction_prompt() -> String:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if _active and player and player.position.y < _ROAD_SIDE_Y:
		return "E  CLIMB IN"
	return ""


func get_gesture() -> StringName:
	return &"press"


func interact(actor: Node3D) -> void:
	if not _active or actor.position.y >= _ROAD_SIDE_Y:
		return
	actor.position = DECK_LANDING
	if actor is CharacterBody3D:
		(actor as CharacterBody3D).velocity = Vector3.ZERO
