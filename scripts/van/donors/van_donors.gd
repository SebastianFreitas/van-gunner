class_name VanDonors
extends RefCounted
## Pure function of the van seed: picks the donor vans, rolls the six windows, then cuts the
## walls, floor and ceiling into donor regions. Never reads the interior builder or a node.

const _DONOR_PATHS: Array[String] = [
	"res://resources/van/donors/flat_blue.tres",
	"res://resources/van/donors/hvan_olive.tres",
	"res://resources/van/donors/sprinter_grey.tres",
	"res://resources/van/donors/transit_red.tres",
]
const _SURFACES: Array[StringName] = [&"left_wall", &"right_wall", &"floor", &"ceiling"]
const _Cuts := preload("res://scripts/van/donors/van_donor_cuts.gd")
const _Windows := preload("res://scripts/van/donors/van_donor_windows.gd")


static func roll(look: VanLook) -> VanDonorSet:
	return roll_seed(look.van_seed)


static func roll_seed(van_seed: int) -> VanDonorSet:
	var dset := VanDonorSet.new()
	dset.donors = _pick_donors(van_seed)
	dset.windows = _Windows.roll(van_seed)
	var pitches: Array[float] = []
	for d in dset.donors:
		pitches.append(d.rib_pitch_m * 100.0)
	var prior_bands: Array[Vector2] = []
	for surface in _SURFACES:
		var pieces: Array[PackedVector2Array] = []
		for w in dset.windows:
			if w[&"surface"] == surface:
				pieces.append(w[&"piece_outline"])
		var rng := VanLook.rng_for_seed(van_seed, StringName("kit/regions/" + String(surface)))
		var res := _Cuts.roll_surface(rng, surface, dset.donors.size(), pitches, pieces, prior_bands)
		var cuts: Array = res[&"cuts"]
		dset.dropped_cuts += res[&"dropped"]
		for cut: Dictionary in cuts:
			prior_bands.append_array(_Cuts.bands_of(cut))
		_split(dset, surface, cuts, res[&"coin"])
	return dset


static func _pick_donors(van_seed: int) -> Array[VanDonor]:
	var pool: Array[VanDonor] = []
	for path in _DONOR_PATHS:
		pool.append(load(path) as VanDonor)
	pool.sort_custom(func(a: VanDonor, b: VanDonor) -> bool: return String(a.id) < String(b.id))
	var rng := VanLook.rng_for_seed(van_seed, &"donors")
	var out: Array[VanDonor] = []
	for _i in rng.randi_range(2, 4):
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


## Splits the surface rectangle by its cuts and gives the regions donors in front-to-back order.
static func _split(dset: VanDonorSet, surface: StringName, cuts: Array, coin: float) -> void:
	var rect: Rect2 = _Cuts.EXTENTS[surface]
	var polys: Array[PackedVector2Array] = [PackedVector2Array([rect.position,
		Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])]
	for cut: Dictionary in cuts:
		var joined: PackedVector2Array = cut[&"joined"]
		var ext := joined.duplicate()
		ext.insert(0, joined[0] + (joined[0] - joined[1]).normalized() * 20.0)
		ext.append(joined[-1] + (joined[-1] - joined[-2]).normalized() * 20.0)
		var ribbon := Geometry2D.offset_polyline(ext, 0.005, Geometry2D.JOIN_MITER,
			Geometry2D.END_BUTT)
		var mid := _mid_point(joined)
		for i in polys.size():
			if Geometry2D.is_point_in_polygon(mid, polys[i]) and not ribbon.is_empty():
				var parts := Geometry2D.clip_polygons(polys[i], ribbon[0])
				parts = parts.filter(func(p: PackedVector2Array) -> bool:
					return not Geometry2D.is_polygon_clockwise(p))
				if parts.size() > 1:
					polys.remove_at(i)
					polys.append_array(parts)
				break
	var horizontals: Array[float] = []
	for cut: Dictionary in cuts:
		if cut[&"kind"] == &"HORIZONTAL":
			horizontals.append(_mid_point(cut[&"joined"]).y)
	var keyed: Array = []
	for poly in polys:
		var c := _centroid(poly)
		var above := 0
		for y in horizontals:
			above += int(c.y > y)
		keyed.append([above, c.x, poly])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var n := dset.donors.size()
	var start := 0 if coin < 0.5 else n - keyed.size()
	var ordered: Array[PackedVector2Array] = []
	for i in keyed.size():
		var poly: PackedVector2Array = keyed[i][2]
		ordered.append(poly)
		dset.regions.append({&"surface": surface, &"outline": poly,
			&"donor_id": dset.donors[start + i].id})
	for cut: Dictionary in cuts:
		var sides := _sides(cut[&"joined"], ordered)
		dset.boundaries.append({&"surface": surface, &"kind": cut[&"kind"], &"parts": cut[&"parts"],
			&"donor_a": dset.donors[start + sides.x].id, &"donor_b": dset.donors[start + sides.y].id,
			&"z_band": _band(cut)})


## Indices (in the ordered list) of the regions either side of a cut.
static func _sides(joined: PackedVector2Array, ordered: Array[PackedVector2Array]) -> Vector2i:
	var best := 0
	for i in joined.size() - 1:
		if joined[i].distance_to(joined[i + 1]) > joined[best].distance_to(joined[best + 1]):
			best = i
	var mid := joined[best].lerp(joined[best + 1], 0.5)
	var nrm := (joined[best + 1] - joined[best]).orthogonal().normalized() * 0.5
	var found: Array[int] = []
	for off in [nrm, -nrm]:
		for i in ordered.size():
			if Geometry2D.is_point_in_polygon(mid + off, ordered[i]):
				found.append(i)
				break
	if found.size() < 2:
		return Vector2i(0, 0)
	return Vector2i(mini(found[0], found[1]), maxi(found[0], found[1]))


static func _band(cut: Dictionary) -> Vector2:
	var bands := _Cuts.bands_of(cut)
	if bands.is_empty():
		return Vector2(INF, -INF)
	var out := bands[0]
	for b in bands:
		out = Vector2(minf(out.x, b.x), maxf(out.y, b.y))
	return out


static func _mid_point(joined: PackedVector2Array) -> Vector2:
	var best := 0
	for i in joined.size() - 1:
		if joined[i].distance_to(joined[i + 1]) > joined[best].distance_to(joined[best + 1]):
			best = i
	return joined[best].lerp(joined[best + 1], 0.5)


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / poly.size()
