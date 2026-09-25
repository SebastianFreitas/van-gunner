extends RefCounted
## Plans one facade side: splits the 20 m tile edge into buildings and gives each a skin preset,
## height, floors, ground kind and setback. Pure data (Dictionaries) that the body and prop
## builders turn into meshes; nothing here touches the scene tree.


const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")

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

## Step 4 moves these into resources; for now a plain table per district, index = district.
const DISTRICTS: Array[Dictionary] = [
	{  # 0 tenement
		&"presets": [
			&"brick_red", &"brick_red", &"brick_brown", &"brick_brown", &"plaster_tan", &"plaster_green"
		],
		&"height_min": 16.0,
		&"height_max": 26.0,
		&"tall_chance": 0.2,
		&"tall_min": 28.0,
		&"tall_max": 34.0,
		&"ground_kinds": [1, 1, 1, 2, 5, 0],
		&"lit_ratio": 0.35,
		&"grime": 0.55,
		&"boarded_ratio": 0.0,
		&"broken_ratio": 0.03,
		&"damage": 0.05,
		&"band_every": [0.0, 2.0, 3.0],
	},
	{  # 1 industrial
		&"presets": [
			&"concrete_grey", &"concrete_grey", &"corrugated_green", &"corrugated_rust", &"brick_brown"
		],
		&"height_min": 12.0,
		&"height_max": 20.0,
		&"tall_chance": 0.15,
		&"tall_min": 22.0,
		&"tall_max": 30.0,
		&"ground_kinds": [3, 3, 4, 4, 0, 0],
		&"lit_ratio": 0.15,
		&"grime": 0.6,
		&"boarded_ratio": 0.0,
		&"broken_ratio": 0.05,
		&"damage": 0.1,
		&"band_every": [0.0],
	},
	{  # 2 commercial
		&"presets": [&"glass_blue", &"glass_blue", &"concrete_grey", &"plaster_tan", &"stone_grey"],
		&"height_min": 28.0,
		&"height_max": 40.0,
		&"tall_chance": 0.5,
		&"tall_min": 40.0,
		&"tall_max": 40.0,
		&"ground_kinds": [1, 1, 1, 1, 5, 0],
		&"lit_ratio": 0.5,
		&"grime": 0.25,
		&"boarded_ratio": 0.0,
		&"broken_ratio": 0.0,
		&"damage": 0.0,
		&"band_every": [0.0, 0.0, 4.0],
	},
	{  # 3 derelict
		&"presets": [
			&"plaster_tan", &"plaster_green", &"brick_brown", &"brick_red", &"concrete_grey"
		],
		&"height_min": 14.0,
		&"height_max": 24.0,
		&"tall_chance": 0.1,
		&"tall_min": 26.0,
		&"tall_max": 30.0,
		&"ground_kinds": [2, 2, 2, 0, 1, 4],
		&"lit_ratio": 0.05,
		&"grime": 0.85,
		&"boarded_ratio": 0.35,
		&"broken_ratio": 0.3,
		&"damage": 0.5,
		&"band_every": [0.0, 3.0],
	},
	{  # 4 civic
		&"presets": [&"stone_grey", &"stone_grey", &"plaster_tan", &"plaster_tan", &"brick_brown"],
		&"height_min": 14.0,
		&"height_max": 20.0,
		&"tall_chance": 0.15,
		&"tall_min": 24.0,
		&"tall_max": 30.0,
		&"ground_kinds": [5, 5, 5, 0, 1],
		&"lit_ratio": 0.25,
		&"grime": 0.35,
		&"boarded_ratio": 0.0,
		&"broken_ratio": 0.02,
		&"damage": 0.05,
		&"band_every": [1.0, 1.0, 2.0],
	},
]


static func plan_side(
	rng: RandomNumberGenerator, district: int, opening: int, neighborhood_seed: int
) -> Array[Dictionary]:
	district = clampi(district, 0, DISTRICTS.size() - 1)
	var table: Dictionary = DISTRICTS[district]
	var plans: Array[Dictionary] = []
	if opening == OPENING_SIDE_STREET:
		return plans
	if opening == OPENING_BAY:
		var preset: StringName = _pick(rng, table[&"presets"])
		var height: float = maxf(_pick_height(rng, table), 16.0)
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
				rng, table, preset, 20.0, height, GROUND_BLANK, 1, neighborhood_seed
			),
			&"tags": tags,
			&"rare": &"",
		})
		return plans
	var split_index := _weighted_index(rng, SPLIT_WEIGHTS)
	var widths: Array = SPLITS[split_index]
	var z := -TILE_HALF_Z
	for width: float in widths:
		var preset: StringName = _pick(rng, table[&"presets"])
		var height: float = _pick_height(rng, table)
		var floors := maxi(MIN_FLOORS, roundi((height - GROUND_HEIGHT - PARAPET) / FLOOR_HEIGHT))
		var setback: float = SETBACKS[rng.randi() % SETBACKS.size()]
		var ground_kind: int = _pick(rng, table[&"ground_kinds"])
		var ground_units: int = clampi(roundi(width / 5.0), 1, 4)
		var tags: Array[StringName] = []
		plans.append({
			&"z0": z,
			&"z1": z + width,
			&"width": width,
			&"height": height,
			&"floors": floors,
			&"setback": setback,
			&"preset": preset,
			&"ground_kind": ground_kind,
			&"ground_units": ground_units,
			&"mouth": false,
			&"params": _params_for(
				rng, table, preset, width, height, ground_kind, ground_units, neighborhood_seed
			),
			&"tags": tags,
			&"rare": &"",
		})
		z += width
	return plans


static func _pick_height(rng: RandomNumberGenerator, table: Dictionary) -> float:
	var h: float
	if rng.randf() < float(table[&"tall_chance"]):
		h = rng.randf_range(table[&"tall_min"], table[&"tall_max"])
	else:
		h = rng.randf_range(table[&"height_min"], table[&"height_max"])
	var floors := maxi(MIN_FLOORS, roundi((h - GROUND_HEIGHT - PARAPET) / FLOOR_HEIGHT))
	h = GROUND_HEIGHT + floors * FLOOR_HEIGHT + PARAPET
	return minf(h, MAX_HEIGHT)


static func _params_for(
	rng: RandomNumberGenerator,
	table: Dictionary,
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
	p[&"lit_ratio"] = clampf(float(table[&"lit_ratio"]) * rng.randf_range(0.7, 1.3), 0.0, 1.0)
	p[&"grime"] = clampf(float(table[&"grime"]) * rng.randf_range(0.8, 1.2), 0.0, 1.0)
	p[&"boarded_ratio"] = table[&"boarded_ratio"]
	p[&"broken_ratio"] = table[&"broken_ratio"]
	p[&"damage"] = table[&"damage"]
	p[&"band_every"] = _pick(rng, table[&"band_every"])
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
