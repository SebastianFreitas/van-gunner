class_name RearDoorDonorBeam
extends RefCounted
## The donor rear leaf's foundation (spec 2): one big fresh-steel I-beam, level along the door
## bottom from the latch corner to the hinge corner, through the leaf's thickness and a few cm
## proud of both faces. Bolt heads on the web make the door's other parts read as attached to it.
## The roofing sheet sits on its top. Hinge-local metres.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")

## Beam bottom above the leaf rect's bottom and overall height.
const LIFT := 0.08
const HEIGHT := 0.175
## Street face (3.5 cm proud of the leaf's street skin, clear of the jamb ring's 2 cm plane; FRONT_Z is the
## hydraulic's lug reference) and cabin face (6 cm proud of its cabin skin).
const FRONT_Z := _LeafBuild.STREET_HALF + 0.02
const BEAM_FRONT_Z := _LeafBuild.STREET_HALF + 0.065
const BACK_Z := _LeafBuild.CABIN_Z - 0.10
## Hinge-local y of the beam's top, relative to the leaf rect's bottom.
const TOP := LIFT + HEIGHT
## The beam is part of the door: each end sits this far in from the leaf's corner, so with the end
## caps' 1 cm overhang it never passes the hinge edge (pillars) or the latch edge (other leaf).
const END_SET := 0.04
const CAP_T := 0.015
## I section: each flange is FLANGE_T thick across the beam, the web WEB_T thick through z, centred.
const FLANGE_T := 0.05
const WEB_T := 0.06
## The web's cabin face sits this far in from the flanges' cabin edge: a dark channel the bolts sit in.
const WEB_SET := 0.07
const BOLT_R := 0.016
const BOLT_H := 0.014
## Bolt spacing along a run and the gap from the run's start to the first bolt.
const BOLT_PITCH := 0.42
const BOLT_LEAD := 0.12
## The hydraulic's mount (spec 3): the hinge-end cap's hinge face (never past the door edge), the
## beam's mid height above the leaf rect's bottom, and the hinge axis' z.
const MOUNT := Vector3(END_SET - 0.005, LIFT + HEIGHT * 0.5, 0.0)
const WEB_ZB := BACK_Z + WEB_SET
const WEB_ZF := WEB_ZB + WEB_T


## The hinge-end mount the hydraulic fits to: the hinge end cap's hinge-side face.
static func hinge_mount(rect: Rect2) -> Vector3:
	return Vector3(MOUNT.x, rect.position.y + MOUNT.y, MOUNT.z)


## Builds the beam under `hinge`; `rect` is the leaf rect. Returns every node added. Its latch end
## is mitred with the edge beam's upright (the welded L), its hinge end carries the mount plate.
static func build(hinge: Node3D, rect: Rect2) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var y0 := rect.position.y + LIFT
	var y1 := y0 + HEIGHT
	var x0 := rect.position.x + END_SET
	var x1 := rect.end.x - END_SET
	var ym := (y0 + y1) * 0.5
	var steel := SurfaceTool.new()
	steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector2(x0, ym)
	var b := Vector2(x1, ym)
	_run(steel, a, Vector2(x1 - HEIGHT * 0.5, ym), Vector2.ZERO, Vector2.ONE.normalized(), true,
			false)
	_commit(hinge, steel, true, out)
	_bolts(hinge, a, b, WEB_ZB, WEB_ZF, [1.0, -1.0], true, out, "DonorBeam", BOLT_LEAD,
			BOLT_LEAD)
	return out


## The upright edge beam of the donor leaf: the bottom beam's section, material, cap and
## bolts turned upright along the hinge-local latch edge, then bent 45 degrees along the latch
## cut (`RearDoorProfile.DONOR_LATCH_CUT`), END_SET inside it. The runs meet on mitre planes
## (each ends on it, no overlap), the upright's foot mitred with the bottom beam. Same z range as the bottom beam, so it shows from outside too. Not collidable.
static func build_edge(hinge: Node3D, rect: Rect2) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var r2 := sqrt(2.0)
	var xo := rect.end.x - END_SET
	var xi := xo - HEIGHT
	var co := rect.end.x + rect.end.y - RearDoorProfile.DONOR_LATCH_CUT - END_SET * r2
	var ci := co - HEIGHT * r2
	var mo := Vector2(xo, co - xo)
	var mi := Vector2(xi, ci - xi)
	var top_y := rect.end.y - END_SET
	var far_o := Vector2(co - top_y, top_y)
	var far_i := far_o - Vector2.ONE * (HEIGHT / r2)
	assert(absf(co - 4.431) < 0.002 and absf(ci - 4.184) < 0.002 and absf(mo.y - 1.783) < 0.002
			and absf(mi.y - 1.711) < 0.002 and absf(far_o.y - 2.01) < 0.002,
			"donor edge beam corners moved")
	var mitre := (mo - mi).normalized()
	var n := Vector2(-mitre.y, mitre.x)
	var y_bottom := rect.position.y + LIFT + HEIGHT
	var mid_up := Vector2((xo + xi) * 0.5, y_bottom)
	var mid_m := (mo + mi) * 0.5
	var mid_far := (far_o + far_i) * 0.5
	var steel := SurfaceTool.new()
	steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The upright starts on the L's mitre, on the bottom beam's centreline.
	var foot := Vector2(mid_up.x, y_bottom - HEIGHT * 0.5)
	_run(steel, foot, mid_m, -Vector2.ONE.normalized(), n, false, false)
	_run(steel, mid_m, mid_far, -n, Vector2.ZERO, false, true)
	_commit(hinge, steel, true, out, "DonorEdgeBeam")
	# Every bolt is present: the straps move to sit between them (`upright_bolt_ys`).
	# One continuous pitch along both runs (the bend carries on the vertical's pattern).
	var up_len := mid_up.distance_to(mid_m)
	var carried := BOLT_LEAD + ceili((up_len - BOLT_LEAD) / BOLT_PITCH) * BOLT_PITCH - up_len
	_bolts(hinge, mid_up, mid_m, WEB_ZB, WEB_ZF, [1.0, -1.0], true, out, "DonorEdgeBeam",
			BOLT_LEAD, 0.0)
	_bolts(hinge, mid_m, mid_far, WEB_ZB, WEB_ZF, [1.0, -1.0], true, out, "DonorEdgeBeam",
			carried)
	return out


## Hinge-local y of each upright bolt, plus one more past the bend (the bend's first bolt, so
## the last strap can sit between two bolts too). Same pitch and lead as `build_edge` lays.
static func upright_bolt_ys(rect: Rect2) -> Array[float]:
	var r2 := sqrt(2.0)
	var xo := rect.end.x - END_SET
	var co := rect.end.x + rect.end.y - RearDoorProfile.DONOR_LATCH_CUT - END_SET * r2
	var ci := co - HEIGHT * r2
	var y_bottom := rect.position.y + LIFT + HEIGHT
	var up_len := ((co - xo) + (ci - (xo - HEIGHT))) * 0.5 - y_bottom
	var ys: Array[float] = []
	var k := 0
	while BOLT_LEAD + (k - 1) * BOLT_PITCH <= up_len:
		ys.append(y_bottom + BOLT_LEAD + k * BOLT_PITCH)
		k += 1
	return ys


## One straight I-beam run p -> q (hinge-local XY centreline, HEIGHT wide, z from BACK_Z to
## BEAM_FRONT_Z) into `st`: a flange along each long edge and the web between them. An end whose
## normal (`np`, `nq`) is zero is square, otherwise it is cut on the plane with that outward
## normal through the end point. `cap_p`/`cap_q` close a square end with a solid plate.
static func _run(st: SurfaceTool, p: Vector2, q: Vector2, np: Vector2, nq: Vector2, cap_p: bool,
		cap_q: bool) -> void:
	var dir := (q - p).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var h := HEIGHT * 0.5
	var p0 := p
	var q0 := q
	if cap_p:
		p0 += dir * CAP_T
		_slab(st, p - dir * 0.005, p0, perp)
	if cap_q:
		q0 -= dir * CAP_T
		_slab(st, q0, q, perp)
	_beam_part(st, p0, q0, dir, perp, np, nq, h - FLANGE_T, h, BACK_Z, BEAM_FRONT_Z)
	_beam_part(st, p0, q0, dir, perp, np, nq, -h, FLANGE_T - h, BACK_Z, BEAM_FRONT_Z)
	_beam_part(st, p0, q0, dir, perp, np, nq, FLANGE_T - h, h - FLANGE_T, WEB_ZB, WEB_ZF)


## The full-section end plate between `a` and `b` (square ends only).
static func _slab(st: SurfaceTool, a: Vector2, b: Vector2, perp: Vector2) -> void:
	var h := perp * (HEIGHT * 0.5)
	_add_prism(st, PackedVector2Array([a - h, b - h, b + h, a + h]), BACK_Z, BEAM_FRONT_Z)


## One slab of the section between perp offsets `o1` and `o2`, z `zb`..`zf`, ends cut like the run's.
static func _beam_part(st: SurfaceTool, p: Vector2, q: Vector2, dir: Vector2, perp: Vector2,
		np: Vector2, nq: Vector2, o1: float, o2: float, zb: float, zf: float) -> void:
	var poly := PackedVector2Array([_cut_at(p, dir, perp * o1, np), _cut_at(q, dir, perp * o1, nq),
			_cut_at(q, dir, perp * o2, nq), _cut_at(p, dir, perp * o2, np)])
	_add_prism(st, poly, zb, zf)


## `add_box` appends indexed meshes, which makes `st` indexed: raw added vertices would be
## dropped, so the prism is built apart, indexed and appended.
static func _add_prism(st: SurfaceTool, poly: PackedVector2Array, zb: float, zf: float) -> void:
	if _area(poly) < 0.0:
		poly.reverse()
	var pt := SurfaceTool.new()
	pt.begin(Mesh.PRIMITIVE_TRIANGLES)
	_prism(pt, poly, zb, zf)
	pt.index()
	st.append_from(pt.commit(), 0, Transform3D.IDENTITY)


## The point at offset `v` from the end `e`, slid along `dir` onto the cut plane of outward normal
## `n` (zero: square).
static func _cut_at(e: Vector2, dir: Vector2, v: Vector2, n: Vector2) -> Vector2:
	var t := 0.0 if n == Vector2.ZERO else -v.dot(n) / dir.dot(n)
	return e + v + dir * t


static func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		var j := (i + 1) % poly.size()
		sum += poly[i].x * poly[j].y - poly[j].x * poly[i].y
	return sum * 0.5


## A convex XY polygon (counter-clockwise from +z) extruded from z `zb` to `zf`, wound clockwise
## outside like Godot's fronts.
static func _prism(st: SurfaceTool, poly: PackedVector2Array, zb: float, zf: float) -> void:
	var n := poly.size()
	var lo := poly[0]
	var hi := poly[0]
	for v in poly:
		lo = lo.min(v)
		hi = hi.max(v)
	var bb := Rect2(lo, (hi - lo).max(Vector2.ONE * 0.001))
	for i in range(1, n - 1):
		_tri(st, Vector3(poly[0].x, poly[0].y, zf), Vector3(poly[i].x, poly[i].y, zf),
				Vector3(poly[i + 1].x, poly[i + 1].y, zf), bb)
		_tri(st, Vector3(poly[0].x, poly[0].y, zb), Vector3(poly[i + 1].x, poly[i + 1].y, zb),
				Vector3(poly[i].x, poly[i].y, zb), bb)
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var a0 := Vector3(a.x, a.y, zb)
		var b0 := Vector3(b.x, b.y, zb)
		var b1 := Vector3(b.x, b.y, zf)
		var a1 := Vector3(a.x, a.y, zf)
		_tri(st, a0, b0, b1, bb, [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
		_tri(st, a0, b1, a1, bb, [Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)])


## One triangle given counter-clockwise seen from outside, emitted clockwise with its normal. UVs
## run 0..1 like a BoxMesh's: over `bb` for the end faces, or the given `uvs` (side faces: along
## the edge, through z), so the grime shader scales it the same as a box.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, bb: Rect2,
		uvs: Array[Vector2] = []) -> void:
	st.set_normal((b - a).cross(c - a).normalized())
	var pts: Array[Vector3] = [a, c, b]
	var order: Array[int] = [0, 2, 1]
	for i in 3:
		var v := pts[i]
		st.set_uv(uvs[order[i]] if not uvs.is_empty()
				else (Vector2(v.x, v.y) - bb.position) / bb.size)
		st.add_vertex(v)


## Adds the run's merged steel mesh as a layer-2 node; `street` also puts it on the
## street-and-interior layers (both beams show from outside).
static func _commit(hinge: Node3D, steel: SurfaceTool, street: bool, out: Array[Node3D],
		prefix := "DonorBeam") -> void:
	var mat := _Panels.grime(Color(0.17, 0.17, 0.18)) as ShaderMaterial
	mat.set_shader_parameter(&"wall_size_m", Vector2(0.5, 0.25))
	mat.set_shader_parameter(&"panel_spacing_m", 40.0)
	mat.set_shader_parameter(&"belt_y_m", 90.0)
	mat.set_shader_parameter(&"waist_y_m", 90.0)
	mat.set_shader_parameter(&"roughness_value", 0.8)
	mat.set_shader_parameter(&"metallic_value", 0.25)
	mat.set_shader_parameter(&"kick_height_m", 0.05)
	mat.set_shader_parameter(&"kick_color", Color(0.2, 0.15, 0.12))
	_Panels.add(hinge, prefix, steel.commit(), mat, Vector3.ZERO, Vector3.ZERO, out)
	if street:
		_street(out.back())


## Hex bolt heads along the run p -> q on the faces `sides` (+1 front at `zf`, -1 back at `zb`),
## so the beam shows as bolted.
static func _bolts(hinge: Node3D, p: Vector2, q: Vector2, zb: float, zf: float,
		sides: Array[float], street: bool, out: Array[Node3D], prefix := "DonorBeam",
		lead := BOLT_LEAD, tail := BOLT_LEAD) -> void:
	var head := CylinderMesh.new()
	head.top_radius = BOLT_R
	head.bottom_radius = BOLT_R
	head.height = BOLT_H
	head.radial_segments = 6
	head.rings = 1
	var rust := _Panels.flat(Color(0.2, 0.17, 0.15), 0.8, 0.3)
	var dir := (q - p).normalized()
	var length := p.distance_to(q)
	var k := 0
	while lead + k * BOLT_PITCH <= length - tail - (1e-4 if tail == 0.0 else 0.0):
		var at := p + dir * (lead + k * BOLT_PITCH)
		k += 1
		for s: float in sides:
			var z := (zf if s > 0.0 else zb) + s * (BOLT_H * 0.5 - 0.002)
			_Panels.add(hinge, prefix + "Bolt", head, rust, Vector3(at.x, at.y, z),
					Vector3(PI * 0.5, 0.0, 0.0), out)
			if street:
				_street(out.back())


static func _street(node: Node3D) -> void:
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	VanLighting.retarget_layers(node as VisualInstance3D, VanLighting.LAYER_STREET_AND_INTERIOR)
