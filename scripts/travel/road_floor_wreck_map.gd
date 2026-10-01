extends RefCounted
## The street's destruction map: one smooth world-space field saying how wrecked the sidewalk is at a point, continuous across corridor tiles and calibrated so DESTROYED_SHARE of it is obliterated.

## Owner's knob: the share of sidewalk that is obliterated (no paving, no curb).
const DESTROYED_SHARE := 0.30
## Simplex features of roughly 14 m.
const FREQUENCY := 0.07
## Added to the field per ruin tier away from 1.5.
const RUIN_BIAS := 0.10
const FRAGMENT_BAND := 0.10
const ROUGH_BAND := 0.25

enum Zone { GOOD, ROUGH, FRAGMENT, GONE }

## Live share; the walk_wreck console command changes it.
static var share := DESTROYED_SHARE

static var _noise: FastNoiseLite = null
static var _noise_seed := -1
## 65 quantiles of the raw noise, so _to_uniform maps it to an even 0..1 spread.
static var _cdf := PackedFloat32Array()


## Signed wreck value at a world XZ point: positive means obliterated, about -1..+0.5.
static func damage(world_xz: Vector2, tier: int) -> float:
	_ensure(_run_seed())
	var u := _to_uniform(_noise.get_noise_2d(world_xz.x, world_xz.y))
	var bias := (clampi(tier, 0, 3) - 1.5) * RUIN_BIAS
	return u + bias - (1.0 - share)


## Unbiased wreck value at a world point: above 0 the walk is gone; about -0.7..+0.3.
static func raw(world_xz: Vector2) -> float:
	_ensure(_run_seed())
	var u := _to_uniform(_noise.get_noise_2d(world_xz.x, world_xz.y))
	return u - (1.0 - share)


## The damage band a wreck value falls in.
static func zone(e: float) -> Zone:
	if e > 0.0:
		return Zone.GONE
	if e > -FRAGMENT_BAND:
		return Zone.FRAGMENT
	if e > -(FRAGMENT_BAND + ROUGH_BAND):
		return Zone.ROUGH
	return Zone.GOOD


## How far into its band a value is toward GONE, 0..1.
static func band_t(e: float) -> float:
	match zone(e):
		Zone.FRAGMENT:
			return clampf(1.0 + e / FRAGMENT_BAND, 0.0, 1.0)
		Zone.ROUGH:
			return clampf(1.0 + (e + FRAGMENT_BAND) / ROUGH_BAND, 0.0, 1.0)
		Zone.GONE:
			return 1.0
	return 0.0


## Crater depth weight, 0..1.
static func crater(e: float) -> float:
	if share <= 0.0:
		return 0.0
	return smoothstep(share * 0.45, share * 0.85, e)


## The vertex colour wreck value for the shader.
static func wreck_tint(e: float) -> float:
	return clampf(1.0 + e / (FRAGMENT_BAND + ROUGH_BAND), 0.0, 1.0)


## Sums the (gone_m, len_m) metas of every tile's RoadFloor; the share is out.x / out.y.
static func measure(corridor_root: Node) -> Vector2:
	var out := Vector2.ZERO
	if corridor_root == null:
		return out
	for child in corridor_root.get_children():
		var floor_node := child.get_node_or_null(^"RoadFloor")
		if floor_node == null:
			continue
		for key in [&"walk_gone_0", &"walk_gone_1"]:
			if floor_node.has_meta(key):
				out += floor_node.get_meta(key) as Vector2
	return out


## Reads the run seed by node path: helpers never name autoloads.
static func _run_seed() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 0
	var gs := tree.root.get_node_or_null(^"GameSession")
	return int(gs.get(&"run_seed")) if gs != null else 0


## Builds the noise for a seed and its quantile table, once per seed.
static func _ensure(seed_value: int) -> void:
	if _noise != null and _noise_seed == seed_value:
		return
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = seed_value
	_noise.frequency = FREQUENCY
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 2
	var samples := PackedFloat32Array()
	for ix in 64:
		for iz in 64:
			samples.append(_noise.get_noise_2d(ix * 9.1 + 0.37, iz * 9.1 + 5.3))
	samples.sort()
	_cdf = PackedFloat32Array()
	for k in 65:
		_cdf.append(samples[int(round(k * 4095.0 / 64.0))])
	_noise_seed = seed_value


## Piecewise-linear inverse of _cdf: raw noise to a uniform 0..1 value.
static func _to_uniform(n: float) -> float:
	if n < _cdf[0]:
		return 0.0
	if n > _cdf[64]:
		return 1.0
	var lo := 0
	var hi := 63
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if _cdf[mid] <= n:
			lo = mid
		else:
			hi = mid - 1
	var k := lo
	if is_equal_approx(_cdf[k], _cdf[k + 1]):
		return k / 64.0
	return (k + inverse_lerp(_cdf[k], _cdf[k + 1], n)) / 64.0
