extends RefCounted
## Coplanar-overlap (flicker) check over an AuditMesh triangle set, split off
## van_audit_overlap.gd (vanfix specs 1-2, 5-1). Every func is static.

const AuditOverlap := preload("res://tools/van_audit/van_audit_overlap.gd")
const CELL := 0.25
const NORMAL_DOT := 0.985
const PLANE_EPS := 0.01
const AuditExempt := preload("res://tools/van_audit/van_audit_exempt.gd")
const MIN_AREA := 1e-4
## Rows under this total area are slivers nobody sees in play (D47): reported as FLICKER_MINOR.
const MIN_VISIBLE_AREA := 0.005
## Per-pair floor: only numerical slivers, so the row-level MIN_AREA cut can't flip pair counts.
const PAIR_EPS := 1e-6
const DUP_EPS := 0.001


static func check_flicker(tris: RefCounted, runner: Node, state: String, only_moving: Dictionary) -> void:
	var started := Time.get_ticks_msec()
	var node_root: Dictionary = {} if only_moving.is_empty() else AuditOverlap.build_node_roots(tris, only_moving)
	var grid: Dictionary = tris.build_grid(CELL)
	var agg: Dictionary = {}
	var owners: PackedInt32Array = tris.owner_idx
	var lo: PackedVector3Array = tris.tri_lo
	var hi: PackedVector3Array = tris.tri_hi
	var nrm: PackedVector3Array = tris.n
	var gap: float = PLANE_EPS * 2.0
	var moving := PackedByteArray()
	moving.resize(tris.count())
	if not only_moving.is_empty():
		for t in range(tris.count()):
			moving[t] = 1 if node_root.has(owners[t]) else 0
	for cell: Vector3i in grid.keys():
		var list: PackedInt32Array = grid[cell]
		var size: int = list.size()
		for ii in range(size):
			var i0: int = list[ii]
			for jj in range(ii + 1, size):
				var j0: int = list[jj]
				var i: int = mini(i0, j0)
				var j: int = maxi(i0, j0)
				# Visit each pair once: only in the cell holding the min corner of the
				# two triangles' shared cell range.
				if Vector3i((lo[i].max(lo[j]) / CELL).floor()) != cell:
					continue
				if not only_moving.is_empty() and moving[i] == 0 and moving[j] == 0 \
						and owners[i] != owners[j]:
					continue
				if owners[i] != owners[j] and nrm[i].dot(nrm[j]) <= NORMAL_DOT:
					continue
				var sep: Vector3 = lo[i].max(lo[j]) - hi[i].min(hi[j])
				if sep.x > gap or sep.y > gap or sep.z > gap:
					continue
				_flicker_pair(tris, i, j, only_moving, node_root, agg)
	var rows: Array = agg.values()
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.area) > float(y.area) \
		or (float(x.area) == float(y.area) and float(x.total) > float(y.total)))
	for row: Dictionary in rows:
		if float(row.total) <= MIN_AREA:
			continue
		var at: Vector3 = row.at
		var text := "state=%s area=%.5f total=%.5f pairs=%d a=%s b=%s at=(%.3f, %.3f, %.3f)" % [
			state, row.area, row.total, row.pairs, row.a, row.b, at.x, at.y, at.z,
		]
		var rule: Dictionary = AuditExempt.rule_for("FLICKER", row.a, row.b)
		if not rule.is_empty():
			runner.add_finding("FLICKER_EXEMPT", text + " rule=%s" % rule.d)
		elif float(row.area) < MIN_VISIBLE_AREA:
			runner.add_finding("FLICKER_MINOR", text)
		else:
			runner.add_finding("FLICKER", text)
	print("AUDIT flicker[%s] (%d ms)" % [state, Time.get_ticks_msec() - started])


static func _flicker_pair(tris: RefCounted, i: int, j: int, only_moving: Dictionary, node_root: Dictionary, agg: Dictionary) -> void:
	var oi: int = tris.owner_idx[i]
	var oj: int = tris.owner_idx[j]
	var exact := false
	if oi == oj:
		if not _same_triangle(tris, i, j):
			return
		exact = true
	elif not only_moving.is_empty() and not (node_root.has(oi) or node_root.has(oj)):
		return
	if not exact:
		if tris.n[i].dot(tris.n[j]) <= NORMAL_DOT or not _coplanar(tris, i, j):
			return
	var area: float = _tri_area(tris, i) if exact else _overlap_area(tris, i, j)
	if area <= PAIR_EPS:
		return
	var a_path: String = tris.path_of(i)
	var b_path: String = tris.path_of(j)
	var key: String = "%s|%s" % [a_path, b_path] if a_path <= b_path else "%s|%s" % [b_path, a_path]
	var at: Vector3 = (tris.a[i] + tris.b[i] + tris.c[i]) / 3.0
	## Sliver pairs keep a row present (total) but add no visible area (D47).
	var row: Dictionary = agg.get(key, {"area": 0.0, "total": 0.0, "pairs": 0, "a": a_path, "b": b_path, "at": at, "_best": 0.0})
	row.total = float(row.total) + area
	if area > MIN_AREA:
		row.area = float(row.area) + area
	if area > float(row["_best"]):
		row.at = at
		row["_best"] = area
	row.pairs = int(row.pairs) + 1
	agg[key] = row


static func _same_triangle(tris: RefCounted, i: int, j: int) -> bool:
	var pj: Array = [tris.a[j], tris.b[j], tris.c[j]]
	for pv: Vector3 in [tris.a[i], tris.b[i], tris.c[i]]:
		var found := false
		for qv: Vector3 in pj:
			if pv.distance_to(qv) <= DUP_EPS:
				found = true
				break
		if not found:
			return false
	return true


static func _coplanar(tris: RefCounted, i: int, j: int) -> bool:
	for p: Vector3 in [tris.a[j], tris.b[j], tris.c[j]]:
		if absf((p - tris.a[i]).dot(tris.n[i])) > PLANE_EPS:
			return false
	return true


static func _tri_area(tris: RefCounted, t: int) -> float:
	return 0.5 * (tris.b[t] - tris.a[t]).cross(tris.c[t] - tris.a[t]).length()


static func _overlap_area(tris: RefCounted, i: int, j: int) -> float:
	var nrm: Vector3 = tris.n[i]
	var u: Vector3 = nrm.cross(Vector3.UP)
	if u.length_squared() < 1e-8:
		u = nrm.cross(Vector3.RIGHT)
	u = u.normalized()
	var v: Vector3 = nrm.cross(u).normalized()
	var origin: Vector3 = tris.a[i]
	var clip := PackedVector2Array([
		_project(tris.a[i], origin, u, v), _project(tris.b[i], origin, u, v), _project(tris.c[i], origin, u, v),
	])
	var subject := PackedVector2Array([
		_project(tris.a[j], origin, u, v), _project(tris.b[j], origin, u, v), _project(tris.c[j], origin, u, v),
	])
	return _polygon_area(_clip_polygon(subject, _ensure_ccw(clip)))


static func _project(p: Vector3, origin: Vector3, u: Vector3, v: Vector3) -> Vector2:
	var d: Vector3 = p - origin
	return Vector2(d.dot(u), d.dot(v))


static func _ensure_ccw(poly: PackedVector2Array) -> PackedVector2Array:
	if _signed_area2(poly) >= 0.0:
		return poly
	var rev := PackedVector2Array()
	for idx in range(poly.size() - 1, -1, -1):
		rev.append(poly[idx])
	return rev


static func _signed_area2(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for idx in range(poly.size()):
		var p1: Vector2 = poly[idx]
		var p2: Vector2 = poly[(idx + 1) % poly.size()]
		sum += p1.x * p2.y - p2.x * p1.y
	return sum


static func _clip_polygon(subject: PackedVector2Array, clip: PackedVector2Array) -> PackedVector2Array:
	var output := subject
	for k in range(clip.size()):
		if output.is_empty():
			break
		var edge_a: Vector2 = clip[k]
		var edge_b: Vector2 = clip[(k + 1) % clip.size()]
		var input := output
		output = PackedVector2Array()
		for idx in range(input.size()):
			var cur: Vector2 = input[idx]
			var prev: Vector2 = input[(idx - 1 + input.size()) % input.size()]
			var cur_in := _is_left(edge_a, edge_b, cur)
			var prev_in := _is_left(edge_a, edge_b, prev)
			if cur_in:
				if not prev_in:
					output.append(_segment_intersection(prev, cur, edge_a, edge_b))
				output.append(cur)
			elif prev_in:
				output.append(_segment_intersection(prev, cur, edge_a, edge_b))
	return output


static func _is_left(a: Vector2, b: Vector2, p: Vector2) -> bool:
	return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) >= 0.0


static func _segment_intersection(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Vector2:
	var d1: Vector2 = p2 - p1
	var d2: Vector2 = p4 - p3
	var denom: float = d1.x * d2.y - d1.y * d2.x
	if absf(denom) < 1e-12:
		return p2
	var t: float = ((p3.x - p1.x) * d2.y - (p3.y - p1.y) * d2.x) / denom
	return p1 + d1 * t


static func _polygon_area(poly: PackedVector2Array) -> float:
	if poly.size() < 3:
		return 0.0
	return absf(_signed_area2(poly)) * 0.5
