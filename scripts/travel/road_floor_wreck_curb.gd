extends RefCounted
## Builds the wrecked paving's granite curb: 1 m blocks, knocked, missing or toppled in gone stretches.

const _PavingMesh := preload("res://scripts/travel/road_floor_paving_mesh.gd")
const _WreckMap = preload("res://scripts/travel/road_floor_wreck_map.gd")

const CURB_LEN := 1.0
const JOINT := 0.03
const CHAMFER := 0.025
const MIN_PIECE := 0.12
const MISSING: Array[float] = [0.0, 0.02, 0.06, 0.12]
const KNOCKED: Array[float] = [0.02, 0.06, 0.12, 0.18]


## `wreck` is the RoadFloorWreck (untyped: it preloads this file); its fields are read as is.
func build(wreck, side_idx: int, side_sign: float, rng: RandomNumberGenerator, curb: Object,
		rubble: Object) -> void:
	var curb_depth: float = wreck._curb_depth
	if curb_depth <= 0.0:
		return
	var z_start: float = wreck._z_start
	var z_end: float = wreck._z_end
	var top: float = wreck._top
	var inner: float = wreck._inner
	var gutter_top_y: float = wreck._gutter_top_y
	var y_bot := gutter_top_y - 0.04
	var height := top + 0.02 - y_bot
	var cx := inner - curb_depth * 0.5
	var k := floori(z_start / CURB_LEN)
	while k * CURB_LEN < z_end:
		var z0 := maxf(k * CURB_LEN, z_start)
		var z1 := minf((k + 1) * CURB_LEN, z_end)
		k += 1
		if z1 - z0 < MIN_PIECE:
			continue
		var z := (z0 + z1) * 0.5
		var r_miss := rng.randf()
		var r_knock := rng.randf()
		var tone := rng.randf()
		var tier: int = wreck.tier_at(side_idx, z)
		var e: float = wreck.damage_at(inner - 0.06, z)
		var tint := maxf(tier / 3.0, _WreckMap.wreck_tint(e))
		var t := _WreckMap.band_t(e)
		var missing := false
		var knocked := false
		var scale := 0.35 + 0.3 * t
		match _WreckMap.zone(e):
			_WreckMap.Zone.GONE:
				if r_knock < 0.12:
					_add_chunks(wreck, side_sign, rng, rubble, z0, z1)
				continue
			_WreckMap.Zone.FRAGMENT:
				missing = r_miss < 0.2 + 0.4 * t
				knocked = not missing
				scale = 0.5 + 0.5 * t
			_WreckMap.Zone.ROUGH:
				missing = r_miss < MISSING[tier]
				knocked = r_knock < KNOCKED[tier] + 0.1 + 0.2 * t
			_:
				missing = r_miss < MISSING[tier] * 0.5
				knocked = r_knock < KNOCKED[tier] * 0.5
		if missing:
			_add_chunks(wreck, side_sign, rng, rubble, z0, z1)
			continue
		var size := Vector3(curb_depth, height, z1 - z0 - JOINT)
		var centre := Vector3(side_sign * cx, y_bot + height * 0.5, z)
		if not knocked:
			var sides := _PavingMesh.SIDE_NEG_X | _PavingMesh.SIDE_POS_X \
					| _PavingMesh.SIDE_NEG_Z | _PavingMesh.SIDE_POS_Z
			curb.add_block(size, Transform3D(Basis(), centre), tint, tone, CHAMFER, sides, false)
			continue
		var yaw_deg := rng.randf_range(4.0, 12.0) * scale
		var shift := rng.randf_range(0.03, 0.10) * scale
		var drop := rng.randf_range(0.03, 0.10) * scale
		if rng.randf() < 0.5:
			yaw_deg = -yaw_deg
		# The top leans toward the road, pivoting on the bottom edge.
		var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg)) \
				* Basis(Vector3.BACK, side_sign * deg_to_rad(rng.randf_range(4.0, 14.0) * scale))
		var pivot := Vector3(centre.x, y_bot, z)
		var origin := pivot + basis * Vector3(0.0, height * 0.5, 0.0)
		origin += Vector3(-side_sign * shift, -drop, 0.0)
		# Keep the walk-side top corner from rising above the walk.
		var corner := origin + basis * Vector3(side_sign * curb_depth * 0.5, height * 0.5, 0.0)
		if corner.y > top + 0.06:
			origin.y -= corner.y - (top + 0.06)
		curb.add_block(size, Transform3D(basis, origin), tint, tone, CHAMFER,
				_PavingMesh.SIDE_ALL, true)


## Kerb returns across the shallower run's end wherever two touching runs' kerb lines differ;
## returns how many.
func build_returns(wreck, side_idx: int, side_sign: float, runs: Array, curb: Object) -> int:
	var curb_depth: float = wreck._curb_depth
	if curb_depth <= 0.0:
		return 0
	var top: float = wreck._top
	var gutter_top_y: float = wreck._gutter_top_y
	var road: Node = wreck.road
	var y_bot := gutter_top_y - 0.04
	var height := top + 0.02 - y_bot
	var count := 0
	for b in range(runs.size() - 1):
		var a: Vector4 = runs[b]
		var n: Vector4 = runs[b + 1]
		if absf(a.y - n.x) >= 0.01 or absf(a.z - n.z) <= 0.01:
			continue
		count += 1
		var x0 := minf(a.z, n.z)
		var x1 := maxf(a.z, n.z)
		var z_lo := n.x
		var lean := -1.0
		if a.z < n.z:
			z_lo = a.y - curb_depth
			lean = 1.0
		var zc := z_lo + curb_depth * 0.5
		var rng := RandomNumberGenerator.new()
		rng.seed = road._seed_value(397 + side_idx * 1000 + b * 7919)
		var cuts: Array[float] = []
		var p := x0
		while p < x1:
			cuts.append(p)
			p += CURB_LEN
		cuts.append(x1)
		if cuts.size() > 2 and cuts[cuts.size() - 1] - cuts[cuts.size() - 2] < MIN_PIECE:
			cuts.remove_at(cuts.size() - 2)
		for c in range(cuts.size() - 1):
			var p0: float = cuts[c]
			var p1: float = cuts[c + 1]
			var xm := (p0 + p1) * 0.5
			var r_miss := rng.randf()
			var r_knock := rng.randf()
			var tone := rng.randf()
			var tier: int = wreck.tier_at(side_idx, zc)
			var e: float = wreck.damage_at(xm, zc)
			var tint := maxf(tier / 3.0, _WreckMap.wreck_tint(e))
			var t := _WreckMap.band_t(e)
			var missing := false
			var knocked := false
			var scale := 0.35 + 0.3 * t
			match _WreckMap.zone(e):
				_WreckMap.Zone.GONE:
					continue
				_WreckMap.Zone.FRAGMENT:
					missing = r_miss < 0.2 + 0.4 * t
					knocked = not missing
					scale = 0.5 + 0.5 * t
				_WreckMap.Zone.ROUGH:
					missing = r_miss < MISSING[tier]
					knocked = r_knock < KNOCKED[tier] + 0.1 + 0.2 * t
				_:
					missing = r_miss < MISSING[tier] * 0.5
					knocked = r_knock < KNOCKED[tier] * 0.5
			if missing:
				continue
			var size := Vector3(p1 - p0 - JOINT, height, curb_depth)
			var centre := Vector3(side_sign * xm, y_bot + height * 0.5, zc)
			if not knocked:
				var sides := _PavingMesh.SIDE_NEG_X | _PavingMesh.SIDE_POS_X \
						| _PavingMesh.SIDE_NEG_Z | _PavingMesh.SIDE_POS_Z
				curb.add_block(size, Transform3D(Basis(), centre), tint, tone, CHAMFER, sides,
						false)
				continue
			var yaw_deg := rng.randf_range(4.0, 12.0) * scale
			var shift := rng.randf_range(0.03, 0.10) * scale
			var drop := rng.randf_range(0.03, 0.10) * scale
			if rng.randf() < 0.5:
				yaw_deg = -yaw_deg
			var lean_deg := rng.randf_range(4.0, 14.0) * scale
			# The top leans toward the deeper run, pivoting on the bottom edge.
			var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg)) \
					* Basis(Vector3.RIGHT, lean * deg_to_rad(lean_deg))
			var pivot := Vector3(centre.x, y_bot, zc)
			var origin := pivot + basis * Vector3(0.0, height * 0.5, 0.0)
			origin += Vector3(0.0, -drop, lean * shift)
			var high := -INF
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var corner := origin + basis * Vector3(sx * size.x * 0.5, height * 0.5,
							sz * curb_depth * 0.5)
					high = maxf(high, corner.y)
			if high > top + 0.06:
				origin.y -= high - (top + 0.06)
			curb.add_block(size, Transform3D(basis, origin), tint, tone, CHAMFER,
					_PavingMesh.SIDE_ALL, true)
	return count


## One small lump of granite in the gutter where a block is gone.
func _add_chunks(wreck, side_sign: float, rng: RandomNumberGenerator, rubble: Object, z0: float,
		z1: float) -> void:
	var curb_depth: float = wreck._curb_depth
	var inner: float = wreck._inner
	var gutter_top_y: float = wreck._gutter_top_y
	rng.randf()  # keeps the stream aligned
	var size := Vector3(rng.randf_range(0.08, 0.18), rng.randf_range(0.05, 0.10),
			rng.randf_range(0.08, 0.18))
	var pos := Vector3(side_sign * (inner - curb_depth - rng.randf_range(0.05, 0.30)),
			gutter_top_y + size.y * 0.3, rng.randf_range(z0, z1))
	var t := rng.randf() * TAU
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) \
			* Basis(Vector3(cos(t), 0.0, sin(t)), deg_to_rad(rng.randf_range(0.0, 20.0)))
	rubble.add_block(size, Transform3D(basis, pos), 1.0, rng.randf(), 0.015,
			_PavingMesh.SIDE_ALL, true)
