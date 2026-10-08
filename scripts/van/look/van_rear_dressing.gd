class_name VanRearDressing
extends Node3D
## Seeded scrap dressing on the inside of the rear doors (rust patches, strap hinges, locking rod)
## and on the cage bulkhead's lower corners (welded plates, rebar), parented to the moving leaves
## so it swings with them.

const _Hardware := preload("res://scripts/van/look/van_rear_door_hardware.gd")
const _Scrap := preload("res://scripts/van/look/van_rear_door_scrap.gd")

const _Plates := preload("res://scripts/van/look/van_rear_door_plates.gd")

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Skeleton := preload("res://scripts/van/rear_door_skeleton.gd")

const LEAF_INNER_Z := _Hardware.FACE_Z
## Rust patches: thickness, how far the front stands off the beam face, clearance round obstacles.
const RUST_T := 0.02
const RUST_PROUD := 0.003
const RUST_MARGIN := 0.03

const CORNER_X_MIN := VanInteriorSize.BULKHEAD_HALF - 0.96
const CORNER_X_MAX := VanInteriorSize.BULKHEAD_HALF - 0.16
const CORNER_Y_MAX := 1.0
const CORNER_PLATE_Z := 0.03

var _spawned: Array[Node] = []


func rebuild_look(look: VanLook) -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()

	var rear_wall: Node3D = get_tree().get_first_node_in_group(&"rear_doors") as Node3D
	if rear_wall == null:
		push_warning("VanRearDressing: no rear_doors group node found")
		return

	var left_hinge := rear_wall.get_node_or_null(^"LeftHinge") as Node3D
	var right_hinge := rear_wall.get_node_or_null(^"RightHinge") as Node3D
	if left_hinge == null or right_hinge == null:
		push_warning("VanRearDressing: rear door hinges not found")
		return

	var bulkhead := get_node_or_null(^"../Interior/Bulkhead") as Node3D

	var steel_mat := MachineParts.dark(Color(0.24, 0.23, 0.21), 0.8)
	var dark_mat := MachineParts.dark(Color(0.2, 0.19, 0.17), 0.8)
	var plate_mat := MachineParts.dark(Color(0.26, 0.17, 0.11), 0.9)
	var rebar_mat := MachineParts.dark(Color(0.18, 0.13, 0.09), 0.88)

	var rng := look.rng_for(&"rear_dressing")
	var hardware_rng := look.rng_for(&"rear_door_hardware")

	var plates_rng := look.rng_for(&"rear_door_plates")

	_build_leaf(left_hinge, 1.0, rng, plate_mat, hardware_rng, steel_mat, dark_mat, plates_rng)
	_build_leaf(right_hinge, -1.0, rng, plate_mat, hardware_rng, steel_mat, dark_mat, plates_rng)

	if bulkhead != null:
		_build_bulkhead_corner(bulkhead, 1.0, rng, plate_mat, rebar_mat)
		_build_bulkhead_corner(bulkhead, -1.0, rng, plate_mat, rebar_mat)


## Spawns a mesh instance parented to `parent`, sets the shared render/shadow flags and tracks it.
func _spawn(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO,
		mesh_scale: Vector3 = Vector3.ONE, node_name: String = "") -> void:
	var inst := MeshInstance3D.new()
	if not node_name.is_empty():
		inst.name = node_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.layers = 2
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position = pos
	inst.rotation = rot
	inst.scale = mesh_scale
	parent.add_child(inst)
	_spawned.append(inst)


func _build_leaf(hinge: Node3D, mirror: float, rng: RandomNumberGenerator,
		plate_mat: Material, hardware_rng: RandomNumberGenerator, steel_mat: Material,
		dark_mat: Material, plates_rng: RandomNumberGenerator) -> void:
	for node: Node3D in _Hardware.build(hinge, mirror, hardware_rng, steel_mat, dark_mat):
		_spawned.append(node)
	for node: Node3D in _Scrap.build(hinge, mirror, hardware_rng, steel_mat, dark_mat):
		_spawned.append(node)

	for node: Node3D in _Plates.build(hinge, mirror, plates_rng, _plate_keep_out()):
		_spawned.append(node)

	var taken := _footprints(hinge, _spawned)
	var patch_count := rng.randi_range(0, 2)
	for i: int in range(patch_count):
		_add_rust_patch(hinge, mirror, rng, plate_mat, i, taken)


## Spec 4's hardware boxes (hinge-local, left leaf) plus the frame band, each grown 3 cm, so no
## scrap plate covers them.
func _plate_keep_out() -> Array[AABB]:
	var raw: Array[AABB] = [
		AABB(Vector3(0.0, -1.6, -0.30), Vector3(0.21, 3.2, 0.24)),
		AABB(Vector3(0.05, 1.225, -0.23), Vector3(0.35, 0.11, 0.11)),
		AABB(Vector3(0.05, -1.225, -0.23), Vector3(0.35, 0.11, 0.11)),
		AABB(Vector3(0.03, 1.23, -0.30), Vector3(0.10, 0.10, 0.10)),
		AABB(Vector3(0.03, -1.22, -0.30), Vector3(0.10, 0.10, 0.10)),
		AABB(Vector3(_Hardware.ROD_X - 0.075, -1.50, -0.30), Vector3(0.15, 0.50, 0.13)),
		AABB(Vector3(_Hardware.ROD_X - 0.075, -0.60, -0.30), Vector3(0.15, 1.55, 0.13)),
		AABB(Vector3(_Hardware.ROD_X + 0.005, -1.01, -0.27), Vector3(0.155, 0.11, 0.10)),
		AABB(Vector3(_Hardware.ROD_X + 0.02, -0.94, -0.205), Vector3(0.18, 0.24, 0.11)),
		# The leaf's big access hole and the small holes and ribs above it (rear_door_skeleton.gd).
		AABB(Vector3(0.45, -1.45, -0.30), Vector3(1.57, 0.38, 0.25)),
		AABB(Vector3(1.28, -1.0, -0.30), Vector3(1.27, 0.38, 0.25)),
	]
	var grown: Array[AABB] = []
	for box: AABB in raw:
		grown.append(box.grow(0.03))
	return grown


## Thin plate lying on the bottom beam or the lower cross-member: front 3 mm proud of the beam
## face, back buried in the beam. Skipped (the draws are still spent) when it would touch the
## window bars' margin, any hardware, scrap or plate already on the leaf, or an earlier patch.
func _add_rust_patch(hinge: Node3D, mirror: float, rng: RandomNumberGenerator, mat: Material,
		index: int, taken: Array[Rect2]) -> void:
	var size := Vector2(rng.randf_range(0.25, 0.45), rng.randf_range(0.05, 0.08))
	var x_lo := 0.25 + size.x * 0.5
	var x_hi := VanInteriorSize.REAR_DOOR_HALF - 0.25 - size.x * 0.5
	var patch_x := rng.randf_range(x_lo, x_hi)
	var beam_y := -hinge.position.y + _LeafBuild.Y_MIN + _Skeleton.BEAM_W * 0.5
	if rng.randf() < 0.5:
		beam_y = -hinge.position.y + _LeafBuild.Y_MIN + _Skeleton.BEAM_W \
				+ (_Skeleton.CROSS.x + _Skeleton.CROSS.y) * 0.5
	var center := Vector2(mirror * patch_x, beam_y)
	var rect := Rect2(center - size * 0.5, size).grow(RUST_MARGIN)
	var bars_y := 1.775 - hinge.position.y
	var bars := Rect2(mirror * _LeafBuild.WINDOW_X - 1.12, bars_y - 0.9, 2.24, 1.8)
	if rect.intersects(bars.grow(RUST_MARGIN)):
		return
	for other: Rect2 in taken:
		if rect.intersects(other):
			return
	taken.append(rect)
	var patch_mesh := BoxMesh.new()
	patch_mesh.size = Vector3(size.x, size.y, RUST_T)
	_spawn(hinge, patch_mesh, mat,
			Vector3(center.x, center.y, LEAF_INNER_Z - RUST_PROUD + RUST_T * 0.5), Vector3.ZERO,
			Vector3.ONE, "RustPatch%d" % index)


## Hinge-local XY footprints of every mesh in `nodes` (and their children), each grown by the
## rust margin.
func _footprints(hinge: Node3D, nodes: Array[Node]) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node: Node in nodes:
		var node3d := node as Node3D
		if node3d != null and node3d.get_parent() == hinge:
			_collect_rects(node3d, node3d.transform, out)
	return out


func _collect_rects(node: Node3D, xform: Transform3D, out: Array[Rect2]) -> void:
	var inst := node as MeshInstance3D
	if inst != null and inst.mesh != null:
		var box := xform * inst.mesh.get_aabb()
		out.append(Rect2(box.position.x, box.position.y, box.size.x, box.size.y).grow(RUST_MARGIN))
	for child: Node in node.get_children():
		var child3d := child as Node3D
		if child3d != null:
			_collect_rects(child3d, xform * child3d.transform, out)


func _build_bulkhead_corner(bulkhead: Node3D, mirror: float, rng: RandomNumberGenerator,
		plate_mat: Material, rebar_mat: Material) -> void:
	var plate_count := rng.randi_range(1, 2)
	for i: int in range(plate_count):
		var w := rng.randf_range(0.35, 0.6)
		var h := rng.randf_range(0.3, 0.6)
		var cx := mirror * rng.randf_range(CORNER_X_MIN, CORNER_X_MAX - w * 0.5)
		var cy := rng.randf_range(0.0, minf(CORNER_Y_MAX - h * 0.5, 1.0))
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(w, h, 0.012)
		for sign_z: float in [-1.0, 1.0]:
			_spawn(bulkhead, plate_mesh, plate_mat, Vector3(cx, cy, sign_z * CORNER_PLATE_Z))

	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.012
	rod_mesh.bottom_radius = 0.012
	rod_mesh.height = 0.9
	rod_mesh.radial_segments = 6
	var rod_x := mirror * (CORNER_X_MIN + 0.4)
	for i: int in range(2):
		var rot_z := deg_to_rad(45.0 if i == 0 else -45.0)
		_spawn(bulkhead, rod_mesh, rebar_mat, Vector3(rod_x, 0.5, 0.0), Vector3(0.0, 0.0, rot_z))
