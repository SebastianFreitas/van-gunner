extends RefCounted
## Cut-to-fit welds of the donor rear leaf (spec 4): an L-section angle-iron strip along each raw
## cut edge (bottom, latch side, diagonal top cut) with an uneven weld bead where it meets the
## skin, and a bead all round the hinge-corner filler plate with two plug welds in its middle.
## Positions come from the leaf profile's outline and filler, never from constants of their own.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")

## Angle-iron leg width and thickness: 3 cm legs, thick enough to clear the audit's 1 cm plane test.
const LEG := 0.03
const LEG_T := 0.024
## Weld bead width (about 2 cm), height and the length range of its overlapping segments.
const BEAD_W := 0.02
const BEAD_H := 0.012
## Strip beads are deep so their fronts clear the strip's and the pressed lip's by 1 cm.
const STRIP_BEAD_H := 0.04
## The bottom strip stops this far short of the rounded hinge corner.
const HINGE_STOP := 0.04
## Clearance kept above and below the scene Handle on the latch edge.
const HANDLE_CLEAR := 0.03
## Bead z centre against the cabin crest; its band clears both strip legs by 1.5 cm.
const BEAD_Z := -0.032
## Bottom and diagonal strips stand this far in from the raw edge, off the skin's edge faces.
const EDGE_LIFT := 0.015
const SEG_MIN := 0.06
const SEG_MAX := 0.09
## The filler plate's front face (rear_door_skin.gd puts it 5 cm behind the cabin crest).
const FILLER_FACE_Z := _LeafBuild.CABIN_Z + 0.05
const PLUG_R := 0.02


static func rust_steel() -> Material:
	return _Panels.flat(Color(0.22, 0.14, 0.09), 0.88, 0.35)


## Fresh welds: darker, bluish steel.
static func weld_steel() -> Material:
	return _Panels.flat(Color(0.09, 0.11, 0.16), 0.5, 0.6)


## Builds the strips, their beads and the filler welds under `hinge`; `rect` is the leaf rect in
## hinge-local XY (the one the skin was pressed from).
static func build(hinge: Node3D, rect: Rect2, profile: RearDoorProfile,
		rng: RandomNumberGenerator, out: Array[Node3D]) -> void:
	var outline := profile.outline(rect)
	var gap := _handle_gap(hinge)
	var iron := SurfaceTool.new()
	iron.begin(Mesh.PRIMITIVE_TRIANGLES)
	var beads := SurfaceTool.new()
	beads.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The three straight cuts follow the hinge-side arc in the outline: bottom, latch, diagonal.
	for i: int in 3:
		var a := outline[i]
		var b := outline[i + 1]
		var dir := (b - a).normalized()
		var inward := Vector2(-dir.y, dir.x)
		var from := a + (dir * LEG * 1.2 if i > 0 else dir * HINGE_STOP)
		# The latch edge carries the centre astragal; its strip stands just inboard of the bar.
		var shift := inward * (_LeafBuild.ASTRAGAL_HALF_W + LEG_T if i == 1 else EDGE_LIFT)
		from += shift
		b += shift
		for run: Array in (_runs(from, b, gap) if i == 1 else [[from, b]]):
			_strip(iron, run[0], run[1], inward)
			add_bead(beads, run[0], run[1], _LeafBuild.CABIN_Z + BEAD_Z, inward * (LEG + 0.012),
					rng, STRIP_BEAD_H)
	_commit(hinge, iron, "CutStrip", rust_steel(), out)
	if profile.filler(rect).size() > 3:
		_filler(beads, profile.filler(rect), rng)
		_filler_plugs(hinge, profile.filler(rect), out)
	_commit(hinge, beads, "CutWeld", weld_steel(), out)


## Appends a box of `size` centred at `at` (XY plus z), turned `angle` about z.
static func add_box(st: SurfaceTool, size: Vector3, at: Vector3, angle: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	st.append_from(mesh, 0, Transform3D(Basis(Vector3.BACK, angle), at))


## Adds the merged `st` as one layer-2 mesh under `parent`.
static func _commit(parent: Node3D, st: SurfaceTool, node_name: String, mat: Material,
		out: Array[Node3D]) -> void:
	_Panels.add(parent, node_name, st.commit(), mat, Vector3.ZERO, Vector3.ZERO, out)


## One L-section strip along a -> b: the flat leg lies on the cabin face inside the cut, the
## standing leg rises from the cut edge.
static func _strip(st: SurfaceTool, a: Vector2, b: Vector2, inward: Vector2) -> void:
	var angle := (b - a).angle()
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var z := _LeafBuild.CABIN_Z
	var flat := mid + inward * LEG * 0.5
	add_box(st, Vector3(length, LEG, 0.034), Vector3(flat.x, flat.y, z - 0.005), angle)
	var rise := mid + inward * LEG_T * 0.5
	add_box(st, Vector3(length, LEG_T, 0.05), Vector3(rise.x, rise.y, z - 0.011), angle)


## The y range of the scene Handle's boxes (hinge-local) widened by HANDLE_CLEAR, as (lo, hi).
static func _handle_gap(hinge: Node3D) -> Vector2:
	var handle := hinge.get_node("Handle") as Node3D
	var lo := INF
	var hi := -INF
	var stack: Array = [[handle, handle.transform]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node3D = item[0]
		var xf: Transform3D = item[1]
		var csg := node as CSGBox3D
		if csg != null:
			var box := xf * AABB(-csg.size * 0.5, csg.size)
			lo = minf(lo, box.position.y)
			hi = maxf(hi, box.end.y)
		for child in node.get_children():
			if child is Node3D:
				stack.append([child, xf * (child as Node3D).transform])
	return Vector2(lo - HANDLE_CLEAR, hi + HANDLE_CLEAR)


## a -> b split into the runs outside the y range `gap` (the whole edge when it misses).
static func _runs(a: Vector2, b: Vector2, gap: Vector2) -> Array:
	var y0 := minf(a.y, b.y)
	var y1 := maxf(a.y, b.y)
	if gap.y <= y0 or gap.x >= y1:
		return [[a, b]]
	var p := a.lerp(b, clampf((gap.x - a.y) / (b.y - a.y), 0.0, 1.0))
	var q := a.lerp(b, clampf((gap.y - a.y) / (b.y - a.y), 0.0, 1.0))
	if a.y > b.y:
		var t := p
		p = q
		q = t
	# p is the gap end nearer a, q the one nearer b.
	var runs: Array = []
	if a.distance_to(p) > 0.05:
		runs.append([a, p])
	if q.distance_to(b) > 0.05:
		runs.append([q, b])
	return runs


## An uneven bead a -> b (short overlapping segments, jittered width and lean) at `offset` to
## the side of the line, centred on `z`.
static func add_bead(st: SurfaceTool, a: Vector2, b: Vector2, z: float, offset: Vector2,
		rng: RandomNumberGenerator, height: float = BEAD_H) -> void:
	var angle := (b - a).angle()
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var t := 0.0
	while t < length:
		var seg := minf(rng.randf_range(SEG_MIN, SEG_MAX), length - t + 0.01)
		var mid := a + dir * (t + seg * 0.5) + offset
		var side := Vector2(-dir.y, dir.x) * rng.randf_range(-0.004, 0.004)
		var w := BEAD_W * rng.randf_range(0.7, 1.2)
		add_box(st, Vector3(seg, w, height * rng.randf_range(0.95, 1.05)),
				Vector3(mid.x + side.x, mid.y + side.y, z), angle + rng.randf_range(-0.12, 0.12))
		t += seg * rng.randf_range(0.65, 0.85)


## A bead centred on every edge of the filler plate's outline, standing off its front face.
static func _filler(st: SurfaceTool, poly: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	for i: int in poly.size():
		add_bead(st, poly[i], poly[(i + 1) % poly.size()], FILLER_FACE_Z - BEAD_H * 0.4,
				Vector2.ZERO, rng)


## Two plug-weld discs in the sliver between the corner and the arc: half way along the corner's
## diagonal, pushed a little each way along the arc's tangent.
static func _filler_plugs(parent: Node3D, poly: PackedVector2Array, out: Array[Node3D]) -> void:
	var corner := poly[1]
	var arc_mid := poly[3 + int((poly.size() - 3) * 0.5)]
	var u := arc_mid - corner
	var v := Vector2(-u.y, u.x)
	var disc := CylinderMesh.new()
	disc.top_radius = PLUG_R
	disc.bottom_radius = PLUG_R * 1.15
	disc.height = BEAD_H
	disc.radial_segments = 8
	disc.rings = 1
	for s: float in [-1.0, 1.0]:
		var p := corner + u * 0.5 + v * 0.3 * s
		_Panels.add(parent, "FillerPlug", disc, weld_steel(),
				Vector3(p.x, p.y, FILLER_FACE_Z - BEAD_H * 0.4), Vector3(PI * 0.5, 0.0, 0.0), out)
