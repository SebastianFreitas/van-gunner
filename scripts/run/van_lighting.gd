extends Node3D

## Marks van interior meshes as render layer 2 so DoorSpill (cull mask layer 1)
## lights the corridor through openings without washing the cabin. In Godot,
## objects excluded from a light's cull mask still cast shadows for that light,
## so the outer shell blocks spill everywhere except real holes.

const LAYER_WORLD := 1
const LAYER_VAN_INTERIOR := 2

@export var interior_path: NodePath = NodePath("../Interior")
@export var player_path: NodePath = NodePath("../Player")


func _ready() -> void:
	var interior := get_node_or_null(interior_path)
	if interior:
		_set_geometry_layers(interior, LAYER_VAN_INTERIOR)
	var player := get_node_or_null(player_path)
	if player:
		_set_geometry_layers(player, LAYER_VAN_INTERIOR)


func _set_geometry_layers(root: Node, layer: int) -> void:
	if root is VisualInstance3D:
		(root as VisualInstance3D).layers = layer
	for child in root.get_children():
		_set_geometry_layers(child, layer)
