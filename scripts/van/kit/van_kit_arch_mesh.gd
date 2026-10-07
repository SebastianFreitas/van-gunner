class_name VanKitArchMesh
extends RefCounted
## Mesh of one wheel-tub box: a front face leaning back toward the wall, a 3 cm folded lip down
## its top edge, a top and two end faces; nothing against the wall and no bottom on the floor.

const LIP_M := 0.03
## The main front sits this far behind the lip's plane, so the lip reads as a fold.
const FOLD_M := 0.015
## The end and top faces reach this far into the liner so no gap shows along the wall.
const INTO_WALL_M := 0.01


## `geo`: {fb, ft, xs, y1, z0, z1, wall} in the van's frame (|x| in metres); `wall` holds the
## liner's (|x|, y) samples.
static func build(parent: Node3D, p: VanKitPlaced, geo: Dictionary, paint: Color, rust: float,
		wall_style: int, pitch: float, van_seed: int) -> MeshInstance3D:
	var s: float = geo[&"xs"]
	var h: float = geo[&"y1"]
	var z0: float = geo[&"z0"]
	var z1: float = geo[&"z1"]
	var fb: float = geo[&"fb"]
	var ft: float = geo[&"ft"]
	var inv := p.transform.affine_inverse()
	var fl := func(y: float) -> float: return lerpf(fb, ft, y / h)
	var fm := func(y: float) -> float: return fl.call(y) + FOLD_M
	var wall: PackedVector2Array = geo[&"wall"]
	var wall_top := wall[wall.size() - 1].x + INTO_WALL_M
	var yl := h - LIP_M
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_strip(st, s, fm.call(0.0), 0.0, fm.call(yl), yl, z0, z1, Vector3(-1.0, 0.0, 0.0), inv)
	_strip(st, s, fm.call(yl), yl, fl.call(yl), yl, z0, z1, Vector3(0.0, -1.0, 0.0), inv)
	_strip(st, s, fl.call(yl), yl, fl.call(h), h, z0, z1, Vector3(-1.0, 0.0, 0.0), inv)
	_strip(st, s, fl.call(h), h, wall_top, h, z0, z1, Vector3(0.0, 1.0, 0.0), inv)
	var side := PackedVector2Array([Vector2(fm.call(0.0), 0.0), Vector2(fm.call(yl), yl),
		Vector2(fl.call(yl), yl), Vector2(fl.call(h), h)])
	for i in range(wall.size() - 1, -1, -1):
		side.append(Vector2(wall[i].x + INTO_WALL_M, wall[i].y))
	var tris := Geometry2D.triangulate_polygon(side)
	for k in range(0, tris.size(), 3):
		for z_end: float in [z0, z1]:
			var pts: Array[Vector3] = []
			for i in 3:
				var v := side[tris[k + i]]
				pts.append(inv * Vector3(v.x * s, v.y, z_end))
			_tri(st, pts[0], pts[1], pts[2], inv.basis * Vector3(0.0, 0.0, -1.0 if z_end == z0 else 1.0))
	st.generate_normals()
	var mi := VanKitWindowsMesh.node(parent, "ArchBox", st.commit())
	mi.transform = p.transform
	VanKitWindowsMesh.style(mi, paint, paint.darkened(0.3), rust, wall_style, pitch, van_seed,
			p.def_id)
	return mi


## A quad between two lines (|x|, y) running from z0 to z1; `want` is its front normal in |x|, y, z.
static func _strip(st: SurfaceTool, s: float, xa: float, ya: float, xb: float, yb: float,
		z0: float, z1: float, want: Vector3, inv: Transform3D) -> void:
	var a := inv * Vector3(xa * s, ya, z0)
	var b := inv * Vector3(xa * s, ya, z1)
	var c := inv * Vector3(xb * s, yb, z1)
	var d := inv * Vector3(xb * s, yb, z0)
	var n := inv.basis * Vector3(want.x * s, want.y, want.z)
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)


## A triangle wound so its front face looks along `want`.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, want: Vector3) -> void:
	var flip := (b - a).cross(c - a).dot(want) > 0.0
	for v in ([a, c, b] if flip else [a, b, c]):
		st.add_vertex(v)
