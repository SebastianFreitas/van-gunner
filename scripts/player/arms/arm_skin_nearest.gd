class_name ArmSkinNearest
extends RefCounted
## Nearest point on the arm skin mesh (bind space) to a query vertex, with the outward
## triangle normal there and the height above it. Static only.


## Triangle numbers (index into `indices` is 3 * n) with at least one vertex within `limit`
## of `centre`. Build once per finger and reuse it for every `nearest` query.
static func prefilter(positions: PackedVector3Array, indices: PackedInt32Array,
		centre: Vector3, limit: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var lim2 := limit * limit
	for t in int(indices.size() / 3.0):
		for k in 3:
			if positions[indices[t * 3 + k]].distance_squared_to(centre) <= lim2:
				out.append(t)
				break
	return out


## Closest point on the listed triangles to `v`: {p, n, s}. n is the unit normal of the
## triangle p lies on, front face clockwise as Godot winds it (the arm mesh's convention),
## s = (v - p) . n. Empty `tris` gives p = v, n = ZERO, s = 0.
static func nearest(positions: PackedVector3Array, indices: PackedInt32Array,
		tris: PackedInt32Array, v: Vector3) -> Dictionary:
	var best_d2 := INF
	var best_p := v
	var best_t := -1
	for t in tris:
		var p := _closest(v, positions[indices[t * 3]], positions[indices[t * 3 + 1]],
				positions[indices[t * 3 + 2]])
		var d2 := v.distance_squared_to(p)
		if d2 < best_d2:
			best_d2 = d2
			best_p = p
			best_t = t
	var n := Vector3.ZERO
	if best_t >= 0:
		var a := positions[indices[best_t * 3]]
		var b := positions[indices[best_t * 3 + 1]]
		var c := positions[indices[best_t * 3 + 2]]
		n = (c - a).cross(b - a).normalized()
	return {&"p": best_p, &"n": n, &"s": (v - best_p).dot(n)}


## Ericson, Real-Time Collision Detection 5.1.5: closest point on triangle abc to p.
static func _closest(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)
