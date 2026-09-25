class_name VanLighting
extends Node3D

## Marks van interior meshes as render layer 2 so DoorSpill (cull mask layer 1)
## lights the corridor through openings without washing the cabin. In Godot,
## objects excluded from a light's cull mask still cast shadows for that light,
## so the outer shell blocks spill everywhere except real holes.

const LAYER_VAN_INTERIOR := 2

@export var interior_path: NodePath = NodePath("../Interior")
@export var player_path: NodePath = NodePath("../Player")


func _ready() -> void:
	# Mark one frame in, as the old workaround did, so geometry added during
	# the first frame is covered.
	await get_tree().process_frame

	var interior := get_node_or_null(interior_path)
	if interior:
		mark_interior_geometry(interior)
	var player := get_node_or_null(player_path)
	if player:
		mark_interior_geometry(player)


## Moves every non-light VisualInstance3D under root to the van interior layer.
static func mark_interior_geometry(root: Node) -> void:
	if root is VisualInstance3D and not (root is Light3D):
		retarget_layers(root as VisualInstance3D, LAYER_VAN_INTERIOR)
	for child in root.get_children():
		mark_interior_geometry(child)


## Changes vi.layers without leaving a stale light pairing. Godot 4.7 Forward+ keeps a
## light↔geometry pairing across a layers change and skips unpairing once the masks stop overlapping
## (Godot #121989, fixed in 4.8), so freeing the light or mesh later crashes the renderer. Hiding
## the instance first unpairs it from every light, street lamps included, under the old mask.
static func retarget_layers(vi: VisualInstance3D, mask: int) -> void:
	if vi.layers == mask:
		return
	if not vi.is_inside_tree():
		vi.layers = mask
		return
	var instance: RID = vi.get_instance()
	RenderingServer.instance_set_visible(instance, false)
	vi.layers = mask
	RenderingServer.instance_set_visible(instance, vi.is_visible_in_tree())
