extends RefCounted
## Builds RoadFloor's wrecked paving: tiles and setts graded by the destruction map and set into a raised dirt floor, each side as merged meshes.

const RoadFloorMaterials = preload("res://scripts/travel/road_floor_materials.gd")
const _PavingMesh := preload("res://scripts/travel/road_floor_paving_mesh.gd")
const _WreckCurb := preload("res://scripts/travel/road_floor_wreck_curb.gd")
const _WreckMap = preload("res://scripts/travel/road_floor_wreck_map.gd")
const _WreckGround = preload("res://scripts/travel/road_floor_wreck_ground.gd")

const PIT_DEPTH := 0.12 ## collision bed top sits this far under the walk top, under the dirt
const JOINT := 0.03
const CHAMFER := 0.012
const TILE_PITCH := 0.5
const SETT_PITCH := 0.25
const MIN_PIECE := 0.12
const MISSING: Array[float] = [0.0, 0.03, 0.08, 0.14]
const MISSING_SETT: Array[float] = [0.0, 0.04, 0.10, 0.18]
const TILT: Array[float] = [0.02, 0.08, 0.16, 0.25]
const TILT_DEG: Array[float] = [3.0, 6.0, 10.0, 14.0]
const SINK: Array[float] = [0.03, 0.08, 0.12, 0.16]

enum Piece { FLAT, MISSING_PIECE, TILTED, SUNK, FRAGMENT }

var road: RoadFloor
var _xform := Transform3D.IDENTITY
var _side_idx := 0
var _soil := _PavingMesh.new()
var _tiles := _PavingMesh.new()
var _setts := _PavingMesh.new()
var _rubble := _PavingMesh.new()
var _curb := _PavingMesh.new()
var _sign := 1.0
var _z_start := 0.0
var _z_end := 0.0
var _top := 0.0
var _bed_y := 0.0
var _inner := 0.0
var _width := 0.0
var _gutter_top_y := 0.0
var _curb_depth := 0.0
var _tile_cols := 1
var _tile_w := TILE_PITCH
var _sett_rows := 0
var _sett_w := SETT_PITCH
## Dressing z values (drains, hydrants...) on this side: their pieces stay flat.
var _kept: Array[float] = []


func _init(owner_road: RoadFloor) -> void:
	road = owner_road


func build(side_idx: int, walk_len: float, walk_cz: float, walk_inner_x: float,
		sidewalk_top: float, gutter_top_y: float, curb_depth: float) -> void:
	_width = road.sidewalk_width
	if walk_len <= 0.0 or _width <= 0.0:
		return
	_sign = -1.0 if side_idx == 0 else 1.0
	_z_start = walk_cz - walk_len * 0.5
	_z_end = walk_cz + walk_len * 0.5
	_top = sidewalk_top
	_bed_y = sidewalk_top - PIT_DEPTH
	_inner = absf(walk_inner_x)
	_gutter_top_y = gutter_top_y
	_curb_depth = curb_depth
	_kept.clear()
	if road.dressing_z.size() == 2:
		for dz: float in road.dressing_z[side_idx]:
			_kept.append(dz)
	_side_idx = side_idx
	_xform = road.global_transform if road.is_inside_tree() else Transform3D.IDENTITY
	_layout()
	_build_tiles(side_idx)
	_build_setts(side_idx)
	var rng_ground := RandomNumberGenerator.new()
	rng_ground.seed = road._seed_value(497 + side_idx * 1000)
	_WreckGround.new().build(self, rng_ground, _soil, _rubble, _tiles)
	var rng_curb := RandomNumberGenerator.new()
	rng_curb.seed = road._seed_value(297 + side_idx * 1000)
	_WreckCurb.new().build(self, side_idx, _sign, rng_curb, _curb, _rubble)
	var tag := "Left" if side_idx == 0 else "Right"
	_soil.commit(road, "WalkSoil" + tag,
			RoadFloorMaterials.paving_mat(RoadFloorMaterials.PAVING_SOIL))
	_rubble.commit(road, "WalkRubble" + tag,
			RoadFloorMaterials.paving_mat(RoadFloorMaterials.PAVING_RUBBLE))
	_curb.commit(road, "WalkCurb" + tag,
			RoadFloorMaterials.paving_mat(RoadFloorMaterials.PAVING_CURB))
	_tiles.commit(road, "WalkTiles" + tag,
			RoadFloorMaterials.paving_mat(RoadFloorMaterials.PAVING_TILE))
	_setts.commit(road, "WalkSetts" + tag,
			RoadFloorMaterials.paving_mat(RoadFloorMaterials.PAVING_SETT))
	var samples := 0
	var count := 0
	var z := _z_start + 0.125
	while z < _z_end:
		samples += 1
		if damage_at(_inner + _width * 0.5, z) > 0.0:
			count += 1
		z += 0.25
	road.set_meta(StringName("walk_gone_%d" % side_idx), Vector2(count * 0.25, samples * 0.25))


## Tile-local (x_abs outward from the road axis, z along the walk) to world XZ.
func world_xz(x_abs: float, z: float) -> Vector2:
	var p := _xform * Vector3(_sign * x_abs, _top, z)
	return Vector2(p.x, p.z)


## The destruction map's wreck value at a walk point (positive: obliterated).
func damage_at(x_abs: float, z: float) -> float:
	return _WreckMap.damage(world_xz(x_abs, z), tier_at(_side_idx, z))


func tier_at(side_idx: int, z: float) -> int:
	if road.wreck_spans.size() == 2:
		for v: Vector3 in road.wreck_spans[side_idx]:
			if v.x <= z and z < v.y:
				return clampi(int(v.z), 0, 3)
	return clampi(road.default_wreck_tier, 0, 3)


## Splits the walk width into tile columns by the curb and sett strips toward the buildings.
func _layout() -> void:
	_tile_cols = 2 if _width >= 1.5 else 1
	_tile_w = TILE_PITCH
	var strip := _width - _tile_cols * TILE_PITCH
	_sett_rows = maxi(1, roundi(strip / SETT_PITCH))
	_sett_w = strip / _sett_rows
	if strip < 0.15:
		_sett_rows = 0
		_tile_w = _width / _tile_cols


func _is_kept(z0: float, z1: float) -> bool:
	for dz in _kept:
		if z1 >= dz - 0.4 and z0 <= dz + 0.4:
			return true
	return false


## Draw order is fixed (miss, move, kind) so the other outcomes never shift the stream.
func _piece_state(rng: RandomNumberGenerator, tier: int, e: float, kept: bool,
		is_tile: bool) -> int:
	var r_miss := rng.randf()
	var r_move := rng.randf()
	var r_kind := rng.randf()
	if kept:
		return Piece.FLAT
	var zone := _WreckMap.zone(e)
	if zone == _WreckMap.Zone.GONE:
		return Piece.MISSING_PIECE
	var t := _WreckMap.band_t(e)
	var miss: Array[float] = MISSING if is_tile else MISSING_SETT
	if zone == _WreckMap.Zone.FRAGMENT:
		if r_miss < 0.15 + 0.55 * t + (0.0 if is_tile else 0.1):
			return Piece.MISSING_PIECE
		if r_kind < 0.4 + 0.5 * t:
			return Piece.FRAGMENT
		return Piece.TILTED if r_move < 0.5 else Piece.SUNK
	if zone == _WreckMap.Zone.ROUGH:
		if r_miss < miss[tier] * 0.5 + 0.06 * t:
			return Piece.MISSING_PIECE
		if r_move < 0.15 + 0.35 * t:
			return Piece.TILTED
		if r_move < 0.4 + 0.6 * t:
			return Piece.SUNK
		return Piece.FLAT
	if r_miss < miss[tier] * 0.25:
		return Piece.MISSING_PIECE
	if r_move < TILT[tier] * 0.5:
		return Piece.TILTED
	if r_move < (TILT[tier] + SINK[tier]) * 0.5:
		return Piece.SUNK
	return Piece.FLAT


func _build_tiles(side_idx: int) -> void:
	_build_columns(side_idx, 97, true)


func _build_setts(side_idx: int) -> void:
	_build_columns(side_idx, 197, false)


## Tiles and setts share one pass: columns across the walk, cells along z on a grid anchored
## at z = 0 (setts shift every other strip by half a sett for the running bond).
func _build_columns(side_idx: int, salt: int, is_tile: bool) -> void:
	var cols := _tile_cols if is_tile else _sett_rows
	if cols <= 0:
		return
	var pitch := TILE_PITCH if is_tile else SETT_PITCH
	var w := _tile_w if is_tile else _sett_w
	var x0 := _inner if is_tile else _inner + _tile_cols * _tile_w
	var rng := RandomNumberGenerator.new()
	rng.seed = road._seed_value(salt + side_idx * 1000)
	var cells: Array = []
	var states: Array = []
	var tones: Array = []
	var damages: Array = []
	for c in cols:
		var shift := 0.0 if is_tile else (c % 2) * SETT_PITCH * 0.5
		var col_cells := _cells(pitch, shift)
		var col_states: Array[int] = []
		var col_tones: Array[float] = []
		var col_damages: Array[float] = []
		for cell in col_cells:
			var zm := (cell.x + cell.y) * 0.5
			var e := damage_at(x0 + (c + 0.5) * w, zm)
			col_damages.append(e)
			col_states.append(_piece_state(rng, tier_at(side_idx, zm), e,
					_is_kept(cell.x, cell.y), is_tile))
			col_tones.append(rng.randf())
		cells.append(col_cells)
		states.append(col_states)
		tones.append(col_tones)
		damages.append(col_damages)
	var out := _tiles if is_tile else _setts
	for c in cols:
		var cx := x0 + (c + 0.5) * w
		var col_cells: Array[Vector2] = cells[c]
		var col_states: Array[int] = states[c]
		for r in col_cells.size():
			var cell := col_cells[r]
			var zm := (cell.x + cell.y) * 0.5
			var tier := tier_at(side_idx, zm)
			var e: float = damages[c][r]
			var tone: float = tones[c][r]
			var state := col_states[r]
			var sides := 0
			if state == Piece.FLAT:
				sides = _flat_sides(states, c, r, cols, is_tile)
			_emit(rng, out, state, Vector2(cx, zm), Vector2(w, cell.y - cell.x), tier,
					e, tone, sides)


## Cells of one grid line along z: [k * pitch + shift, (k + 1) * pitch + shift] clipped to the walk.
func _cells(pitch: float, shift: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var k := floori((_z_start - shift) / pitch)
	while k * pitch + shift < _z_end:
		var z0 := maxf(k * pitch + shift, _z_start)
		var z1 := minf((k + 1) * pitch + shift, _z_end)
		if z1 - z0 >= MIN_PIECE:
			out.append(Vector2(z0, z1))
		k += 1
	return out


## A flat piece shows a side only where its neighbour is not flat or there is none.
func _flat_sides(states: Array, c: int, r: int, cols: int, is_tile: bool) -> int:
	var col_states: Array[int] = states[c]
	var sides := 0
	if r == 0 or col_states[r - 1] != Piece.FLAT:
		sides |= _PavingMesh.SIDE_NEG_Z
	if r == col_states.size() - 1 or col_states[r + 1] != Piece.FLAT:
		sides |= _PavingMesh.SIDE_POS_Z
	var toward_curb := _PavingMesh.SIDE_NEG_X if _sign > 0.0 else _PavingMesh.SIDE_POS_X
	var toward_wall := _PavingMesh.SIDE_POS_X if _sign > 0.0 else _PavingMesh.SIDE_NEG_X
	var inner_open := not is_tile or c == 0
	var outer_open := not is_tile or c == cols - 1
	if is_tile:
		if c > 0:
			var inner_col: Array[int] = states[c - 1]
			inner_open = r >= inner_col.size() or inner_col[r] != Piece.FLAT
		if c < cols - 1:
			var outer_col: Array[int] = states[c + 1]
			outer_open = r >= outer_col.size() or outer_col[r] != Piece.FLAT
	if inner_open:
		sides |= toward_curb
	if outer_open:
		sides |= toward_wall
	return sides


func _emit(rng: RandomNumberGenerator, out: _PavingMesh, state: int, at: Vector2, cell: Vector2,
		tier: int, e: float, tone: float, sides: int) -> void:
	var w := cell.x
	var length := cell.y
	var zone := _WreckMap.zone(e)
	var wreck := clampf(_WreckMap.wreck_tint(e) + 0.1 * tier, 0.0, 1.0)
	var joint := JOINT * (0.7 + 0.6 * fposmod(tone * 7.31, 1.0))
	var size := Vector3(w - joint, PIT_DEPTH + 0.02, length - joint)
	var centre := Vector3(_sign * at.x, _top - size.y * 0.5, at.y)
	match state:
		Piece.FLAT:
			out.add_block(size, Transform3D(Basis(), centre), wreck, tone, CHAMFER, sides, false)
		Piece.TILTED:
			var deg := rng.randf_range(0.4, 1.0) * TILT_DEG[tier] * 0.5
			if zone == _WreckMap.Zone.FRAGMENT:
				deg = rng.randf_range(4.0, 14.0)
			elif zone == _WreckMap.Zone.ROUGH:
				deg = rng.randf_range(1.0, 5.0)
			var a := deg_to_rad(deg)
			var on_x := rng.randf() < 0.5
			var s := 1.0 if rng.randf() < 0.5 else -1.0
			var hinge := Vector3(centre.x, _top, centre.z + s * size.z * 0.5)
			var axis := Vector3.RIGHT
			var angle := s * a
			if not on_x:
				hinge = Vector3(centre.x + s * size.x * 0.5, _top, centre.z)
				axis = Vector3.BACK
				angle = -s * a
			var xf := Transform3D(Basis(), hinge) \
					* Transform3D(Basis(axis, angle), Vector3.ZERO) \
					* Transform3D(Basis(), -hinge) * Transform3D(Basis(), centre)
			out.add_block(size, xf, wreck, tone, CHAMFER, _PavingMesh.SIDE_ALL, false)
		Piece.SUNK:
			var drop := rng.randf_range(0.015, 0.05)
			var tilt := rng.randf_range(0.0, 3.0)
			if zone == _WreckMap.Zone.FRAGMENT:
				drop = lerpf(0.005, 0.025, _WreckMap.band_t(e)) + rng.randf_range(0.0, 0.01)
				tilt = rng.randf_range(0.0, 4.0)
			elif zone == _WreckMap.Zone.ROUGH:
				drop = rng.randf_range(0.005, 0.03)
				tilt = rng.randf_range(0.0, 2.0)
			centre.y -= drop
			var t := rng.randf() * TAU
			var basis := Basis(Vector3(cos(t), 0.0, sin(t)), deg_to_rad(tilt))
			out.add_block(size, Transform3D(basis, centre), wreck, tone, CHAMFER,
					_PavingMesh.SIDE_ALL, false)
		Piece.FRAGMENT:
			var fp := _WreckGround.fragment_footprint(rng, w - joint, length - joint)
			var drop := lerpf(0.0, 0.02, _WreckMap.band_t(e)) + rng.randf_range(0.0, 0.012)
			var height := maxf(PIT_DEPTH + 0.02 - drop, 0.03)
			var t := rng.randf() * TAU
			var basis := Basis(Vector3(cos(t), 0.0, sin(t)), deg_to_rad(rng.randf_range(0.0, 10.0)))
			var pos := Vector3(centre.x, _top - drop - height * 0.5, centre.z)
			out.add_prism(fp, height, Transform3D(basis, pos), wreck, tone, false)
			if rng.randf() < 0.08:
				_add_chunk(rng, at)
		Piece.MISSING_PIECE:
			if zone == _WreckMap.Zone.FRAGMENT and rng.randf() < 0.10:
				_add_chunk(rng, at)


## A rare broken lump of paving, half buried in the dirt floor.
func _add_chunk(rng: RandomNumberGenerator, at: Vector2) -> void:
	var size := Vector3(rng.randf_range(0.08, 0.18), rng.randf_range(0.05, 0.10),
			rng.randf_range(0.08, 0.18))
	var pos := Vector3(_sign * (at.x + rng.randf_range(-0.08, 0.08)),
			_top - _WreckGround.DIRT_DROP - size.y * 0.25, at.y + rng.randf_range(-0.08, 0.08))
	var t := rng.randf() * TAU
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) \
			* Basis(Vector3(cos(t), 0.0, sin(t)), deg_to_rad(rng.randf_range(0.0, 25.0)))
	_rubble.add_block(size, Transform3D(basis, pos), 1.0, rng.randf(), 0.015,
			_PavingMesh.SIDE_ALL, true)
