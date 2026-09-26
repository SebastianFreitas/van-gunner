class_name VanWheels
extends Node3D
## The van's seeded road wheels, arches, mud flaps, side exhaust and chained spares; visual only, spun by the van's measured speed.

const HULL_PATH := ^"../Hull"

const ROAD_Y := -0.2
const WHEEL_X := 2.8
const TYRE_WIDTH := 0.42

const FRONT_AXLE_Z := -7.25
const FRONT_RADIUS := 0.5
const REAR_RADIUS := 0.58

const REAR_AXLES_4: Array[float] = [3.0]
const REAR_AXLES_6: Array[float] = [2.3, 3.6]

const TREAD_BLOCKS := 14

## Spinning pivots, one per wheel.
var wheel_pivots: Array[Node3D] = []
## The radius per pivot, same order as wheel_pivots.
var _radii: Array[float] = []
var _last_pos := Vector3.ZERO
var _has_last := false


func rebuild_look(look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	wheel_pivots.clear()
	_radii.clear()
	_has_last = false

	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.05, 0.05, 0.05)
	rubber.roughness = 0.92
	rubber.metallic = 0.0

	var hull := get_node_or_null(HULL_PATH) as VanHull
	var hull_mat: Material = rubber
	if hull != null and hull.material != null:
		hull_mat = hull.material

	var rng := look.rng_for(&"wheels")
	var six := rng.randf() < 0.4
	var exhaust_side := -1.0 if rng.randf() < 0.5 else 1.0
	var spare_mask := rng.randi_range(1, 3)

	var rear_axles: Array[float] = REAR_AXLES_6 if six else REAR_AXLES_4
	var last_rear_z: float = rear_axles[rear_axles.size() - 1]

	for side: float in [-1.0, 1.0]:
		var side_label := "L" if side < 0.0 else "R"
		var idx := 0
		_build_wheel("Wheel%s%d" % [side_label, idx],
				Vector3(side * WHEEL_X, ROAD_Y + FRONT_RADIUS, FRONT_AXLE_Z), FRONT_RADIUS, hull_mat, rubber)
		_build_arch("Arch%s%d" % [side_label, idx],
				Vector3(side * WHEEL_X, ROAD_Y + FRONT_RADIUS, FRONT_AXLE_Z), FRONT_RADIUS, hull_mat)
		idx += 1
		for z: float in rear_axles:
			_build_wheel("Wheel%s%d" % [side_label, idx],
					Vector3(side * WHEEL_X, ROAD_Y + REAR_RADIUS, z), REAR_RADIUS, hull_mat, rubber)
			_build_arch("Arch%s%d" % [side_label, idx],
					Vector3(side * WHEEL_X, ROAD_Y + REAR_RADIUS, z), REAR_RADIUS, hull_mat)
			idx += 1
		_build_mud_flap("MudFlap%s" % side_label,
				Vector3(side * WHEEL_X, ROAD_Y + 0.3, last_rear_z + REAR_RADIUS + 0.14), rubber)

	_build_exhaust(exhaust_side, hull_mat)
	if spare_mask & 1:
		_build_spare("SpareL", -1.0, rubber, hull_mat)
	if spare_mask & 2:
		_build_spare("SpareR", 1.0, rubber, hull_mat)


func _process(delta: float) -> void:
	if delta <= 0.0 or wheel_pivots.is_empty():
		return
	var pos := global_position
	if _has_last:
		var dist := pos.distance_to(_last_pos)
		if dist > 5.0:
			dist = 0.0
		for i: int in range(wheel_pivots.size()):
			wheel_pivots[i].rotation.x -= dist / _radii[i]
	_last_pos = pos
	_has_last = true


func _build_wheel(wheel_name: String, pos: Vector3, radius: float, hull_mat: Material, rubber: Material) -> void:
	var pivot := Node3D.new()
	pivot.name = wheel_name
	pivot.position = pos
	add_child(pivot)
	wheel_pivots.append(pivot)
	_radii.append(radius)

	var tyre_mesh := CylinderMesh.new()
	tyre_mesh.top_radius = radius * 0.86
	tyre_mesh.bottom_radius = radius * 0.86
	tyre_mesh.height = TYRE_WIDTH
	tyre_mesh.radial_segments = 16
	var tyre := _add_mesh("Tyre", tyre_mesh, rubber, Vector3.ZERO, pivot)
	tyre.rotation_degrees.z = 90.0

	var r_c := radius * 0.93
	for i: int in range(TREAD_BLOCKS):
		var a: float = i * TAU / TREAD_BLOCKS
		var block_pos := Vector3(0.0, cos(a), sin(a)) * r_c
		var block := _add_mesh("Tread%d" % i, _box(Vector3(TYRE_WIDTH, radius * 0.14, radius * 0.26)),
				rubber, block_pos, pivot)
		block.rotation.x = a

	var hub_x: float = sign(pos.x) * (TYRE_WIDTH * 0.5 + 0.01)
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = radius * 0.45
	hub_mesh.bottom_radius = radius * 0.45
	hub_mesh.height = 0.06
	var hub := _add_mesh("Hub", hub_mesh, hull_mat, Vector3(hub_x, 0.0, 0.0), pivot)
	hub.rotation_degrees.z = 90.0

	for i: int in range(5):
		var ba: float = i * TAU / 5.0
		var bolt_pos := Vector3(hub_x, cos(ba) * radius * 0.28, sin(ba) * radius * 0.28)
		_add_mesh("Bolt%d" % i, _box(Vector3(0.05, 0.05, 0.05)), hull_mat, bolt_pos, pivot)


func _build_arch(arch_name: String, pos: Vector3, radius: float, hull_mat: Material) -> void:
	var w := TYRE_WIDTH + 0.1
	_add_mesh(arch_name + "Top", _box(Vector3(w, 0.06, radius * 1.3)), hull_mat,
			Vector3(pos.x, pos.y + radius + 0.05, pos.z))
	var front := _add_mesh(arch_name + "Front", _box(Vector3(w, 0.06, radius * 0.8)), hull_mat,
			Vector3(pos.x, pos.y + radius * 0.55, pos.z + radius * 0.85))
	front.rotation_degrees.x = -40.0
	var back := _add_mesh(arch_name + "Back", _box(Vector3(w, 0.06, radius * 0.8)), hull_mat,
			Vector3(pos.x, pos.y + radius * 0.55, pos.z - radius * 0.85))
	back.rotation_degrees.x = 40.0


func _build_mud_flap(flap_name: String, pos: Vector3, rubber: Material) -> void:
	_add_mesh(flap_name, _box(Vector3(0.44, 0.5, 0.03)), rubber, pos)


func _build_exhaust(side: float, hull_mat: Material) -> void:
	var pipe_mesh := CylinderMesh.new()
	pipe_mesh.top_radius = 0.07
	pipe_mesh.bottom_radius = 0.07
	pipe_mesh.height = 7.9
	var pipe := _add_mesh("ExhaustPipe", pipe_mesh, hull_mat, Vector3(side * 2.66, ROAD_Y + 0.12, -2.45))
	pipe.rotation_degrees.x = 90.0

	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.08
	tip_mesh.bottom_radius = 0.08
	tip_mesh.height = 0.35
	var tip := _add_mesh("ExhaustTip", tip_mesh, hull_mat, Vector3(side * 2.66, ROAD_Y + 0.2, 1.62))
	tip.rotation_degrees.x = 60.0


func _build_spare(spare_name: String, side: float, rubber: Material, hull_mat: Material) -> void:
	var tyre_mesh := CylinderMesh.new()
	tyre_mesh.top_radius = 0.42
	tyre_mesh.bottom_radius = 0.42
	tyre_mesh.height = 0.26
	var tyre := _add_mesh(spare_name, tyre_mesh, rubber, Vector3(side * 2.6, 0.75, -5.5))
	tyre.rotation_degrees.z = 90.0

	var side_letter := spare_name.substr(5, 1)
	for i: int in range(2):
		var strap := _add_mesh("SpareChain%s%d" % [side_letter, i], _box(Vector3(0.04, 0.04, 0.95)),
				hull_mat, Vector3(side * 2.75, 0.75, -5.5))
		strap.rotation.x = deg_to_rad(45.0) if i == 0 else deg_to_rad(-45.0)


func _add_mesh(mesh_name: String, mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh
