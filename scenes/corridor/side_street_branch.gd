extends Node3D

@export var mirror_x := false


func _ready() -> void:
	if not mirror_x:
		return
	# Mirror every child (including RoadFloor), not only MeshInstance3D —
	# otherwise the branch road stays on the wrong side of the wall.
	for child in get_children():
		var t := (child as Node3D).transform
		child.transform = Transform3D(
			Vector3(-t.basis.x.x, t.basis.x.y, t.basis.x.z),
			t.basis.y,
			Vector3(-t.basis.z.x, t.basis.z.y, t.basis.z.z),
			Vector3(-t.origin.x, t.origin.y, t.origin.z)
		)
