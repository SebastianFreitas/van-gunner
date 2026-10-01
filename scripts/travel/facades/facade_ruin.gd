extends RefCounted
## Rolls each street building's ruin condition and the column/hole data that later geometry cuts
## the facade with, and clips the plan that the prop families see so nothing floats over a gap.
##
## Plan keys written by apply():
##   &"ruin":       int 0..3 (INTACT, WORN, BROKEN, GUTTED).
##   &"ruin_cols":  Array[Vector3], each (z_a, z_b, top_y); contiguous, ascending z, covering
##                  plan.z0..plan.z1 exactly; top_y is absolute (same frame as BASE_Y + height).
##   &"ruin_holes": Array[Vector3], each (col_index, y_a, y_b), absolute y; at most one per column.
##   &"ruin_side":  int -1 or 1, the end a BROKEN corner collapsed toward (-1 = z0 end); else 0.
## It also lowers the window-state ratios in plan.params (lit, broken, boarded) by tier.

const INTACT := 0
const WORN := 1
const BROKEN := 2
const GUTTED := 3

const COL_MIN_W := 1.6
const COL_MAX_W := 2.8

# Mirrors facade_plan.gd; facade_plan preloads this file, so it can't preload facade_plan back.
const BASE_Y := -0.4
const GROUND_HEIGHT := 4.6
const FLOOR_HEIGHT := 3.2
const PARAPET := 0.6

const _DEFAULT_WEIGHTS: Array[float] = [0.12, 0.38, 0.32, 0.18]
## Per-tier multiplier on the ruin weights in front of a destroyed walk, blended in by walk_wreck.
const _WALK_TIER_MULT: Array[float] = [0.1, 0.5, 1.5, 3.0]
const _MIN_EDGE_GAP := 0.8
const _MIN_HOLE_COL_W := 1.2
const _SKIN_SOOT: Array[float] = [0.45, 0.6, 0.75, 0.9]
const _SKIN_PEEL: Array[float] = [0.55, 0.7, 0.85, 1.0]
const _SKIN_GROWTH: Array[float] = [0.15, 0.3, 0.55, 0.8]
const _SKIN_DAMAGE: Array[float] = [0.15, 0.3, 0.5, 0.7]
const _SKIN_GRIME: Array[float] = [0.55, 0.65, 0.75, 0.85]
const _SKIN_GROWTH_HEIGHT: Array[float] = [0.5, 0.9, 1.6, 2.2]
const _SKIN_IVY: Array[float] = [0.0, 0.1, 0.35, 0.7]


## Rolls the building's condition and writes the ruin keys into `plan`. Uses its own rng so the
## caller's stream (and every family seeded after it) stays byte-identical.
static func apply(plan: Dictionary, district: FacadeDistrict) -> void:
	var params: Dictionary = plan[&"params"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([float(params[&"seed"]), &"ruin"])
	var weights: Array[float] = _DEFAULT_WEIGHTS
	if district.ruin_weights.size() == 4:
		weights = district.ruin_weights
	# A building in front of a destroyed walk rolls a worse tier (walk_wreck is -1 when unknown).
	var walk_t := smoothstep(-0.30, 0.10, float(plan.get(&"walk_wreck", -1.0)))
	var w: Array[float] = weights.duplicate()
	if walk_t > 0.0:
		for i in 4:
			w[i] = lerpf(w[i], w[i] * _WALK_TIER_MULT[i], walk_t)
	var tier := _pick_tier(rng, w)
	var z0 := float(plan[&"z0"])
	var z1 := float(plan[&"z1"])
	var height := float(plan[&"height"])
	var full := BASE_Y + height
	var cols: Array[Vector3] = []
	var holes: Array[Vector3] = []
	var side := 0
	if tier == INTACT:
		cols.append(Vector3(z0, z1, full))
	else:
		var edges := _edges(rng, z0, z1)
		var n := edges.size() - 1
		var drops: Array[float] = []
		drops.resize(n)
		drops.fill(0.0)
		var collapsed: Array[int] = []
		if tier == WORN:
			_worn_drops(rng, drops, range(n))
		elif tier == BROKEN:
			side = -1 if rng.randf() < 0.5 else 1
			var k := clampi(ceili(n * rng.randf_range(0.3, 0.55)), 1, n - 1)
			var big := height * rng.randf_range(0.3, 0.55)
			for j in k:
				var idx := j if side == -1 else n - 1 - j
				collapsed.append(idx)
				var t := float(j) / float(maxi(1, k - 1))
				drops[idx] = big * lerpf(1.0, 0.45, t) + rng.randf_range(-1.0, 1.0)
			var rest: Array = []
			for i in n:
				if not collapsed.has(i):
					rest.append(i)
			_worn_drops(rng, drops, rest)
		else:
			var d := height * rng.randf_range(0.15, 0.45)
			for i in n:
				d = clampf(d + rng.randf_range(-0.2, 0.2) * height, 0.05 * height, 0.7 * height)
				drops[i] = d
			var breach := rng.randi_range(0, n - 1)
			drops[breach] = maxf(drops[breach], height * rng.randf_range(0.6, 0.85))
		var floor_top := BASE_Y + GROUND_HEIGHT + FLOOR_HEIGHT + PARAPET + 0.5
		var short := full < floor_top + 0.5
		for i in n:
			var top := full if short else clampf(full - drops[i], floor_top, full)
			cols.append(Vector3(edges[i], edges[i + 1], top))
		_roll_holes(rng, tier, cols, collapsed, holes)
	plan[&"ruin"] = tier
	plan[&"ruin_cols"] = cols
	plan[&"ruin_holes"] = holes
	plan[&"ruin_side"] = side
	_wear_windows(params, tier)
	_wear_skin(params, tier, rng)
	if walk_t > 0.5:
		params[&"ivy"] = minf(1.0, float(params[&"ivy"]) + 0.3 * walk_t)
		params[&"growth_height"] = float(params[&"growth_height"]) + 1.5 * walk_t
		params[&"overgrowth"] = minf(1.0, float(params[&"overgrowth"]) + 0.2 * walk_t)


## The plan the prop families should see: cornices, fire escapes and balconies stop under the
## lowest broken top instead of floating over a collapsed corner.
static func props_plan(plan: Dictionary) -> Dictionary:
	if not is_shaped(plan):
		return plan
	var p := plan.duplicate()
	var floors_c := maxi(
		1, floori((min_top(plan) - BASE_Y - GROUND_HEIGHT - PARAPET) / FLOOR_HEIGHT)
	)
	floors_c = mini(floors_c, int(plan[&"floors"]))
	p[&"floors"] = floors_c
	p[&"height"] = minf(
		float(plan[&"height"]), GROUND_HEIGHT + floors_c * FLOOR_HEIGHT + PARAPET
	)
	if int(plan.get(&"ruin", 0)) >= BROKEN:
		var suppress: Array[StringName] = []
		suppress.assign(plan.get(&"suppress", []))
		if not suppress.has(&"roof_clutter"):
			suppress.append(&"roof_clutter")
		p[&"suppress"] = suppress
	return p


## Lowest column top (absolute y), or the full building top when there are no columns.
static func min_top(plan: Dictionary) -> float:
	var cols: Array = plan.get(&"ruin_cols", [])
	if cols.is_empty():
		return BASE_Y + float(plan[&"height"])
	var lowest := INF
	for c: Vector3 in cols:
		lowest = minf(lowest, c.z)
	return lowest


## True when the ruin geometry applies: ruined, not a bay mouth, not a set piece, and not one of
## the set pieces that cut their own collapse (params.collapse_y).
static func is_shaped(plan: Dictionary) -> bool:
	return (
		int(plan.get(&"ruin", 0)) > INTACT
		and not bool(plan.get(&"mouth", false))
		and plan.get(&"rare", &"") == &""
		and float(plan[&"params"].get(&"collapse_y", 0.0)) <= 0.0
	)


static func _pick_tier(rng: RandomNumberGenerator, weights: Array[float]) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return i
	return weights.size() - 1


## Column edges z0..z1: even split, interior edges jittered unless that would leave a column
## narrower than _MIN_EDGE_GAP.
static func _edges(rng: RandomNumberGenerator, z0: float, z1: float) -> Array[float]:
	var w := z1 - z0
	var n := maxi(2, roundi(w / rng.randf_range(COL_MIN_W, COL_MAX_W)))
	var step := w / n
	var edges: Array[float] = [z0]
	for i in range(1, n):
		var e := z0 + step * i
		var jittered := e + rng.randf_range(-0.2, 0.2) * step
		var next_edge := z0 + step * (i + 1)
		if jittered - edges[i - 1] >= _MIN_EDGE_GAP and next_edge - jittered >= _MIN_EDGE_GAP:
			e = jittered
		edges.append(e)
	edges.append(z1)
	return edges


static func _worn_drops(rng: RandomNumberGenerator, drops: Array[float], idxs: Array) -> void:
	for i: int in idxs:
		if rng.randf() < 0.45:
			drops[i] = rng.randf_range(0.3, 1.6)


## At most one hole per column; BROKEN holes only in columns that did not collapse.
static func _roll_holes(
	rng: RandomNumberGenerator, tier: int, cols: Array[Vector3], collapsed: Array[int],
	holes: Array[Vector3]
) -> void:
	var count := 0
	if tier == WORN:
		count = 1 if rng.randf() < 0.35 else 0
	elif tier == BROKEN:
		count = rng.randi_range(1, 2)
	else:
		count = rng.randi_range(2, 3)
	var pool: Array[int] = []
	for i in cols.size():
		if not collapsed.has(i):
			pool.append(i)
	for _h in mini(count, pool.size()):
		var pick := rng.randi_range(0, pool.size() - 1)
		var col: int = pool[pick]
		pool.remove_at(pick)
		var c := cols[col]
		if c.y - c.x < _MIN_HOLE_COL_W:
			continue
		var y_lo := BASE_Y + GROUND_HEIGHT + 1.0
		var y_hi := c.z - 1.4
		if y_hi - y_lo < 1.6:
			continue
		var h := rng.randf_range(1.6, minf(3.6, y_hi - y_lo))
		var y_a := rng.randf_range(y_lo, y_hi - h)
		holes.append(Vector3(col, y_a, y_a + h))


## Ruined buildings have fewer lit windows and more broken and boarded ones (shader inputs).
static func _wear_windows(params: Dictionary, tier: int) -> void:
	if tier == WORN:
		_set_windows(params, 0.7, 0.12, 0.06)
	elif tier == BROKEN:
		_set_windows(params, 0.4, 0.3, 0.15)
	elif tier == GUTTED:
		_set_windows(params, 0.0, 0.55, 0.2)


## Soot, peeling paint and foot growth by tier (shader inputs); even INTACT is not pristine.
## Draws last on the ruin rng so the ruin shapes keep their output.
static func _wear_skin(params: Dictionary, tier: int, rng: RandomNumberGenerator) -> void:
	var t := clampi(tier, 0, 3)
	params[&"soot"] = _SKIN_SOOT[t]
	params[&"peel"] = _SKIN_PEEL[t]
	params[&"overgrowth"] = _SKIN_GROWTH[t]
	params[&"ivy"] = _SKIN_IVY[t]
	params[&"damage"] = maxf(float(params.get(&"damage", 0.0)), _SKIN_DAMAGE[t])
	params[&"grime"] = maxf(float(params.get(&"grime", 0.0)), _SKIN_GRIME[t])
	params[&"growth_height"] = _SKIN_GROWTH_HEIGHT[t] * rng.randf_range(0.75, 1.25)


static func _set_windows(
	params: Dictionary, lit_scale: float, broken: float, boarded: float
) -> void:
	params[&"lit_ratio"] = float(params[&"lit_ratio"]) * lit_scale
	params[&"broken_ratio"] = maxf(float(params[&"broken_ratio"]), broken)
	params[&"boarded_ratio"] = maxf(float(params[&"boarded_ratio"]), boarded)
