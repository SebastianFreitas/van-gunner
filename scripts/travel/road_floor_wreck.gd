extends RefCounted
## Builds RoadFloor's wrecked paving: tiles, setts and gone stretches over a soil pit, each side as merged meshes.

const RoadFloorMaterials = preload("res://scripts/travel/road_floor_materials.gd")
const _PavingMesh := preload("res://scripts/travel/road_floor_paving_mesh.gd")
const _WreckCurb := preload("res://scripts/travel/road_floor_wreck_curb.gd")

const PIT_DEPTH := 0.25 ## soil bed top sits this far under the walk top
const JOINT := 0.03
const CHAMFER := 0.025
const TILE_PITCH := 0.5
const SETT_PITCH := 0.25
const MIN_PIECE := 0.12
const GONE_MISSING := 0.9 ## chance a piece is missing in the middle of a gone stretch
const EDGE_REACH := 0.6 ## damage leaks this far out of a gone stretch
const RAMP := 0.75 ## a gone stretch thickens over this distance from its ends
const MISSING: Array[float] = [0.0, 0.03, 0.08, 0.14]
const MISSING_SETT: Array[float] = [0.0, 0.04, 0.10, 0.18]
const TILT: Array[float] = [0.02, 0.08, 0.16, 0.25]
const TILT_DEG: Array[float] = [3.0, 6.0, 10.0, 14.0]
const SINK: Array[float] = [0.03, 0.08, 0.12, 0.16]

enum Piece { FLAT, MISSING_PIECE, TILTED, SUNK, TUMBLED }

var road: RoadFloor
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
## Gone stretches, as tile-local z ranges.
var _gone: Array[Vector2] = []


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
	_layout()
	_pick_gone(side_idx)
	_build_tiles(side_idx)
	_build_setts(side_idx)
	var rng_curb := RandomNumberGenerator.new()
	rng_curb.seed = road._seed_value(297 + side_idx * 1000)
	_WreckCurb.new().build(self, side_idx, _sign, rng_curb, _curb, _rubble)
	var tag := "Left" if side_idx == 0 else "Right"
	_rubble.commit(road, "WalkRubble" + tag,
			RoadFloorMaterials.paving_mat(RoadFloorMaterials.PAVING_RUBBLE))
	_curb.commit(road, "WalkCurb" + tag,
			RoadFloorMaterials.paving_mat(RoadFloorMaterials.PAVING_CURB))
	_tiles.commit(road, "WalkTiles" + tag,
			RoadFloorMaterials.paving_mat(RoadFloorMaterials.PAVING_TILE))
	_setts.commit(road, "WalkSetts" + tag,
			RoadFloorMaterials.paving_mat(RoadFloorMaterials.PAVING_SETT))


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


## Picks the gone stretches: about half the walk, favouring the worst-ruined buildings.
func _pick_gone(side_idx: int) -> void:
	_gone.clear()
	if road.wreck_spans.size() != 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = road._seed_value(497 + side_idx * 1000)
	var target := rng.randf_range(0.40, 0.60) * (_z_end - _z_start)
	var cands: Array[Vector3] = []
	for v: Vector3 in road.wreck_spans[side_idx]:
		var z0 := maxf(v.x, _z_start)
		var z1 := minf(v.y, _z_end)
		var tier := clampi(int(v.z), 0, 3)
		var score := tier + rng.randf() * 1.5
		if z1 - z0 < 1.0 or tier == 0:
			continue
		cands.append(Vector3(z0, z1, score))
	cands.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z > b.z)
	var total := 0.0
	for c in cands:
		if total >= target:
			break
		_gone.append(Vector2(c.x, c.y))
		total += c.y - c.x


## 0 outside the gone stretches; inside, how deep into one (0.3 at its ends, 1 beyond RAMP).
func _gone_at(z: float) -> float:
	for r in _gone:
		if z >= r.x and z <= r.y:
			var d := INF
			if r.x > _z_start + 0.01:
				d = minf(d, z - r.x)
			if r.y < _z_end - 0.01:
				d = minf(d, r.y - z)
			return clampf(d / RAMP, 0.3, 1.0)
	return 0.0


## Outside the gone stretches, how close to one (1 at its end, 0 at EDGE_REACH).
func _edge_near(z: float) -> float:
	var d := INF
	for r in _gone:
		if z >= r.x and z <= r.y:
			return 0.0
		if r.x > _z_start + 0.01:
			d = minf(d, absf(z - r.x))
		if r.y < _z_end - 0.01:
			d = minf(d, absf(z - r.y))
	return maxf(0.0, 1.0 - d / EDGE_REACH)


func _is_kept(z0: float, z1: float) -> bool:
	for dz in _kept:
		if z1 >= dz - 0.4 and z0 <= dz + 0.4:
			return true
	return false


## Draw order is fixed (miss, move, kind) so the other outcomes never shift the stream.
func _piece_state(rng: RandomNumberGenerator, tier: int, gone: float, edge: float,
		kept: bool, miss_table: Array[float]) -> int:
	var r_miss := rng.randf()
	var r_move := rng.randf()
	var r_kind := rng.randf()
	if kept:
		return Piece.FLAT
	var p_miss := miss_table[tier] + 0.35 * edge
	if gone > 0.0:
		p_miss = lerpf(miss_table[tier], GONE_MISSING, gone)
	if r_miss < p_miss:
		return Piece.MISSING_PIECE
	if gone > 0.0:
		return Piece.TUMBLED if r_kind < 0.75 else Piece.TILTED
	var p_tilt := TILT[tier] + 0.3 * edge
	if r_move < p_tilt:
		return Piece.TILTED
	if r_move < p_tilt + SINK[tier]:
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
	var miss_table := MISSING if is_tile else MISSING_SETT
	var rng := RandomNumberGenerator.new()
	rng.seed = road._seed_value(salt + side_idx * 1000)
	var cells: Array = []
	var states: Array = []
	var tones: Array = []
	for c in cols:
		var shift := 0.0 if is_tile else (c % 2) * SETT_PITCH * 0.5
		var col_cells := _cells(pitch, shift)
		var col_states: Array[int] = []
		var col_tones: Array[float] = []
		for cell in col_cells:
			var zm := (cell.x + cell.y) * 0.5
			var gone := _gone_at(zm)
			col_states.append(_piece_state(rng, tier_at(side_idx, zm), gone,
					_edge_near(zm), _is_kept(cell.x, cell.y), miss_table))
			col_tones.append(rng.randf())
		cells.append(col_cells)
		states.append(col_states)
		tones.append(col_tones)
	var out := _tiles if is_tile else _setts
	for c in cols:
		var cx := x0 + (c + 0.5) * w
		var col_cells: Array[Vector2] = cells[c]
		var col_states: Array[int] = states[c]
		for r in col_cells.size():
			var cell := col_cells[r]
			var zm := (cell.x + cell.y) * 0.5
			var tier := tier_at(side_idx, zm)
			var gone := _gone_at(zm)
			var wreck := 1.0 if gone > 0.0 else tier / 3.0
			var tone: float = tones[c][r]
			var state := col_states[r]
			var sides := 0
			if state == Piece.FLAT:
				sides = _flat_sides(states, c, r, cols, is_tile)
			_emit(rng, out, state, Vector2(cx, zm), Vector2(w, cell.y - cell.x), tier,
					gone, wreck, tone, sides, is_tile)


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
		tier: int, gone: float, wreck: float, tone: float, sides: int, is_tile: bool) -> void:
	var w := cell.x
	var length := cell.y
	var size := Vector3(w - JOINT, PIT_DEPTH + 0.02, length - JOINT)
	var centre := Vector3(_sign * at.x, _top - size.y * 0.5, at.y)
	match state:
		Piece.FLAT:
			out.add_block(size, Transform3D(Basis(), centre), wreck, tone, CHAMFER, sides, false)
		Piece.TILTED:
			var deg := rng.randf_range(0.4, 1.0) * TILT_DEG[tier]
			if gone > 0.0:
				deg = rng.randf_range(8.0, 20.0)
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
			centre.y -= rng.randf_range(0.015, 0.05)
			var t := rng.randf() * TAU
			var basis := Basis(Vector3(cos(t), 0.0, sin(t)), deg_to_rad(rng.randf_range(0.0, 3.0)))
			out.add_block(size, Transform3D(basis, centre), wreck, tone, CHAMFER,
					_PavingMesh.SIDE_ALL, false)
		Piece.TUMBLED:
			var thin := Vector3((w - JOINT) * rng.randf_range(0.6, 1.0),
					0.08 if is_tile else 0.10, (length - JOINT) * rng.randf_range(0.6, 1.0))
			var pos := Vector3(centre.x, _bed_y + thin.y * 0.5 + rng.randf_range(0.0, 0.06),
					centre.z)
			var t := rng.randf() * TAU
			var basis := Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)) \
					* Basis(Vector3(cos(t), 0.0, sin(t)), deg_to_rad(rng.randf_range(8.0, 28.0)))
			out.add_block(thin, Transform3D(basis, pos), wreck, tone, CHAMFER,
					_PavingMesh.SIDE_ALL, true)
		Piece.MISSING_PIECE:
			var chance := 0.6 if is_tile else 0.25
			if gone <= 0.0:
				chance = 0.5 if is_tile else 0.2
			if rng.randf() < chance:
				_add_chunk(rng, at)


## A broken lump of paving lying in the pit.
func _add_chunk(rng: RandomNumberGenerator, at: Vector2) -> void:
	var size := Vector3(rng.randf_range(0.10, 0.30), rng.randf_range(0.05, 0.14),
			rng.randf_range(0.10, 0.30))
	var pos := Vector3(_sign * (at.x + rng.randf_range(-0.08, 0.08)), _bed_y + size.y * 0.3,
			at.y + rng.randf_range(-0.08, 0.08))
	var t := rng.randf() * TAU
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) \
			* Basis(Vector3(cos(t), 0.0, sin(t)), deg_to_rad(rng.randf_range(0.0, 25.0)))
	_rubble.add_block(size, Transform3D(basis, pos), 1.0, rng.randf(), 0.015,
			_PavingMesh.SIDE_ALL, true)
