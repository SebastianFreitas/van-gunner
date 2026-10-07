class_name VanKitRulesLines
extends RefCounted
## Rules check, cut and line groups: per-surface cuts, donor order and the boundary lines.

const _Cuts := preload("res://scripts/van/donors/van_donor_cuts.gd")
const BREAK := "VAN KIT RULE BREAK: "
const _SURFACES: Array[StringName] = [&"left_wall", &"right_wall", &"floor", &"ceiling"]
const _DOOR_BAY_CM := Vector2(-475.5, -208.5)
const _ANGLE_TOL := 0.3


## `placed` adds the wall and ceiling skin panels' z ends as factory edges to the gap rules.
static func check(dset: VanDonorSet, placed: Array[VanKitPlaced]) -> PackedStringArray:
	var out := PackedStringArray()
	for surface in _SURFACES:
		var cuts: Array[Dictionary] = []
		for b in dset.boundaries:
			if b[&"surface"] == surface:
				cuts.append(b)
		var regions: Array[Dictionary] = []
		for r in dset.regions:
			if r[&"surface"] == surface:
				regions.append(r)
		_surface(dset, surface, cuts, regions, out)
	var lines: Array[Dictionary] = []
	lines.append_array(dset.boundaries)
	lines.append_array(_panel_edges(placed))
	_gaps(lines, out, false)
	return out


## One vertical part at each factory panel edge: the hi and/or lap-side lo z end of every panel the
## skin pass tagged. Clip ends against ribs, fixtures, gaps and holes are not tagged.
static func _panel_edges(placed: Array[VanKitPlaced]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in placed:
		if p.def_id != VanKitSkin.PANEL:
			continue
		var both := p.reason == VanKitSkin.PANEL_EDGE_BOTH
		var hi_edge := both or p.reason == VanKitSkin.PANEL_EDGE
		var lo_edge := both or p.reason == VanKitSkin.PANEL_EDGE_LO
		if not hi_edge and not lo_edge:
			continue
		var z0 := INF
		var z1 := -INF
		var v0 := INF
		var v1 := -INF
		for pt in p.outline:
			z0 = minf(z0, pt.x)
			z1 = maxf(z1, pt.x)
			v0 = minf(v0, pt.y)
			v1 = maxf(v1, pt.y)
		for z in ([z1] if hi_edge else []) + ([z0] if lo_edge else []):
			out.append({&"surface": p.surface, &"kind": &"PANEL", &"parts": [
				PackedVector2Array([Vector2(z, v0), Vector2(z, v1)])]})
	return out


## Break-line name of a boundary: its index among the cuts, or "panel edge" for a skin edge.
static func _name(bound: Dictionary, i: int) -> String:
	return "panel edge" if bound[&"kind"] == &"PANEL" else "cut %d" % i


static func _surface(dset: VanDonorSet, surface: StringName, cuts: Array[Dictionary],
		regions: Array[Dictionary], out: PackedStringArray) -> void:
	var n := dset.donors.size()
	if cuts.size() > n - 1:
		out.append(BREAK + "cuts %s: %d cuts with %d donors" % [surface, cuts.size(), n])
	if regions.size() != cuts.size() + 1:
		out.append(BREAK + "regions %s: %d regions for %d cuts" % [surface, regions.size(), cuts.size()])
	_order(dset, surface, regions, out)
	var wall := surface == &"left_wall" or surface == &"right_wall"
	var max_deg := 15.0 if wall else _Cuts.FLOOR_CEIL_MAX_DEG
	for i in cuts.size():
		var cut := cuts[i]
		var kind: StringName = cut[&"kind"]
		var tag := "%s cut %d %s" % [surface, i, kind]
		if kind == &"ANGLED" or kind == &"TORCH":
			var deg := absf(_angle(cut))
			if deg < 3.0 - _ANGLE_TOL or deg > max_deg + _ANGLE_TOL:
				out.append(BREAK + "angle %s: %.2f deg outside 3..%.0f" % [tag, deg, max_deg])
		if wall:
			_wall_cut(dset, cut, tag, out)
		for j in i:
			var other := cuts[j]
			if other[&"kind"] == kind and absf(_angle(other) - _angle(cut)) < 5.0 \
					and absf(_step(other) - _step(cut)) < 10.0:
				out.append(BREAK + "alike %s and cut %d" % [tag, j])


static func _wall_cut(dset: VanDonorSet, cut: Dictionary, tag: String,
		out: PackedStringArray) -> void:
	var parts: Array = cut[&"parts"]
	if cut[&"kind"] != &"HORIZONTAL" and parts.size() == 1:
		var band: Vector2 = _Cuts.bands_of(cut)[0] * 0.01
		if not VanKitFootprint.in_free_band(band.x, band.y):
			out.append(BREAK + "free band %s z %.3f..%.3f is outside the free bands" % [
				tag, band.x, band.y])
	for part: PackedVector2Array in parts:
		if not Geometry2D.intersect_polyline_with_polygon(part, PackedVector2Array([
				Vector2(_DOOR_BAY_CM.x, -10.0), Vector2(_DOOR_BAY_CM.y, -10.0),
				Vector2(_DOOR_BAY_CM.y, 320.0), Vector2(_DOOR_BAY_CM.x, 320.0)])).is_empty():
			out.append(BREAK + "door bay %s enters the bay + 10 cm" % tag)
		for w in dset.windows:
			var piece: PackedVector2Array = w[&"piece_outline"]
			if w[&"surface"] != cut[&"surface"] or piece.is_empty():
				continue
			var hit := false
			if parts.size() == 2:
				hit = not Geometry2D.intersect_polyline_with_polygon(
					VanDonorCutGeometry.shorten(part, 0.5), piece).is_empty()
			else:
				hit = not VanDonorCutGeometry.clear_of(part, piece)
			if hit:
				out.append(BREAK + "window piece %s crosses %s" % [tag, w[&"window_id"]])


## Regions sorted as the roller sorts them take consecutive donors from the first or to the last.
static func _order(dset: VanDonorSet, surface: StringName, regions: Array[Dictionary],
		out: PackedStringArray) -> void:
	if regions.is_empty():
		return
	var ids: Array[int] = []
	for r in regions:
		for i in dset.donors.size():
			if dset.donors[i].id == r[&"donor_id"]:
				ids.append(i)
	var start := ids[0] if ids.size() == regions.size() else -1
	var ok := start == 0 or start + regions.size() == dset.donors.size()
	for i in ids.size():
		ok = ok and ids[i] == start + i
	if not ok:
		out.append(BREAK + "donor order %s: donors %s" % [surface, ids])


## Angle off the cross direction (deg) from the lower or only part's chord.
static func _angle(cut: Dictionary) -> float:
	if cut[&"kind"] == &"HORIZONTAL":
		return 0.0
	var part: PackedVector2Array = cut[&"parts"][0]
	var d := part[part.size() - 1] - part[0]
	return rad_to_deg(atan2(d.x, d.y))


## The across length of a STEPPED cut (its longest z jump), 0 for the other kinds.
static func _step(cut: Dictionary) -> float:
	if cut[&"kind"] != &"STEPPED":
		return 0.0
	var part: PackedVector2Array = cut[&"parts"][0]
	var best := 0.0
	for i in part.size() - 1:
		best = maxf(best, absf(part[i + 1].x - part[i].x))
	return best


## Bands on different surfaces keep 0.5 m (`pair_panels` false: factory panel edges exempt), and
## no 3 surfaces within 0.30 m or 4 within 0.5 m.
static func _gaps(bounds: Array[Dictionary], out: PackedStringArray,
		pair_panels := true) -> void:
	var bands: Array[Dictionary] = []
	for i in bounds.size():
		for band in _Cuts.bands_of(bounds[i]):
			bands.append({&"i": i, &"surface": bounds[i][&"surface"], &"band": band,
				&"panel": bounds[i][&"kind"] == &"PANEL"})
	for i in bands.size():
		for j in i:
			if bands[i][&"surface"] == bands[j][&"surface"] \
					or (not pair_panels and (bands[i][&"panel"] or bands[j][&"panel"])):
				continue
			var a: Vector2 = bands[i][&"band"]
			var b: Vector2 = bands[j][&"band"]
			if maxf(a.x, b.x) - minf(a.y, b.y) < _Cuts.SURFACE_GAP_CM:
				out.append(BREAK + "band gap %s %s and %s %s under 0.5 m" % [
					bands[i][&"surface"], _name(bounds[bands[i][&"i"]], bands[i][&"i"]),
					bands[j][&"surface"], _name(bounds[bands[j][&"i"]], bands[j][&"i"])])
	for probe: Dictionary in bands:
		var label := _name(bounds[probe[&"i"]], probe[&"i"])
		var band: Vector2 = probe[&"band"]
		for z in [band.x, band.y]:
			for reach in [[30.0, 3], [50.0, 4]]:
				var near := {}
				for other: Dictionary in bands:
					var ob: Vector2 = other[&"band"]
					if z >= ob.x - reach[0] and z <= ob.y + reach[0]:
						near[other[&"surface"]] = true
				if near.size() >= reach[1]:
					out.append(BREAK + "crowd at z %.0f (%s): %d surfaces within %.0f cm" % [
						z, label, near.size(), reach[0]])
