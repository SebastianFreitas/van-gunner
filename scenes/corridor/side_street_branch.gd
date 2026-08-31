extends Node3D

@export var mirror_x := false


func _ready() -> void:
	if mirror_x:
		for child in get_children():
			if child is MeshInstance3D:
				var mesh_node := child as MeshInstance3D
				var t := mesh_node.transform
				mesh_node.transform = Transform3D(
					Vector3(-t.basis.x.x, t.basis.x.y, t.basis.x.z),
					t.basis.y,
					Vector3(-t.basis.z.x, t.basis.z.y, t.basis.z.z),
					Vector3(-t.origin.x, t.origin.y, t.origin.z)
				)
