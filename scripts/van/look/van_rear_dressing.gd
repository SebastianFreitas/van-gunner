class_name VanRearDressing
extends Node3D
## Seeded scrap dressing on the inside of the rear doors (lock bar, welded bars, chains) and on the
## cage bulkhead's lower corners (welded plates, rebar), parented to the moving leaves so it swings
## with them.

const BAR_LENGTH := 2.2
const BAR_SIZE := 0.05
const BAR_Y_LOW := -0.9
const BAR_Y_HIGH := 0.7
const LEAF_INNER_Z := -0.12
const WELD_BEAD_SIZE := 0.06

const LOCK_BAR_LENGTH := 0.9
const LOCK_BAR_SIZE := 0.07
const LOCK_BAR_Z := -0.16
const LOCK_BRACKET_X := 0.3

const CHAIN_LINKS := 7
const CHAIN_INNER := 0.018
const CHAIN_OUTER := 0.032

const LEAF_CENTER_X := 1.19
const LEAF_FREE_EDGE_X := 2.38

const CORNER_X_MIN := 1.4
const CORNER_X_MAX := 2.2
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

	var bar_mat := MachineParts.dark(Color(0.2, 0.19, 0.17), 0.8)
	var plate_mat := MachineParts.dark(Color(0.26, 0.17, 0.11), 0.9)
	var chain_mat := MachineParts.dark(Color(0.22, 0.21, 0.19), 0.8)
	var rebar_mat := MachineParts.dark(Color(0.18, 0.13, 0.09), 0.88)

	var rng := look.rng_for(&"rear_dressing")

	_build_leaf(left_hinge, 1.0, true, rng, bar_mat, plate_mat, chain_mat)
	_build_leaf(right_hinge, -1.0, false, rng, bar_mat, plate_mat, chain_mat)

	if bulkhead != null:
		_build_bulkhead_corner(bulkhead, 1.0, rng, plate_mat, rebar_mat)
		_build_bulkhead_corner(bulkhead, -1.0, rng, plate_mat, rebar_mat)


## Spawns a mesh instance parented to `parent`, sets the shared render/shadow flags and tracks it.
func _spawn(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO,
		mesh_scale: Vector3 = Vector3.ONE) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.layers = 2
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position = pos
	inst.rotation = rot
	inst.scale = mesh_scale
	parent.add_child(inst)
	_spawned.append(inst)


func _build_leaf(hinge: Node3D, mirror: float, is_left_leaf: bool, rng: RandomNumberGenerator,
		bar_mat: Material, plate_mat: Material, chain_mat: Material) -> void:
	var y_low := BAR_Y_LOW + rng.randf_range(-0.05, 0.05)
	var y_high := BAR_Y_HIGH + rng.randf_range(-0.05, 0.05)

	_add_horizontal_bar(hinge, y_low, mirror, bar_mat)
	_add_horizontal_bar(hinge, y_high, mirror, bar_mat)

	if is_left_leaf:
		_add_lock_bar(hinge, mirror, bar_mat)

	if rng.randf() < 0.7:
		_add_chain(hinge, mirror, y_low, y_high, chain_mat)

	var patch_count := rng.randi_range(0, 2)
	for i: int in range(patch_count):
		_add_rust_patch(hinge, mirror, rng, plate_mat)


func _add_horizontal_bar(hinge: Node3D, y: float, mirror: float, mat: Material) -> void:
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(BAR_LENGTH, BAR_SIZE, BAR_SIZE)
	var center_x := mirror * LEAF_CENTER_X
	_spawn(hinge, bar_mesh, mat, Vector3(center_x, y, LEAF_INNER_Z))

	var bead_mesh := BoxMesh.new()
	bead_mesh.size = Vector3(WELD_BEAD_SIZE, WELD_BEAD_SIZE, WELD_BEAD_SIZE)
	for sign_x: float in [-1.0, 1.0]:
		_spawn(hinge, bead_mesh, mat, Vector3(center_x + sign_x * BAR_LENGTH * 0.5, y, LEAF_INNER_Z))


func _add_lock_bar(hinge: Node3D, mirror: float, mat: Material) -> void:
	var free_edge_x := mirror * LEAF_FREE_EDGE_X
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(LOCK_BAR_LENGTH, LOCK_BAR_SIZE, LOCK_BAR_SIZE)
	_spawn(hinge, bar_mesh, mat, Vector3(free_edge_x, 0.0, LOCK_BAR_Z))

	var piece_mesh := BoxMesh.new()
	piece_mesh.size = Vector3(0.05, 0.12, 0.03)
	for sign_x: float in [-1.0, 1.0]:
		var bracket_center := Vector3(free_edge_x - sign_x * LOCK_BRACKET_X, 0.0, LOCK_BAR_Z)
		for part_offset: Vector3 in [Vector3(0.0, 0.0, 0.0), Vector3(0.04, 0.0, 0.02),
				Vector3(-0.04, 0.0, 0.02)]:
			_spawn(hinge, piece_mesh, mat, bracket_center + part_offset)


func _add_chain(hinge: Node3D, mirror: float, y_low: float, y_high: float, mat: Material) -> void:
	var chain_x := mirror * (LEAF_FREE_EDGE_X - 0.3)
	var link_mesh := TorusMesh.new()
	link_mesh.inner_radius = CHAIN_INNER
	link_mesh.outer_radius = CHAIN_OUTER
	link_mesh.rings = 8
	link_mesh.ring_segments = 6
	for i: int in range(CHAIN_LINKS):
		var t := float(i) / float(CHAIN_LINKS - 1)
		var y := lerpf(y_high, y_low, t)
		var sag := sin(t * PI) * 0.08
		var rot_z := 0.0 if i % 2 == 0 else PI * 0.5
		_spawn(hinge, link_mesh, mat, Vector3(chain_x - sag, y, LEAF_INNER_Z - 0.04),
				Vector3(0.0, 0.0, rot_z), Vector3(1.0, 1.0, 0.5))


func _add_rust_patch(hinge: Node3D, mirror: float, rng: RandomNumberGenerator, mat: Material) -> void:
	var patch_mesh := BoxMesh.new()
	patch_mesh.size = Vector3(rng.randf_range(0.3, 0.5), rng.randf_range(0.3, 0.5), 0.012)
	var patch_x := mirror * rng.randf_range(0.3, 1.6)
	var patch_y := rng.randf_range(-1.4, -0.3)
	_spawn(hinge, patch_mesh, mat, Vector3(patch_x, patch_y, LEAF_INNER_Z - 0.02))


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
