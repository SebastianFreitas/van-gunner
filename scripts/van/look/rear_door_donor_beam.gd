class_name RearDoorDonorBeam
extends RefCounted
## The donor rear leaf's foundation (spec 2): one big fresh-steel rectangular box beam, level along
## the door bottom from the latch corner to the hinge corner, through the leaf's thickness and a
## few cm proud of both faces. Weld beads on its top edges and bolt heads on both faces make the
## door's other parts read as attached to it. The roofing sheet sits on its top. Hinge-local metres.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Welds := preload("res://scripts/van/look/rear_door_donor_welds.gd")

## Beam bottom above the leaf rect's bottom and overall height.
const LIFT := 0.08
const HEIGHT := 0.175
## Street face (3.5 cm proud of the leaf's street skin, clear of the jamb ring's 2 cm plane; FRONT_Z is the
## hydraulic's lug reference) and cabin face (6 cm proud of its cabin skin).
const FRONT_Z := _LeafBuild.STREET_HALF + 0.02
const BEAM_FRONT_Z := _LeafBuild.STREET_HALF + 0.065
const BACK_Z := _LeafBuild.CABIN_Z - 0.06
## The edge beam's cabin-side box ends 5 mm proud of the cabin skin.
const EDGE_FRONT_Z := _LeafBuild.CABIN_Z + 0.005
## Hinge-local y of the beam's top, relative to the leaf rect's bottom.
const TOP := LIFT + HEIGHT
## The beam is part of the door: each end sits this far in from the leaf's corner, so with the end
## caps' 1 cm overhang it never passes the hinge edge (pillars) or the latch edge (other leaf).
const END_SET := 0.04
const CAP_T := 0.015
const BOLT_R := 0.016
const BOLT_H := 0.014
## The edge beam's bigger cabin bolts and the 45-degree lit lip on its inner (lamp-side) edge.
const EDGE_BOLT_R := 0.028
const EDGE_BOLT_H := 0.02
const EDGE_CHAMFER := 0.03
## The hydraulic's mount (spec 3): the hinge-end cap's hinge face (never past the door edge), the
## beam's mid height above the leaf rect's bottom, and the hinge axis' z.
const MOUNT := Vector3(END_SET - 0.005, LIFT + HEIGHT * 0.5, 0.0)


## The hinge-end mount the hydraulic fits to: the hinge end cap's hinge-side face.
static func hinge_mount(rect: Rect2) -> Vector3:
	return Vector3(MOUNT.x, rect.position.y + MOUNT.y, MOUNT.z)


## Builds the beam under `hinge`; `rect` is the leaf rect. Returns every node added.
static func build(hinge: Node3D, rect: Rect2) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var y0 := rect.position.y + LIFT
	var y1 := y0 + HEIGHT
	var x0 := rect.position.x + END_SET
	var x1 := rect.end.x - END_SET
	var ym := (y0 + y1) * 0.5
	var steel := SurfaceTool.new()
	steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	var beads := SurfaceTool.new()
	beads.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector2(x0, ym)
	var b := Vector2(x1, ym)
	_run(steel, a, b, Vector2.ZERO, Vector2.ZERO, BACK_Z, BEAM_FRONT_Z, true, true)
	# Diamond beads sunk into the joins (no bead face parallel to a beam face): the top face to
	# the leaf's street skin and to its cabin skin, and the street edge of the hinge-side cap.
	_corner(beads, Vector3(0.03, y1, _LeafBuild.STREET_HALF),
			Vector3(x1 - 0.04, y1, _LeafBuild.STREET_HALF))
	_corner(beads, Vector3(0.03, y1, _LeafBuild.CABIN_Z), Vector3(x1 - 0.04, y1, _LeafBuild.CABIN_Z))
	_commit(hinge, steel, beads, true, out)
	_bolts(hinge, a, b, BACK_Z, BEAM_FRONT_Z, [1.0, -1.0], true, out)
	return out


## The upright edge beam of the donor leaf: the bottom beam's section, material, caps, beads and
## bolts turned upright along the hinge-local latch edge, then bent 45 degrees along the latch
## cut (`RearDoorProfile.DONOR_LATCH_CUT`), END_SET inside it. The two runs meet on a mitre plane
## (each ends on it, no overlap). Cabin side only, z BACK_Z to EDGE_FRONT_Z. Not collidable.
static func build_edge(hinge: Node3D, rect: Rect2, strap_y: Array[float] = [],
		strap_half := 0.0) -> Array[Node3D]:
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
	var beads := SurfaceTool.new()
	beads.begin(Mesh.PRIMITIVE_TRIANGLES)
	_run(steel, mid_up, mid_m, Vector2.ZERO, n, BACK_Z, EDGE_FRONT_Z, false, false, EDGE_CHAMFER)
	_run(steel, mid_m, mid_far, -n, Vector2.ZERO, BACK_Z, EDGE_FRONT_Z, false, true, EDGE_CHAMFER)
	# Beads where each run's side faces meet the cabin skin (none across the mitre: one solid L).
	var skin := _LeafBuild.CABIN_Z
	_corner(beads, Vector3(xo, y_bottom, skin), Vector3(mo.x, mo.y, skin))
	_corner(beads, Vector3(xi, y_bottom, skin), Vector3(mi.x, mi.y, skin))
	_corner(beads, Vector3(mo.x, mo.y, skin), Vector3(far_o.x, far_o.y, skin))
	_corner(beads, Vector3(mi.x, mi.y, skin), Vector3(far_i.x, far_i.y, skin))
	_commit(hinge, steel, beads, false, out, "DonorEdgeBeam")
	# Bolt caps share the strap face legs' plane, so a bolt under a strap's y band is skipped.
	_bolts(hinge, mid_up, mid_m, BACK_Z, EDGE_FRONT_Z, [-1.0], false, out, "DonorEdgeBeam",
			strap_y, strap_half,
			EDGE_BOLT_R, EDGE_BOLT_H)
	_bolts(hinge, mid_m, mid_far, BACK_Z, EDGE_FRONT_Z, [-1.0], false, out, "DonorEdgeBeam",
			[], 0.0, EDGE_BOLT_R, EDGE_BOLT_H)
	return out


## One straight run p -> q (hinge-local XY centreline, HEIGHT thick, z from `zb` to `zf`) into
## `st`. An end whose normal (`np`, `nq`) is zero is square, otherwise it is cut on the plane with
## that outward normal through the end point. `cap_p`/`cap_q` weld on the end plates (square ends).
## `chamfer` > 0 cuts a 45-degree lip that wide off the cabin face's +perp edge (the inner edge,
## facing the cabin lamps).
static func _run(st: SurfaceTool, p: Vector2, q: Vector2, np: Vector2, nq: Vector2, zb: float,
		zf: float, cap_p: bool, cap_q: bool, chamfer := 0.0) -> void:
	var dir := (q - p).normalized()
	var depth := zf - zb
	var zc := (zf + zb) * 0.5
	var angle := dir.angle()
	if chamfer > 0.0:
		_chamfer_prism(st, p, q, np, nq, zb, zf, chamfer)
	elif np == Vector2.ZERO and nq == Vector2.ZERO:
		var mid := (p + q) * 0.5
		_Welds.add_box(st, Vector3((q - p).length(), HEIGHT, depth), Vector3(mid.x, mid.y, zc),
				angle)
	else:
		var perp := Vector2(-dir.y, dir.x)
		var pa := _cut_corner(p, dir, perp, np)
		var pb := _cut_corner(q, dir, perp, nq)
		var poly := PackedVector2Array([pa[0], pb[0], pb[1], pa[1]])
		if _area(poly) < 0.0:
			poly.reverse()
		_prism(st, poly, zb, zf)
	# End caps, a cm larger all round so the open ends of the tube read as welded-on plates.
	var ends: Array[Vector2] = []
	if cap_p:
		ends.append(p + dir * (CAP_T * 0.5) - dir * 0.005)
	if cap_q:
		ends.append(q - dir * (CAP_T * 0.5) + dir * 0.005)
	for e in ends:
		_Welds.add_box(st, Vector3(CAP_T + 0.01, HEIGHT, depth + 0.02), Vector3(e.x, e.y, zc),
				angle)


## The two corners (+perp side, -perp side) of a run's end at `e`, slid along `dir` onto the cut
## plane of outward normal `n` (zero: square).
static func _cut_corner(e: Vector2, dir: Vector2, perp: Vector2, n: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for s: float in [1.0, -1.0]:
		var v := perp * (s * HEIGHT * 0.5)
		var t := 0.0 if n == Vector2.ZERO else -v.dot(n) / dir.dot(n)
		out.append(e + v + dir * t)
	return out


## A run with the chamfered cross-section (v across the run, z): cabin face, 45-degree lip on the
## +perp edge, side, front, side. Both ends sit on their cut planes, so a mitre joins lip to lip.
static func _chamfer_prism(st: SurfaceTool, p: Vector2, q: Vector2, np: Vector2, nq: Vector2,
		zb: float, zf: float, c: float) -> void:
	var dir := (q - p).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var h := HEIGHT * 0.5
	var vs: Array[float] = [-h, h - c, h, h, -h]
	var zs: Array[float] = [zb, zb, zb + c, zf, zf]
	var pp: Array[Vector3] = []
	var qq: Array[Vector3] = []
	var centre := Vector3.ZERO
	for i in 5:
		var v := perp * vs[i]
		var tp := 0.0 if np == Vector2.ZERO else -v.dot(np) / dir.dot(np)
		var tq := 0.0 if nq == Vector2.ZERO else -v.dot(nq) / dir.dot(nq)
		var a := p + v + dir * tp
		var b := q + v + dir * tq
		pp.append(Vector3(a.x, a.y, zs[i]))
		qq.append(Vector3(b.x, b.y, zs[i]))
		centre += (pp[i] + qq[i]) * 0.1
	for i in 5:
		var j := (i + 1) % 5
		_tri_out(st, pp[i], pp[j], qq[j], centre)
		_tri_out(st, pp[i], qq[j], qq[i], centre)
	for i in range(1, 4):
		_tri_out(st, pp[0], pp[i], pp[i + 1], centre)
		_tri_out(st, qq[0], qq[i], qq[i + 1], centre)


## A triangle of a convex solid, wound so its normal points away from `centre`.
static func _tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centre: Vector3) -> void:
	if (b - a).cross(c - a).dot(centre - a) > 0.0:
		_tri(st, a, c, b)
	else:
		_tri(st, a, b, c)


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
	for i in range(1, n - 1):
		_tri(st, Vector3(poly[0].x, poly[0].y, zf), Vector3(poly[i].x, poly[i].y, zf),
				Vector3(poly[i + 1].x, poly[i + 1].y, zf))
		_tri(st, Vector3(poly[0].x, poly[0].y, zb), Vector3(poly[i + 1].x, poly[i + 1].y, zb),
				Vector3(poly[i].x, poly[i].y, zb))
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var a0 := Vector3(a.x, a.y, zb)
		var b0 := Vector3(b.x, b.y, zb)
		var b1 := Vector3(b.x, b.y, zf)
		var a1 := Vector3(a.x, a.y, zf)
		_tri(st, a0, b0, b1)
		_tri(st, a0, b1, a1)


## One triangle given counter-clockwise seen from outside, emitted clockwise with its normal.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_normal((b - a).cross(c - a).normalized())
	for v: Vector3 in [a, c, b]:
		st.set_uv(Vector2(v.x, v.y))
		st.add_vertex(v)


## Adds the run's merged steel and bead meshes as the two layer-2 nodes; `street` also puts them
## on the street-and-interior layers (the bottom beam shows from outside, the edge beam does not).
static func _commit(hinge: Node3D, steel: SurfaceTool, beads: SurfaceTool, street: bool,
		out: Array[Node3D], prefix := "DonorBeam") -> void:
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
	_Panels.add(hinge, prefix + "Weld", beads.commit(), _Welds.weld_steel(), Vector3.ZERO,
			Vector3.ZERO, out)
	if street:
		_street(out.back())


## Hex bolt heads along the run p -> q on the faces `sides` (+1 front at `zf`, -1 back at `zb`),
## so the beam shows as bolted.
static func _bolts(hinge: Node3D, p: Vector2, q: Vector2, zb: float, zf: float,
		sides: Array[float], street: bool, out: Array[Node3D], prefix := "DonorBeam",
		skip_y: Array[float] = [], skip_half := 0.0, radius := BOLT_R, height := BOLT_H) -> void:
	var head := CylinderMesh.new()
	head.top_radius = radius
	head.bottom_radius = radius
	head.height = height
	head.radial_segments = 6
	head.rings = 1
	var rust := _Panels.flat(Color(0.2, 0.17, 0.15), 0.8, 0.3)
	var pitch := 0.42
	var dir := (q - p).normalized()
	for k in int((p.distance_to(q) - 0.2) / pitch) + 1:
		var at := p + dir * (0.12 + k * pitch)
		var under_strap := false
		for sy: float in skip_y:
			under_strap = under_strap or absf(at.y - sy) < skip_half + radius
		if under_strap:
			continue
		for s: float in sides:
			var z := (zf if s > 0.0 else zb) + s * (height * 0.5 - 0.002)
			_Panels.add(hinge, prefix + "Bolt", head, rust, Vector3(at.x, at.y, z),
					Vector3(PI * 0.5, 0.0, 0.0), out)
			if street:
				_street(out.back())


## A square-section bead a -> b (in an XY plane) turned 45 degrees about its run so it shows only
## diagonal faces: sunk into the join, nothing parallel to a beam face.
static func _corner(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var box := BoxMesh.new()
	box.size = Vector3(d.length(), 0.02, 0.02)
	var basis := Basis(Vector3.BACK, atan2(d.y, d.x)) * Basis(Vector3.RIGHT, PI * 0.25)
	st.append_from(box, 0, Transform3D(basis, (a + b) * 0.5))


static func _street(node: Node3D) -> void:
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	VanLighting.retarget_layers(node as VisualInstance3D, VanLighting.LAYER_STREET_AND_INTERIOR)
