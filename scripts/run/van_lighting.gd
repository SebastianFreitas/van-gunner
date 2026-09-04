class_name VanLighting
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
	# Forward+ leaves stale light↔geometry pairings when VisualInstance.layers
	# changes after pairing (Godot #121989, fixed in 4.8). Hide lights first so
	# they unpair, then retarget layers, then restore.
	var suppressed: Array[Light3D] = []
	for child in get_children():
		if child is Light3D and child.visible:
			child.visible = false
			suppressed.append(child)

	# Let the render server process the hide/unpair before retargeting layers.
	await get_tree().process_frame

	var interior := get_node_or_null(interior_path)
	if interior:
		mark_interior_geometry(interior)
	var player := get_node_or_null(player_path)
	if player:
		mark_interior_geometry(player)

	await get_tree().process_frame

	for light in suppressed:
		if is_instance_valid(light):
			light.visible = true


static func mark_interior_geometry(root: Node) -> void:
	if root is Light3D:
		pass
	elif root is VisualInstance3D:
		(root as VisualInstance3D).layers = LAYER_VAN_INTERIOR
	for child in root.get_children():
		mark_interior_geometry(child)
