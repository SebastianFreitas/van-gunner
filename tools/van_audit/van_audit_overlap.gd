extends RefCounted
## Coplanar-overlap (flicker), moving-part interpenetration (clip) and door/window
## opening-blocked checks over an AuditMesh triangle set (vanfix spec 1-2). Every func is
## static: this is used as a namespace of pure checks, never instantiated.

const CELL := 0.25
const TOUCH_EPS := 0.002


static func check_clip(tris: RefCounted, runner: Node, state: String, roots: Dictionary) -> void:
	var started := Time.get_ticks_msec()
	var node_root: Dictionary = build_node_roots(tris, roots)
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
	var node_root: Dictionary = build_node_roots(tris, roots)
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


static func build_node_roots(tris: RefCounted, roots: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for idx in range(tris.nodes.size()):
		var node: Node = tris.nodes[idx]
		for label in roots.keys():
			var root: Node = roots[label]
			if root == node or root.is_ancestor_of(node):
				result[idx] = label
				break
	return result
