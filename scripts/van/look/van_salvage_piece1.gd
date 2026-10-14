extends Node3D
## Salvage piece 1, wall pieces: the rear-right corner post, kick box and head panel (one mesh
## from `van_salvage_piece1_wall.gd`, with Shell collision) on the rear arch's own outline.

const _Wall := preload("res://scripts/van/look/van_salvage_piece1_wall.gd")
const RUST_MATERIAL := "res://scenes/van/van_rust_steel_material.tres"

var _collisions: Array[CollisionShape3D] = []


## The cable trunk stays out of the post, kick box and roof pieces (router reads this).
func keepout_aabbs() -> Array[AABB]:
	return [
		AABB(Vector3(2.80, -0.05, 4.88), Vector3(0.65, 3.78, 1.42)),
		AABB(Vector3(2.0, 3.47, 4.18), Vector3(1.1, 0.48, 2.12)),
		AABB(Vector3(0.0, 3.47, 4.88), Vector3(2.0, 0.63, 1.42)),
	]


func _ready() -> void:
	add_to_group(&"cable_keepout")
	var wall := _Wall.new()
	var profile := VanBodyProfile.from_interior(get_parent().get_parent())
	var doors := get_parent().get_node_or_null(^"RearWall") as Node3D
	var hinge := doors.get_node_or_null(^"RightHinge") as Node3D if doors != null else null
	var hinge_z := VanInteriorSize.REAR_Z if hinge == null else (doors.transform * hinge.position).z
	var m := MeshInstance3D.new()
	m.name = "WallPieces"
	m.mesh = wall.build_walls(profile, hinge_z)
	m.material_override = load(RUST_MATERIAL) as Material
	m.layers = VanLighting.LAYER_VAN_INTERIOR
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(m, true)
	for pts in wall.hulls:
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		var cs := CollisionShape3D.new()
		cs.name = "SalvagePiece1Collision"
		cs.shape = shape
		_collisions.append(cs)
		get_parent().add_child.call_deferred(cs, true)


func _exit_tree() -> void:
	for cs in _collisions:
		if not is_instance_valid(cs):
			continue
		if cs.get_parent() != null:
			cs.queue_free()
		else:
			cs.free()
	_collisions.clear()
