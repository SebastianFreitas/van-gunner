extends RefCounted
## Rubble, partitions, a broken stair, pipes, planks and weeds inside a deep ruined body.


const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeGrimeMaterials := preload("res://scripts/travel/facades/facade_grime_materials.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")

const _GROUND_TOP := -0.06
## Surface-tool slots: concrete, brick, timber, pipe, leaf.
const _CONCRETE := 0
const _BRICK := 1
const _WOOD := 2
const _PIPE := 3
const _LEAF := 4


## The five surface tools of one building's clutter; every box goes through `put`, which fits it
## inside a limit rectangle and gates it with the keep-out.
class _Out extends RefCounted:
	var s := 1.0
	var keep: RefCounted
	var sts: Array[SurfaceTool] = []
	var counts: Array[int] = [0, 0, 0, 0, 0]

	func _init(side_sign: float, keep_out: RefCounted) -> void:
		s = side_sign
		keep = keep_out
		for i in 5:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			sts.append(st)

	## Emits a box of `size` carried by `basis` (abs x) whose lowest point sits at y_bot and whose
	## centre is clamped so its footprint stays inside lim = (x_lo, x_hi, z_lo, z_hi); shrinks the
	## box when it cannot fit. Returns (centre x, centre y, centre z, top y).
	func put(
		k: int, x: float, z: float, y_bot: float, basis: Basis, size: Vector3, lim: Vector4
	) -> Vector4:
		var b := Vector3(
			absf(basis.x.x) * size.x + absf(basis.y.x) * size.y + absf(basis.z.x) * size.z,
			absf(basis.x.y) * size.x + absf(basis.y.y) * size.y + absf(basis.z.y) * size.z,
			absf(basis.x.z) * size.x + absf(basis.y.z) * size.y + absf(basis.z.z) * size.z
		) * 0.5
		var f := minf(1.0, minf((lim.y - lim.x) / (2.0 * b.x), (lim.w - lim.z) / (2.0 * b.z)))
		var box := size * f
		b *= f
		var c := Vector3(
			clampf(x, lim.x + b.x, lim.y - b.x), y_bot + b.y, clampf(z, lim.z + b.z, lim.w - b.z)
		)
		var centre := Vector3(s * c.x, c.y, c.z)
		if basis.is_equal_approx(Basis.IDENTITY):
			if keep == null:
				_FacadeMeshKit.add_box_ungated(sts[k], centre, box)
				counts[k] += 1
			elif _FacadeMeshKit.add_box(sts[k], centre, box, keep):
				counts[k] += 1
		else:
			var m := Basis(Vector3(s, 0.0, 0.0), Vector3.UP, Vector3.BACK)
			if _FacadeMeshKit.add_box_xf(sts[k], Transform3D(m * basis * m, centre), box, keep):
				counts[k] += 1
		return Vector4(c.x, c.y, c.z, c.y + b.y)


## Adds the clutter to host. xi/xo and zi0/zi1 are the abs interior ranges; own rng, so no other
## family's draws move. Works in abs x and mirrors by side_sign when emitting.
static func build(
	host: Node3D, plan: Dictionary, side_sign: float, index: int, xi: float, xo: float,
	zi0: float, zi1: float, y0: float, keep_out: RefCounted, y_cut: float
) -> void:
	var params: Dictionary = plan[&"params"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([float(params[&"seed"]), &"ruin_clutter"])
	var gh := float(params.get(&"ground_height", _FacadePlan.GROUND_HEIGHT))
	var out := _Out.new(side_sign, keep_out)
	var lim := Vector4(xi, xo, zi0, zi1)
	var mounds: Array[Vector3] = []
	# Ground-floor families top out under the first floor line; skip them when it is under the cut.
	var ground_seen := y0 + gh > y_cut
	var cols: Array = plan.get(&"ruin_cols", []) if ground_seen else []
	for v in cols:
		var c: Vector3 = v
		var za := maxf(c.x, zi0)
		var zb := minf(c.y, zi1)
		if zb - za < 0.2:
			continue
		var collapsed := c.z < y0 + gh + 1.0
		var highs: Array[Vector3] = []
		_mound(out, rng, Vector4(xi, xo, za, zb), collapsed, mounds, highs)
		if collapsed:
			_greens(out, rng, lim, highs)
	var slabs: Array = plan.get(&"ruin_slabs", [])
	_heaps(out, rng, slabs)
	if ground_seen:
		if xo - xi >= 1.5:
			if zi1 - zi0 >= 4.0:
				_partitions(out, rng, lim, gh)
			if rng.randf() < 0.5:
				_stair(out, rng, lim)
		_pipes(out, rng, lim)
		_planks(out, rng, lim, mounds)

	var names: Array[String] = ["Clutter", "ClutterBrick", "ClutterWood", "ClutterPipe", "ClutterLeaf"]
	var mats: Array[Material] = [
		_FacadeGrimeMaterials.from_prop(_FacadeMaterials.concrete_material()),
		_FacadeGrimeMaterials.from_prop(_FacadeMaterials.prop_material(
			&"ruin_brick_chunk", Color(0.13, 0.07, 0.05), 0.92, 0.0, Color.BLACK, 0.0
		)),
		_FacadeGrimeMaterials.from_prop(_FacadeMaterials.prop_material(
			&"ruin_joist", Color(0.09, 0.07, 0.05), 0.9, 0.0, Color.BLACK, 0.0
		)),
		_FacadeGrimeMaterials.from_prop(_FacadeMaterials.rust_pipe_material()),
		_FacadeGrimeMaterials.from_prop(_leaf_material()),
	]
	for k in 5:
		if out.counts[k] > 0:
			_FacadeMeshKit.commit(host, out.sts[k], "Body%d%s" % [index, names[k]], mats[k], false)


static func _leaf_material() -> StandardMaterial3D:
	return _FacadeMaterials.prop_material(
		&"ruin_clutter_leaf", Color(0.05, 0.08, 0.03), 0.9, 0.0, Color.BLACK, 0.0
	)


## A mound of 3-20 yawed boxes stacked on each other, lower the further from its centre. `lim` is
## the column's (x_in, x_out, z_a, z_b). Records the peak in `mounds` and, for collapsed columns,
## the high boxes' tops in `highs` (abs x, top y, z) for the weeds.
static func _mound(
	out: _Out, rng: RandomNumberGenerator, lim: Vector4, collapsed: bool,
	mounds: Array[Vector3], highs: Array[Vector3]
) -> void:
	var n := rng.randi_range(12, 20) if collapsed else rng.randi_range(3, 6)
	var cx := lim.x + rng.randf_range(0.0, 0.4 if collapsed else 1.0) * (lim.y - lim.x)
	var cz := rng.randf_range(lim.z, lim.w)
	var peak := rng.randf_range(1.2, 2.2) if collapsed else rng.randf_range(0.5, 0.9)
	var radius := 0.4 * sqrt(float(n)) + 0.4
	var falls: Array[float] = []
	for i in n:
		falls.append(rng.randf())
	falls.sort()
	var placed: Array[Vector4] = []
	var best := Vector3(cx, _GROUND_TOP, cz)
	for f in falls:
		var ang := rng.randf() * TAU
		var d := (1.0 - f) * radius
		var p := Vector2(cx + cos(ang) * d, cz + sin(ang) * d)
		var size := Vector3(
			rng.randf_range(0.3, 1.2), rng.randf_range(0.3, 1.2), rng.randf_range(0.3, 1.2)
		)
		var r := 0.5 * maxf(size.x, size.z)
		var base := _GROUND_TOP - 0.1
		for q in placed:
			if Vector2(q.x, q.y).distance_to(p) < q.z + r:
				base = maxf(base, q.w - 0.2)
		var top_max := _GROUND_TOP + 0.35 + (peak - 0.35) * f
		size.y = clampf(top_max - base, 0.3, size.y)
		var k := _CONCRETE if rng.randf() < 0.7 else _BRICK
		var res := out.put(k, p.x, p.y, base, Basis(Vector3.UP, rng.randf() * TAU), size, lim)
		placed.append(Vector4(res.x, res.z, r, res.w))
		if res.w > best.y:
			best = Vector3(res.x, res.w, res.z)
		if collapsed and res.w > _GROUND_TOP + 0.6:
			highs.append(Vector3(res.x, res.w, res.z))
	mounds.append(best)


## Blade clumps on the high rubble of a collapsed column, and now and then a sapling.
static func _greens(
	out: _Out, rng: RandomNumberGenerator, lim: Vector4, highs: Array[Vector3]
) -> void:
	var sapling := rng.randf() < 0.2
	if highs.is_empty():
		return
	for i in rng.randi_range(2, 4):
		var p := highs[rng.randi_range(0, highs.size() - 1)]
		for b in rng.randi_range(3, 5):
			var tilted := Basis(Vector3.UP, rng.randf() * TAU) \
				* Basis(Vector3.BACK, rng.randf_range(0.1, 0.5))
			var size := Vector3(0.04, rng.randf_range(0.3, 0.6), 0.03)
			out.put(
				_LEAF, p.x + rng.randf_range(-0.12, 0.12), p.z + rng.randf_range(-0.12, 0.12),
				p.y - 0.03, tilted, size, lim
			)
	if not sapling:
		return
	var base_p := highs[rng.randi_range(0, highs.size() - 1)]
	var h := rng.randf_range(1.5, 2.5)
	var yaw := rng.randf() * TAU
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, rng.randf_range(0.0, 0.3))
	var at := out.put(_WOOD, base_p.x, base_p.z, base_p.y - 0.1, basis, Vector3(0.08, h, 0.08), lim)
	var tip := Vector3(at.x, at.y, at.z) + basis * Vector3(0.0, h * 0.5, 0.0)
	for l in rng.randi_range(2, 3):
		var size := Vector3(
			rng.randf_range(0.6, 0.9), rng.randf_range(0.6, 0.9), rng.randf_range(0.6, 0.9)
		)
		out.put(
			_LEAF, tip.x + rng.randf_range(-0.2, 0.2), tip.z + rng.randf_range(-0.2, 0.2),
			tip.y - size.y * 0.5 + rng.randf_range(-0.1, 0.2), Basis(Vector3.UP, rng.randf() * TAU),
			size, lim
		)


## 2-4 small boxes on 40% of the surviving floor slabs, kept inside each slab's footprint.
static func _heaps(out: _Out, rng: RandomNumberGenerator, slabs: Array) -> void:
	for v in slabs:
		var sl: Dictionary = v
		if rng.randf() >= 0.4:
			continue
		var lim := Vector4(
			float(sl[&"x_in"]), float(sl[&"x_out"]), float(sl[&"z_a"]), float(sl[&"z_b"])
		)
		for i in rng.randi_range(2, 4):
			var size := Vector3(
				rng.randf_range(0.2, 0.6), rng.randf_range(0.2, 0.6), rng.randf_range(0.2, 0.6)
			)
			var k := _CONCRETE if rng.randf() < 0.7 else _BRICK
			out.put(
				k, rng.randf_range(lim.x + 0.3, lim.y - 0.3), rng.randf_range(lim.z, lim.w),
				float(sl[&"y"]), Basis(Vector3.UP, rng.randf() * TAU), size, lim
			)


## 1-2 wall stubs along x from the back wall, each of 2-3 pieces of ragged height.
static func _partitions(out: _Out, rng: RandomNumberGenerator, lim: Vector4, gh: float) -> void:
	var n := rng.randi_range(1, 2)
	var z_lo := lim.z + 1.5
	var z_hi := lim.w - 1.5
	var z_mid := (z_lo + z_hi) * 0.5
	var h_max := maxf(minf(gh - 0.2, 3.0), 0.8)
	for i in n:
		var z := rng.randf_range(z_lo, z_hi)
		if n == 2:
			z = rng.randf_range(z_lo, z_mid - 0.2) if i == 0 else rng.randf_range(z_mid + 0.2, z_hi)
		var xe := minf(lim.x + rng.randf_range(0.6, 2.0), lim.y - 0.3)
		var len_x := lim.y - xe
		var pieces := rng.randi_range(2, 3) if len_x >= 1.2 else 1
		var w := len_x / pieces
		var k := _BRICK if rng.randf() < 0.5 else _CONCRETE
		for p in pieces:
			var h := rng.randf_range(0.8, h_max)
			out.put(
				k, xe + (p + 0.5) * w, z, _GROUND_TOP - 0.1, Basis.IDENTITY,
				Vector3(w, h + 0.1, 0.15), lim
			)


## Solid steps rising toward the back along one end wall, the top step broken short, plus 2-3
## loose steps tilted on the ground beside it.
static func _stair(out: _Out, rng: RandomNumberGenerator, lim: Vector4) -> void:
	var near := rng.randf() < 0.5
	var z := lim.z + 0.6 if near else lim.w - 0.6
	var n := mini(rng.randi_range(5, 9), int((lim.y - lim.x - 0.5) / 0.3))
	if n < 3:
		return
	var x0 := lim.x + 0.5
	for i in n:
		var tread := 0.3 if i < n - 1 else 0.3 * rng.randf_range(0.4, 0.9)
		out.put(
			_CONCRETE, x0 + 0.3 * i + tread * 0.5, z, _GROUND_TOP - 0.1, Basis.IDENTITY,
			Vector3(tread, 0.18 * (i + 1) + 0.1, 1.0), lim
		)
	var dir := 1.0 if near else -1.0
	for i in rng.randi_range(2, 3):
		var basis := Basis(Vector3.UP, rng.randf() * TAU) \
			* Basis(Vector3.RIGHT, rng.randf_range(0.2, 0.6))
		out.put(
			_CONCRETE, rng.randf_range(x0, x0 + 0.3 * n), z + dir * rng.randf_range(1.0, 2.0),
			_GROUND_TOP - 0.02, basis, Vector3(0.3, 0.18, 1.0), lim
		)


## 1-3 vertical pipes on the back wall's inner face, some bent into a run toward the street.
static func _pipes(out: _Out, rng: RandomNumberGenerator, lim: Vector4) -> void:
	var px := lim.y - 0.06
	for i in rng.randi_range(1, 3):
		var z := rng.randf_range(lim.z + 0.3, lim.w - 0.3)
		var h := rng.randf_range(1.0, 4.0)
		out.put(
			_PIPE, px, z, _GROUND_TOP - 0.1, Basis.IDENTITY, Vector3(0.08, h + 0.1, 0.08), lim
		)
		if rng.randf() < 0.5:
			var len_p := minf(rng.randf_range(0.5, 1.0), lim.y - lim.x - 0.2)
			out.put(
				_PIPE, px - len_p * 0.5 + 0.04, z, _GROUND_TOP + h - 0.08, Basis.IDENTITY,
				Vector3(len_p, 0.08, 0.08), lim
			)


## 3-6 boards leaning on the back wall or lying across a mound's peak.
static func _planks(
	out: _Out, rng: RandomNumberGenerator, lim: Vector4, mounds: Array[Vector3]
) -> void:
	for i in rng.randi_range(3, 6):
		var len_p := rng.randf_range(2.0, 3.0)
		var yaw := rng.randf() * TAU
		if not mounds.is_empty() and rng.randf() < 0.4:
			var m := mounds[rng.randi_range(0, mounds.size() - 1)]
			var flat := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
			out.put(
				_WOOD, m.x + rng.randf_range(-0.3, 0.3), m.z + rng.randf_range(-0.3, 0.3),
				m.y - 0.05, flat, Vector3(0.2, len_p, 0.03), lim
			)
			continue
		var tilt := rng.randf_range(0.5, 1.1)
		len_p = minf(len_p, (lim.y - lim.x - 0.3) / sin(tilt))
		var lean := Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)) * Basis(Vector3.BACK, -tilt)
		out.put(
			_WOOD, lim.y, rng.randf_range(lim.z, lim.w), _GROUND_TOP - 0.03, lean,
			Vector3(0.2, len_p, 0.03), lim
		)
