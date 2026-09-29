extends RefCounted
## Seam tests for the van audit EDGE check: open edges that meet other meshes or collinear edges.

const EDGE_WELD := 0.001
## Collinear tolerance for T-junction seam matching.
const SEAM_EPS := 0.002


## True when both ends and the midpoint of an edge each lie within 1.5 cm of some triangle edge
## of a different mesh node (a seam where two meshes meet edge to edge).
static func edge_meets_other_mesh(tris: RefCounted, grid: Dictionary, idx: int, p0: Vector3, p1: Vector3) -> bool:
	for p: Vector3 in [p0, (p0 + p1) * 0.5, p1]:
		var reach := Vector3(0.015, 0.015, 0.015)
		var lo := Vector3i(((p - reach) / 0.25).floor())
		var hi := Vector3i(((p + reach) / 0.25).floor())
		var covered := false
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					var list: PackedInt32Array = grid.get(Vector3i(x, y, z), PackedInt32Array())
					for t in list:
						if tris.owner_idx[t] == idx:
							continue
						if _point_near_tri_edge(p, tris.a[t], tris.b[t], tris.c[t]):
							covered = true
							break
					if covered:
						break
				if covered:
					break
			if covered:
				break
		if not covered:
			return false
	return true


static func _point_near_tri_edge(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	for seg: Array in [[a, b], [b, c], [c, a]]:
		var s0: Vector3 = seg[0]
		var ab: Vector3 = (seg[1] as Vector3) - s0
		var len_sq: float = ab.length_squared()
		var f: float = 0.0 if len_sq < 1e-12 else clampf((p - s0).dot(ab) / len_sq, 0.0, 1.0)
		if p.distance_to(s0 + ab * f) <= 0.015:
			return true
	return false


## An open edge whose whole length lies on other triangles' collinear edges is a T-junction
## seam, not a hole.
static func edge_covered_by_collinear(tris: RefCounted, grid: Dictionary, p0: Vector3, p1: Vector3) -> bool:
	var seg_len := p0.distance_to(p1)
	if seg_len < 1e-6:
		return false
	var dir := (p1 - p0).normalized()
	var pad := Vector3(SEAM_EPS, SEAM_EPS, SEAM_EPS)
	var lo := Vector3i(((p0.min(p1) - pad) / 0.25).floor())
	var hi := Vector3i(((p0.max(p1) + pad) / 0.25).floor())
	var seen: Dictionary = {}
	var spans: Array[Vector2] = []
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var list: PackedInt32Array = grid.get(Vector3i(x, y, z), PackedInt32Array())
				for t in list:
					if seen.has(t):
						continue
					seen[t] = true
					var corners: Array[Vector3] = [tris.a[t], tris.b[t], tris.c[t]]
					for k in 3:
						var q0: Vector3 = corners[k]
						var q1: Vector3 = corners[(k + 1) % 3]
						if _is_same_edge(q0, q1, p0, p1):
							continue
						var span := _collinear_span(q0, q1, p0, dir, seg_len)
						if span.y > span.x:
							spans.append(span)
	spans.sort_custom(func(s: Vector2, o: Vector2) -> bool: return s.x < o.x)
	var reached := 0.0
	for span in spans:
		if span.x > reached + SEAM_EPS:
			return false
		reached = maxf(reached, span.y)
		if reached >= seg_len - SEAM_EPS:
			return true
	return reached >= seg_len - SEAM_EPS


static func _is_same_edge(q0: Vector3, q1: Vector3, p0: Vector3, p1: Vector3) -> bool:
	if q0.distance_to(p0) <= EDGE_WELD and q1.distance_to(p1) <= EDGE_WELD:
		return true
	return q0.distance_to(p1) <= EDGE_WELD and q1.distance_to(p0) <= EDGE_WELD


## The [start, end] interval of edge q0-q1 along the p0 line, clamped to [0, seg_len]; empty
## (end <= start) when the edge isn't parallel to and on that line.
static func _collinear_span(q0: Vector3, q1: Vector3, p0: Vector3, dir: Vector3, seg_len: float) -> Vector2:
	var qd := q1 - q0
	if qd.length() < 1e-6 or absf(dir.dot(qd.normalized())) < 0.999:
		return Vector2.ZERO
	for q: Vector3 in [q0, q1]:
		var rel := q - p0
		if (rel - dir * rel.dot(dir)).length() > SEAM_EPS:
			return Vector2.ZERO
	var t0 := (q0 - p0).dot(dir)
	var t1 := (q1 - p0).dot(dir)
	return Vector2(maxf(minf(t0, t1), 0.0), minf(maxf(t0, t1), seg_len))
