class_name VanRoof
extends Node3D
## The van's roof rack, antennas, dish and the always-on roof spotlight; the rack's junk is filled by a helper.

const HULL_PATH := ^"../Hull"
const _Junk := preload("res://scripts/van/look/van_roof_junk.gd")

## Cargo roof vault profile, VanLook-local: roof_y(x) = 3.11 + 0.38 * (1 - (x / 2.55)^2).
const RACK_Y := 3.66 ## Top of the rack rails; junk (later) sits on it.
const RACK_HALF_X := 1.9
const RACK_Z_MIN := -4.3
const RACK_Z_MAX := 4.3

const SPOT_Z := -4.0 ## The spotlight's cell at the rack's front; junk must leave z < -3.4 free.
const SPOT_ENERGY := 2.2
const SPOT_RANGE := 24.0
const SPOT_ANGLE := 22.0

var spotlight: SpotLight3D
var rack_material: StandardMaterial3D


func rebuild_look(look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	spotlight = null

	rack_material = StandardMaterial3D.new()
	rack_material.albedo_color = Color(0.10, 0.095, 0.09)
	rack_material.roughness = 0.82
	rack_material.metallic = 0.35

	var hull := get_node_or_null(HULL_PATH) as VanHull
	var hull_mat: Material = rack_material
	if hull != null and hull.material != null:
		hull_mat = hull.material

	var rng := look.rng_for(&"roof")

	_build_rack(rack_material)
	_build_antennas(rack_material, rng)
	_build_dish(hull_mat, rng)
	_build_spotlight(hull_mat, rng)
	_Junk.new(self).build(look.rng_for(&"roof_junk"))


static func roof_y(x: float) -> float:
	return 3.11 + 0.38 * (1.0 - pow(x / 2.55, 2.0))


func _build_rack(mat: Material) -> void:
	add_bar("RackRailL", Vector3(-RACK_HALF_X, RACK_Y, RACK_Z_MIN), Vector3(-RACK_HALF_X, RACK_Y, RACK_Z_MAX),
			0.06, mat)
	add_bar("RackRailR", Vector3(RACK_HALF_X, RACK_Y, RACK_Z_MIN), Vector3(RACK_HALF_X, RACK_Y, RACK_Z_MAX),
			0.06, mat)
	add_bar("RackEndF", Vector3(-RACK_HALF_X, RACK_Y, RACK_Z_MIN), Vector3(RACK_HALF_X, RACK_Y, RACK_Z_MIN),
			0.06, mat)
	add_bar("RackEndB", Vector3(-RACK_HALF_X, RACK_Y, RACK_Z_MAX), Vector3(RACK_HALF_X, RACK_Y, RACK_Z_MAX),
			0.06, mat)

	var span := RACK_Z_MAX - RACK_Z_MIN
	for i: int in range(5):
		var z: float = RACK_Z_MIN + span * float(i + 1) / 6.0
		add_bar("RackSlat%d" % i, Vector3(-RACK_HALF_X, RACK_Y, z), Vector3(RACK_HALF_X, RACK_Y, z), 0.045, mat)

	var leg_zs: Array[float] = [RACK_Z_MIN + 0.1, 0.0, RACK_Z_MAX - 0.1]
	var leg_idx := 0
	for side: float in [-1.0, 1.0]:
		var x := side * RACK_HALF_X
		for z: float in leg_zs:
			add_bar("RackLeg%d" % leg_idx, Vector3(x, roof_y(x) - 0.04, z), Vector3(x, RACK_Y, z), 0.06, mat)
			leg_idx += 1


func _build_antennas(mat: Material, rng: RandomNumberGenerator) -> void:
	var slots: Array[Vector2] = [
		Vector2(-RACK_HALF_X, RACK_Z_MAX - 0.1),
		Vector2(RACK_HALF_X, RACK_Z_MAX - 0.1),
		Vector2(RACK_HALF_X, 1.2),
	]
	var n := rng.randi_range(1, 3)
	for i: int in range(n):
		var slot := slots[i]
		var base := Vector3(slot.x, RACK_Y, slot.y)
		var h := rng.randf_range(1.2, 2.2)
		var tilt_rad := deg_to_rad(rng.randf_range(5.0, 15.0))
		var dir := Vector3(0.0, cos(tilt_rad), sin(tilt_rad))

		var whip_mesh := CylinderMesh.new()
		whip_mesh.top_radius = 0.008
		whip_mesh.bottom_radius = 0.018
		whip_mesh.height = h
		var whip := _add_mesh("Antenna%d" % i, whip_mesh, mat, base + dir * (h * 0.5))
		whip.rotation = Vector3(tilt_rad, 0.0, 0.0)

		var base_mesh := BoxMesh.new()
		base_mesh.size = Vector3(0.08, 0.08, 0.08)
		_add_mesh("AntennaBase%d" % i, base_mesh, mat, base)


func _build_dish(mat: Material, rng: RandomNumberGenerator) -> void:
	var has_dish := rng.randf() < 0.5
	var yaw := rng.randf_range(-60.0, 60.0)
	if not has_dish:
		return

	var post_top := Vector3(-RACK_HALF_X, RACK_Y + 0.45, 3.4)
	add_bar("DishPost", Vector3(-RACK_HALF_X, RACK_Y, 3.4), post_top, 0.05, mat)

	var dish_mesh := CylinderMesh.new()
	dish_mesh.top_radius = 0.45
	dish_mesh.bottom_radius = 0.08
	dish_mesh.height = 0.16
	dish_mesh.radial_segments = 14
	var dish := _add_mesh("Dish", dish_mesh, mat, post_top)
	dish.basis = Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(-40.0))


func _build_spotlight(hull_mat: Material, rng: RandomNumberGenerator) -> void:
	var housing_mesh := CylinderMesh.new()
	housing_mesh.top_radius = 0.17
	housing_mesh.bottom_radius = 0.17
	housing_mesh.height = 0.32
	var housing := _add_mesh("SpotHousing", housing_mesh, hull_mat, Vector3(0.0, RACK_Y + 0.28, SPOT_Z))
	housing.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	add_bar("SpotMount", Vector3(0.0, RACK_Y, SPOT_Z), Vector3(0.0, RACK_Y + 0.14, SPOT_Z), 0.05, hull_mat)

	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.9, 0.85, 0.7)
	lens_mat.emission_enabled = true
	lens_mat.emission = Color(1.0, 0.9, 0.7)
	lens_mat.emission_energy_multiplier = 2.0

	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.14
	lens_mesh.bottom_radius = 0.14
	lens_mesh.height = 0.02
	var lens := _add_mesh("SpotLens", lens_mesh, lens_mat, Vector3(0.0, RACK_Y + 0.28, SPOT_Z - 0.17))
	lens.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	var yaw := rng.randf_range(-20.0, 20.0)
	var light := SpotLight3D.new()
	light.name = "RoofSpot"
	light.position = Vector3(0.0, RACK_Y + 0.28, SPOT_Z - 0.2)
	light.rotation_degrees = Vector3(-14.0, yaw, 0.0)
	light.light_energy = SPOT_ENERGY
	light.spot_range = SPOT_RANGE
	light.spot_angle = SPOT_ANGLE
	light.light_color = Color(1.0, 0.92, 0.78)
	light.shadow_enabled = false
	light.light_cull_mask = 1
	add_child(light)
	spotlight = light


func add_bar(bar_name: String, from: Vector3, to: Vector3, thickness: float, mat: Material) -> MeshInstance3D:
	var dir := to - from
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, dir.length())
	var up := Vector3.UP
	if absf(dir.normalized().y) > 0.95:
		up = Vector3.RIGHT
	var bar := _add_mesh(bar_name, mesh, mat, (from + to) * 0.5)
	bar.basis = Basis.looking_at(dir, up)
	return bar


## Public wrapper so helpers beside this script can add meshes without reaching into a private method.
func add_mesh(mesh_name: String, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	return _add_mesh(mesh_name, mesh, mat, pos)


func _add_mesh(mesh_name: String, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi
