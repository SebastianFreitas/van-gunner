class_name VanCab
extends Node3D

## The van's cab-over cab on the body profile: one closed body with a raked windshield, grille,
## headlights, doors, mirrors and two real headlights, rebuilt from the look seed.

const HULL_PATH := ^"../Hull"
const VanCabParts := preload("res://scripts/van/look/van_cab_parts.gd")
const _FrontKit := preload("res://scripts/van/look/van_front_kit.gd")
const VanCabBody := preload("res://scripts/van/look/van_cab_body.gd")
const VanCabFace := preload("res://scripts/van/look/van_cab_face.gd")

const NOSE_Z := -8.2
const BASE_Y := -0.25

const HEADLIGHT_ENERGY := 3.0
const HEADLIGHT_RANGE := 26.0
const HEADLIGHT_ANGLE := 30.0

const INTERIOR_PATH := ^"../../Interior"
## Segments per body-profile section outline; matches the shell and floor cross-sections.
const SECTION_STEPS := 12
const WS_BOT_Y := 1.95
const WS_TOP_Y := 2.9
const WS_HALF_W := 1.6
## Depth of the windshield pocket behind the raked face, along +z.
const WS_REVEAL := 0.07
## Where the front breaks from the vertical lower face to the raked windshield face.
const BELT_Y := 1.75
## Windshield face lean back from vertical.
const RAKE_DEG := 20.0
## Bevel on the front's vertical corners and roof edge (the bottom edge is not bevelled).
const CHAMFER := 0.22
## Back end of the solid body: 2.5 cm ahead of the hull's front-face step (z -4.70), clear of
## it, the cab door leaf (-4.67) and the wall reveals (-4.655) (audit FLICKER). The cab is a
## front off another vehicle bolted on, so a visible seam at the join is on purpose; its back
## cap is what the cab door window shows from the cargo room.
const BODY_BACK_Z := -4.725
const GRILLE_HALF_W := 1.2
const GRILLE_BOT_Y := 0.35
const GRILLE_TOP_Y := 1.25
const HEADLIGHT_X := 1.75
const HEADLIGHT_Y := 0.95
const BUMPER_Y := 0.05
const BUMPER_H := 0.45
const BUMPER_D := 0.32
const BUMPER_W := 5.1
const BUMPER_FRONT_Z := NOSE_Z - 0.34
const BUMPER_TOP_Y := BUMPER_Y + BUMPER_H * 0.5
const DOOR_BACK_Z := -4.95
const DOOR_FRONT_Z := -6.45
const DOOR_BOT_Y := 0.15
const DOOR_TOP_Y := 2.9
const DOOR_WIN_BOT_Y := 1.85
const DOOR_WIN_TOP_Y := 2.7

## The two road lights; step 5b's kit may cage them.
var headlights: Array[SpotLight3D] = []

## Where the front kit (step 5b) bolts its ram and bumper.
var nose_z := NOSE_Z

## The body cross-section the cab extrudes; set each rebuild.
var profile: VanBodyProfile


func rebuild_look(look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	headlights.clear()

	var hull := get_node_or_null(HULL_PATH) as VanHull
	if hull == null or hull.material == null:
		push_warning("VanCab: no Hull material at %s" % HULL_PATH)
		return

	profile = VanBodyProfile.from_interior(get_node_or_null(INTERIOR_PATH))
	var rng := look.rng_for(&"cab")
	var parts := VanCabParts.new(self)
	VanCabBody.new(self).build(hull.material)
	VanCabFace.new(self).build(hull.material, rng)
	parts.build_mirrors(hull.material, rng)
	_build_headlight_spots()
	_FrontKit.new(self).build(hull.material, look.rng_for(&"front_kit"))


## The raked face plane's z at height y (the front kit and mirrors call it).
static func front_z_at(y: float) -> float:
	return NOSE_Z + maxf(0.0, y - BELT_Y) * tan(deg_to_rad(RAKE_DEG))


func _build_headlight_spots() -> void:
	for s: float in [-1.0, 1.0]:
		var suffix := "L" if s < 0.0 else "R"

		var light := SpotLight3D.new()
		light.name = "Headlight%s" % suffix
		light.position = Vector3(s * HEADLIGHT_X, HEADLIGHT_Y, NOSE_Z - 0.2)
		light.rotation_degrees = Vector3(-7.0, 0.0, 0.0)
		light.light_energy = HEADLIGHT_ENERGY
		light.spot_range = HEADLIGHT_RANGE
		light.spot_angle = HEADLIGHT_ANGLE
		light.spot_attenuation = 1.0
		light.spot_angle_attenuation = 0.9
		light.light_color = Color(1.0, 0.92, 0.78)
		light.shadow_enabled = false
		light.light_cull_mask = 1
		add_child(light)
		headlights.append(light)


func _add_mesh(mesh_name: String, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func glass_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.025, 0.03, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.35
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _dark_material(albedo: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.metallic = 0.0
	return mat


static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		centre: Vector3, inward: bool = false) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var to_face := ((a + b + c + d) * 0.25 - centre).normalized()
	var facing := normal.dot(to_face)
	if inward:
		facing = -facing
	if facing < 0.0:
		st.add_vertex(a)
		st.add_vertex(d)
		st.add_vertex(c)
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(d)


static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centre: Vector3,
		inward: bool = false) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var to_face := ((a + b + c) / 3.0 - centre).normalized()
	var facing := normal.dot(to_face)
	if inward:
		facing = -facing
	if facing < 0.0:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)
