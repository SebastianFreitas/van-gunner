extends RefCounted
## Builds a sidewalk side's ground: a near-flush soil heightfield under the paving with shallow dips where the destruction map is worst, and sparse half-buried shards, stones and rubble.

const _WreckMap = preload("res://scripts/travel/road_floor_wreck_map.gd")
const _PavingMesh := preload("res://scripts/travel/road_floor_paving_mesh.gd")

const DIRT_DROP := 0.05 ## dirt surface under the walk top
const DIP_DEPTH := 0.07 ## deepest hollow in the worst spots
const STEP := 0.25
const CELL := 0.5
const MIN_KEPT := 0.35 ## a clip that leaves less of the fragment than this is undone


## Fills `soil` with the side's heightfield, and `rubble` and `tiles` with what lies on it.
func build(wreck, rng: RandomNumberGenerator, soil, rubble, tiles) -> void:
	var inner: float = wreck._inner
	var width: float = wreck._width
	var z_start: float = wreck._z_start
	var z_end: float = wreck._z_end
	var nx := maxi(2, ceili(width / STEP) + 1)
	var nz := maxi(2, ceili((z_end - z_start) / STEP) + 1)
	var points := PackedVector3Array()
	var wrecks := PackedFloat32Array()
	for iz: int in nz:
		var z := lerpf(z_start, z_end, float(iz) / float(nz - 1))
		for ix: int in nx:
			var x_abs := inner + width * float(ix) / float(nx - 1)
			var e: float = wreck.damage_at(x_abs, z)
			points.append(Vector3(wreck._sign * x_abs, height_at(wreck, x_abs, z, e), z))
			wrecks.append(_WreckMap.wreck_tint(e))
	soil.add_grid(points, nx, nz, wrecks, rng.randf())
	_scatter(wreck, rng, rubble, tiles)


## Ground height at a point on the walk, in the side's local space; `e` is the damage there.
## The dirt sits DIRT_DROP under the walk top, so surviving tiles stand slightly proud and any
## piece sunk deeper vanishes into it.
func height_at(wreck, x_abs: float, z: float, e: float) -> float:
	var y: float = wreck._top - DIRT_DROP
	var inner: float = wreck._inner
	var xfade := smoothstep(inner + 0.05, inner + 0.35, x_abs) \
			* (1.0 - smoothstep(inner + 0.8, inner + 1.1, x_abs))
	y -= _WreckMap.crater(e) * xfade * DIP_DEPTH
	var w: Vector2 = wreck.world_xz(x_abs, z)
	var lump := fposmod(sin(w.x * 12.9898 + w.y * 78.233) * 43758.5453, 1.0) - 0.5
	y += lump * 0.024 * xfade
	return y


## A convex polygon of 3-6 points: the rectangle sx by sz with one or two corners sheared off.
static func fragment_footprint(
		rng: RandomNumberGenerator, sx: float, sz: float) -> PackedVector2Array:
	var poly := PackedVector2Array([Vector2(-sx * 0.5, -sz * 0.5), Vector2(sx * 0.5, -sz * 0.5),
			Vector2(sx * 0.5, sz * 0.5), Vector2(-sx * 0.5, sz * 0.5)])
	var clips := 2 if rng.randf() < 0.4 else 1
	for i: int in clips:
		var p := Vector2(rng.randf_range(-sx * 0.25, sx * 0.25),
				rng.randf_range(-sz * 0.25, sz * 0.25))
		var a := rng.randf() * TAU
		var n := Vector2(cos(a), sin(a))
		var side_a := _clip(poly, p, n)
		var side_b := _clip(poly, p, -n)
		var kept := side_a if _area(side_a) >= _area(side_b) else side_b
		if _area(kept) >= MIN_KEPT * sx * sz and kept.size() >= 3:
			poly = kept
	return poly


static func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i: int in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return absf(sum) * 0.5


## Sutherland-Hodgman: keeps the part of a convex polygon on the `n` side of the line through `p`.
static func _clip(poly: PackedVector2Array, p: Vector2, n: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var da := (a - p).dot(n)
		var db := (b - p).dot(n)
		if da >= 0.0:
			out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			out.append(a + (b - a) * (da / (da - db)))
	return out


## Height at a point, asking the wreck for the damage there.
func _h(wreck, x_abs: float, z: float) -> float:
	var e: float = wreck.damage_at(x_abs, z)
	return height_at(wreck, x_abs, z, e)


## Sparse pieces on 0.5 m cells wherever the damage is above 0: broken tile at the gone edge,
## a few stones anywhere, rarely a rubble chunk. The core of a gone zone stays almost bare.
func _scatter(wreck, rng: RandomNumberGenerator, rubble, tiles) -> void:
	var inner: float = wreck._inner
	var width: float = wreck._width
	var z_start: float = wreck._z_start
	var x0 := inner + 0.1
	var x_span := width - 0.2
	var cols := maxi(1, ceili(x_span / CELL))
	var rows := maxi(1, ceili((wreck._z_end - z_start) / CELL))
	var cw := x_span / float(cols)
	var ch: float = (wreck._z_end - z_start) / float(rows)
	for iz: int in rows:
		for ix: int in cols:
			var r_n := rng.randi_range(0, 2)
			var r_shard := rng.randf()
			var r_slab := rng.randf()
			var jx := rng.randf_range(-0.2, 0.2)
			var jz := rng.randf_range(-0.2, 0.2)
			var cx := x0 + (float(ix) + 0.5) * cw + jx
			var cz := z_start + (float(iz) + 0.5) * ch + jz
			var e: float = wreck.damage_at(cx, cz)
			if e <= 0.0:
				continue
			var edge := 1.0 - smoothstep(0.0, 0.06, e) # 1 at the gone edge, 0 in the core
			if r_shard < 0.30 * edge:
				_shard(wreck, rng, tiles, cx, cz, e)
			if r_slab < 0.05 + 0.10 * edge:
				_stone(wreck, rng, rubble, cx, cz, e)
			elif r_n == 0 and r_slab > 1.0 - 0.10 * edge:
				_chunk(wreck, rng, rubble, cx, cz, 0)


## One rubble box, the same recipe as the paving wreck's chunks, about half buried.
func _chunk(wreck, rng: RandomNumberGenerator, rubble, cx: float, cz: float, i: int) -> void:
	var size := Vector3(rng.randf_range(0.08, 0.18), rng.randf_range(0.05, 0.10),
			rng.randf_range(0.08, 0.18))
	var x_abs := cx + rng.randf_range(-0.15, 0.15)
	var z := cz + rng.randf_range(-0.15, 0.15)
	var pos := Vector3(wreck._sign * x_abs, _h(wreck, x_abs, z) - size.y * 0.25 + i * 0.05, z)
	var t := rng.randf() * TAU
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) \
			* Basis(Vector3(cos(t), 0.0, sin(t)), deg_to_rad(rng.randf_range(0.0, 20.0)))
	rubble.add_block(size, Transform3D(basis, pos), 1.0, rng.randf(), 0.015,
			_PavingMesh.SIDE_ALL, true)


## A small broken tile fragment lying almost flush on the dirt, its top 1 cm proud.
func _shard(wreck, rng: RandomNumberGenerator, tiles, cx: float, cz: float, e: float) -> void:
	var fp := fragment_footprint(rng, rng.randf_range(0.12, 0.3), rng.randf_range(0.12, 0.3))
	var pos := Vector3(wreck._sign * cx, height_at(wreck, cx, cz, e) - 0.01, cz)
	var t := rng.randf() * TAU
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) \
			* Basis(Vector3(cos(t), 0.0, sin(t)), deg_to_rad(rng.randf_range(0.0, 8.0)))
	tiles.add_prism(fp, 0.04, Transform3D(basis, pos), 1.0, rng.randf(), true)


## A low flat rock half-sunk in the dirt, showing about 1.5 cm.
func _stone(wreck, rng: RandomNumberGenerator, rubble, cx: float, cz: float, e: float) -> void:
	var fp := fragment_footprint(rng, rng.randf_range(0.10, 0.22), rng.randf_range(0.08, 0.18))
	var pos := Vector3(wreck._sign * cx, height_at(wreck, cx, cz, e) - 0.015, cz)
	var t := rng.randf() * TAU
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) \
			* Basis(Vector3(cos(t), 0.0, sin(t)), deg_to_rad(rng.randf_range(0.0, 12.0)))
	rubble.add_prism(fp, 0.06, Transform3D(basis, pos), 1.0, rng.randf(), true)
