class_name VanKitBracesMesh
extends RefCounted
## Meshes of one brace: its section (angle iron L, scaffold pipe, rebar) extruded along the
## piece's z with unevenly cut ends, plus bolt heads, welded tabs or weld blobs at its fixings.

const ANGLE_LEG_M := 0.005


## One merged mesh node under `parent`, in the piece's frame (placed at its transform).
static func build(parent: Node3D, p: VanKitPlaced, made: Dictionary, paint: Color, rust: float,
		van_seed: int) -> MeshInstance3D:
	var half := p.size.x * 0.5
	var top := p.size.y * 0.5
	var mid := top - half
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := _profile(String(p.def_id).get_slice("/", 1), half)
	var frame := Transform3D(Basis.IDENTITY, Vector3(0.0, mid, 0.0))
	_extrude(st, profile, frame, -p.size.z * 0.5, p.size.z * 0.5, made[&"cut_a"], made[&"cut_b"])
	# Heads sit on the front face: local z of this frame is the piece's up.
	var up := Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), Vector3.ZERO)
	for fix: Dictionary in made[&"fixes"]:
		var kind: int = fix[&"kind"]
		var poly := _ngon(6 if kind == 0 else 8, 0.017 if kind == 0 else 0.022)
		if kind == 1:
			poly = PackedVector2Array([Vector2(-0.03, -0.03), Vector2(0.03, -0.03),
				Vector2(0.03, 0.03), Vector2(-0.03, 0.03)])
		var xf := Transform3D(up.basis, Vector3(0.0, top, float(fix[&"s"])))
		_extrude(st, poly, xf, -0.002, VanKitBraces.HEAD_M if kind != 1 else 0.006, 0.0, 0.0)
	st.generate_normals()
	var mi := VanKitWindowsMesh.node(parent, "Brace", st.commit())
	mi.transform = p.transform
	VanKitWindowsMesh.style(mi, paint, paint.darkened(0.3), rust, int(VanDonor.WallStyle.FLAT),
			1.0, van_seed, p.def_id)
	return mi


static func _profile(section: String, half: float) -> PackedVector2Array:
	match section:
		"angle_iron":
			var t := ANGLE_LEG_M
			return PackedVector2Array([Vector2(-half, -half), Vector2(half, -half),
				Vector2(half, -half + t), Vector2(-half + t, -half + t), Vector2(-half + t, half),
				Vector2(-half, half)])
		"rebar":
			return _ngon(8, half)
	return _ngon(12, half)


static func _ngon(n: int, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		out.append(Vector2.from_angle(TAU * i / n) * radius)
	return out


## Extrudes `poly` (in `xf`'s local xy) along local z from z0 to z1; each end is cut by a plane
## tilted `cut_a` / `cut_b` radians about local y.
static func _extrude(st: SurfaceTool, poly: PackedVector2Array, xf: Transform3D, z0: float,
		z1: float, cut_a: float, cut_b: float) -> void:
	var pts := poly
	if Geometry2D.is_polygon_clockwise(pts):
		pts = pts.duplicate()
		pts.reverse()
	var n := pts.size()
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for pt in pts:
		lo.append(xf * Vector3(pt.x, pt.y, z0 + tan(cut_a) * pt.x))
		hi.append(xf * Vector3(pt.x, pt.y, z1 + tan(cut_b) * pt.x))
	for i in n:
		var j := (i + 1) % n
		var edge := pts[j] - pts[i]
		var out := xf.basis * Vector3(edge.y, -edge.x, 0.0)
		_quad(st, lo[i], lo[j], hi[j], hi[i], out)
	var tris := Geometry2D.triangulate_polygon(pts)
	for k in range(0, tris.size(), 3):
		_tri(st, lo[tris[k]], lo[tris[k + 1]], lo[tris[k + 2]], -(xf.basis * Vector3.BACK))
		_tri(st, hi[tris[k]], hi[tris[k + 1]], hi[tris[k + 2]], xf.basis * Vector3.BACK)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		want: Vector3) -> void:
	_tri(st, a, b, c, want)
	_tri(st, a, c, d, want)


## A triangle wound so its front face looks along `want`.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, want: Vector3) -> void:
	var flip := (b - a).cross(c - a).dot(want) > 0.0
	for v in ([a, c, b] if flip else [a, b, c]):
		st.add_vertex(v)
