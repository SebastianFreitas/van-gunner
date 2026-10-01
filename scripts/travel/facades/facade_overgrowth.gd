extends RefCounted
## Weeds along building feet and gaps, ivy strands from broken tops, saplings on gutted ruins.


const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeGrimeMaterials := preload("res://scripts/travel/facades/facade_grime_materials.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadeInfill := preload("res://scripts/travel/facades/facade_infill.gd")
const _FacadeRuin := preload("res://scripts/travel/facades/facade_ruin.gd")
const _FacadeRuinDebris := preload("res://scripts/travel/facades/facade_ruin_debris.gd")

const MIN_WIDTH := 0.3
const MAX_CLUMPS := 60
const GAP_CLUMPS_PER_M := 6.0
const GAP_GROWTH_HEIGHT := 0.8
## The ivy never hangs lower than this above the ground.
const IVY_FLOOR := 0.3
const GREENS: Array[Color] = [
	Color(0.05, 0.08, 0.03), Color(0.07, 0.075, 0.035), Color(0.04, 0.06, 0.025),
]
const GREEN_KEYS: Array[StringName] = [&"growth_a", &"growth_b", &"growth_c"]
const IVY_COLOR := Color(0.045, 0.075, 0.03)
const TRUNK_COLOR := Color(0.09, 0.07, 0.05)


## Clumps along every building foot and gap, ivy from broken tops, saplings on gutted tops.
static func build(
	root: Node3D, plans: Array, side_sign: float, keep_out: RefCounted,
	rng: RandomNumberGenerator
) -> void:
	for plan: Dictionary in plans:
		if plan.get(&"mouth", false):
			return
	for i in plans.size():
		var plan: Dictionary = plans[i]
		if float(plan[&"width"]) < MIN_WIDTH:
			continue
		var params: Dictionary = plan.get(&"params", {})
		var g := float(params.get(&"overgrowth", 0.15))
		var gh := float(params.get(&"growth_height", 0.5))
		var blades := _new_st()
		var leaves := _new_st()
		var trunks := _new_st()
		var ivy := _new_st()
		var green := rng.randi_range(0, 2)
		var n := mini(roundi(g * 4.0 * float(plan[&"width"])), MAX_CLUMPS)
		var face := absf(_FacadePlan.face_x(plan, side_sign))
		var z0 := float(plan[&"z0"])
		var z1 := float(plan[&"z1"])
		for _k in n:
			_clump(blades, side_sign, face, z0, z1, gh, keep_out, rng)
		_ivy(ivy, plan, side_sign, face, keep_out, rng)
		if int(plan.get(&"ruin", _FacadeRuin.INTACT)) == _FacadeRuin.GUTTED:
			_saplings(trunks, leaves, plan, side_sign, face, keep_out, rng)
		_commit(root, blades, "Growth%d" % i, GREEN_KEYS[green], GREENS[green])
		_commit(root, leaves, "GrowthLeaf%d" % i, GREEN_KEYS[0], GREENS[0])
		_commit(root, trunks, "GrowthWood%d" % i, &"ruin_joist", TRUNK_COLOR)
		_commit(root, ivy, "GrowthIvy%d" % i, &"growth_ivy", IVY_COLOR)
	var spans := _FacadeInfill.gaps(plans)
	for gi in spans.size():
		var w := spans[gi].y - spans[gi].x
		if w < MIN_WIDTH:
			continue
		var blades := _new_st()
		var green := rng.randi_range(0, 2)
		for _k in roundi(GAP_CLUMPS_PER_M * w):
			_clump(blades, side_sign, _FacadePlan.FACE_X, spans[gi].x, spans[gi].y,
				GAP_GROWTH_HEIGHT, keep_out, rng)
		_commit(root, blades, "GrowthGap%d" % gi, GREEN_KEYS[green], GREENS[green])


static func _new_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Commits st as one shadowless mesh; an empty one is skipped.
static func _commit(
	root: Node3D, st: SurfaceTool, node_name: String, key: StringName, color: Color
) -> void:
	if not _FacadeMeshKit.has_geometry(st):
		return
	var mat := _FacadeGrimeMaterials.from_prop(
		_FacadeMaterials.prop_material(key, color, 0.9, 0.0, Color.BLACK, 0.0)
	)
	_FacadeMeshKit.commit(root, st, node_name, mat, false)


## 3-5 tilted blades round one point in front of the face, gated once as a clump.
static func _clump(
	st: SurfaceTool, sx: float, face: float, z0: float, z1: float, gh: float,
	keep_out: RefCounted, rng: RandomNumberGenerator
) -> void:
	var z := rng.randf_range(z0 + 0.1, z1 - 0.1)
	var ax := face - rng.randf_range(0.05, 0.4)
	var foot_y: float = _FacadeRuinDebris.DIRT_Y - 0.02
	var centre := Vector3(sx * ax, _FacadeRuinDebris.DIRT_Y + 0.75, z)
	var count := rng.randi_range(3, 5)
	if not keep_out.allows(_FacadeKeepOut.box_aabb(centre, Vector3(0.6, 1.5, 0.6), 0.0)):
		return
	for _b in count:
		var length := rng.randf_range(0.3, 0.7) * clampf(gh / 0.5, 1.0, 2.0)
		var base := Vector3(
			sx * (ax + rng.randf_range(-0.08, 0.08)), foot_y, z + rng.randf_range(-0.08, 0.08)
		)
		_leaning(st, base, length, 0.03, 0.04, rng.randf_range(0.1, 0.5),
			rng.randf_range(0.0, TAU))


## An ungated box of size (sx, length, sz) standing on `base`, tilted `tilt` rad toward `dir`.
static func _leaning(
	st: SurfaceTool, base: Vector3, length: float, sx: float, sz: float, tilt: float, dir: float
) -> void:
	var basis := Basis(Vector3(-sin(dir), 0.0, cos(dir)), tilt)
	var xf := Transform3D(basis, base + basis * Vector3(0.0, length * 0.5, 0.0))
	_FacadeMeshKit.add_box_xf_ungated(st, xf, Vector3(sx, length, sz))


## The top of the column over z, or the roof line when the plan has no columns.
static func _top_at(plan: Dictionary, z: float) -> float:
	var top := _FacadePlan.roofline_y(plan)
	for c: Vector3 in plan.get(&"ruin_cols", []):
		if z >= c.x and z <= c.y:
			return c.z
	return top


## Ivy hanging from broken column tops (40% each) and, on ivy-rich plans, from the roof line.
static func _ivy(
	st: SurfaceTool, plan: Dictionary, sx: float, face: float, keep_out: RefCounted,
	rng: RandomNumberGenerator
) -> void:
	var full := _FacadePlan.roofline_y(plan)
	var ruin := int(plan.get(&"ruin", _FacadeRuin.INTACT))
	if ruin >= _FacadeRuin.BROKEN:
		for c: Vector3 in plan.get(&"ruin_cols", []):
			if c.z > full - 0.5 or rng.randf() >= 0.4:
				continue
			for _s in rng.randi_range(2, 4):
				_strand(st, sx, face, c.z, rng.randf_range(c.x + 0.25, maxf(c.x + 0.25, c.y - 0.25)),
					keep_out, rng)
	var params: Dictionary = plan.get(&"params", {})
	if float(params.get(&"ivy", 0.0)) >= 0.35:
		var z0 := float(plan[&"z0"])
		var z1 := float(plan[&"z1"])
		for _s in rng.randi_range(2, 5):
			var z := rng.randf_range(z0 + 0.3, z1 - 0.3)
			# Over a collapsed column the strand hangs from that column's top, never from air.
			_strand(st, sx, face, _top_at(plan, z), z, keep_out, rng)


## One 6 cm x 0.5 m ivy strip hanging from `top`, shortened to stay 0.3 m above the ground.
static func _strand(
	st: SurfaceTool, sx: float, face: float, top: float, z: float, keep_out: RefCounted,
	rng: RandomNumberGenerator
) -> void:
	var length := minf(rng.randf_range(1.0, 3.0), top - (_FacadeRuinDebris.DIRT_Y + IVY_FLOOR))
	if length < 0.1:
		return
	_FacadeMeshKit.add_box(st, Vector3(sx * (face - 0.03), top - length * 0.5, z),
		Vector3(0.06, length, 0.5), keep_out)


## 1-3 saplings on random column tops of a gutted plan: a leaning trunk and leaf boxes.
static func _saplings(
	trunks: SurfaceTool, leaves: SurfaceTool, plan: Dictionary, sx: float, face: float,
	keep_out: RefCounted, rng: RandomNumberGenerator
) -> void:
	var cols: Array = plan.get(&"ruin_cols", [])
	if cols.is_empty():
		return
	for _s in rng.randi_range(1, 3):
		var c: Vector3 = cols[rng.randi_range(0, cols.size() - 1)]
		var base := Vector3(sx * (face + 0.17), c.z, rng.randf_range(c.x + 0.1, c.y - 0.1))
		var length := rng.randf_range(0.8, 1.6)
		var tilt := rng.randf_range(0.0, 0.35)
		var dir := rng.randf_range(0.0, TAU)
		var gate := _FacadeKeepOut.box_aabb(base + Vector3(0.0, 1.0, 0.0), Vector3(1.8, 2.4, 1.8))
		var leaf_n := rng.randi_range(2, 3)
		if not keep_out.allows(gate):
			continue
		_leaning(trunks, base, length, 0.08, 0.08, tilt, dir)
		var basis := Basis(Vector3(-sin(dir), 0.0, cos(dir)), tilt)
		var tip := base + basis * Vector3(0.0, length, 0.0)
		for _l in leaf_n:
			var s := rng.randf_range(0.5, 0.8)
			var off := Vector3(
				rng.randf_range(-0.2, 0.2), rng.randf_range(-0.1, 0.2), rng.randf_range(-0.2, 0.2)
			)
			_FacadeMeshKit.add_box_xf_ungated(leaves,
				Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), tip + off),
				Vector3(s, s * 0.6, s))
