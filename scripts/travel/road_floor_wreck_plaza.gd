extends RefCounted
## Lays a plaza run's 1 m flagstones and the flat soil under them into the wreck's meshes.

const _WreckGround = preload("res://scripts/travel/road_floor_wreck_ground.gd")
const _WreckMap = preload("res://scripts/travel/road_floor_wreck_map.gd")

const X0 := 9.0 ## plaza starts at the old walk's outer edge
const PITCH := 1.0
const MIN_LAST := 0.5 ## a last row shorter than this merges into the one before
const TILT_SCALE := 0.5 ## 1 m stones tilt half as far as 0.5 m tiles, so edges lift the same


func build(wreck, side_idx: int, walk_len: float, walk_cz: float) -> void:
	if wreck.road.ground_runs.size() != 2:
		return
	var z0w := walk_cz - walk_len * 0.5
	var z1w := walk_cz + walk_len * 0.5
	var runs: Array = wreck.road.ground_runs[side_idx]
	for i in runs.size():
		var run: Vector4 = runs[i]
		if int(run.w) != 1 or run.z < 1.0:
			continue
		var a := maxf(run.x, z0w)
		var b := minf(run.y, z1w)
		if b - a < 0.01:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = wreck.road._seed_value(697 + side_idx * 1000 + i * 7919)
		_lay_stones(wreck, side_idx, rng, a, b, roundi(run.z))
		_lay_soil(wreck, rng, a, b, float(roundi(run.z)))


## Rows of PITCH from `a`; a short remainder joins the last full row.
func _rows(wreck, a: float, b: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n := floori((b - a) / PITCH)
	var rem := b - a - n * PITCH
	for k in n:
		out.append(Vector2(a + k * PITCH, a + (k + 1) * PITCH))
	if n == 0 or rem >= MIN_LAST:
		out.append(Vector2(b - rem, b))
	else:
		out[n - 1].y = b
	if out.size() == 1 and out[0].y - out[0].x < wreck.MIN_PIECE:
		return []
	return out


func _lay_stones(wreck, side_idx: int, rng: RandomNumberGenerator, a: float, b: float,
		cols: int) -> void:
	var rows := _rows(wreck, a, b)
	if rows.is_empty():
		return
	var states: Array = []
	var tones: Array = []
	var damages: Array = []
	for c in cols:
		var cx := X0 + (c + 0.5) * PITCH
		var col_states: Array[int] = []
		var col_tones: Array[float] = []
		var col_damages: Array[float] = []
		for row in rows:
			var zm := (row.x + row.y) * 0.5
			var e: float = wreck.damage_at(cx, zm)
			col_damages.append(e)
			col_states.append(wreck._piece_state(rng, wreck.tier_at(side_idx, zm), e,
					wreck._is_kept(row.x, row.y), true))
			col_tones.append(rng.randf())
		states.append(col_states)
		tones.append(col_tones)
		damages.append(col_damages)
	for c in cols:
		var cx := X0 + (c + 0.5) * PITCH
		var col_states: Array[int] = states[c]
		for r in rows.size():
			var row := rows[r]
			var zm := (row.x + row.y) * 0.5
			var tier: int = wreck.tier_at(side_idx, zm)
			var e: float = damages[c][r]
			var tone: float = tones[c][r]
			var state := col_states[r]
			var sides := 0
			if state == wreck.Piece.FLAT:
				sides = wreck._flat_sides(states, c, r, cols, true)
			wreck._emit(rng, wreck._flags, state, Vector2(cx, zm),
					Vector2(PITCH, row.y - row.x), tier, e, tone, sides, TILT_SCALE)


## A flat grid under the stones, so a missing one shows dirt, not sky.
func _lay_soil(wreck, rng: RandomNumberGenerator, a: float, b: float, r: float) -> void:
	var y: float = wreck._top - _WreckGround.DIRT_DROP
	var nx := maxi(2, ceili(r / _WreckGround.STEP) + 1)
	var nz := maxi(2, ceili((b - a) / _WreckGround.STEP) + 1)
	var points := PackedVector3Array()
	var wrecks := PackedFloat32Array()
	for iz: int in nz:
		var z := lerpf(a, b, float(iz) / float(nz - 1))
		for ix: int in nx:
			var x_abs := lerpf(X0, X0 + r, float(ix) / float(nx - 1))
			points.append(Vector3(wreck._sign * x_abs, y, z))
			wrecks.append(_WreckMap.wreck_tint(wreck.damage_at(x_abs, z)))
	wreck._soil.add_grid(points, nx, nz, wrecks, rng.randf())
