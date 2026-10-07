class_name VanRoof
extends Node3D
## The van's roof rack, antennas, dish and the always-on roof spotlight; add-ons over the D24-D26 height caps are dropped, not built.

const HULL_PATH := ^"../Hull"
const INTERIOR_PATH := ^"../../Interior"
const _Junk := preload("res://scripts/van/look/van_roof_junk.gd")

const ROOF_CAP_M := 0.7 ## D24: add-on tops at most this far over the roof crown.
const RACK_CLEAR_M := 0.12 ## D26: rack height over the crown; the rear zone's ceiling.
const REAR_ZONE_M := 1.5 ## D25/D26: length of the rear roof zone, from the body's rear end.
const FIT_EPS := 0.005

const RACK_Y := 3.66 ## Top of the rack rails; junk (later) sits on it.
const RACK_HALF_X := 1.96
const RACK_LEG_TOP_Y := RACK_Y - 0.01 ## Legs end inside the rail, clear of its and the slats' planes.
const RACK_LEG_THICK := 0.035 ## Thinner than the 0.06 rail so the leg's sides sit 1.25 cm inside.
const RACK_Z_MIN := -4.3
const RACK_Z_MAX := VanInteriorSize.REAR_Z - 0.4

const SPOT_Z := -4.0 ## The spotlight's cell at the rack's front; junk must leave z < -3.4 free.
const SPOT_ENERGY := 2.2
const SPOT_RANGE := 24.0
const SPOT_ANGLE := 22.0
const SPOT_PITCH := -8.0 ## Beam pitch in degrees; shallow enough that most of the cone clears the cab roof.
const SPOT_LENS_GLOW := 1.2 ## Lens emission; a warm glow, not a white disc.

var spotlight: SpotLight3D
var rack_material: StandardMaterial3D
var crown_y := 3.57 ## Outer roof crown height, from VanBodyProfile.
var rear_zone_z := 3.2 ## Roof z past which D25/D26 apply.

var _profile: VanBodyProfile
var _group: StringName = &""


func rebuild_look(look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	spotlight = null

	_profile = VanBodyProfile.from_interior(get_node_or_null(INTERIOR_PATH))
	crown_y = _profile.outer_roof_y_at(0.0)
	rear_zone_z = VanInteriorSize.REAR_Z - REAR_ZONE_M

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
	_drop_misfits()


func begin_group(group: StringName) -> void:
	_group = group


func end_group() -> void:
	_group = &""


## True when an add-on with this top height and rear extent may stand on the roof.
func fits(top_y: float, z_max: float, antenna: bool = false) -> bool:
	if antenna:
		return z_max <= rear_zone_z + FIT_EPS
	if top_y > crown_y + ROOF_CAP_M + FIT_EPS:
		return false
	if z_max > rear_zone_z and top_y > crown_y + RACK_CLEAR_M + FIT_EPS:
		return false
	return true


## Frees every add-on that fails fits(), with the rest of its group (no orphan posts or straps).
func _drop_misfits() -> void:
	var bad_groups: Dictionary = {}
	var doomed: Array[MeshInstance3D] = []
	for child in get_children():
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var group: StringName = mi.get_meta(&"roof_group", &"")
		if group == &"rack":
			continue
		var box := mi.transform * mi.mesh.get_aabb()
		if fits(box.end.y, box.end.z, String(group).begins_with("antenna")):
			continue
		if group == &"":
			doomed.append(mi)
		else:
			bad_groups[group] = true
	for child in get_children():
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var group: StringName = mi.get_meta(&"roof_group", &"")
		if bad_groups.has(group) and not doomed.has(mi):
			doomed.append(mi)
	for mi in doomed:
		remove_child(mi)
		mi.queue_free()


func _build_rack(mat: Material) -> void:
	begin_group(&"rack")
	add_bar("RackRailL", Vector3(-RACK_HALF_X, RACK_Y, RACK_Z_MIN), Vector3(-RACK_HALF_X, RACK_Y, RACK_Z_MAX),
			0.06, mat)
	add_bar("RackRailR", Vector3(RACK_HALF_X, RACK_Y, RACK_Z_MIN), Vector3(RACK_HALF_X, RACK_Y, RACK_Z_MAX),
			0.06, mat)
	# End bars 2 cm inside the rails' top and bottom faces: closer faces flicker (D12).
	add_bar("RackEndF", Vector3(-RACK_HALF_X, RACK_Y, RACK_Z_MIN), Vector3(RACK_HALF_X, RACK_Y, RACK_Z_MIN),
			0.02, mat)
	add_bar("RackEndB", Vector3(-RACK_HALF_X, RACK_Y, RACK_Z_MAX), Vector3(RACK_HALF_X, RACK_Y, RACK_Z_MAX),
			0.02, mat)

	var span := RACK_Z_MAX - RACK_Z_MIN
	for i: int in range(5):
		var z: float = RACK_Z_MIN + span * float(i + 1) / 6.0
		# Centred on the rail's top face so no slat plane lies within 1 cm of a rail plane.
		var slat_y := RACK_Y + 0.03
		add_bar("RackSlat%d" % i, Vector3(-RACK_HALF_X, slat_y, z), Vector3(RACK_HALF_X, slat_y, z),
				0.045, mat)

	var leg_zs: Array[float] = [RACK_Z_MIN + 0.1, 0.0, RACK_Z_MAX - 0.1]
	var leg_idx := 0
	for side: float in [-1.0, 1.0]:
		var x := side * RACK_HALF_X
		for z: float in leg_zs:
			add_bar("RackLeg%d" % leg_idx, Vector3(x, _profile.outer_roof_y_at(x) - 0.04, z),
					Vector3(x, RACK_LEG_TOP_Y, z), RACK_LEG_THICK, mat)
			leg_idx += 1
	end_group()


func _build_antennas(mat: Material, rng: RandomNumberGenerator) -> void:
	var slots: Array[Vector2] = [
		Vector2(-RACK_HALF_X, rear_zone_z - 0.65),
		Vector2(RACK_HALF_X, rear_zone_z - 0.65),
		Vector2(RACK_HALF_X, 1.2),
	]
	var n := rng.randi_range(1, 3)
	for i: int in range(n):
		begin_group(StringName("antenna%d" % i))
		var slot := slots[i]
		# The base box sits 2 cm into the rail's top; the whip starts on the base's top face.
		var base_pos := Vector3(slot.x, RACK_Y + 0.05, slot.y)
		var base := base_pos + Vector3(0.0, 0.04, 0.0)
		var h := rng.randf_range(1.2, 2.2)
		var tilt_rad := deg_to_rad(rng.randf_range(5.0, 15.0))
		var dir := Vector3(0.0, cos(tilt_rad), sin(tilt_rad))

		var whip_mesh := CylinderMesh.new()
		whip_mesh.top_radius = 0.008
		whip_mesh.bottom_radius = 0.018
		whip_mesh.height = h
		whip_mesh.radial_segments = 8 ## Default 64 segments x 4 rings: sliver triangles flag against each other.
		whip_mesh.rings = 1
		var whip := _add_mesh("Antenna%d" % i, whip_mesh, mat, base + dir * (h * 0.5))
		whip.rotation = Vector3(tilt_rad, 0.0, 0.0)

		var base_mesh := BoxMesh.new()
		base_mesh.size = Vector3(0.10, 0.08, 0.08)
		_add_mesh("AntennaBase%d" % i, base_mesh, mat, base_pos)
		end_group()


func _build_dish(mat: Material, rng: RandomNumberGenerator) -> void:
	var has_dish := rng.randf() < 0.5
	var yaw := rng.randf_range(-60.0, 60.0)
	if not has_dish:
		return

	begin_group(&"dish")
	var post_top := Vector3(-RACK_HALF_X, RACK_Y + 0.45, 3.4)
	add_bar("DishPost", Vector3(-RACK_HALF_X, RACK_Y, 3.4), post_top, 0.05, mat)

	var dish_mesh := CylinderMesh.new()
	dish_mesh.top_radius = 0.45
	dish_mesh.bottom_radius = 0.08
	dish_mesh.height = 0.16
	dish_mesh.radial_segments = 14
	var dish := _add_mesh("Dish", dish_mesh, mat, post_top)
	dish.basis = Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(-40.0))
	end_group()


func _build_spotlight(hull_mat: Material, rng: RandomNumberGenerator) -> void:
	begin_group(&"spot")
	var housing_mesh := CylinderMesh.new()
	housing_mesh.top_radius = 0.17
	housing_mesh.bottom_radius = 0.17
	housing_mesh.height = 0.32
	var housing := _add_mesh("SpotHousing", housing_mesh, hull_mat, Vector3(0.0, RACK_Y + 0.28, SPOT_Z))
	housing.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	add_bar("SpotMount", Vector3(0.0, RACK_Y, SPOT_Z), Vector3(0.0, RACK_Y + 0.14, SPOT_Z), 0.05, hull_mat)

	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.30, 0.26, 0.19)
	lens_mat.roughness = 0.8
	lens_mat.emission_enabled = true
	lens_mat.emission = Color(1.0, 0.9, 0.7)
	lens_mat.emission_energy_multiplier = SPOT_LENS_GLOW

	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.14
	lens_mesh.bottom_radius = 0.14
	lens_mesh.height = 0.02
	var lens := _add_mesh("SpotLens", lens_mesh, lens_mat, Vector3(0.0, RACK_Y + 0.28, SPOT_Z - 0.17))
	lens.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.40, 0.025, 0.22)
	var visor := _add_mesh("SpotVisor", visor_mesh, hull_mat, Vector3(0.0, RACK_Y + 0.28 + 0.175, SPOT_Z - 0.26))
	visor.rotation_degrees = Vector3(-8.0, 0.0, 0.0)

	var cheek_mesh := BoxMesh.new()
	cheek_mesh.size = Vector3(0.025, 0.14, 0.20)
	_add_mesh("SpotVisorCheekL", cheek_mesh, hull_mat, Vector3(-0.19, RACK_Y + 0.28 + 0.10, SPOT_Z - 0.26))
	_add_mesh("SpotVisorCheekR", cheek_mesh, hull_mat, Vector3(0.19, RACK_Y + 0.28 + 0.10, SPOT_Z - 0.26))
	end_group()

	var yaw := rng.randf_range(-20.0, 20.0)
	var light := SpotLight3D.new()
	light.name = "RoofSpot"
	light.position = Vector3(0.0, RACK_Y + 0.28, SPOT_Z - 0.2)
	light.rotation_degrees = Vector3(SPOT_PITCH, yaw, 0.0)
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
	if _group != &"":
		mi.set_meta(&"roof_group", _group)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi
