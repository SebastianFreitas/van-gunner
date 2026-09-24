class_name RoomZone
extends Area3D
## Marks a van interior zone; tells GameSession which room the player is in.

@export var room_id: StringName = &"center"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		GameSession.set_room(room_id)
