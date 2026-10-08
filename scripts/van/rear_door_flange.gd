extends RefCounted
## Rear door portal flange: the pressed, rounded edge of the door opening. A sloped band stands
## out from the portal's cabin face toward the leaves and rolls round at its lip, and corner plates
## behind the leaves round the opening off.

## Opening corner radii: the top clearly round, the bottom only slightly.
const RADIUS_TOP := 0.375
const RADIUS_BOTTOM := 0.18
## The band runs from this far outside the opening edge (lip) to this far (wall side).
const LIP_OFFSET := 0.04
const WALL_OFFSET := 0.14
## How far the lip stands out from the portal's cabin face (a 13 cm slope, about 40 degrees).
const STAND_OUT := 0.085
## Offset of the wall-side edge from the portal's cabin face: 0, so it sits flush on it.
const SINK := 0.0
## Opening fills reach this far past the leaf's top and bottom edge, so no face is coplanar.
const FILL_OVER := 0.015
## The top fill reaches up into the header, clear of the right leaf's lip at about 2 cm.
const FILL_TOP := 0.045
## The top fill's arc ends this far above the leaf top, so no arc facet lies on its top face.
const ARC_LIFT := 0.012
## Corner plates stop this far short of the opening edge's bottom line.
const PLATE_DROP := 0.05
const ROLL_R := 0.025
const ROLL_SIDES := 6
const ARC_STEPS := 12
## Corner plate depth offsets from the leaf's hinge plane, clear of the leaf and of the lips.
const PLATE_Z0 := -0.29
const PLATE_Z1 := -0.245
## How far a plate reaches past the opening edge, into the band's lip.
const PLATE_REACH := 0.10


## Adds the band and its rolled lip; `z0` is the portal's cabin face.
static func build(portal: Node3D, mat: Material, half: float, top: float, y_a: float,
		z0: float) -> void:
	var inner := _path(half, top, y_a, LIP_OFFSET)
	var outer := _path(half, top, y_a, WALL_OFFSET)
	var z_in := z0 + SINK - STAND_OUT
	var z_out := z0 + SINK
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg_n: Array[Vector3] = []
	for i in range(inner.size() - 1):
		var a0 := Vector3(inner[i].x, inner[i].y, z_in)
		var b0 := Vector3(inner[i + 1].x, inner[i + 1].y, z_in)
		var c0 := Vector3(outer[i].x, outer[i].y, z_out)
		var n0 := (b0 - a0).cross(c0 - a0).normalized()
		seg_n.append(-n0 if n0.z > 0.0 else n0)
	for i in range(inner.size() - 1):
		var a := Vector3(inner[i].x, inner[i].y, z_in)
		var b := Vector3(inner[i + 1].x, inner[i + 1].y, z_in)
		var c := Vector3(outer[i].x, outer[i].y, z_out)
		var d := Vector3(outer[i + 1].x, outer[i + 1].y, z_out)
		var n := seg_n[i]
		# Averaged along the path so the arcs shade round, not faceted.
		var n_a := seg_n[i] if i == 0 else (seg_n[i - 1] + seg_n[i]).normalized()
		var n_b := seg_n[i] if i == seg_n.size() - 1 else (seg_n[i] + seg_n[i + 1]).normalized()
		_tri(st, [a, b, d], [n_a, n_b, n_b], n)
		_tri(st, [a, d, c], [n_a, n_b, n_a], n)
	for i in range(inner.size() - 1):
		_roll_segment(st, inner, i, z_in)
	_add(portal, mat, st, "FlangeBand")


## Right-hand corner plates (top, bottom) as xy outlines; mirror x for the left side. They sit
## behind the leaves at PLATE_Z0..PLATE_Z1 from the hinge plane.
static func corner_plates(half: float, top: float, y_a: float) -> Array[PackedVector2Array]:
	var r_t := RADIUS_TOP
	var r_b := RADIUS_BOTTOM
	var reach := half + PLATE_REACH
	var t := PackedVector2Array([Vector2(reach, top - r_t)])
	for k in range(ARC_STEPS + 1):
		var a := PI * 0.5 * float(k) / float(ARC_STEPS)
		t.append(Vector2(half - r_t + r_t * cos(a), top - r_t + r_t * sin(a)))
	t.append(Vector2(half - r_t, top + LIP_OFFSET * 2.0))
	t.append(Vector2(reach, top + LIP_OFFSET * 2.0))
	var b := PackedVector2Array([Vector2(reach, y_a - PLATE_DROP)])
	for k in range(ARC_STEPS + 1):
		var a2 := PI * 0.5 * float(k) / float(ARC_STEPS)
		b.append(Vector2(half - r_b + r_b * cos(a2), y_a + r_b - r_b * sin(a2)))
	b.append(Vector2(half - r_b, y_a - PLATE_DROP))
	return [t, b]


## Right-hand fills (top, bottom) that round the opening in the portal steel itself: the square
## corner between the opening and the pillar/header, minus the corner arc. Mirror x for the left.
static func opening_fills(half: float, top: float, y_a: float) -> Array[PackedVector2Array]:
	var x1 := half + 0.02
	# The arc is concentric with the leaf's corner circle but ARC_LIFT wider, so
	# the arc's facets stay clear of the closed leaf's.
	var r_f := RADIUS_TOP + ARC_LIFT
	var cx := half - RADIUS_TOP
	var cy := top - RADIUS_TOP
	var t := PackedVector2Array([Vector2(x1, cy)])
	for k in range(ARC_STEPS + 1):
		var a := PI * 0.5 * float(k) / float(ARC_STEPS)
		t.append(Vector2(cx + r_f * cos(a), cy + r_f * sin(a)))
	t.append(Vector2(cx, top + FILL_TOP))
	t.append(Vector2(x1, top + FILL_TOP))
	var b := PackedVector2Array([Vector2(x1, y_a + RADIUS_BOTTOM)])
	for k in range(ARC_STEPS + 1):
		var a2 := PI * 0.5 * float(k) / float(ARC_STEPS)
		b.append(Vector2(half - RADIUS_BOTTOM + (RADIUS_BOTTOM + ARC_LIFT) * cos(a2),
				y_a + RADIUS_BOTTOM - (RADIUS_BOTTOM + ARC_LIFT) * sin(a2)))
	b.append(Vector2(half - RADIUS_BOTTOM, y_a - FILL_OVER))
	b.append(Vector2(x1, y_a - FILL_OVER))
	return [t, b]


## Open outline of the opening pushed out by `o`: up the left side, over the rounded top corners,
## down the right side.
static func _path(half: float, top: float, y_a: float, o: float) -> PackedVector2Array:
	var r := RADIUS_TOP
	var pts := PackedVector2Array([Vector2(-(half + o), y_a)])
	for k in range(ARC_STEPS + 1):
		var a := PI * 0.5 + PI * 0.5 * float(k) / float(ARC_STEPS)
		pts.append(Vector2(-(half - r) + (r + o) * cos(a), top - r + (r + o) * sin(a)))
	for k in range(ARC_STEPS + 1):
		var a2 := PI * 0.5 * float(ARC_STEPS - k) / float(ARC_STEPS)
		pts.append(Vector2(half - r + (r + o) * cos(a2), top - r + (r + o) * sin(a2)))
	pts.append(Vector2(half + o, y_a))
	return pts


## One stretch of the round lip between path points `i` and `i + 1`.
static func _roll_segment(st: SurfaceTool, path: PackedVector2Array, i: int, z: float) -> void:
	var ring_a := _ring(path, i, z)
	var ring_b := _ring(path, i + 1, z)
	for k in range(ROLL_SIDES):
		var k2 := (k + 1) % ROLL_SIDES
		var da: Vector3 = ring_a[k][0]
		var db: Vector3 = ring_a[k2][0]
		var out := (da + db).normalized()
		# Per-vertex ring directions as normals: the roll shades as one round bead.
		_tri(st, [ring_a[k][1], ring_b[k][1], ring_b[k2][1]],
				[ring_a[k][0], ring_b[k][0], ring_b[k2][0]], out)
		_tri(st, [ring_a[k][1], ring_b[k2][1], ring_a[k2][1]],
				[ring_a[k][0], ring_b[k2][0], ring_a[k2][0]], out)


## Ring of `ROLL_SIDES` entries [outward direction, position] around path point `i`.
static func _ring(path: PackedVector2Array, i: int, z: float) -> Array:
	var prev := path[maxi(i - 1, 0)]
	var next := path[mini(i + 1, path.size() - 1)]
	var t := (next - prev).normalized()
	var across := Vector2(-t.y, t.x)
	var centre := Vector3(path[i].x, path[i].y, z)
	var ring := []
	for k in range(ROLL_SIDES):
		var phi := TAU * float(k) / float(ROLL_SIDES)
		var dir := Vector3(across.x * cos(phi), across.y * cos(phi), sin(phi))
		ring.append([dir, centre + dir * ROLL_R])
	return ring


## One triangle with per-vertex normals `ns`, swapped when needed so it is clockwise seen from
## `out` (Godot's front).
static func _tri(st: SurfaceTool, v: Array[Vector3], ns: Array[Vector3], out: Vector3) -> void:
	var order := [0, 1, 2]
	if (v[1] - v[0]).cross(v[2] - v[0]).dot(out) > 0.0:
		order = [0, 2, 1]
	for k: int in order:
		st.set_normal(ns[k])
		st.set_uv(Vector2(v[k].x / VanInteriorSize.LENGTH + 0.5,
				v[k].y / VanInteriorSize.WALL_HEIGHT))
		st.add_vertex(v[k])


static func _add(parent: Node3D, mat: Material, st: SurfaceTool, node_name: String) -> void:
	var m := MeshInstance3D.new()
	m.name = node_name
	m.mesh = st.commit()
	m.material_override = mat
	parent.add_child(m)
