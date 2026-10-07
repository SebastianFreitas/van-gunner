extends RefCounted
## Rolls the cuts of one surface: survivor lines that run from edge to edge (or end on another
## cut) and later split the surface into donor regions. Polys are surface cm (z, v).

const EXTENTS := {
	&"left_wall": Rect2(-450.0, 0.0, 905.0, 308.0), &"right_wall": Rect2(-450.0, 0.0, 905.0, 308.0),
	&"floor": Rect2(-452.0, -224.0, 908.0, 448.0), &"ceiling": Rect2(-450.0, -200.0, 905.0, 400.0),
}
## Cross cuts keep this far from the surface z ends (walls also keep 10 cm off the door bay).
const MARGIN_CM := 5.0
const DOOR_MARGIN_CM := 10.0
const MAX_ROLLS := 8
## D23 (auto): capped at 8 degrees because signature seed 7 dropped a cut at 15.
const FLOOR_CEIL_MAX_DEG := 8.0
const SURFACE_GAP_CM := 50.0
const BRIDGE_BAND_MAX_CM := 65.0
const _DOOR := [Vector2(-475.5, -10.0), Vector2(-208.5, -10.0), Vector2(-208.5, 320.0),
	Vector2(-475.5, 320.0)]


## {cuts: Array[Dictionary], dropped: int, coin: float}; a cut is {kind, parts, joined, angle, step}.
static func roll_surface(rng: RandomNumberGenerator, surface: StringName, n_donors: int,
		pitches_cm: Array[float], pieces: Array[PackedVector2Array],
		prior_bands: Array[Vector2]) -> Dictionary:
	var wall := surface == &"left_wall" or surface == &"right_wall"
	var count := 0
	if wall:
		count = 0 if rng.randf() < 0.2 else 1 + int(rng.randf() < 0.5)
	else:
		count = int(rng.randf() < 0.5)
	count = mini(count, n_donors - 1)
	var coin := rng.randf()
	var fwd := 0 if coin < 0.5 else n_donors - (count + 1)
	var kinds: Array[StringName] = [&"ANGLED", &"STEPPED", &"TORCH"]
	if wall:
		kinds.append(&"HORIZONTAL")
	var out := {&"cuts": [] as Array[Dictionary], &"dropped": 0, &"coin": coin}
	for _i in count:
		var kind: StringName = kinds[rng.randi_range(0, kinds.size() - 1)]
		var made := {}
		for _try in MAX_ROLLS:
			var cut := _roll_cut(rng, surface, kind, pitches_cm, fwd, out[&"cuts"], pieces)
			if not cut.is_empty():
				cut = _trim(rng, cut, out[&"cuts"])
			var trial: Array = out[&"cuts"].duplicate()
			trial.append(cut)
			if not cut.is_empty() and _valid(cut, surface, out[&"cuts"], pieces, prior_bands) \
					and _steps_ok(trial, pitches_cm, fwd):
				made = cut
				break
		if made.is_empty():
			out[&"dropped"] += 1
		else:
			out[&"cuts"].append(made)
	return out


## Every z interval of a cut that counts for the band rules: the whole z range for the cross
## kinds (a bridged cut's gap included), only the turned ends for HORIZONTAL.
static func bands_of(cut: Dictionary) -> Array[Vector2]:
	var bands: Array[Vector2] = []
	if cut[&"kind"] != &"HORIZONTAL":
		var lo := INF
		var hi := -INF
		for part: PackedVector2Array in cut[&"parts"]:
			for p in part:
				lo = minf(lo, p.x)
				hi = maxf(hi, p.x)
		bands.append(Vector2(lo, hi))
		return bands
	var part: PackedVector2Array = cut[&"parts"][0]
	var run := Vector2(INF, -INF)
	for i in part.size() - 1:
		if absf(part[i + 1].y - part[i].y) > 0.01:
			run = Vector2(minf(run.x, minf(part[i].x, part[i + 1].x)),
				maxf(run.y, maxf(part[i].x, part[i + 1].x)))
		elif run.x < INF:
			bands.append(run)
			run = Vector2(INF, -INF)
	if run.x < INF:
		bands.append(run)
	return bands


## z limits of a cross cut's points on a surface.
static func _z_limits(surface: StringName) -> Vector2:
	var ext: Rect2 = EXTENTS[surface]
	var lo := ext.position.x + MARGIN_CM
	if surface == &"left_wall" or surface == &"right_wall":
		lo = maxf(lo, _DOOR[1].x + DOOR_MARGIN_CM)
	return Vector2(lo, ext.end.x - MARGIN_CM)


static func _mean_z(cut: Dictionary) -> float:
	var lo := INF
	var hi := -INF
	for p: Vector2 in cut[&"joined"]:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
	return (lo + hi) * 0.5


## Cuts on a surface that sit at a lower z than this z (not HORIZONTAL): the donors in front.
static func _behind(cuts: Array, z: float, skip: Dictionary = {}) -> int:
	var n := 0
	for other: Dictionary in cuts:
		if other[&"kind"] != &"HORIZONTAL" and not is_same(other, skip) and _mean_z(other) < z:
			n += 1
	return n


## A STEPPED cut's across length is the rib pitch of the donor in front of it, whatever cuts
## were kept after it was rolled.
static func _steps_ok(cuts: Array, pitches_cm: Array[float], fwd: int) -> bool:
	for cut: Dictionary in cuts:
		if cut[&"kind"] == &"STEPPED":
			var at := clampi(fwd + _behind(cuts, _mean_z(cut), cut), 0, pitches_cm.size() - 1)
			if absf(cut[&"step"] - pitches_cm[at]) > 0.01:
				return false
	return true


static func _roll_cut(rng: RandomNumberGenerator, surface: StringName, kind: StringName,
		pitches_cm: Array[float], fwd: int, kept: Array,
		pieces: Array[PackedVector2Array]) -> Dictionary:
	var ext: Rect2 = EXTENTS[surface]
	var wall := surface == &"left_wall" or surface == &"right_wall"
	var cut :={&"kind": kind, &"angle": 0.0, &"step": 0.0, &"bridged": -1}
	if kind == &"HORIZONTAL":
		cut[&"parts"] = [_horizontal(rng, ext)]
		cut[&"joined"] = cut[&"parts"][0]
		return cut
	var max_deg := 15.0 if wall else FLOOR_CEIL_MAX_DEG
	var length := ext.size.y
	var sgn := 1.0 if rng.randf() < 0.5 else -1.0
	var rel := PackedVector2Array()
	var l1 := 0.0
	match kind:
		&"ANGLED":
			cut[&"angle"] = rng.randf_range(3.0, max_deg) * sgn
			rel = PackedVector2Array([Vector2(0.0, 0.0),
				Vector2(tan(deg_to_rad(cut[&"angle"])) * length, length)])
		&"STEPPED":
			# The pitch needs the donor in front, which needs z0: size the z range with the
			# largest pitch, then rebuild with the real one below.
			l1 = rng.randf_range(40.0, 120.0)
			rel = _stepped(l1, pitches_cm.max() * sgn, length)
		_:
			cut[&"angle"] = rng.randf_range(3.0, 10.0) * sgn
			var slope := tan(deg_to_rad(cut[&"angle"]))
			var end := Vector2(slope * length, length)
			rel.append(Vector2.ZERO)
			var tries := 0
			while rel[rel.size() - 1].distance_to(end) > 15.0:
				# Points sit 8..15 cm apart as 2D distance, jitter included, and 8+ from the end.
				var v := rel[rel.size() - 1].y + rng.randf_range(8.0, 15.0)
				var p := Vector2(slope * v + rng.randf_range(2.0, 5.0) * (1.0 if rng.randf() < 0.5
					else -1.0), v)
				tries += 1
				if tries > 200:
					return {}
				var d := rel[rel.size() - 1].distance_to(p)
				if d >= 8.0 and d <= 15.0 and p.distance_to(end) >= 8.0:
					rel.append(p)
			rel.append(end)
	var lo := INF
	var hi := -INF
	for p in rel:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
	var zlim := _z_limits(surface)
	var z0 := rng.randf_range(zlim.x - lo, zlim.y - hi)
	if kind == &"STEPPED":
		var pitch := pitches_cm[clampi(fwd + _behind(kept, z0), 0, pitches_cm.size() - 1)]
		cut[&"step"] = pitch
		cut[&"angle"] = rad_to_deg(atan(pitch * sgn / length))
		rel = _stepped(l1, pitch * sgn, length)
	var pts := PackedVector2Array()
	for p in rel:
		pts.append(Vector2(z0 + p.x, ext.position.y + p.y))
	cut[&"parts"] = [pts]
	if wall and not VanDonorCutGeometry.bridge(rng, cut, pieces):
		return {}
	var joined := PackedVector2Array()
	for part: PackedVector2Array in cut[&"parts"]:
		joined.append_array(part)
	cut[&"joined"] = joined
	return cut


static func _stepped(l1: float, s: float, length: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, l1), Vector2(s, l1),
		Vector2(s, length)])


## A horizontal run at the low or high band, each end reaching the wall end or turning to the edge.
static func _horizontal(rng: RandomNumberGenerator, ext: Rect2) -> PackedVector2Array:
	var low := rng.randf() < 0.5
	var y := rng.randf_range(45.0, 80.0) if low else rng.randf_range(280.0, 288.0)
	var edge_v := ext.position.y if low else ext.end.y
	var s_edge := rng.randf() < 0.5
	var e_edge := rng.randf() < 0.5
	var zs := ext.position.x if s_edge else rng.randf_range(ext.position.x + 50.0, ext.end.x - 250.0)
	var ze := ext.end.x if e_edge else rng.randf_range(zs + 150.0, ext.end.x - 50.0)
	var pts := PackedVector2Array([Vector2(zs, y), Vector2(ze, y)])
	var tilt := tan(deg_to_rad(rng.randf_range(3.0, 15.0)))
	if not s_edge:
		pts.insert(0, Vector2(zs + tilt * absf(y - edge_v) * (1.0 if rng.randf() < 0.5 else -1.0), edge_v))
	if not e_edge:
		pts.append(Vector2(ze + tilt * absf(y - edge_v) * (1.0 if rng.randf() < 0.5 else -1.0), edge_v))
	return pts


## A single-part cut that crosses one earlier cut ends on it, keeping a random side.
static func _trim(rng: RandomNumberGenerator, cut: Dictionary, existing: Array) -> Dictionary:
	if existing.is_empty() or cut[&"parts"].size() != 1:
		return cut
	var pts: PackedVector2Array = cut[&"parts"][0]
	var found: Array = []
	for other: Dictionary in existing:
		var oj: PackedVector2Array = other[&"joined"]
		for i in pts.size() - 1:
			for j in oj.size() - 1:
				var x: Variant = Geometry2D.segment_intersects_segment(pts[i], pts[i + 1], oj[j], oj[j + 1])
				if x != null:
					found.append([i, x])
	if found.is_empty():
		return cut
	if found.size() > 1:
		return {}
	var at: int = found[0][0]
	var hit: Vector2 = found[0][1]
	var kept := PackedVector2Array()
	if rng.randf() < 0.5:
		kept = pts.slice(0, at + 1)
		kept.append(hit)
	else:
		kept = PackedVector2Array([hit])
		kept.append_array(pts.slice(at + 1))
	cut[&"parts"] = [kept]
	cut[&"joined"] = kept
	return cut


static func _valid(cut: Dictionary, surface: StringName, existing: Array,
		pieces: Array[PackedVector2Array], prior_bands: Array[Vector2]) -> bool:
	var horizontal: bool = cut[&"kind"] == &"HORIZONTAL"
	var wall := surface == &"left_wall" or surface == &"right_wall"
	var zlim := _z_limits(surface)
	for part: PackedVector2Array in cut[&"parts"]:
		for p in part:
			if not horizontal and (p.x < zlim.x - 0.01 or p.x > zlim.y + 0.01):
				return false
		if wall:
			if not Geometry2D.intersect_polyline_with_polygon(part, PackedVector2Array(_DOOR)).is_empty():
				return false
			for i in pieces.size():
				if i == cut[&"bridged"]:
					# The bridge ends touch the outline: test the part 0.5 cm shorter.
					var short := VanDonorCutGeometry.shorten(part, 0.5)
					if not Geometry2D.intersect_polyline_with_polygon(short, pieces[i]).is_empty():
						return false
				elif not VanDonorCutGeometry.clear_of(part, pieces[i]):
					return false
	var bands := bands_of(cut)
	if cut[&"parts"].size() == 2 and bands[0].y - bands[0].x > BRIDGE_BAND_MAX_CM:
		return false
	for band in bands:
		for prior in prior_bands:
			if maxf(band.x, prior.x) - minf(band.y, prior.y) < SURFACE_GAP_CM:
				return false
	var joined: PackedVector2Array = cut[&"joined"]
	for other: Dictionary in existing:
		var oj: PackedVector2Array = other[&"joined"]
		for i in joined.size() - 1:
			for j in oj.size() - 1:
				var x: Variant = Geometry2D.segment_intersects_segment(joined[i], joined[i + 1], oj[j], oj[j + 1])
				if x != null and cut[&"parts"].size() == 2:
					return false
		if other[&"kind"] == cut[&"kind"] and absf(other[&"angle"] - cut[&"angle"]) < 5.0 \
				and absf(other[&"step"] - cut[&"step"]) < 10.0:
			return false
	return true
