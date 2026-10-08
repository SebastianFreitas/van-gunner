extends StaticBody3D
## Sizes the shell's floor, side pillar and side door collider shapes from VanInteriorSize and VanOpenings, so the editor values in van_shell.tscn are previews only.


func _ready() -> void:
	var floor_node := get_node_or_null(^"FloorCollision") as CollisionShape3D
	if floor_node != null and floor_node.shape is BoxShape3D:
		var floor_shape := floor_node.shape as BoxShape3D
		floor_shape.size = Vector3(VanInteriorSize.FLOOR_WIDTH, floor_shape.size.y,
				VanInteriorSize.FLOOR_LENGTH)
		floor_node.position.z = VanInteriorSize.CENTER_Z
	for pillar in get_node(^"SidePillars").get_children():
		var cs := pillar as CollisionShape3D
		if cs != null and cs.shape is BoxShape3D:
			var s := cs.shape as BoxShape3D
			s.size = Vector3(s.size.x, VanInteriorSize.WALL_HEIGHT, s.size.z)
	var door_hit := get_node_or_null(^"SideDoors/Left/Blocker/Shape") as CollisionShape3D
	if door_hit != null and door_hit.shape is BoxShape3D:
		var d := door_hit.shape as BoxShape3D
		d.size = Vector3(d.size.x, VanOpenings.SIDE_DOOR_HEIGHT, VanOpenings.SIDE_DOOR_LEAF_LEN)
