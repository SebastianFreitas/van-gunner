extends RefCounted
## Debris for ruined street buildings: hanging slabs, rebar and sill chunks on the body, and the
## rubble heaps on the sidewalk below a collapse. Every piece is a rotated box, keep-out gated.


const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeGrimeMaterials := preload("res://scripts/travel/facades/facade_grime_materials.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeRuin := preload("res://scripts/travel/facades/facade_ruin.gd")

# facade_ruin_body aliases these (it preloads this file, so they live here, not there).
const ROOFED_DROP := 2.0
const HOLE_DEPTH := 1.8
# The paving pit floor: walk top -0.06 minus the 0.25 m pit, so rubble sits in the pits, not over them.
const RUBBLE_Y0 := -0.31
const PIT_DEPTH := 0.25

const _SLAB_P := 0.65
const _SLAB_T := 0.22


## Hanging floor slabs, rebar and sill chunks on the body; own rng so the tile's stream is intact.
static func build_body_debris(
	host: Node3D, plan: Dictionary, side_sign: float, index: int, keep_out: RefCounted
) -> void:
	var cols: Array = plan[&"ruin_cols"]
	var holes: Array = plan[&"ruin_holes"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([float(plan[&"params"][&"seed"]), &"ruin_debris"])
	var x_face := _FacadePlan.face_x(plan, side_sign)
	var y0 := _FacadePlan.BASE_Y
	var full := y0 + float(plan[&"height"])
	var sts: Array[SurfaceTool] = [_begin(), _begin(), _begin()]
	var n: Array[int] = [0, 0, 0]  # emitted slabs, bars, chunks
	for i in cols.size():
		var c: Vector3 = cols[i]
		if full - c.z >= ROOFED_DROP:
			for j: int in [i - 1, i + 1]:
				if j < 0 or j >= cols.size():
					continue
				var nb: Vector3 = cols[j]
				if nb.z - c.z <= 1.0:
					continue
				var yf := y0 + _FacadePlan.GROUND_HEIGHT + _FacadePlan.FLOOR_HEIGHT
				while yf < nb.z - 0.3:
					if yf > c.z + 0.3 and rng.randf() < _SLAB_P:
						var hinge_z := c.x if j < i else c.y
						var dz := 1.0 if j < i else -1.0
						_slab(sts, n, rng, x_face, side_sign, hinge_z, dz, yf, c.y - c.x, keep_out)
					yf += _FacadePlan.FLOOR_HEIGHT
		if full - c.z >= 0.3:
			for k in rng.randi_range(1, 4):
				var anchor := Vector3(
					x_face + side_sign * rng.randf_range(0.1, 0.3), c.z,
					rng.randf_range(c.x + 0.15, c.y - 0.15)
				)
				_bar(sts[1], n, rng, anchor, keep_out)
	for h: Vector3 in holes:
		_sill_chunks(sts[2], n, rng, x_face, side_sign, h, cols[int(h.x)] as Vector3, keep_out)
	var concrete := _FacadeGrimeMaterials.from_prop(_FacadeMaterials.concrete_material())
	if n[0] > 0:
		_FacadeMeshKit.commit(host, sts[0], "Body%dSlabs" % index, concrete, true)
	if n[1] > 0:
		var rust := _FacadeMaterials.rust_pipe_material()
		_FacadeMeshKit.commit(host, sts[1], "Body%dRebar" % index, rust, true)
	if n[2] > 0:
		_FacadeMeshKit.commit(host, sts[2], "Body%dChunks" % index, concrete, true)


## Heaps of broken concrete on the sidewalk under a collapse; tile sides only (needs the gate).
static func build_rubble(
	host: Node3D, plan: Dictionary, side_sign: float, index: int, keep_out: RefCounted
) -> void:
	if not _FacadeRuin.is_shaped(plan):
		return
	var tier := int(plan[&"ruin"])
	var cols: Array = plan.get(&"ruin_cols", [])
	var holes: Array = plan.get(&"ruin_holes", [])
	var wanted := tier >= _FacadeRuin.BROKEN or (tier == _FacadeRuin.WORN and not holes.is_empty())
	if cols.is_empty() or not wanted:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([float(plan[&"params"][&"seed"]), &"ruin_rubble"])
	var full := _FacadePlan.BASE_Y + float(plan[&"height"])
	var z_lo := float(plan[&"z0"]) + 0.3
	var z_hi := float(plan[&"z1"]) - 0.3
	var reach := absf(_FacadePlan.face_x(plan, side_sign)) + 0.2
	var st := _begin()
	var emitted := 0
	for z in _rubble_spots(rng, cols, holes, tier, full):
		var size := Vector3(
			rng.randf_range(0.25, 0.9), rng.randf_range(0.15, 0.5), rng.randf_range(0.25, 0.9)
		)
		var basis := Basis.from_euler(Vector3(
			rng.randf_range(-0.45, 0.45), rng.randf_range(0.0, TAU), rng.randf_range(-0.45, 0.45)
		))
		var lo := 7.75 + 0.5 * maxf(size.x, maxf(size.y, size.z))
		if lo > reach:
			continue
		var pos := Vector3(side_sign * rng.randf_range(lo, reach), 0.0, clampf(z, z_lo, z_hi))
		var stack := rng.randf() < 0.3
		# Boxes start in the pit and are 0.25 m taller, so their tops stay where they were.
		var base_size := size + Vector3(0.0, PIT_DEPTH, 0.0)
		pos.y = RUBBLE_Y0 + base_size.y * 0.5
		if _FacadeMeshKit.add_box_xf(st, Transform3D(basis, pos), base_size, keep_out):
			emitted += 1
		if stack:
			var top_size := size * 0.6 + Vector3(0.0, PIT_DEPTH, 0.0)
			pos.y = RUBBLE_Y0 + top_size.y * 0.5 + 0.3
			if _FacadeMeshKit.add_box_xf(st, Transform3D(basis, pos), top_size, keep_out):
				emitted += 1
	if emitted > 0:
		var concrete := _FacadeGrimeMaterials.from_prop(_FacadeMaterials.concrete_material())
		_FacadeMeshKit.commit(host, st, "Ruin%dRubble" % index, concrete, true)


## z of each rubble chunk: under the collapsed columns (BROKEN), weighted to the lowest columns
## (GUTTED), or under each hole's column (WORN).
static func _rubble_spots(
	rng: RandomNumberGenerator, cols: Array, holes: Array, tier: int, full: float
) -> Array[float]:
	var zs: Array[float] = []
	if tier == _FacadeRuin.WORN:
		for h: Vector3 in holes:
			var c: Vector3 = cols[int(h.x)]
			for k in rng.randi_range(2, 4):
				zs.append(rng.randf_range(c.x, c.y))
	elif tier == _FacadeRuin.BROKEN:
		var idx: Array[int] = []
		var deepest := 0
		for i in cols.size():
			var c: Vector3 = cols[i]
			if full - c.z >= ROOFED_DROP:
				idx.append(i)
			if c.z < (cols[deepest] as Vector3).z:
				deepest = i
		if idx.is_empty():
			idx.append(deepest)
		for k in rng.randi_range(7, 12):
			var c: Vector3 = cols[idx[rng.randi_range(0, idx.size() - 1)]]
			zs.append(rng.randf_range(c.x, c.y))
	else:
		var total := 0.0
		for c: Vector3 in cols:
			total += full - c.z + 0.5
		for k in rng.randi_range(10, 16):
			var roll := rng.randf() * total
			var pick: Vector3 = cols[cols.size() - 1]
			for c: Vector3 in cols:
				roll -= full - c.z + 0.5
				if roll < 0.0:
					pick = c
					break
			zs.append(rng.randf_range(pick.x, pick.y))
	return zs


## One floor slab hinged on the taller neighbour's edge at hinge_z, its free end hanging down
## into the collapsed column (dz is +1 when it reaches toward +z), plus two rebar from the tip.
static func _slab(
	sts: Array[SurfaceTool], n: Array[int], rng: RandomNumberGenerator, x_face: float, s: float,
	hinge_z: float, dz: float, yf: float, max_len: float, keep_out: RefCounted
) -> void:
	var size := Vector3(
		rng.randf_range(1.0, 2.2), _SLAB_T, minf(rng.randf_range(0.6, 1.6), max_len - 0.05)
	)
	# Rotating about +X by dz * angle sends a point at +dz along z down, so the tip drops.
	var angle := dz * rng.randf_range(0.05, 0.6)
	var hinge := Transform3D(Basis(Vector3.RIGHT, angle), Vector3(x_face, yf, hinge_z))
	var half := Vector3(s * (0.15 + size.x * 0.5), 0.0, dz * size.z * 0.5)
	var xf := hinge * Transform3D(Basis(), half)
	if not _FacadeMeshKit.add_box_xf(sts[0], xf, size, keep_out):
		return
	n[0] += 1
	for k in 2:
		var tip := xf * Vector3(rng.randf_range(-0.35, 0.35) * size.x, 0.0, dz * size.z * 0.5)
		_bar(sts[1], n, rng, tip, keep_out)


## A rust bar standing from `anchor`, leaning up to 0.7 rad off vertical in a random direction.
static func _bar(
	st: SurfaceTool, n: Array[int], rng: RandomNumberGenerator, anchor: Vector3,
	keep_out: RefCounted
) -> void:
	var bar_len := rng.randf_range(0.4, 1.1)
	var tilt := rng.randf_range(0.0, 0.7)
	var dir := rng.randf_range(0.0, TAU)
	var basis := Basis(Vector3.RIGHT, tilt * cos(dir)) * Basis(Vector3.BACK, tilt * sin(dir))
	var xf := Transform3D(basis, anchor + basis * Vector3(0.0, bar_len * 0.5, 0.0))
	if _FacadeMeshKit.add_box_xf(st, xf, Vector3(0.035, bar_len, 0.035), keep_out):
		n[1] += 1


## Two or three broken blocks resting on a hole's sill, inside its reveal.
static func _sill_chunks(
	st: SurfaceTool, n: Array[int], rng: RandomNumberGenerator, x_face: float, s: float,
	hole: Vector3, col: Vector3, keep_out: RefCounted
) -> void:
	for k in rng.randi_range(2, 3):
		var size := Vector3(
			rng.randf_range(0.15, 0.4), rng.randf_range(0.15, 0.4), rng.randf_range(0.15, 0.4)
		)
		var pos := Vector3(
			x_face + s * rng.randf_range(0.2, HOLE_DEPTH - 0.2), hole.y + size.y * 0.5,
			rng.randf_range(col.x + 0.2, col.y - 0.2)
		)
		var basis := Basis.from_euler(Vector3(
			rng.randf_range(-0.4, 0.4), rng.randf_range(0.0, TAU), rng.randf_range(-0.4, 0.4)
		))
		if _FacadeMeshKit.add_box_xf(st, Transform3D(basis, pos), size, keep_out):
			n[2] += 1


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st
