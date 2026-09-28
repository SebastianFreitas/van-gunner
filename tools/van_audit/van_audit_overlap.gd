extends RefCounted
## Coplanar-overlap (flicker), moving-part interpenetration (clip) and door/window
## opening-blocked checks over an AuditMesh triangle set (vanfix spec 1-2). Every func is
## static: this is used as a namespace of pure checks, never instantiated.

const CELL := 0.25
const NORMAL_DOT := 0.985
const PLANE_EPS := 0.01
const MIN_AREA := 1e-4
const DUP_EPS := 0.001
const TOUCH_EPS := 0.002


static func check_flicker(tris: RefCounted, runner: Node, state: String, only_moving: Dictionary) -> void:
	var started := Time.get_ticks_msec()
	var node_root: Dictionary = {} if only_moving.is_empty() else _build_node_roots(tris, only_moving)
	var grid: Dictionary = tris.build_grid(CELL)
	var n: int = tris.count()
	var seen: Dictionary = {}
	var agg: Dictionary = {}
	for cell in grid.keys():
		var list: PackedInt32Array = grid[cell]
		for ii in range(list.size()):
			for jj in range(ii + 1, list.size()):
				var i: int = mini(list[ii], list[jj])
				var j: int = maxi(list[ii], list[jj])
				var key: int = i * n + j
				if seen.has(key):
					continue
				seen[key] = true
				_flicker_pair(tris, i, j, only_moving, node_root, agg)
	var rows: Array = agg.values()
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.area) > float(y.area))
	for row: Dictionary in rows:
		var at: Vector3 = row.at
		runner.add_finding("FLICKER", "state=%s area=%.5f pairs=%d a=%s b=%s at=(%.3f, %.3f, %.3f)" % [
			state, row.area, row.pairs, row.a, row.b, at.x, at.y, at.z,
		])
	print("AUDIT flicker[%s] (%d ms)" % [state, Time.get_ticks_msec() - started])


static func check_clip(tris: RefCounted, runner: Node, state: String, roots: Dictionary) -> void:
	var started := Time.get_ticks_msec()
	var node_root: Dictionary = _build_node_roots(tris, roots)
	var grid: Dictionary = tris.build_grid(CELL)
	var n: int = tris.count()
	var seen: Dictionary = {}
	var agg: Dictionary = {}
	for cell in grid.keys():
		var list: PackedInt32Array = grid[cell]
		for ii in range(list.size()):
			var i: int = list[ii]
			if not node_root.has(tris.owner_idx[i]):
				continue
			var label: StringName = node_root[tris.owner_idx[i]]
			for jj in range(list.size()):
				if ii == jj:
					continue
				var j: int = list[jj]
				if node_root.get(tris.owner_idx[j], &"") == label:
					continue
				var key: int = i * n + j
				if seen.has(key):
					continue
				seen[key] = true
				_clip_pair(tris, i, j, label, agg)
	for key in agg.keys():
		var row: Dictionary = agg[key]
		var at: Vector3 = row.sum / row.hits
		runner.add_finding("CLIP", "state=%s part=%s a=%s b=%s hits=%d at=(%.3f, %.3f, %.3f)" % [
			state, row.label, row.a, row.b, row.hits, at.x, at.y, at.z,
		])
	print("AUDIT clip[%s] (%d ms)" % [state, Time.get_ticks_msec() - started])


static func check_openings(tris: RefCounted, runner: Node, roots: Dictionary, closed_boxes: Dictionary) -> void:
	var started := Time.get_ticks_msec()
	var node_root: Dictionary = _build_node_roots(tris, roots)
	var agg: Dictionary = {}
	for label in closed_boxes.keys():
		var box: AABB = closed_boxes[label]
		var wall: AABB = AABB(
			box.position + Vector3(-0.08, 0.03, 0.03),
			box.size + Vector3(0.16, -0.06, -0.06),
		)
		for t in range(tris.count()):
			if node_root.get(tris.owner_idx[t], &"") == label:
				continue
			var centroid: Vector3 = (tris.a[t] + tris.b[t] + tris.c[t]) / 3.0
			var inside := wall.has_point(tris.a[t]) or wall.has_point(tris.b[t]) \
				or wall.has_point(tris.c[t]) or wall.has_point(centroid)
			if not inside:
				continue
			var key: String = "%s|%s" % [label, tris.path_of(t)]
			var row: Dictionary = agg.get(key, {"label": label, "node": tris.path_of(t), "tris": 0, "sum": Vector3.ZERO})
			row.tris = int(row.tris) + 1
			row.sum = row.sum + centroid
			agg[key] = row
	var out_keys: Array = agg.keys()
	out_keys.sort()
	for key in out_keys:
		var row: Dictionary = agg[key]
		var at: Vector3 = row.sum / row.tris
		runner.add_finding("OPENING", "open=%s node=%s tris=%d at=(%.3f, %.3f, %.3f)" % [
			row.label, row.node, row.tris, at.x, at.y, at.z,
		])
	print("AUDIT openings (%d ms)" % (Time.get_ticks_msec() - started))


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
	if area <= MIN_AREA:
		return
	var a_path: String = tris.path_of(i)
	var b_path: String = tris.path_of(j)
	var key: String = "%s|%s" % [a_path, b_path] if a_path <= b_path else "%s|%s" % [b_path, a_path]
	var at: Vector3 = (tris.a[i] + tris.b[i] + tris.c[i]) / 3.0
	var row: Dictionary = agg.get(key, {"area": 0.0, "pairs": 0, "a": a_path, "b": b_path, "at": at, "_best": 0.0})
	if area > float(row["_best"]):
		row.at = at
		row["_best"] = area
	row.area = float(row.area) + area
	row.pairs = int(row.pairs) + 1
	agg[key] = row


static func _clip_pair(tris: RefCounted, i: int, j: int, label: StringName, agg: Dictionary) -> void:
	var hit: Variant = _tri_hit(tris, i, j)
	if hit == null:
		return
	var b_path: String = tris.path_of(j)
	var key: String = "%s|%s" % [label, b_path]
	var row: Dictionary = agg.get(key, {"label": label, "a": tris.path_of(i), "b": b_path, "hits": 0, "sum": Vector3.ZERO})
	row.hits = int(row.hits) + 1
	row.sum = row.sum + (hit as Vector3)
	agg[key] = row


static func _tri_hit(tris: RefCounted, i: int, j: int) -> Variant:
	var ai: Vector3 = tris.a[i]
	var bi: Vector3 = tris.b[i]
	var ci: Vector3 = tris.c[i]
	var aj: Vector3 = tris.a[j]
	var bj: Vector3 = tris.b[j]
	var cj: Vector3 = tris.c[j]
	var edges_i: Array = [[ai, bi], [bi, ci], [ci, ai]]
	var edges_j: Array = [[aj, bj], [bj, cj], [cj, aj]]
	for e: Array in edges_i:
		var hit: Variant = Geometry3D.segment_intersects_triangle(e[0], e[1], aj, bj, cj)
		if hit != null and not (_edge_dist_min(hit, ai, bi, ci) < TOUCH_EPS and _edge_dist_min(hit, aj, bj, cj) < TOUCH_EPS):
			return hit
	for e: Array in edges_j:
		var hit: Variant = Geometry3D.segment_intersects_triangle(e[0], e[1], ai, bi, ci)
		if hit != null and not (_edge_dist_min(hit, ai, bi, ci) < TOUCH_EPS and _edge_dist_min(hit, aj, bj, cj) < TOUCH_EPS):
			return hit
	return null


static func _edge_dist_min(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	return minf(_point_segment_dist(p, a, b), minf(_point_segment_dist(p, b, c), _point_segment_dist(p, c, a)))


static func _point_segment_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 1e-12:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _build_node_roots(tris: RefCounted, roots: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for idx in range(tris.nodes.size()):
		var node: Node = tris.nodes[idx]
		for label in roots.keys():
			var root: Node = roots[label]
			if root == node or root.is_ancestor_of(node):
				result[idx] = label
				break
	return result


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
