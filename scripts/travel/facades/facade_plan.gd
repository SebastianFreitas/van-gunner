extends RefCounted
## Plans one facade side: splits the 20 m tile edge into buildings and gives each a skin preset,
## height, floors, ground kind and setback. Pure data (Dictionaries) that the body and prop
## builders turn into meshes; nothing here touches the scene tree.


const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeRuin := preload("res://scripts/travel/facades/facade_ruin.gd")

const TILE_HALF_Z := 10.0
const BASE_Y := -0.4
const FACE_X := 8.8
const FLOOR_HEIGHT := 3.2
const GROUND_HEIGHT := 4.6
const PARAPET := 0.6
const MIN_FLOORS := 2
const MAX_HEIGHT := 40.0
const BAY_HEADER_Y := 7.9
const BAY_FLANK_HALF_Z := 4.5
const SETBACKS: Array[float] = [0.0, 0.15, 0.3]
## Narrowest a building may get once its edge gaps are trimmed off (metres).
const GAP_MIN_BUILDING := 4.0
## Building depth behind the face on plain sides, read by the bodies.
const PLAIN_DEPTH := 3.5

## Opening codes mirror the tile's enum (same values as facade_keep_out.gd).
const OPENING_NONE := 0
const OPENING_SIDE_STREET := 1
const OPENING_BAY := 2

## Ground kinds match the facade shader's `ground_kind` uniform.
const GROUND_BLANK := 0
const GROUND_STOREFRONT := 1
const GROUND_BOARDED := 2
const GROUND_ROLLUP := 3
const GROUND_DOCK := 4
const GROUND_ARCADE := 5

## How a 20 m tile edge is cut into buildings; SPLIT_WEIGHTS picks a row of SPLITS by index.
const SPLITS := [
	[20.0],
	[8.0, 12.0],
	[12.0, 8.0],
	[10.0, 10.0],
	[6.0, 7.0, 7.0],
	[7.0, 6.0, 7.0],
	[7.0, 7.0, 6.0],
]
const SPLIT_WEIGHTS := [0.34, 0.15, 0.15, 0.16, 0.07, 0.07, 0.06]

static func plan_side(
	rng: RandomNumberGenerator, district: FacadeDistrict, opening: int, neighborhood_seed: int,
	wreck_at: Callable = Callable()
) -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	if opening == OPENING_SIDE_STREET:
		return plans
	if opening == OPENING_BAY:
		var preset: StringName = _pick(rng, district.presets)
		var height: float = maxf(_pick_height(rng, district), 16.0)
		var floors := maxi(MIN_FLOORS, roundi((height - GROUND_HEIGHT - PARAPET) / FLOOR_HEIGHT))
		var tags: Array[StringName] = []
		plans.append({
			&"z0": -TILE_HALF_Z,
			&"z1": TILE_HALF_Z,
			&"width": 20.0,
			&"height": height,
			&"floors": floors,
			&"setback": 0.0,
			&"preset": preset,
			&"ground_kind": GROUND_BLANK,
			&"ground_units": 1,
			&"mouth": true,
			&"params": _params_for(
				rng, district, preset, 20.0, height, GROUND_BLANK, 1, neighborhood_seed
			),
			&"tags": tags,
			&"rare": &"",
			&"district_id": district.id,
		})
		return plans
	return plan_length(rng, district, 20.0, neighborhood_seed, wreck_at, true)


## Splits a `length` metre span into buildings the same way a 20 m tile edge is split, scaling
## each `SPLITS` row to fit; used for tile sides (length 20.0, bit-identical to the old code) and
## for junction stems, branches and side-street flanks of any other length.
static func plan_length(
	rng: RandomNumberGenerator, district: FacadeDistrict, length: float, neighborhood_seed: int,
	wreck_at: Callable = Callable(), with_gaps: bool = false
) -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	# Gap decisions never draw from `rng`, so its sequence is the same with or without gaps.
	var gap_rng := RandomNumberGenerator.new()
	gap_rng.seed = hash([rng.state, &"gaps"])
	var split_index := _weighted_index(rng, SPLIT_WEIGHTS)
	var scale := length / 20.0
	var widths: Array = SPLITS[split_index]
	var z := -length / 2.0
	var prev: Dictionary = {}
	for k in widths.size():
		var base_width: float = widths[k]
		var width: float = base_width * scale
		var preset: StringName = _pick(rng, district.presets)
		var lo := 0.0
		var hi := 0.0
		var joined := false
		if with_gaps:
			if k == 0:
				if gap_rng.randf() < 0.45:
					lo = gap_rng.randf_range(0.6, 1.5)
			elif preset == prev[&"preset"]:
				joined = true
			elif gap_rng.randf() < 0.7:
				lo = gap_rng.randf_range(1.0, 1.5)
			else:
				lo = gap_rng.randf_range(1.5, 3.0)
			if k == widths.size() - 1 and gap_rng.randf() < 0.45:
				hi = gap_rng.randf_range(0.6, 1.5)
			if width - lo - hi < GAP_MIN_BUILDING:
				hi = 0.0
				if width - lo < GAP_MIN_BUILDING:
					lo = 0.0
		var height: float = _pick_height(rng, district)
		var floors := maxi(MIN_FLOORS, roundi((height - GROUND_HEIGHT - PARAPET) / FLOOR_HEIGHT))
		var setback: float = SETBACKS[rng.randi() % SETBACKS.size()]
		if joined:
			height = float(prev[&"height"])
			floors = int(prev[&"floors"])
			setback = float(prev[&"setback"])
		var ground_kind: int = _pick(rng, district.ground_kinds)
		var w_eff := width - lo - hi
		var ground_units: int = clampi(roundi(w_eff / 5.0), 1, 4)
		var tags: Array[StringName] = []
		plans.append({
			&"z0": z + lo,
			&"z1": z + width - hi,
			&"width": w_eff,
			&"height": height,
			&"floors": floors,
			&"setback": setback,
			&"preset": preset,
			&"ground_kind": ground_kind,
			&"ground_units": ground_units,
			&"mouth": false,
			&"params": _params_for(
				rng, district, preset, w_eff, height, ground_kind, ground_units, neighborhood_seed
			),
			&"tags": tags,
			&"rare": &"",
			&"district_id": district.id,
		})
		if with_gaps:
			plans[-1][&"depth"] = PLAIN_DEPTH
			plans[-1][&"gap_lo"] = lo
			plans[-1][&"gap_hi"] = hi
		prev = plans[-1]
		if wreck_at.is_valid():
			plans[-1][&"walk_wreck"] = float(wreck_at.call(
				(float(plans[-1][&"z0"]) + float(plans[-1][&"z1"])) * 0.5
			))
		_FacadeRuin.apply(plans[plans.size() - 1], district)
		z += width
	return plans


static func _pick_height(rng: RandomNumberGenerator, district: FacadeDistrict) -> float:
	var h: float
	if rng.randf() < district.tall_chance:
		h = rng.randf_range(district.tall_min, district.tall_max)
	else:
		h = rng.randf_range(district.height_min, district.height_max)
	var floors := maxi(MIN_FLOORS, roundi((h - GROUND_HEIGHT - PARAPET) / FLOOR_HEIGHT))
	h = GROUND_HEIGHT + floors * FLOOR_HEIGHT + PARAPET
	return minf(h, MAX_HEIGHT)


static func _params_for(
	rng: RandomNumberGenerator,
	district: FacadeDistrict,
	preset: StringName,
	width: float,
	height: float,
	ground_kind: int,
	ground_units: int,
	neighborhood_seed: int
) -> Dictionary:
	var p := _FacadeMaterials.preset(preset)
	p[&"facade_width"] = width
	p[&"facade_height"] = height
	p[&"floor_height"] = FLOOR_HEIGHT
	p[&"ground_height"] = GROUND_HEIGHT
	p[&"ground_kind"] = ground_kind
	p[&"ground_units"] = float(ground_units)
	p[&"lit_ratio"] = clampf(district.lit_ratio * rng.randf_range(0.7, 1.3), 0.0, 1.0)
	p[&"grime"] = clampf(district.grime * rng.randf_range(0.8, 1.2), 0.0, 1.0)
	p[&"boarded_ratio"] = district.boarded_ratio
	p[&"broken_ratio"] = district.broken_ratio
	p[&"damage"] = district.damage
	p[&"band_every"] = _pick(rng, district.band_every)
	p[&"seed"] = rng.randf() * 1000.0
	# Neighborhood drift: a shared per-tile hue/value nudge so a street reads as one place.
	var drift := RandomNumberGenerator.new()
	drift.seed = neighborhood_seed
	var hue := drift.randf_range(-0.03, 0.03)
	var value := drift.randf_range(0.92, 1.08)
	for key: StringName in [&"base_color", &"accent_color", &"mortar_color"]:
		if p.has(key):
			var c: Color = p[key]
			p[key] = Color.from_hsv(fposmod(c.h + hue, 1.0), c.s, clampf(c.v * value, 0.0, 1.0), c.a)
	# Nothing pristine: every plan carries soot, peeling paint and foot growth. Own rng, so
	# no later building's draws shift.
	var age := RandomNumberGenerator.new()
	age.seed = hash([float(p[&"seed"]), &"age"])
	p[&"soot"] = 0.45
	p[&"peel"] = 0.55
	p[&"overgrowth"] = 0.15
	p[&"ivy"] = 0.0
	p[&"growth_height"] = 0.5 + age.randf_range(-0.15, 0.15)
	p[&"grime"] = maxf(float(p[&"grime"]), 0.55)
	p[&"damage"] = maxf(float(p[&"damage"]), 0.15)
	return p


static func _pick(rng: RandomNumberGenerator, items: Array) -> Variant:
	return items[rng.randi() % items.size()]


static func _weighted_index(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var roll := rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += float(weights[i])
		if roll < acc:
			return i
	return weights.size() - 1


static func roofline_y(plan: Dictionary) -> float:
	return BASE_Y + float(plan[&"height"])


static func face_x(plan: Dictionary, side_sign: float) -> float:
	return side_sign * (FACE_X - float(plan.get(&"setback", 0.0)))
