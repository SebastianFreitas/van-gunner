class_name VanFloorPlates
extends RefCounted
## Five scrap plates welded onto the rear floor sheet: donor ribs, weld bead rings, pocket data.

const PLATE_Y0 := -0.02
const PLATE_Y1 := 0.06
const BEAD_Y1 := 0.045
const BEAD_W := 0.04
const BEAD_LEN := 0.06
const BEAD_GAP := 0.01
const BEAD_SINK := 0.02
## The two mid-slab patches: plate y 0.28..0.35, beads to 0.335, no holes.
const MID_Y0 := 0.28
const MID_Y1 := 0.35
## Bead bottom 1.5 cm above the plate bottom so the two bottom faces never coincide (audit FLICKER).
const MID_BEAD_Y0 := 0.295
const MID_BEAD_Y1 := 0.335
## Mid ribs stop this far inside a patch outline.
const MID_RIB_INSET := 0.02
const BEAD_YAW := deg_to_rad(8.0)
## Bead segments start this far from each outline corner so neighbours never overlap.
const BEAD_CORNER := 0.05
const RIB_PITCH := 0.25
const RIB_INSET := 0.02
## Host ribs stop this far inside a plate outline, clear of the bead's sunk inner face (D33).
const HOST_RIB_INSET := 0.03
const HOLE_UNDER := 0.10
const POCKET_GROW := 0.02
## Per plate: donor (B transverse ribs, C 45 degree ribs, D flat checker), tint, seed, width x,
## length z, centre x, centre z, yaw in degrees, hole edge's local outward normal (zero = none),
## cut corner index (0..3 around -x-z, +x-z, +x+z, -x+z; -1 = none), hole length along the edge,
## hole reach past the edge, hole shift along the edge (sign of the world edge direction).
const _TABLE := [
	[&"B", VanFloorSkin.TINT_B, 5.0, 1.2, 0.9, 2.3, 2.3, 4.0, Vector2(0, 1), -1, 0.60, 0.30, -0.06],
	[&"C", VanFloorSkin.TINT_C, 6.0, 0.8, 1.4, -2.4, 3.6, -6.0, Vector2(-1, 0), 2, 0.50, 0.15, 0.0],
	[&"D", VanFloorSkin.TINT_D, 7.0, 1.0, 0.6, 0.3, 4.5, 0.0, Vector2(0, -1), -1, 0.50, 0.15, 0.0],
	[&"B", VanFloorSkin.TINT_E, 8.0, 0.6, 0.6, -1.6, 5.2, 3.0, Vector2.ZERO, -1, 0.0, 0.0, 0.0],
	[&"C", VanFloorSkin.TINT_F, 9.0, 1.5, 0.5, 2.4, 4.9, 0.0, Vector2.ZERO, 0, 0.0, 0.0, 0.0],
]
## Per mid patch, the same columns as `_TABLE` (no hole, no cut corner).
const _MID_TABLE := [
	[&"D", VanFloorSkin.TINT_D, 10.0, 0.7, 0.5, 1.9, -0.6, 0.0, Vector2.ZERO, -1, 0.0, 0.0, 0.0],
	[&"B", VanFloorSkin.TINT_B, 11.0, 0.5, 0.9, -2.2, -0.5, -5.0, Vector2.ZERO, -1, 0.0, 0.0, 0.0],
]


## Adds `Plate1..5` (box, donor ribs) and `Bead1..5` (weld rings) under `parent`.
static func add(parent: Node3D) -> void:
	for k in _TABLE.size():
		var p: Array = _TABLE[k]
		var ring := _outline(p)
		var mat := VanFloorSkin.material(p[1], p[2], 0.95, 1.0)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_prism(st, ring, PLATE_Y0, PLATE_Y1, &"checker" if p[0] == &"D" else &"top", &"edge")
		if p[0] != &"D":
			_add_ribs(st, p, ring)
		_add_mesh(parent, "Plate%d" % (k + 1), st, mat)
		var bst := SurfaceTool.new()
		bst.begin(Mesh.PRIMITIVE_TRIANGLES)
		_add_bead(bst, p, ring, PLATE_Y0, BEAD_Y1)
		_add_mesh(parent, "Bead%d" % (k + 1), bst, mat)


## Adds `M1`, `M2` (box, donor ribs) and `MBead1`, `MBead2` (weld rings) on the mid slab.
static func add_mid(parent: Node3D) -> void:
	for k in _MID_TABLE.size():
		var p: Array = _MID_TABLE[k]
		var ring := _outline(p)
		var mat := VanFloorSkin.material(p[1], p[2], 0.95, 1.0)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_prism(st, ring, MID_Y0, MID_Y1, &"checker" if p[0] == &"D" else &"top", &"edge")
		if p[0] != &"D":
			_add_ribs(st, p, ring, MID_Y1)
		_add_mesh(parent, "M%d" % (k + 1), st, mat)
		var bst := SurfaceTool.new()
		bst.begin(Mesh.PRIMITIVE_TRIANGLES)
		_add_bead(bst, p, ring, MID_BEAD_Y0, MID_BEAD_Y1)
		_add_mesh(parent, "MBead%d" % (k + 1), bst, mat)


## Sorted z intervals a mid-slab rib at `x` may not cover: the patches shrunk 2 cm.
static func mid_rib_blocked(x: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in _MID_TABLE:
		var iv := _clip_line(Vector2(x, 0.0), Vector2(0.0, 1.0), _outline(p), MID_RIB_INSET)
		if iv.x < iv.y:
			out.append(iv)
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return out


## Per hole, the pocket footprint (world xz): the plate's hole length along its edge, 0.10 under
## the plate to its reach past the edge.
static func pocket_polygons() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for p in _TABLE:
		var hole := _hole(p)
		if hole.is_empty():
			continue
		var m: Vector2 = hole[0]
		var u: Vector2 = hole[1]
		var n: Vector2 = hole[2]
		var hl: float = float(hole[3]) * 0.5
		var past: float = hole[4]
		out.append(PackedVector2Array([m - u * hl - n * HOLE_UNDER,
				m + u * hl - n * HOLE_UNDER, m + u * hl + n * past, m - u * hl + n * past]))
	return out


## Sorted z intervals a host rib at `x` may not cover: plates shrunk 2 cm, pockets grown 2 cm past the rib's base edge.
static func rib_blocked(x: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in _TABLE:
		var iv := _clip_line(Vector2(x, 0.0), Vector2(0.0, 1.0), _outline(p), HOST_RIB_INSET)
		if iv.x < iv.y:
			out.append(iv)
	for poly in pocket_polygons():
		var iv := _clip_line(Vector2(x, 0.0), Vector2(0.0, 1.0), Array(poly),
				-(POCKET_GROW + VanFloorSheet.RIB_BASE * 0.5))
		if iv.x < iv.y:
			out.append(iv)
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return out


static func _to_world(p: Array, v: Vector2) -> Vector2:
	var yaw := deg_to_rad(float(p[7]))
	return Vector2(p[5], p[6]) + Vector2(v.x * cos(yaw) + v.y * sin(yaw),
			-v.x * sin(yaw) + v.y * cos(yaw))


static func _dir_to_world(p: Array, v: Vector2) -> Vector2:
	return _to_world(p, v) - _to_world(p, Vector2.ZERO)


## The outline corners in world xz, with the cut corner replaced by two points.
static func _outline(p: Array) -> Array:
	var h := Vector2(p[3], p[4]) * 0.5
	var loc: Array[Vector2] = [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)]
	var ring: Array = []
	for i in 4:
		if i == int(p[9]):
			var prev := loc[(i + 3) % 4]
			var next := loc[(i + 1) % 4]
			ring.append(_to_world(p, loc[i] + (prev - loc[i]).normalized() * 0.2))
			ring.append(_to_world(p, loc[i] + (next - loc[i]).normalized() * 0.2))
		else:
			ring.append(_to_world(p, loc[i]))
	return ring


## [hole centre on the edge, along-edge dir, outward normal, length, reach past] in world xz, or
## empty without a hole.
static func _hole(p: Array) -> Array:
	var n: Vector2 = p[8]
	if n == Vector2.ZERO:
		return []
	var m := _to_world(p, Vector2(n.x * p[3] * 0.5, n.y * p[4] * 0.5))
	var nw := _dir_to_world(p, n)
	var u := Vector2(-nw.y, nw.x)
	return [m + u * float(p[12]), u, nw, float(p[10]), float(p[11])]


static func _centroid(ring: Array) -> Vector2:
	var c := Vector2.ZERO
	for q in ring:
		c += q
	return c / float(ring.size())


## Clips the line `p0 + t * d` to the convex ring moved `inset` inward; returns (t0, t1),
## empty when x >= y. `half` is a rib's half base width: edges the line crosses push the
## inset out by the cap corner's reach, so the whole base ends `inset` inside.
static func _clip_line(p0: Vector2, d: Vector2, ring: Array, inset: float,
		half: float = 0.0) -> Vector2:
	var c := _centroid(ring)
	var t0 := -INF
	var t1 := INF
	var perp := Vector2(-d.y, d.x)
	for i in ring.size():
		var a: Vector2 = ring[i]
		var e: Vector2 = ring[(i + 1) % ring.size()] - a
		var n := Vector2(e.y, -e.x).normalized()
		if n.dot(a - c) < 0.0:
			n = -n
		var num := -inset - n.dot(p0 - a)
		var den := n.dot(d)
		if absf(den) < 0.000001:
			if num < 0.0:
				return Vector2(1.0, 0.0)
		elif den > 0.0:
			t1 = minf(t1, (num - half * absf(perp.dot(n))) / den)
		else:
			t0 = maxf(t0, (num - half * absf(perp.dot(n))) / den)
	return Vector2(t0, t1)


static func _add_ribs(st: SurfaceTool, p: Array, ring: Array, top_y: float = PLATE_Y1) -> void:
	var dir_l := Vector2(1.0, 0.0) if p[0] == &"B" else Vector2(1.0, 1.0).normalized()
	var d := _dir_to_world(p, dir_l)
	var perp := Vector2(-d.y, d.x)
	var c := Vector2(p[5], p[6])
	for k in range(-8, 8):
		var p0 := c + perp * ((k + 0.5) * RIB_PITCH)
		var iv := _clip_line(p0, d, ring, RIB_INSET, VanFloorSheet.RIB_BASE * 0.5)
		if iv.y - iv.x >= 0.05:
			VanFloorSheet.add_rib(st, p0 + d * iv.x, p0 + d * iv.y, top_y)


static func _add_bead(st: SurfaceTool, p: Array, ring: Array, y0: float, y1: float) -> void:
	var c := _centroid(ring)
	var hole := _hole(p)
	var flip := 1.0
	for i in ring.size():
		var a: Vector2 = ring[i]
		var e: Vector2 = ring[(i + 1) % ring.size()] - a
		var edge_len := e.length()
		var u := e / edge_len
		var n := Vector2(u.y, -u.x)
		if n.dot(a - c) < 0.0:
			n = -n
		var count := int((edge_len - 2.0 * BEAD_CORNER + BEAD_GAP) / (BEAD_LEN + BEAD_GAP))
		for j in count:
			var mid := a + u * (BEAD_CORNER + BEAD_LEN * 0.5 + j * (BEAD_LEN + BEAD_GAP)) \
					+ n * (BEAD_W * 0.5 - BEAD_SINK)
			flip = -flip
			if not hole.is_empty():
				var v: Vector2 = mid - hole[0]
				if absf(v.dot(hole[1])) < float(hole[3]) * 0.5 + BEAD_LEN * 0.5 \
						and absf(v.dot(hole[2])) < HOLE_UNDER:
					continue
			var ua := u.rotated(BEAD_YAW * flip)
			var na := Vector2(ua.y, -ua.x) * (1.0 if n.dot(Vector2(ua.y, -ua.x)) > 0.0 else -1.0)
			var seg: Array = [mid - ua * BEAD_LEN * 0.5 - na * BEAD_W * 0.5,
					mid + ua * BEAD_LEN * 0.5 - na * BEAD_W * 0.5,
					mid + ua * BEAD_LEN * 0.5 + na * BEAD_W * 0.5,
					mid - ua * BEAD_LEN * 0.5 + na * BEAD_W * 0.5]
			_prism(st, seg, y0, y1, &"weld", &"weld")


static func _add_mesh(parent: Node3D, node_name: String, st: SurfaceTool, mat: Material) -> void:
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	parent.add_child(mi)


## Appends a closed convex prism over the xz `ring` between y0 and y1.
static func _prism(st: SurfaceTool, ring: Array, y0: float, y1: float, top_tag: StringName,
		side_tag: StringName) -> void:
	var c := _centroid(ring)
	var cnt := ring.size()
	for i in cnt:
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % cnt]
		var out3 := Vector3((a + b).x * 0.5 - c.x, 0.0, (a + b).y * 0.5 - c.y)
		VanFloorSkin.set_tag(st, side_tag)
		VanFloorSheet._quad(st, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y),
				Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), out3)
	for i in range(1, cnt - 1):
		var a: Vector2 = ring[0]
		var b: Vector2 = ring[i]
		var e: Vector2 = ring[i + 1]
		VanFloorSkin.set_tag(st, top_tag)
		_tri(st, Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3(e.x, y1, e.y), Vector3.UP)
		VanFloorSkin.set_tag(st, side_tag)
		_tri(st, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(e.x, y0, e.y), Vector3.DOWN)


## Adds a triangle facing `out`, wound like VanFloorSheet._quad.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var n := (c - b).cross(b - a).normalized()
	var pts: Array[Vector3] = [a, b, c]
	if n.dot(out) < 0.0:
		pts = [c, b, a]
		n = -n
	for q in pts:
		st.set_normal(n)
		st.set_uv(Vector2(q.x + q.z, q.y + q.z * 0.5))
		st.add_vertex(q)
