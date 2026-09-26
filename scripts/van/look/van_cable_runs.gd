class_name VanCableRuns
extends Node3D
## Seeded interior cable trunks along the ceiling corners with drops to the generator, relay rack,
## PC rig, welding bench and ceiling lamps, zip ties and taped splices, plus wall junk (battery
## bank, jerry cans, gas bottles).

const LIGHTING_PATH := ^"../../Lighting"
const TRUNK_HALF_X := 2.2
const TRUNK_Y := 2.95
const TRUNK_Z_MIN := -4.4
const TRUNK_Z_MAX := 4.4
const TRUNK_STEPS := 7


func rebuild_look(look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var rubber := MachineParts.dark(Color(0.05, 0.05, 0.05), 0.95)
	var tie := MachineParts.dark(Color(0.3, 0.3, 0.28), 0.85)
	var tape := MachineParts.dark(Color(0.33, 0.32, 0.29), 0.9)
	var bottle := MachineParts.dark(Color(0.32, 0.11, 0.07), 0.8)
	var steel := MachineParts.dark(Color(0.18, 0.18, 0.17), 0.8)

	var rng := look.rng_for(&"cables")

	var trunk_l := _build_trunk(-1.0, rng, rubber, tie, tape)
	var trunk_r := _build_trunk(1.0, rng, rubber, tie, tape)

	_build_drops(rubber)
	_build_lamp_drops(trunk_l, trunk_r, rubber)
	_build_junk(rng, steel, bottle, trunk_l)


func _build_trunk(sx: float, rng: RandomNumberGenerator, rubber_mat: Material, tie_mat: Material,
		tape_mat: Material) -> PackedVector3Array:
	var side := "L" if sx < 0.0 else "R"
	var x := sx * TRUNK_HALF_X
	var pts := PackedVector3Array()
	for i: int in range(TRUNK_STEPS):
		var t := float(i) / float(TRUNK_STEPS - 1)
		var z := lerpf(TRUNK_Z_MIN, TRUNK_Z_MAX, t)
		var sag := 0.0
		if i > 0 and i < TRUNK_STEPS - 1:
			sag = rng.randf_range(0.03, 0.08)
		pts.append(Vector3(x, TRUNK_Y - sag, z))

	MachineParts.cable_bundle(self, pts, rubber_mat, 0.018, 4)
	_add_ties(rng, pts, tie_mat, side)
	_add_splices(rng, pts, tape_mat, side)
	return pts


func _add_ties(rng: RandomNumberGenerator, pts: PackedVector3Array, mat: Material, side: String) -> void:
	var z := TRUNK_Z_MIN + rng.randf_range(0.7, 1.0)
	var idx := 0
	while z < TRUNK_Z_MAX:
		var y := _trunk_y(pts, z)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.05, 0.05, 0.03)
		_add_mesh("Tie%s%d" % [side, idx], mesh, mat, Vector3(pts[0].x, y, z))
		idx += 1
		z += rng.randf_range(0.7, 1.0)


func _add_splices(rng: RandomNumberGenerator, pts: PackedVector3Array, mat: Material, side: String) -> void:
	var n := rng.randi_range(1, 2)
	for i: int in range(n):
		var z := rng.randf_range(TRUNK_Z_MIN + 0.4, TRUNK_Z_MAX - 0.4)
		var y := _trunk_y(pts, z)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.07, 0.07, 0.14)
		_add_mesh("Splice%s%d" % [side, i], mesh, mat, Vector3(pts[0].x, y, z))


## Linear height along a trunk's sampled points, used to anchor drops and lamp taps.
func _trunk_y(pts: PackedVector3Array, z: float) -> float:
	for i: int in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		if z >= a.z and z <= b.z:
			var t := (z - a.z) / (b.z - a.z)
			return lerpf(a.y, b.y, t)
	return pts[pts.size() - 1].y


func _build_drops(rubber_mat: Material) -> void:
	MachineParts.cable_bundle(self, PackedVector3Array([
		Vector3(2.2, 2.95, 1.2), Vector3(2.35, 2.2, 1.22), Vector3(2.38, 1.0, 1.22), Vector3(2.25, 0.7, 1.21),
	]), rubber_mat, 0.015, 3)

	MachineParts.cable_bundle(self, PackedVector3Array([
		Vector3(2.2, 2.95, 0.08), Vector3(2.36, 2.0, 0.08), Vector3(2.36, 1.0, 0.08),
	]), rubber_mat, 0.015, 3)

	MachineParts.cable_bundle(self, PackedVector3Array([
		Vector3(-2.2, 2.95, -4.2), Vector3(-2.0, 2.9, -4.2), Vector3(-1.85, 2.85, -4.2),
	]), rubber_mat, 0.015, 3)

	MachineParts.cable_bundle(self, PackedVector3Array([
		Vector3(-2.2, 2.95, -4.4), Vector3(-2.05, 2.92, -4.5), Vector3(-1.96, 2.86, -4.55),
	]), rubber_mat, 0.015, 3)


## Taps each interior ceiling lamp (Lighting sibling under VanRig) within x +/-1.5 from the nearer trunk.
func _build_lamp_drops(trunk_l: PackedVector3Array, trunk_r: PackedVector3Array, rubber_mat: Material) -> void:
	var lighting := get_node_or_null(LIGHTING_PATH)
	if lighting == null:
		return
	for child in lighting.get_children():
		if not (child is OmniLight3D):
			continue
		var light := child as OmniLight3D
		if light.light_cull_mask != VanLighting.LAYER_VAN_INTERIOR:
			continue
		if absf(light.position.x) > 1.5:
			continue
		var sx := 1.0 if light.position.x >= 0.0 else -1.0
		var trunk_pts := trunk_r if sx > 0.0 else trunk_l
		var anchor := Vector3(sx * TRUNK_HALF_X, _trunk_y(trunk_pts, light.position.z), light.position.z)
		var target := Vector3(light.position.x, minf(light.position.y + 0.05, 2.95), light.position.z)
		MachineParts.cable_bundle(self, PackedVector3Array([anchor, target]), rubber_mat, 0.015, 3)


func _build_junk(rng: RandomNumberGenerator, steel_mat: Material, bottle_mat: Material,
		trunk_l: PackedVector3Array) -> void:
	var batt_zs: Array[float] = [-1.3, -1.05, -0.8]
	var tops := PackedVector3Array()
	for z: float in batt_zs:
		var batt := MachineParts.battery(self, Vector3(-2.25, 0.0, z), steel_mat, steel_mat)
		batt.rotation.y = rng.randf_range(-0.3, 0.3)
		tops.append(Vector3(-2.25, 0.25, z))
	tops.append(Vector3(-TRUNK_HALF_X, _trunk_y(trunk_l, -1.05), -1.05))
	MachineParts.cable_bundle(self, tops, steel_mat, 0.015, 2)

	for z: float in [2.0, 2.35]:
		var can := MachineParts.jerry_can(self, Vector3(-2.25, 0.0, z), steel_mat)
		can.rotation.y = rng.randf_range(-0.3, 0.3)

	var idx := 0
	for z: float in [-1.95, -1.7]:
		var bottle_mesh := CylinderMesh.new()
		bottle_mesh.top_radius = 0.11
		bottle_mesh.bottom_radius = 0.11
		bottle_mesh.height = 0.62
		bottle_mesh.radial_segments = 8
		var body := _add_mesh("GasBottle%d" % idx, bottle_mesh, bottle_mat, Vector3(2.3, 0.31, z))
		body.rotation.y = rng.randf_range(-0.3, 0.3)

		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = 0.03
		cap_mesh.bottom_radius = 0.03
		cap_mesh.height = 0.06
		_add_mesh("GasBottleCap%d" % idx, cap_mesh, steel_mat, Vector3(2.3, 0.65, z))

		var strap_mesh := BoxMesh.new()
		strap_mesh.size = Vector3(0.3, 0.03, 0.03)
		_add_mesh("GasBottleStrap%d" % idx, strap_mesh, steel_mat, Vector3(2.3, 0.5, z))
		idx += 1


func _add_mesh(mesh_name: String, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.layers = 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
