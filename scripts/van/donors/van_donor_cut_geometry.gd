extends RefCounted
class_name VanDonorCutGeometry
## Static geometry for the cut roller: window bridging, outline clearance and ray or edge lookups.

## A cut that does not bridge a window piece stays this far from its outline.
const PIECE_CLEAR_CM := 2.0


## Walls: the line ends on a window piece's bottom edge and resumes from its top edge.
static func bridge(rng: RandomNumberGenerator, cut: Dictionary,
		pieces: Array[PackedVector2Array]) -> bool:
	var pts: PackedVector2Array = cut[&"parts"][0]
	var hits := 0
	for i in pieces.size():
		var piece := pieces[i]
		var box := Rect2(piece[0], Vector2.ZERO)
		for p in piece:
			box = box.expand(p)
		var za := z_at(pts, box.position.y)
		var zb := z_at(pts, box.end.y)
		if maxf(za, zb) < box.position.x or minf(za, zb) > box.end.x:
			continue
		hits += 1
		# Both ends stay 10 cm inside the straight bottom and top edges, off the corner arcs.
		var span_lo := edge_span(piece, box.position.y)
		var span_hi := edge_span(piece, box.end.y)
		if hits > 1 or za < span_lo.x + 10.0 or za > span_lo.y - 10.0 \
				or span_hi.x + 10.0 > span_hi.y - 10.0:
			return false
		var zt := clampf(za + rng.randf_range(-30.0, 30.0), span_hi.x + 10.0, span_hi.y - 10.0)
		var yb := ray_y(piece, za, true)
		var yt := ray_y(piece, zt, false)
		var lower := PackedVector2Array()
		var upper := PackedVector2Array([Vector2(zt, yt)])
		for p in pts:
			if p.y < yb - 0.001:
				lower.append(p)
			elif p.y > yt + 0.001:
				upper.append(Vector2(p.x + zt - zb, p.y))
		lower.append(Vector2(za, yb))
		cut[&"parts"] = [lower, upper]
		cut[&"bridged"] = i
	return true


## z range of the outline points on its straight bottom (y = the box min) or top edge.
static func edge_span(piece: PackedVector2Array, y: float) -> Vector2:
	var span := Vector2(INF, -INF)
	for p in piece:
		if absf(p.y - y) < 0.5:
			span = Vector2(minf(span.x, p.x), maxf(span.y, p.x))
	return span


## y where a vertical ray at z meets the outline: the lowest crossing, or the highest.
static func ray_y(piece: PackedVector2Array, z: float, lowest: bool) -> float:
	var best := INF if lowest else -INF
	for i in piece.size():
		var a := piece[i]
		var b := piece[(i + 1) % piece.size()]
		if (a.x - z) * (b.x - z) <= 0.0 and a.x != b.x:
			var y := lerpf(a.y, b.y, (z - a.x) / (b.x - a.x))
			best = minf(best, y) if lowest else maxf(best, y)
	return best


static func z_at(pts: PackedVector2Array, v: float) -> float:
	for i in pts.size() - 1:
		if pts[i + 1].y > pts[i].y and v >= pts[i].y and v <= pts[i + 1].y:
			return lerpf(pts[i].x, pts[i + 1].x, (v - pts[i].y) / (pts[i + 1].y - pts[i].y))
	return pts[pts.size() - 1].x


## The part cut short by d at both ends, so an end touching an outline does not count.
static func shorten(part: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := part.duplicate()
	var n := out.size()
	out[0] = out[0].move_toward(out[1], d)
	out[n - 1] = out[n - 1].move_toward(out[n - 2], d)
	return out


## Whether every segment of the part is at least PIECE_CLEAR_CM from the outline.
static func clear_of(part: PackedVector2Array, outline: PackedVector2Array) -> bool:
	if not Geometry2D.intersect_polyline_with_polygon(part, outline).is_empty():
		return false
	for i in part.size() - 1:
		for j in outline.size():
			var c := Geometry2D.get_closest_points_between_segments(part[i], part[i + 1],
				outline[j], outline[(j + 1) % outline.size()])
			if c[0].distance_to(c[1]) < PIECE_CLEAR_CM:
				return false
	return true
