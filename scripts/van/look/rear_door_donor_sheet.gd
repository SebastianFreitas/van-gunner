class_name RearDoorDonorSheet
extends RefCounted
## The corrugated roofing sheet screwed over the bottom of the donor rear leaf's hole (spec 4):
## thin pale-olive box-rib sheet stood on end, lapped behind the tread plate on a packer strip,
## skewed, with a lifted corner, six hex-washer screws and one missing. Hinge-local metres.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Skin := preload("res://scripts/van/rear_door_skin.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Plate := preload("res://scripts/van/look/rear_door_donor_plate.gd")

const SHELL := 0.004
const PITCH := 0.11
const PAN_W := 0.07
const SIDE_W := 0.005
const RIB_H := 0.018
const BOTTOM_LIFT := 0.01
const LAP := 0.06
const CUT_GAP := 0.003
## Pan x at the hinge side: 0.06 at the bottom, 0.03 at the top.
const HINGE_X_BOTTOM := 0.06
const HINGE_X_TOP := 0.03
## tan(2 degrees): how far the ribs shift in x per metre of height.
const LEAN := 0.0349
## Corner bend into the cabin and how far it reaches.
const BEND := 0.015
const BEND_REACH := 0.12
const PACKER := Vector3(0.0, 0.03, 0.02)
const SCREW_R := 0.009
const SCREW_H := 0.012
## Sheet colour (sRGB, already darkened to the large-surface luminance ceiling, art-style.md).
const PAINT := Color(0.52, 0.53, 0.36)


## Builds the sheet, its packer, screws and the rust backing that closes the edge gaps. Returns
## every node added.
static func build(hinge: Node3D, rect: Rect2, profile: RearDoorProfile) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var seam := _Plate.seam(rect, profile)
	var y0 := rect.position.y + BOTTOM_LIFT
	var y1 := seam[0].y + LAP
	var y_seam := seam[0].y
	# Street face at the tread plate's street plane; the 4 cm drop to tuck behind the plate (it
	# must clear the plate's backing) is a hurried kink just below the plate.
	var z_street := _LeafBuild.STREET_HALF - _Skin.STREET_SETBACK
	var step := z_street
	# Rows at the cut's corners so the sheet edge follows the cut to its 3 mm gap.
	var rows: Array[float] = []
	for p in profile.donor_cut(rect):
		if p.y > y0 + 0.01 and p.y < y1 - 0.01:
			rows.append(p.y)
	var fixed := rows.duplicate()
	for y: float in [y0, y0 + 0.06, y0 + BEND_REACH, y_seam - 0.25, y_seam - 0.125, y_seam, y1]:
		var near := false
		for f: float in fixed:
			near = near or absf(f - y) <= 0.01
		if not near:
			rows.append(y)
	rows = _clean_rows(rows)
	var xs: Array[float] = [0.0]
	for k in 6:
		for d: float in [PAN_W, PAN_W + SIDE_W, PITCH - SIDE_W, PITCH]:
			xs.append(k * PITCH + d)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for y in rows:
		var t := (y - y0) / (y1 - y0)
		var xl := lerpf(HINGE_X_BOTTOM, HINGE_X_TOP, t)
		var xr := profile.cut_x(rect, y) - CUT_GAP
		var z_base := z_street - step * smoothstep(y_seam - 0.25, y_seam, y)
		# The 2 degrees off plumb: every rib leans toward the hinge going up.
		var skew := LEAN * (y - y0)
		var row: Array[Vector3] = []
		for x in xs:
			var cx := clampf(x - skew, xl, xr)
			var bend := BEND * clampf(1.0 - (cx - xl) / BEND_REACH, 0.0, 1.0) \
					* clampf(1.0 - (y - y0) / BEND_REACH, 0.0, 1.0)
			row.append(Vector3(cx, y, z_base + _rib(cx) - bend))
		grid.append(row)
	_shell(st, grid)
	var mat := _Panels.grime(PAINT)
	_Panels.add(hinge, "DonorSheet", st.commit(), mat, Vector3.ZERO, Vector3.ZERO, out)
	_street(out.back(), true)
	var z_at := func(y: float) -> float:
		return z_street - step * smoothstep(y_seam - 0.25, y_seam, y)
	_packer(hinge, seam, out)
	_screws(hinge, rect, profile, seam, z_at, out)
	_backing(hinge, rect, profile, seam, z_street - RIB_H - SHELL - 0.01, out)
	return out


static func _clean_rows(rows: Array[float]) -> Array[float]:
	rows.sort()
	var clean: Array[float] = []
	for y in rows:
		if clean.is_empty() or y - clean.back() > 0.01:
			clean.append(y)
	return clean


## The cabin-ward depth of the box-rib profile at x (0 on the pans, down to -RIB_H on the ribs).
static func _rib(x: float) -> float:
	var u := fposmod(x, PITCH)
	if u < PAN_W:
		return 0.0
	if u < PAN_W + SIDE_W:
		return -RIB_H * (u - PAN_W) / SIDE_W
	if u < PITCH - SIDE_W:
		return -RIB_H
	return -RIB_H * (PITCH - u) / SIDE_W


static func _shell(st: SurfaceTool, grid: Array) -> void:
	var down := Vector3(0.0, 0.0, -SHELL)
	var rows := grid.size()
	var cols: int = (grid[0] as Array).size()
	for j in rows - 1:
		for i in cols - 1:
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i + 1]
			var c: Vector3 = grid[j + 1][i + 1]
			var d: Vector3 = grid[j + 1][i]
			_quad(st, a, b, c, d, 1.0)
			_quad(st, a + down, b + down, c + down, d + down, -1.0)
	for j in rows - 1:
		var l0: Vector3 = grid[j][0]
		var l1: Vector3 = grid[j + 1][0]
		_quad(st, l0, l1, l1 + down, l0 + down, 0.0, Vector3.LEFT)
		var r0: Vector3 = grid[j][cols - 1]
		var r1: Vector3 = grid[j + 1][cols - 1]
		_quad(st, r0, r1, r1 + down, r0 + down, 0.0, Vector3.RIGHT)
	for i in cols - 1:
		var b0: Vector3 = grid[0][i]
		var b1: Vector3 = grid[0][i + 1]
		_quad(st, b0, b1, b1 + down, b0 + down, 0.0, Vector3.DOWN)
		var t0: Vector3 = grid[rows - 1][i]
		var t1: Vector3 = grid[rows - 1][i + 1]
		_quad(st, t0, t1, t1 + down, t0 + down, 0.0, Vector3.UP)


## Two triangles; faces `side` * the quad's own z (or `fixed` when side is 0), UV in metres / 0.8.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		side: float, fixed := Vector3.ZERO) -> void:
	for tri: Array in [[a, b, c], [a, c, d]]:
		var p: Vector3 = tri[0]
		var q: Vector3 = tri[1]
		var r: Vector3 = tri[2]
		var n := (q - p).cross(r - p)
		if n.length() < 1e-9:
			continue
		var out_n := n.normalized()
		if side != 0.0:
			out_n *= signf(out_n.z) * side
		else:
			out_n = fixed
		if n.dot(out_n) > 0.0:
			var swap := q
			q = r
			r = swap
		for v: Vector3 in [p, q, r]:
			st.set_normal(out_n)
			st.set_uv(Vector2(v.x, v.y) / 0.8)
			st.add_vertex(v)


static func _street(node: Node3D, shadow: bool) -> void:
	if shadow:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	VanLighting.retarget_layers(node as VisualInstance3D, VanLighting.LAYER_STREET_AND_INTERIOR)


## The dark steel offcut packer under the plate's bottom edge, along the seam.
static func _packer(hinge: Node3D, seam: PackedVector2Array, out: Array[Node3D]) -> void:
	var a := seam[0] + Vector2(0.05, 0.0)
	var b := seam[1] - Vector2(0.03, 0.0)
	var span := b - a
	var mid := (a + b) * 0.5
	var box := _Panels.box(Vector3(span.length(), PACKER.y, PACKER.z))
	_Panels.add(hinge, "DonorSheetPacker", box, _Panels.flat(Color(0.16, 0.15, 0.14), 0.8, 0.2),
			Vector3(mid.x, mid.y - 0.005 - PACKER.y * 0.5, 0.024),
			Vector3(0.0, 0.0, span.angle()), out)
	_street(out.back(), true)


static func _screws(hinge: Node3D, rect: Rect2, profile: RearDoorProfile,
		seam: PackedVector2Array, z_at: Callable, out: Array[Node3D]) -> void:
	var steel := _Panels.flat(Color(0.30, 0.17, 0.10), 0.8, 0.2)
	var head := CylinderMesh.new()
	head.top_radius = SCREW_R
	head.bottom_radius = SCREW_R
	head.height = SCREW_H
	head.radial_segments = 6
	head.rings = 1
	var rot := Vector3(PI * 0.5, 0.0, 0.0)
	# Through the lap, into the plate: on the plate's street face, just above its bottom edge.
	var z_plate := _LeafBuild.STREET_HALF - _Skin.STREET_SETBACK
	for x: float in [0.13, 0.25, 0.37]:
		var y := lerpf(seam[0].y, seam[1].y, (x - seam[0].x) / (seam[1].x - seam[0].x)) + 0.03
		_Panels.add(hinge, "DonorSheetScrew", head, steel,
				Vector3(x, y, z_plate + SCREW_H * 0.5 - 0.002), rot, out)
		_street(out.back(), false)
	# Down the cut side, on the last pan clear of the cut; the third is missing.
	var y_low := rect.position.y + BOTTOM_LIFT
	var y_high := seam[0].y - 0.35
	for k in 4:
		var y := lerpf(y_low + 0.12, y_high, float(k) / 3.0)
		var xr := profile.cut_x(rect, y) - CUT_GAP
		var pan := floorf((xr - 0.02 - PAN_W * 0.5) / PITCH) * PITCH + PAN_W * 0.5
		var z := z_at.call(y) as float
		if k == 2:
			var hole := CylinderMesh.new()
			hole.top_radius = SCREW_R * 0.6
			hole.bottom_radius = SCREW_R * 0.6
			hole.height = 0.004
			_Panels.add(hinge, "DonorSheetHole", hole, _Panels.flat(Color(0.02, 0.02, 0.02),
					0.9, 0.0), Vector3(pan, y, z + 0.001), Vector3(PI * 0.5 + 0.2, 0.0, 0.0),
					out)
		else:
			_Panels.add(hinge, "DonorSheetScrew", head, steel,
					Vector3(pan, y, z + SCREW_H * 0.5 - 0.002), rot, out)
		_street(out.back(), false)


## Rust strips behind the sheet that close only the cut-side, hinge-side and bottom slits. The
## bottom strip starts cut-ward of x 0.34 so the sheet's bent corner stays open to the cabin.
static func _backing(hinge: Node3D, rect: Rect2, profile: RearDoorProfile,
		seam: PackedVector2Array, z_front: float, out: Array[Node3D]) -> void:
	var y_bot := rect.position.y
	var y_top := seam[0].y
	var polys: Array[PackedVector2Array] = []
	# Cut side: a 4 cm band along the cut, one convex quad per leg of its polyline.
	var ys: Array[float] = [y_bot]
	for p in profile.donor_cut(rect):
		if p.y > y_bot + 0.01 and p.y < y_top - 0.01:
			ys.append(p.y)
	ys.sort()
	ys.append(y_top)
	for i in ys.size() - 1:
		var xa := profile.cut_x(rect, ys[i])
		var xb := profile.cut_x(rect, ys[i + 1])
		polys.append(PackedVector2Array([Vector2(xa - 0.04, ys[i]), Vector2(xa + 0.012, ys[i]),
				Vector2(xb + 0.012, ys[i + 1]), Vector2(xb - 0.04, ys[i + 1])]))
	# Hinge side, as wide as the slit (the sheet starts at x 0.06 low, 0.03 high).
	polys.append(PackedVector2Array([Vector2(-0.01, y_bot), Vector2(0.07, y_bot),
			Vector2(0.04, y_top), Vector2(-0.01, y_top)]))
	# Bottom, cut-ward of the open corner.
	polys.append(PackedVector2Array([Vector2(0.34, y_bot), Vector2(profile.cut_x(rect, y_bot)
			+ 0.012, y_bot), Vector2(profile.cut_x(rect, y_bot) + 0.012, y_bot + 0.04),
			Vector2(0.34, y_bot + 0.04)]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for poly in polys:
		_Skin._poly(st, poly, z_front, Vector3.BACK)
		_Skin._poly(st, poly, z_front - _Plate.BACKING_T, Vector3.FORWARD)
		_Skin._walls(st, poly, z_front - _Plate.BACKING_T, z_front, false)
	_Panels.add(hinge, "DonorSheetBacking", st.commit(), _Panels.flat(Color(0.28, 0.15, 0.09),
			0.85, 0.2), Vector3.ZERO, Vector3.ZERO, out)
	_street(out.back(), false)
