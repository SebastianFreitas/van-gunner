extends RefCounted
## Fills VanRoof's rack with seeded junk: tyre stacks, jerry cans, crates and strapped tarp bundles.

const CELL_Z_MIN := -3.3
const CELL_Z_MAX := 4.2
const CELL_LEN := 1.25
const LANES: Array[float] = [-0.9, 0.9]

const KINDS: Array[StringName] = [&"empty", &"tyres", &"cans", &"crate", &"tarp"]

var _roof: VanRoof
var _mats: Dictionary = {}
var _count := 0


func _init(roof: VanRoof) -> void:
	_roof = roof


func build(rng: RandomNumberGenerator) -> void:
	_mat(&"rubber", Color(0.05, 0.05, 0.05))
	var can_color := Color(0.20, 0.22, 0.14) if rng.randi_range(0, 1) == 0 else Color(0.30, 0.10, 0.08)
	_mat(&"can", can_color)
	_mat(&"wood", Color(0.24, 0.18, 0.12))
	_mat(&"tarp", Color(0.16, 0.18, 0.14))

	var empty_centers: Array[Vector3] = []
	var filled := 0
	var z := CELL_Z_MIN
	while z + CELL_LEN <= CELL_Z_MAX + 0.001:
		for lane: float in LANES:
			var kind: StringName = KINDS[rng.randi_range(0, KINDS.size() - 1)]
			var center := Vector3(lane, VanRoof.RACK_Y, z + CELL_LEN * 0.5)
			match kind:
				&"tyres":
					_tyres(center, rng)
					filled += 1
				&"cans":
					_cans(center, rng)
					filled += 1
				&"crate":
					_crate(center, rng)
					filled += 1
				&"tarp":
					_tarp(center, rng)
					filled += 1
				_:
					empty_centers.append(center)
		z += CELL_LEN

	var i := 0
	while filled < 4 and i < empty_centers.size():
		_crate(empty_centers[i], rng)
		filled += 1
		i += 1


func _tyres(center: Vector3, rng: RandomNumberGenerator) -> void:
	var n := rng.randi_range(1, 3)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.42
	mesh.height = 0.26
	mesh.radial_segments = 14
	for i: int in range(n):
		var jitter := Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.05, 0.05))
		var pos := center + jitter + Vector3(0.0, 0.13 + 0.26 * i, 0.0)
		_roof.add_mesh(_next_name("JunkTyre"), mesh, _mat(&"rubber", Color()), pos)


func _cans(center: Vector3, rng: RandomNumberGenerator) -> void:
	var n := rng.randi_range(2, 4)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.45, 0.34)
	var span := (n - 1) * 0.22
	for i: int in range(n):
		var pos := center + Vector3(0.0, 0.225, -span * 0.5 + i * 0.22)
		var can := _roof.add_mesh(_next_name("JunkCan"), mesh, _mat(&"can", Color()), pos)
		can.rotation_degrees.y = rng.randf_range(-8.0, 8.0)


func _crate(center: Vector3, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.5, 0.8)
	var h := s * rng.randf_range(0.7, 1.0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(s, h, s)
	var pos := center + Vector3(0.0, h * 0.5, 0.0)
	var crate := _roof.add_mesh(_next_name("JunkCrate"), mesh, _mat(&"wood", Color()), pos)
	crate.rotation_degrees.y = rng.randf_range(-12.0, 12.0)

	var stacked := rng.randf() < 0.35
	if stacked:
		var s2 := s * 0.6
		var h2 := h * 0.6
		var mesh2 := BoxMesh.new()
		mesh2.size = Vector3(s2, h2, s2)
		var pos2 := center + Vector3(0.0, h + h2 * 0.5, 0.0)
		var crate2 := _roof.add_mesh(_next_name("JunkCrate"), mesh2, _mat(&"wood", Color()), pos2)
		crate2.rotation_degrees.y = rng.randf_range(-12.0, 12.0)


func _tarp(center: Vector3, _rng: RandomNumberGenerator) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.28
	mesh.height = 1.15
	var pos := center + Vector3(0.0, 0.28, 0.0)
	var tarp := _roof.add_mesh(_next_name("JunkTarp"), mesh, _mat(&"tarp", Color()), pos)
	tarp.rotation_degrees.x = 90.0

	for sign_z: float in [-0.3, 0.3]:
		var zs := center.z + sign_z
		_roof.add_bar(
			_next_name("JunkStrap"),
			Vector3(center.x - 0.3, VanRoof.RACK_Y + 0.56, zs),
			Vector3(center.x + 0.3, VanRoof.RACK_Y + 0.56, zs),
			0.03,
			_roof.rack_material
		)


func _mat(key: StringName, color: Color) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	_mats[key] = mat
	return mat


func _next_name(prefix: String) -> String:
	var name := prefix + str(_count)
	_count += 1
	return name
