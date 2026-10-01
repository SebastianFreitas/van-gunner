extends RefCounted
## Builds the carriageway's broken edge beside a wrecked sidewalk: asphalt cells cut where the destruction map reaches past the curb, a dirt floor continuous with the walk's soil, and the gutter strip.

const _WreckMap = preload("res://scripts/travel/road_floor_wreck_map.gd")
const _PavingMesh := preload("res://scripts/travel/road_floor_paving_mesh.gd")

const ROAD_BAND := 2.4 ## m from the curb face inward, gutter included
const STEP := 0.25
const FALLOFF := 0.30 ## damage lost per m from the curb
const RAMP := 0.6 ## the edge next to gone walk always breaks, so the dirt connects
const ROAD_DIRT_DROP := 0.06
const JITTER := 0.08
const POTHOLE_CHANCE := 0.12
const CHUNK_CHANCE := 0.06

var _holes := {} ## Vector2i world metre cell -> Vector3(centre x, centre z, radius), radius 0 = none


## Fills `asphalt` and `gutter` with the band's cells and `soil` with its dirt floor.
func build(wreck, rng: RandomNumberGenerator, soil, asphalt, gutter) -> void:
	var inner: float = wreck._inner
	var road: RoadFloor = wreck.road
	var sgn: float = wreck._sign
	var top_y: float = road.road_surface_y
	var gutter_y: float = wreck._gutter_top_y
	var gw: float = road.gutter_width
	var z0: float = wreck._z_start
	var z1: float = wreck._z_end
	var half: float = road.span_z * 0.5
	var walk_dirt_y: float = wreck._top - 0.05
	var dirt_y := top_y - ROAD_DIRT_DROP
	var x_out := inner - ROAD_BAND
	var x_mid := inner - gw
	if z1 <= z0:
		_outside(asphalt, sgn, x_out, x_mid, top_y, -half, half)
		road.set_meta("road_gone_%d" % wreck._side_idx, 0)
		return
	var n_a := ceili((ROAD_BAND - gw) / STEP)
	var ncols := n_a + 1
	var nz := maxi(1, ceili((z1 - z0) / STEP))
	var xe := PackedFloat32Array()
	for ix: int in n_a + 1:
		xe.append(lerpf(x_out, x_mid, float(ix) / float(n_a)))
	xe.append(inner)
	var ze := PackedFloat32Array()
	for iz: int in nz + 1:
		ze.append(lerpf(z0, z1, float(iz) / float(nz)))
	var gone := PackedByteArray()
	gone.resize(ncols * nz)
	var tops := PackedFloat32Array()
	tops.resize(ncols * nz)
	var tints := PackedFloat32Array()
	tints.resize(ncols * nz)
	var gone_count := 0
	for iz: int in nz:
		var zc := (ze[iz] + ze[iz + 1]) * 0.5
		var e_w: float = wreck.damage_at(inner + 0.6, zc)
		for ix: int in ncols:
			var xc := (xe[ix] + xe[ix + 1]) * 0.5
			var d := inner - xc
			var w: Vector2 = wreck.world_xz(xc, zc)
			var h := _hash(w)
			var e_r := e_w - d * FALLOFF - JITTER * h
			var i := iz * ncols + ix
			var is_gone := e_r > 0.0 or (e_w > 0.0 and d < RAMP)
			if not is_gone and d <= ROAD_BAND - 0.5:
				is_gone = _in_pothole(w, wreck.tier_at(wreck._side_idx, zc))
			gone[i] = 1 if is_gone else 0
			gone_count += 1 if is_gone else 0
			var y := gutter_y if ix == n_a else top_y
			if not is_gone and e_r > -JITTER:
				y -= 0.008 + 0.012 * h
			tops[i] = y
			tints[i] = clampf((e_r + 0.25) / 0.25, 0.0, 1.0)
	for iz: int in nz:
		for ix: int in ncols:
			var i := iz * ncols + ix
			if gone[i] == 1:
				continue
			var builder: _PavingMesh = gutter if ix == n_a else asphalt
			var xa := xe[ix]
			var xb := xe[ix + 1]
			builder.add_quad(_p(sgn, xa, tops[i], ze[iz]), _p(sgn, xb, tops[i], ze[iz]),
					_p(sgn, xb, tops[i], ze[iz + 1]), _p(sgn, xa, tops[i], ze[iz + 1]),
					Vector3.UP, tints[i], 0.5, 1.0)
			if ix > 0 and gone[i - 1] == 1:
				_lip(builder, sgn, xa, xa, ze[iz], ze[iz + 1], tops[i], dirt_y, Vector3(-sgn, 0, 0))
			if ix < n_a and gone[i + 1] == 1:
				_lip(builder, sgn, xb, xb, ze[iz], ze[iz + 1], tops[i], dirt_y, Vector3(sgn, 0, 0))
			if iz > 0 and gone[i - ncols] == 1:
				_lip(builder, sgn, xa, xb, ze[iz], ze[iz], tops[i], dirt_y, Vector3(0, 0, -1))
			if iz < nz - 1 and gone[i + ncols] == 1:
				_lip(builder, sgn, xa, xb, ze[iz + 1], ze[iz + 1], tops[i], dirt_y,
						Vector3(0, 0, 1))
	_steps(asphalt, gone, tints, sgn, xe, ze, n_a, nz, top_y, gutter_y)
	if z0 > -half:
		_outside(asphalt, sgn, x_out, x_mid, top_y, -half, z0)
	if z1 < half:
		_outside(asphalt, sgn, x_out, x_mid, top_y, z1, half)
	_dirt(wreck, rng, soil, gone, tops, xe, ze, n_a, nz, dirt_y, walk_dirt_y)
	_chunks(rng, asphalt, gone, sgn, xe, ze, ncols, nz, dirt_y)
	road.set_meta("road_gone_%d" % wreck._side_idx, gone_count)


## The 4 cm step between intact asphalt and an intact gutter cell, facing the curb.
func _steps(asphalt, gone: PackedByteArray, tints: PackedFloat32Array, sgn: float,
		xe: PackedFloat32Array, ze: PackedFloat32Array, n_a: int, nz: int, top_y: float,
		gutter_y: float) -> void:
	var ncols := n_a + 1
	var x := xe[n_a]
	for iz: int in nz:
		var ia := iz * ncols + n_a - 1
		var ig := iz * ncols + n_a
		if gone[ia] == 1 or gone[ig] == 1:
			continue
		asphalt.add_quad(_p(sgn, x, top_y, ze[iz]), _p(sgn, x, top_y, ze[iz + 1]),
				_p(sgn, x, gutter_y, ze[iz + 1]), _p(sgn, x, gutter_y, ze[iz]),
				Vector3(sgn, 0, 0), tints[ia], 0.5, 0.0)


## One intact asphalt quad over the full band width, for the stretch past the walk.
func _outside(asphalt, sgn: float, xa: float, xb: float, y: float, za: float,
		zb: float) -> void:
	asphalt.add_quad(_p(sgn, xa, y, za), _p(sgn, xb, y, za), _p(sgn, xb, y, zb),
			_p(sgn, xa, y, zb), Vector3.UP, 0.0, 0.5, 1.0)


## A vertical face from a cell's top down to just under the dirt.
func _lip(builder, sgn: float, xa: float, xb: float, za: float, zb: float, top: float,
		dirt_y: float, normal: Vector3) -> void:
	var y := dirt_y - 0.01
	builder.add_quad(_p(sgn, xa, top, za), _p(sgn, xb, top, zb), _p(sgn, xb, y, zb),
			_p(sgn, xa, y, za), normal, 1.0, 0.5, 0.0)


func _dirt(wreck, rng: RandomNumberGenerator, soil, gone: PackedByteArray,
		tops: PackedFloat32Array, xe: PackedFloat32Array, ze: PackedFloat32Array, n_a: int,
		nz: int, dirt_y: float, walk_dirt_y: float) -> void:
	var inner: float = wreck._inner
	var ncols := n_a + 1
	var nx := n_a + 2
	var points := PackedVector3Array()
	var wrecks := PackedFloat32Array()
	for iz: int in nz + 1:
		var e_w: float = wreck.damage_at(inner + 0.6, ze[iz])
		for ix: int in nx:
			var d := inner - xe[ix]
			var y := dirt_y + (walk_dirt_y - dirt_y) * (1.0 - smoothstep(0.0, RAMP, d)) \
					* smoothstep(0.0, 0.15, e_w)
			for cz: int in [iz - 1, iz]:
				for cx: int in [ix - 1, ix]:
					if cz < 0 or cz >= nz or cx < 0 or cx >= ncols:
						continue
					if gone[cz * ncols + cx] == 0:
						y = minf(y, tops[cz * ncols + cx] - 0.02)
			points.append(Vector3(wreck._sign * xe[ix], y, ze[iz]))
			wrecks.append(_WreckMap.wreck_tint(e_w))
	soil.add_grid(points, nx, nz + 1, wrecks, rng.randf())


## Broken asphalt chunks lying in gone cells that border intact ones.
func _chunks(rng: RandomNumberGenerator, asphalt, gone: PackedByteArray, sgn: float,
		xe: PackedFloat32Array, ze: PackedFloat32Array, ncols: int, nz: int,
		dirt_y: float) -> void:
	for iz: int in nz:
		for ix: int in ncols:
			var i := iz * ncols + ix
			if gone[i] == 0:
				continue
			var edge := (ix > 0 and gone[i - 1] == 0) or (ix < ncols - 1 and gone[i + 1] == 0) \
					or (iz > 0 and gone[i - ncols] == 0) \
					or (iz < nz - 1 and gone[i + ncols] == 0)
			if not edge or rng.randf() >= CHUNK_CHANCE:
				continue
			var r := rng.randf_range(0.06, 0.10)
			var fp := PackedVector2Array()
			var a0 := rng.randf() * TAU
			for k: int in 5:
				var a := a0 + TAU * float(k) / 5.0
				fp.append(Vector2(cos(a), sin(a)) * r)
			var pos := Vector3(sgn * (xe[ix] + xe[ix + 1]) * 0.5, dirt_y + 0.01,
					(ze[iz] + ze[iz + 1]) * 0.5)
			asphalt.add_prism(fp, 0.04, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos),
					1.0, rng.randf(), true)


## True when the world point lies inside a pothole; holes are hashed per 1 m world cell so they
## stay continuous across tiles.
func _in_pothole(w: Vector2, tier: int) -> bool:
	var base := Vector2i(floori(w.x), floori(w.y))
	for ox: int in [-1, 0, 1]:
		for oy: int in [-1, 0, 1]:
			var cell := base + Vector2i(ox, oy)
			if not _holes.has(cell):
				_holes[cell] = _make_hole(cell, tier)
			var hole: Vector3 = _holes[cell]
			if hole.z > 0.0 and w.distance_to(Vector2(hole.x, hole.y)) <= hole.z:
				return true
	return false


func _make_hole(cell: Vector2i, tier: int) -> Vector3:
	var c := Vector2(cell)
	var centre := c + Vector2(_hash(c + Vector2(3.1, 7.7)), _hash(c + Vector2(11.3, 2.9)))
	var e: float = _WreckMap.damage(centre, tier)
	if _hash(c) >= POTHOLE_CHANCE * smoothstep(-0.25, 0.1, e):
		return Vector3(0.0, 0.0, 0.0)
	return Vector3(centre.x, centre.y, 0.25 + 0.2 * _hash(c + Vector2(5.9, 13.1)))


## World hash in 0..1, the same sin-hash as the ground's lump.
func _hash(w: Vector2) -> float:
	return fposmod(sin(w.x * 12.9898 + w.y * 78.233) * 43758.5453, 1.0)


func _p(sgn: float, x_abs: float, y: float, z: float) -> Vector3:
	return Vector3(sgn * x_abs, y, z)
