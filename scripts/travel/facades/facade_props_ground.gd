extends RefCounted
## Ground-floor props for one building (storefront frames, awnings, roll-up lintels, loading
## docks, arcade pilasters, stoops, sidewalk furniture). Everything lives on the sidewalk strip
## or the face and passes the keep-out gate.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _BASE_Y := _FacadePlan.BASE_Y

## Centre of the sidewalk strip; furniture depth <= 1.0 keeps abs(x) >= 7.75, inside the lane
## keep-out's abs(x) < 7.6 exclusion and short of the 9 m sidewalk's outer edge.
const STRIP_X := 8.25
const MAX_FURNITURE := 3

const _AWNING_COLORS: Array[StringName] = [
	&"awning_red", &"awning_green", &"awning_blue", &"awning_tan",
]
const _FURNITURE_KINDS: Array[StringName] = [
	&"hydrant", &"news_box", &"dumpster", &"booth", &"vending", &"bollards", &"crate", &"bench",
]
const _STOOP_DISTRICTS: Array[StringName] = [&"tenement", &"civic"]


static func build(
	host: Node3D, plan: Dictionary, side_sign: float, keep_out: RefCounted,
	rng: RandomNumberGenerator, district: FacadeDistrict
) -> void:
	if bool(plan.get(&"mouth", false)):
		return
	# A rare piece that owns this plan suppresses the ordinary families it would otherwise double
	# up on, before that family's own chance roll.
	var suppress: Array = plan.get(&"suppress", [])
	_build_storefront(host, plan, side_sign, keep_out, rng, district)
	if not suppress.has(&"awnings"):
		_build_awnings(host, plan, side_sign, keep_out, rng, district)
	_build_rollups(host, plan, side_sign, keep_out, rng, district)
	_build_dock(host, plan, side_sign, keep_out, rng, district)
	_build_arcade(host, plan, side_sign, keep_out, rng, district)
	_build_stoop(host, plan, side_sign, keep_out, rng, district)
	if not suppress.has(&"furniture"):
		_build_furniture(host, plan, side_sign, keep_out, rng, district)


## A box centred `depth` out from the face, toward the road (mirrors facade_props_upper._out_x).
static func _out_x(xf: float, ss: float, depth: float) -> float:
	return xf - ss * (_FacadeMeshKit.FACE_GAP + depth * 0.5)


## u (metres along the building, from its road-view left end) to world z.
static func _z_at(plan: Dictionary, ss: float, u: float) -> float:
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	return z0 + u if ss > 0.0 else z1 - u


static func _u_c(i: int, unit_w: float) -> float:
	return (float(i) + 0.5) * unit_w


## Builds one family's [center, size] box list into one ArrayMesh; returns whether anything passed.
static func _emit(
	host: Node3D, node_name: String, material: Material, shadows: bool, boxes: Array, ko: RefCounted
) -> bool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added := false
	for b: Array in boxes:
		added = _FacadeMeshKit.add_box(st, b[0], b[1], ko) or added
	if added:
		_FacadeMeshKit.commit(host, st, node_name, material, shadows)
	return added


static func _build_storefront(
	host: Node3D, plan: Dictionary, ss: float, ko: RefCounted, rng: RandomNumberGenerator,
	dist: FacadeDistrict
) -> void:
	if int(plan[&"ground_kind"]) != _FacadePlan.GROUND_STOREFRONT:
		return
	var xf := _FacadePlan.face_x(plan, ss)
	var width: float = plan[&"width"]
	var units: int = plan[&"ground_units"]
	var unit_w := width / float(units)
	var pier_size := Vector3(0.35, 4.2, 0.5)
	var boxes := []
	for i in units:
		var u0 := float(i) * unit_w + 0.25
		var u1 := float(i + 1) * unit_w - 0.25
		boxes.append([Vector3(_out_x(xf, ss, 0.35), _BASE_Y + 2.1, _z_at(plan, ss, u0)), pier_size])
		boxes.append([Vector3(_out_x(xf, ss, 0.35), _BASE_Y + 2.1, _z_at(plan, ss, u1)), pier_size])
		var zc := _z_at(plan, ss, _u_c(i, unit_w))
		boxes.append([Vector3(_out_x(xf, ss, 0.3), _BASE_Y + 3.8, zc), Vector3(0.3, 0.8, unit_w - 1.0)])
		boxes.append([Vector3(_out_x(xf, ss, 0.2), _BASE_Y + 0.25, zc), Vector3(0.2, 0.5, unit_w - 1.0)])
	_emit(host, "Storefront", _FacadeMaterials.trim_material(plan[&"preset"]), true, boxes, ko)


## Pitched canopy nodes; the pitch sign puts the outer edge lower than the wall edge on both sides.
static func _build_awnings(
	host: Node3D, plan: Dictionary, ss: float, ko: RefCounted, rng: RandomNumberGenerator,
	dist: FacadeDistrict
) -> void:
	if int(plan[&"ground_kind"]) != _FacadePlan.GROUND_STOREFRONT:
		return
	var xf := _FacadePlan.face_x(plan, ss)
	var width: float = plan[&"width"]
	var units: int = plan[&"ground_units"]
	var unit_w := width / float(units)
	for i in units:
		if rng.randf() >= dist.awning_chance:
			continue
		var key: StringName = _AWNING_COLORS[rng.randi_range(0, _AWNING_COLORS.size() - 1)]
		var material := _FacadeMaterials.ground_material(key)
		var z := _z_at(plan, ss, _u_c(i, unit_w))
		var size := Vector3(1.0, 0.1, unit_w - 1.4)
		var center := Vector3(_out_x(xf, ss, 0.5), _BASE_Y + 3.55, z)
		var rot := Vector3(0.0, 0.0, ss * deg_to_rad(15.0))
		var mi := _FacadeMeshKit.add_box_node(host, "Awning%d" % i, size, center, rot, material, false, ko)
		if mi == null:
			continue
		var valance_size := Vector3(0.04, 0.3, unit_w - 1.4)
		var valance_center := Vector3(xf - ss * 1.0, _BASE_Y + 3.3, z)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_FacadeMeshKit.add_box_ungated(st, valance_center, valance_size)
		_FacadeMeshKit.commit(host, st, "AwningValance%d" % i, material, false)


static func _build_rollups(
	host: Node3D, plan: Dictionary, ss: float, ko: RefCounted, rng: RandomNumberGenerator,
	dist: FacadeDistrict
) -> void:
	if int(plan[&"ground_kind"]) != _FacadePlan.GROUND_ROLLUP:
		return
	var xf := _FacadePlan.face_x(plan, ss)
	var width: float = plan[&"width"]
	var units: int = plan[&"ground_units"]
	var unit_w := width / float(units)
	var rail_size := Vector3(0.12, 3.8, 0.12)
	var boxes := []
	for i in units:
		var zc := _z_at(plan, ss, _u_c(i, unit_w))
		boxes.append([Vector3(_out_x(xf, ss, 0.3), _BASE_Y + 3.85, zc), Vector3(0.3, 0.35, unit_w - 0.6)])
		var u0 := float(i) * unit_w + 0.55
		var u1 := float(i + 1) * unit_w - 0.55
		boxes.append([Vector3(_out_x(xf, ss, 0.12), _BASE_Y + 1.9, _z_at(plan, ss, u0)), rail_size])
		boxes.append([Vector3(_out_x(xf, ss, 0.12), _BASE_Y + 1.9, _z_at(plan, ss, u1)), rail_size])
	_emit(host, "RollupFrames", _FacadeMaterials.metal_grey_material(), false, boxes, ko)


static func _build_dock(
	host: Node3D, plan: Dictionary, ss: float, ko: RefCounted, rng: RandomNumberGenerator,
	dist: FacadeDistrict
) -> void:
	if int(plan[&"ground_kind"]) != _FacadePlan.GROUND_DOCK:
		return
	var xf := _FacadePlan.face_x(plan, ss)
	var width: float = plan[&"width"]
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	var boxes := [[
		Vector3(_out_x(xf, ss, 0.9), _BASE_Y + 0.6, _z_at(plan, ss, width * 0.5)),
		Vector3(0.9, 1.2, width - 0.4),
	]]
	# Three steps descending from the platform to grade at one end, chosen at random.
	var dir := 1.0 if rng.randf() < 0.5 else -1.0
	var edge_z := z1 if dir > 0.0 else z0
	for k in 3:
		var sz := edge_z + dir * (0.45 + float(k) * 0.9)
		var sy := _BASE_Y + 0.9 - 0.3 * float(k)
		boxes.append([Vector3(_out_x(xf, ss, 0.9), sy, sz), Vector3(0.9, 0.3, 0.9)])
	_emit(host, "DockPlatform", _FacadeMaterials.concrete_material(), true, boxes, ko)
	# Bumpers every 2 m along the platform's outer face (same pitch-cell math as a window column).
	var bumpers := []
	var bumper_n := maxi(0, floori((width - 0.4) / 2.0))
	for u in bumper_n:
		var bz := _z_at(plan, ss, (float(u) + 0.5) * 2.0 + 0.2)
		bumpers.append([Vector3(xf - ss * 1.05, _BASE_Y + 0.9, bz), Vector3(0.3, 0.3, 0.3)])
	_emit(host, "DockBumpers", _FacadeMaterials.iron_material(), false, bumpers, ko)


static func _build_arcade(
	host: Node3D, plan: Dictionary, ss: float, ko: RefCounted, rng: RandomNumberGenerator,
	dist: FacadeDistrict
) -> void:
	if int(plan[&"ground_kind"]) != _FacadePlan.GROUND_ARCADE:
		return
	var xf := _FacadePlan.face_x(plan, ss)
	var width: float = plan[&"width"]
	var units: int = plan[&"ground_units"]
	var unit_w := width / float(units)
	var boxes := []
	for e in range(units + 1):
		var z := _z_at(plan, ss, float(e) * unit_w)
		boxes.append([Vector3(_out_x(xf, ss, 0.4), _BASE_Y + 2.2, z), Vector3(0.4, 4.4, 0.6)])
		boxes.append([Vector3(_out_x(xf, ss, 0.5), _BASE_Y + 4.45, z), Vector3(0.5, 0.25, 0.8)])
	_emit(host, "Pilasters", _FacadeMaterials.trim_material(plan[&"preset"]), true, boxes, ko)


static func _build_stoop(
	host: Node3D, plan: Dictionary, ss: float, ko: RefCounted, rng: RandomNumberGenerator,
	dist: FacadeDistrict
) -> void:
	var kind: int = plan[&"ground_kind"]
	var ok_kind := kind == _FacadePlan.GROUND_BLANK or kind == _FacadePlan.GROUND_STOREFRONT
	if not ok_kind or not _STOOP_DISTRICTS.has(dist.id) or rng.randf() >= 0.4:
		return
	var xf := _FacadePlan.face_x(plan, ss)
	var width: float = plan[&"width"]
	var z := _z_at(plan, ss, 1.2 + rng.randf() * (width - 2.4))
	var sizes := [Vector3(0.9, 0.18, 1.4), Vector3(0.6, 0.18, 1.4), Vector3(0.3, 0.18, 1.4)]
	var boxes := []
	for k in 3:
		var size: Vector3 = sizes[k]
		boxes.append([Vector3(_out_x(xf, ss, size.x), _BASE_Y + 0.09 + 0.18 * float(k), z), size])
	_emit(host, "Stoop", _FacadeMaterials.concrete_material(), true, boxes, ko)
	# Outer corner of the bottom (widest) step.
	var post := Vector3(_out_x(xf, ss, 0.9) - ss * 0.45, _BASE_Y + 0.45, z - 0.7)
	_emit(host, "StoopRail", _FacadeMaterials.iron_material(), false, [[post, Vector3(0.05, 0.9, 0.05)]], ko)


static func _build_furniture(
	host: Node3D, plan: Dictionary, ss: float, ko: RefCounted, rng: RandomNumberGenerator,
	dist: FacadeDistrict
) -> void:
	if rng.randf() >= dist.furniture_chance:
		return
	var width: float = plan[&"width"]
	var units: int = plan[&"ground_units"]
	var unit_w := width / float(units)
	var doorway_us: Array[float] = []
	if int(plan[&"ground_kind"]) == _FacadePlan.GROUND_STOREFRONT:
		for i in units:
			doorway_us.append(_u_c(i, unit_w))
	var count := rng.randi_range(1, MAX_FURNITURE)
	for i in count:
		var kind: StringName = _FURNITURE_KINDS[rng.randi_range(0, _FURNITURE_KINDS.size() - 1)]
		var u := 0.8 + rng.randf() * (width - 1.6)
		if doorway_us.any(func(du: float) -> bool: return absf(u - du) < 1.2):
			continue
		_place_furniture(host, kind, i, ss * STRIP_X, _z_at(plan, ss, u), ko)


## Simple sidewalk furniture: [node prefix, size], one gated box in the piece's own material.
const _SIMPLE_FURNITURE := {
	&"hydrant": ["Hydrant", Vector3(0.25, 0.7, 0.25)],
	&"news_box": ["NewsBox", Vector3(0.45, 1.1, 0.4)],
	&"dumpster": ["Dumpster", Vector3(1.0, 1.3, 1.8)],
	&"bench": ["Bench", Vector3(0.5, 0.45, 1.8)],
}
## Glow-front furniture: [node prefix, size, body material key, glow material key].
const _GLOW_FURNITURE := {
	&"booth": ["Booth", Vector3(0.9, 2.2, 0.9), &"booth", &"booth_glow"],
	&"vending": ["Vending", Vector3(0.7, 1.8, 0.9), &"vending", &"vending_glow"],
}


static func _place_furniture(
	host: Node3D, kind: StringName, index: int, x: float, z: float, ko: RefCounted
) -> void:
	if _SIMPLE_FURNITURE.has(kind):
		var prefix_and_size: Array = _SIMPLE_FURNITURE[kind]
		var s: Vector3 = prefix_and_size[1]
		var center := Vector3(x, s.y * 0.5 - 0.06, z)
		_emit(
			host, "%s%d" % [prefix_and_size[0], index], _FacadeMaterials.ground_material(kind), false,
			[[center, s]], ko
		)
	elif _GLOW_FURNITURE.has(kind):
		var spec: Array = _GLOW_FURNITURE[kind]
		_build_glow_prop(host, index, x, z, ko, spec[0], spec[1], spec[2], spec[3])
	elif kind == &"bollards":
		_build_bollards(host, index, x, z, ko)
	elif kind == &"crate":
		_build_crate_stack(host, index, x, z, ko)


## A body box, then (only if it cleared the gate) an ungated emissive panel on its road face.
static func _build_glow_prop(
	host: Node3D, index: int, x: float, z: float, ko: RefCounted, prefix: String, size: Vector3,
	body_key: StringName, glow_key: StringName
) -> void:
	var y := size.y * 0.5 - 0.06
	if not _emit(
		host, "%s%d" % [prefix, index], _FacadeMaterials.ground_material(body_key), false,
		[[Vector3(x, y, z), size]], ko
	):
		return
	var ss := signf(x)
	var glow_size := Vector3(0.02, 0.5, 0.5)
	var glow_center := Vector3(x - ss * (size.x * 0.5 + glow_size.x * 0.5), y, z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_FacadeMeshKit.add_box_ungated(st, glow_center, glow_size)
	_FacadeMeshKit.commit(
		host, st, "%sGlow%d" % [prefix, index], _FacadeMaterials.ground_material(glow_key), false
	)


static func _build_bollards(host: Node3D, index: int, x: float, z: float, ko: RefCounted) -> void:
	var size := Vector3(0.2, 0.9, 0.2)
	var y := size.y * 0.5 - 0.06
	var boxes := []
	for dz: float in [-1.2, 0.0, 1.2]:
		boxes.append([Vector3(x, y, z + dz), size])
	_emit(host, "Bollards%d" % index, _FacadeMaterials.ground_material(&"bollard"), false, boxes, ko)


## Two crates side by side, plus (only if the first cleared the gate) a third stacked on top of it.
static func _build_crate_stack(host: Node3D, index: int, x: float, z: float, ko: RefCounted) -> void:
	var size := Vector3(0.6, 0.6, 0.6)
	var y := size.y * 0.5 - 0.06
	var base_a := Vector3(x, y, z - 0.3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var passed_a := _FacadeMeshKit.add_box(st, base_a, size, ko)
	var passed_b := _FacadeMeshKit.add_box(st, Vector3(x, y, z + 0.3), size, ko)
	if passed_a:
		_FacadeMeshKit.add_box_ungated(st, base_a + Vector3(0.0, size.y, 0.0), size)
	if passed_a or passed_b:
		_FacadeMeshKit.commit(host, st, "Crate%d" % index, _FacadeMaterials.ground_material(&"crate"), false)
