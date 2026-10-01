extends RefCounted
## One closed truck-front body: an upright cab with a split windshield in two sealed dark glass
## pockets, a long hood, front fenders with splash aprons and frame rails, as one mesh of convex
## prisms.

const _SKIN := 0
const _GLASS := 1
const _CAP := 2
## UV modes: metre UVs from two axes (the exterior shader needs them for its normal map).
const _UV_ZY := 0
const _UV_XY := 1
const _UV_XZ := 2
const _UV_NONE := -1
const _FLAT := -1
const _SMOOTH := 0

var _cab: VanCab


func _init(cab: VanCab) -> void:
	_cab = cab


func build(mat: Material) -> void:
	var w := VanCab.CAB_HALF_W
	var b := VanCab.CAB_BOTTOM_Y
	var r := VanCab.CAB_ROOF_Y
	var c := VanCab.CAB_CHAMFER
	var ws_h := VanCab.WS_HALF_W
	var ws_p := VanCab.WS_POST_HALF
	var ws_b := VanCab.WS_BOT_Y
	var ws_t := VanCab.WS_TOP_Y
	var section := PackedVector2Array([
			Vector2(-w, b), Vector2(-ws_h, b), Vector2(-ws_p, b), Vector2(ws_p, b),
			Vector2(ws_h, b), Vector2(w, b), Vector2(w, ws_b), Vector2(w, ws_t),
			Vector2(w, r - c), Vector2(w - c, r), Vector2(-(w - c), r), Vector2(-w, r - c),
			Vector2(-w, ws_t), Vector2(-w, ws_b)])

	var skin := SurfaceTool.new()
	skin.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	_prism(skin, section, VanCab.BODY_BACK_Z, VanCab.CAB_FRONT_Z, cap, null)
	_cab_front(skin)
	_pockets(skin, glass)
	_hood_and_fenders(skin, cap)

	skin.generate_normals()
	skin.generate_tangents()
	glass.generate_normals()
	cap.generate_normals()
	var mesh := skin.commit()
	glass.commit(mesh)
	cap.commit(mesh)
	mesh.surface_set_material(_SKIN, mat)
	mesh.surface_set_material(_GLASS, VanCab._dark_material(Color(0.015, 0.018, 0.02), 0.3))
	mesh.surface_set_material(_CAP, VanCab._dark_material(Color(0.03, 0.03, 0.03), 0.9))
	_cab._add_mesh("CabBody", mesh, null)


## A closed extrusion of a convex XY section from z_back to z_front: side quads on `side`, end caps
## fanned from the section's centroid on `back_cap` / `front_cap` (null skips that cap).
func _prism(side: SurfaceTool, section: PackedVector2Array, z_back: float, z_front: float,
		back_cap: SurfaceTool, front_cap: SurfaceTool) -> void:
	var n := section.size()
	var c2 := Vector2.ZERO
	for p in section:
		c2 += p
	c2 /= float(n)
	var inside := Vector3(c2.x, c2.y, (z_back + z_front) * 0.5)
	for i in range(n):
		var p := section[i]
		var q := section[(i + 1) % n]
		var uv := _UV_XZ if absf(q.x - p.x) >= absf(q.y - p.y) else _UV_ZY
		_quad(side, Vector3(p.x, p.y, z_back), Vector3(q.x, q.y, z_back),
				Vector3(q.x, q.y, z_front), Vector3(p.x, p.y, z_front), inside, uv, _FLAT)
	# Every vertex carries a UV (SurfaceTool rejects a first UV after the first vertex), so the
	# cap surface gets them too.
	var caps: Array = [[back_cap, z_back], [front_cap, z_front]]
	for entry in caps:
		var cap_st: SurfaceTool = entry[0]
		if cap_st == null:
			continue
		var z: float = entry[1]
		for i in range(n):
			var p := section[i]
			var q := section[(i + 1) % n]
			_tri(cap_st, Vector3(c2.x, c2.y, z), Vector3(p.x, p.y, z), Vector3(q.x, q.y, z),
					inside, _UV_XY, _FLAT)


## The cab's flat front face with the two windshield openings left out, and its roof chamfer.
func _cab_front(skin: SurfaceTool) -> void:
	var w := VanCab.CAB_HALF_W
	var f := VanCab.CAB_FRONT_Z
	var r := VanCab.CAB_ROOF_Y
	var c := VanCab.CAB_CHAMFER
	var inside := Vector3(0.0, 1.4, f + 1.0)
	var xs: Array[float] = [-w, -VanCab.WS_HALF_W, -VanCab.WS_POST_HALF, VanCab.WS_POST_HALF,
			VanCab.WS_HALF_W, w]
	var ys: Array[float] = [VanCab.CAB_BOTTOM_Y, VanCab.WS_BOT_Y, VanCab.WS_TOP_Y, r - c]
	for row in range(3):
		for col in range(5):
			if row == 1 and (col == 1 or col == 3):
				continue
			_quad(skin, Vector3(xs[col], ys[row], f), Vector3(xs[col + 1], ys[row], f),
					Vector3(xs[col + 1], ys[row + 1], f), Vector3(xs[col], ys[row + 1], f),
					inside, _UV_XY, _FLAT)
	var apex := Vector3(-(w - c), r, f)
	for col in range(5):
		_tri(skin, apex, Vector3(xs[col], r - c, f), Vector3(xs[col + 1], r - c, f), inside,
				_UV_XY, _FLAT)
	_tri(skin, Vector3(w, r - c, f), Vector3(w - c, r, f), apex, inside, _UV_XY, _FLAT)


## Two windshield panes, each a skin-walled pocket sealed by a dark glass quad at its bottom.
func _pockets(skin: SurfaceTool, glass: SurfaceTool) -> void:
	var f := VanCab.CAB_FRONT_Z
	var ws_b := VanCab.WS_BOT_Y
	var ws_t := VanCab.WS_TOP_Y
	var panes: Array[Vector2] = [Vector2(-VanCab.WS_HALF_W, -VanCab.WS_POST_HALF),
			Vector2(VanCab.WS_POST_HALF, VanCab.WS_HALF_W)]
	for pane in panes:
		var x0 := pane.x
		var x1 := pane.y
		var front: Array[Vector3] = [Vector3(x0, ws_b, f), Vector3(x1, ws_b, f),
				Vector3(x1, ws_t, f), Vector3(x0, ws_t, f)]
		var bz := f + VanCab.WS_REVEAL
		var bottom: Array[Vector3] = [Vector3(x0, ws_b, bz), Vector3(x1, ws_b, bz),
				Vector3(x1, ws_t, bz), Vector3(x0, ws_t, bz)]
		var centre := Vector3((x0 + x1) * 0.5, (ws_b + ws_t) * 0.5, f + VanCab.WS_REVEAL * 0.5)
		for k in range(4):
			var m := (k + 1) % 4
			_quad(skin, front[k], front[m], bottom[m], bottom[k], centre, _UV_XY, _FLAT, true)
		_quad(glass, bottom[0], bottom[1], bottom[2], bottom[3],
				Vector3((x0 + x1) * 0.5, 2.35, f + 1.0), _UV_NONE, _FLAT)


## The long hood, the two front fenders with their splash aprons, and the frame rails.
func _hood_and_fenders(skin: SurfaceTool, cap: SurfaceTool) -> void:
	var h := VanCab.HOOD_HALF_W
	var hb := VanCab.HOOD_BOT_Y
	var ht := VanCab.HOOD_TOP_Y
	var hc := VanCab.HOOD_CHAMFER
	var hood := PackedVector2Array([Vector2(-h, hb), Vector2(h, hb), Vector2(h, ht - hc),
			Vector2(h - hc, ht), Vector2(-(h - hc), ht), Vector2(-h, ht - hc)])
	_prism(skin, hood, VanCab.CAB_FRONT_Z + 0.05, VanCab.NOSE_Z, skin, skin)

	var fc := VanCab.FENDER_CHAMFER
	var fy := VanCab.FENDER_TOP_Y
	var ox := VanCab.FENDER_OUT_X
	for s in [-1.0, 1.0]:
		var fender := PackedVector2Array([Vector2(s * VanCab.FENDER_IN_X, VanCab.FENDER_BOT_Y),
				Vector2(s * ox, VanCab.FENDER_BOT_Y), Vector2(s * ox, fy - fc),
				Vector2(s * (ox - fc), fy), Vector2(s * VanCab.FENDER_IN_X, fy)])
		_prism(skin, fender, VanCab.FENDER_BACK_Z, VanCab.FENDER_FRONT_Z, skin, skin)
		var y1 := VanCab.FENDER_BOT_Y + 0.02
		var front_apron := _rect(s * VanCab.FENDER_IN_X, VanCab.APRON_BOT_Y, s * ox, y1)
		_prism(skin, front_apron, VanCab.FENDER_FRONT_Z + VanCab.APRON_T, VanCab.FENDER_FRONT_Z,
				skin, skin)
		var back_apron := _rect(s * (VanCab.CAB_HALF_W + 0.02), VanCab.APRON_BOT_Y, s * ox, y1)
		_prism(skin, back_apron, VanCab.FENDER_BACK_Z, VanCab.FENDER_BACK_Z - 2.0 * VanCab.APRON_T,
				skin, skin)

	var fh := VanCab.FRAME_HALF_W
	_prism(cap, _rect(-fh, -0.20, fh, VanCab.FRAME_TOP_Y), VanCab.CAB_FRONT_Z + 0.05,
			VanCab.NOSE_Z + 0.02, cap, cap)


## The four corners of an XY rectangle.
func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1),
			Vector2(x0, y1)])


func _vertex(st: SurfaceTool, p: Vector3, uv_mode: int, group: int) -> void:
	st.set_smooth_group(group)
	if uv_mode == _UV_ZY:
		st.set_uv(Vector2(p.z, p.y))
	elif uv_mode == _UV_XY:
		st.set_uv(Vector2(p.x, p.y))
	elif uv_mode == _UV_XZ:
		st.set_uv(Vector2(p.x, p.z))
	st.add_vertex(p)


## One triangle wound clockwise as seen from outside (Godot's front face), facing away from the
## inside reference (toward it when inward).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, uv_mode: int,
		group: int, inward: bool = false) -> void:
	var facing := (b - a).cross(c - a).normalized().dot(((a + b + c) / 3.0 - inside).normalized())
	if inward:
		facing = -facing
	if facing >= 0.0:
		_vertex(st, a, uv_mode, group)
		_vertex(st, c, uv_mode, group)
		_vertex(st, b, uv_mode, group)
	else:
		_vertex(st, a, uv_mode, group)
		_vertex(st, b, uv_mode, group)
		_vertex(st, c, uv_mode, group)


## One quad (two triangles sharing the a-c diagonal) wound like _tri.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3,
		uv_mode: int, group: int, inward: bool = false) -> void:
	var facing := (b - a).cross(c - a).normalized().dot(
			((a + b + c + d) * 0.25 - inside).normalized())
	if inward:
		facing = -facing
	var order: Array[Vector3] = [a, b, c, a, c, d]
	if facing >= 0.0:
		order =[a, d, c, a, c, b]
	for p in order:
		_vertex(st, p, uv_mode, group)
