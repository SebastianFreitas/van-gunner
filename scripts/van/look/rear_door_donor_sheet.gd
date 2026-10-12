class_name RearDoorDonorSheet
extends RefCounted
## The corrugated roofing sheet screwed over the bottom of the donor rear leaf's hole (spec 4):
## thin green sheet with a smooth sine corrugation stood on end, lapped behind the tread plate on
## a packer strip, dented into the cabin with its edges pinned, six hex-washer screws and one
## missing. Hinge-local metres.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Skin := preload("res://scripts/van/rear_door_skin.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Plate := preload("res://scripts/van/look/rear_door_donor_plate.gd")

const SHELL := 0.004
const PITCH := 0.11
const RIB_H := 0.018
const BOTTOM_LIFT := 0.01
const LAP := 0.06
const CUT_GAP := 0.003
## Fixed column grid: this many columns per rib pitch, the same on every row.
const COLS := 10
## The sheet's hinge-side edge, and how far it runs under the cut (hidden behind the door skin).
const EDGE_X := 0.02
## Hinge-local y of the sheet's bottom, set per build, for the UVs.
static var _uv_bottom := 0.0
const EDGE_UNDER := 0.025
## Street face of the ribs' crests, hinge-local z.
const Z_FACE := -0.004
## Corner bend into the cabin and how far it reaches.
const BEND := 0.015
const BEND_REACH := 0.12
## The middle of the sheet is shoved into the cabin this far; its edges stay pinned.
const DENT := 0.09
const PACKER := Vector3(0.0, 0.03, 0.02)
const SCREW_R := 0.009
const SCREW_H := 0.012
## Sheet colour (sRGB, already darkened to the large-surface luminance ceiling, art-style.md).
const PAINT := Color(0.40, 0.46, 0.27)


## Builds the sheet, its packer and screws. Returns every node added.
static func build(hinge: Node3D, rect: Rect2, profile: RearDoorProfile) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var seam := _Plate.seam(rect, profile)
	var y0 := rect.position.y + BOTTOM_LIFT
	var y1 := seam[0].y + LAP
	var y_seam := seam[0].y
	# Rows at the cut's corners so the sheet edge follows the cut to its 3 mm gap.
	var rows: Array[float] = []
	for p in profile.donor_cut(rect):
		if p.y > y0 + 0.01 and p.y < y1 - 0.01:
			rows.append(p.y)
	var fixed := rows.duplicate()
	var extra: Array[float] = [y0, y0 + 0.06, y0 + BEND_REACH, y_seam - 0.25, y_seam - 0.125,
			y_seam, y1]
	# Rows every 12 cm so the dent is a smooth dome, not a few flat bands.
	for k in int((y1 - y0) / 0.12):
		extra.append(y0 + 0.12 * (k + 1))
	for y: float in extra:
		var near := false
		for f: float in fixed:
			near = near or absf(f - y) <= 0.01
		if not near:
			rows.append(y)
	rows = _clean_rows(rows)
	var x_max := 0.0
	for y in rows:
		x_max = maxf(x_max, profile.cut_x(rect, y) + EDGE_UNDER)
	var xs: Array[float] = []
	for k in int(ceil((x_max - EDGE_X) * COLS / PITCH)) + 1:
		xs.append(EDGE_X + k * PITCH / COLS)
	_uv_bottom = y0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for y in rows:
		var t := (y - y0) / (y1 - y0)
		var xr := profile.cut_x(rect, y) + EDGE_UNDER
		var row: Array[Vector3] = []
		for x in xs:
			var cx := minf(x, xr)
			var bend := BEND * clampf(1.0 - (cx - EDGE_X) / BEND_REACH, 0.0, 1.0) 					* clampf(1.0 - (y - y0) / BEND_REACH, 0.0, 1.0)
			var dent := _dome((cx - EDGE_X) / (xr - EDGE_X), t)
			row.append(Vector3(cx, y, Z_FACE + _rib(cx) - bend - dent))
		grid.append(row)
	_shell(st, grid)
	var mat := _Panels.grime(PAINT) as ShaderMaterial
	# Belt and seam lines pushed off the sheet; a rusty band low down.
	mat.set_shader_parameter(&"wall_size_m", Vector2(1.0, 50.0))
	mat.set_shader_parameter(&"panel_spacing_m", 40.0)
	mat.set_shader_parameter(&"belt_y_m", 90.0)
	mat.set_shader_parameter(&"waist_y_m", 90.0)
	mat.set_shader_parameter(&"rib_spacing_m", PITCH)
	mat.set_shader_parameter(&"roughness_value", 0.55)
	mat.set_shader_parameter(&"metallic_value", 0.3)
	mat.set_shader_parameter(&"kick_height_m", 0.3)
	mat.set_shader_parameter(&"kick_color", Color(0.24, 0.1, 0.05))
	_Panels.add(hinge, "DonorSheet", st.commit(), mat, Vector3.ZERO, Vector3.ZERO, out)
	_street(out.back(), true)
	_packer(hinge, seam, out)
	_screws(hinge, rect, profile, seam, out)
	return out


## Depth of the dent at fractions sx, sy across the sheet: zero on every edge, deepest a little
## toward the hinge and below the middle.
static func _dome(sx: float, sy: float) -> float:
	var u := sin(PI * pow(clampf(sx, 0.0, 1.0), 0.76))
	var v := sin(PI * pow(clampf(sy, 0.0, 1.0), 0.87))
	return DENT * u * u * v * v


## The dent's depth at hinge-local (x, y), for fittings that follow the sheet's surface.
static func dent_at(rect: Rect2, profile: RearDoorProfile, x: float, y: float) -> float:
	var y0 := rect.position.y + BOTTOM_LIFT
	var y1 := _Plate.seam(rect, profile)[0].y + LAP
	var t := (y - y0) / (y1 - y0)
	var xr := profile.cut_x(rect, y) + EDGE_UNDER
	return _dome((x - EDGE_X) / (xr - EDGE_X), t)


static func _clean_rows(rows: Array[float]) -> Array[float]:
	rows.sort()
	var clean: Array[float] = []
	for y in rows:
		if clean.is_empty() or y - clean.back() > 0.01:
			clean.append(y)
	return clean


## The cabin-ward depth of the corrugation at x: 0 on the crests, down to -RIB_H in the troughs.
static func _rib(x: float) -> float:
	return -RIB_H * 0.5 * (1.0 - cos(TAU * x / PITCH))


## Smooth normal at grid point (j, i) from the differences to its neighbours.
static func _normal(grid: Array, j: int, i: int) -> Vector3:
	var rows := grid.size()
	var cols: int = (grid[0] as Array).size()
	var dx: Vector3 = (grid[j][mini(i + 1, cols - 1)] as Vector3) - grid[j][maxi(i - 1, 0)]
	var dy: Vector3 = (grid[mini(j + 1, rows - 1)][i] as Vector3) - grid[maxi(j - 1, 0)][i]
	var n := dx.cross(dy)
	return n.normalized() * signf(n.z) if n.length() > 1e-9 else Vector3.BACK


static func _shell(st: SurfaceTool, grid: Array) -> void:
	var down := Vector3(0.0, 0.0, -SHELL)
	var rows := grid.size()
	var cols: int = (grid[0] as Array).size()
	for j in rows - 1:
		for i in cols - 1:
			var ids := [[j, i], [j, i + 1], [j + 1, i + 1], [j + 1, i]]
			var top: Array[Vector3] = []
			var nrm: Array[Vector3] = []
			for id: Array in ids:
				top.append(grid[id[0]][id[1]])
				nrm.append(_normal(grid, id[0], id[1]))
			_smooth(st, top, nrm, 1.0)
			_smooth(st, [top[0] + down, top[1] + down, top[2] + down, top[3] + down], nrm, -1.0)
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


## The wall shader's UV for hinge-local `p`: x in metres shifted 20.02 m (a whole number of ribs,
## half a seam spacing of 40 m) to sit between seams, y in metres up from the sheet's bottom so
## only the bottom `kick_height_m` reads rusty (the material's wall_size_m is (1, 50)).
static func _uv(p: Vector3) -> Vector2:
	return Vector2(p.x + 20.02, (p.y - _uv_bottom) / 50.0)


## Two triangles with per-vertex normals, wound clockwise seen along `side` * those normals.
static func _smooth(st: SurfaceTool, v: Array[Vector3], nrm: Array[Vector3], side: float) -> void:
	for tri: Array in [[0, 1, 2], [0, 2, 3]]:
		var idx: Array = tri.duplicate()
		var n := (v[idx[1]] - v[idx[0]]).cross(v[idx[2]] - v[idx[0]])
		if n.length() < 1e-9:
			continue
		if n.dot(nrm[idx[0]] * side) > 0.0:
			idx = [idx[0], idx[2], idx[1]]
		for k: int in idx:
			st.set_normal(nrm[k] * side)
			st.set_uv(_uv(v[k]))
			st.add_vertex(v[k])


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
			st.set_uv(_uv(v))
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
		seam: PackedVector2Array, out: Array[Node3D]) -> void:
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
		var pan := floorf((profile.cut_x(rect, y) - CUT_GAP - 0.03) / PITCH) * PITCH
		var z := Z_FACE - dent_at(rect, profile, pan, y)
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
