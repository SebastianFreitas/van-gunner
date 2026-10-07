extends RefCounted
## Steel lips and the outer astragal on the rear leaves' street face, covering their slits from outside.


static func build(doors: Node3D, left: Node3D, right: Node3D) -> void:
	if doors == null or left == null or right == null:
		return
	for old in [left.get_node_or_null("OuterLip"), right.get_node_or_null("OuterLip"),
			right.get_node_or_null("AstragalOuter")]:
		if old != null:
			old.free()
	var mat := _material(left)
	var lip_inv := Transform3D(Basis.IDENTITY, -left.position)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_bottom_strip(st, left, lip_inv)
	st.generate_tangents()
	var lip_mesh := st.commit()
	_add_mesh(left, "OuterLip", lip_mesh, mat)
	var right_lip := _add_mesh(right, "OuterLip", lip_mesh, mat)
	# Negative scale mirrors the same mesh onto the right leaf, like the leaf body.
	right_lip.scale = Vector3(-1.0, 1.0, 1.0)
	var inv := Transform3D(Basis.IDENTITY, -right.position)
	var ast := SurfaceTool.new()
	ast.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := VanInteriorSize.REAR_DOOR_TOP
	_box(ast, Vector3(-0.05, -0.05, 6.735), Vector3(0.05, top + 0.045, 6.747), inv)
	_box(ast, Vector3(0.035, 0.10, 6.65), Vector3(0.05, top - 0.10, 6.735), inv)
	ast.generate_tangents()
	_add_mesh(right, "AstragalOuter", ast.commit(), mat)


static func _add_mesh(hinge: Node3D, node_name: String, mesh: Mesh,
		mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.layers = 1
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	hinge.add_child(node)
	return node


static func _bottom_strip(st: SurfaceTool, left: Node3D, inv: Transform3D) -> void:
	var a := _six(-(absf(left.position.x) - 0.02), -0.01, 0.07, 0.055)
	var b := _six(-0.025, -0.01, 0.07, 0.055)
	_span(st, a, b, inv)
	_fan(st, a, Vector3(-1.0, 0.0, 0.0), inv)
	_fan(st, b, Vector3(1.0, 0.0, 0.0), inv)


## Six-point section at a station: inner and outer edge of the plate, lip return, buried base.
static func _six(x: float, y_outer: float, y_inner: float, y_mid: float) -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(x, y_inner, 6.65), Vector3(x, y_inner, 6.715), Vector3(x, y_outer, 6.715),
		Vector3(x, y_outer, 6.70), Vector3(x, y_mid, 6.70), Vector3(x, y_mid, 6.65)])


## One quad per section edge between stations a and b.
static func _span(st: SurfaceTool, a: PackedVector3Array, b: PackedVector3Array,
		inv: Transform3D) -> void:
	var count := a.size()
	var ia := Vector2(a[0].x, a[0].y)
	var ib := Vector2(b[0].x, b[0].y)
	var oa := Vector2(a[2].x, a[2].y)
	var ob := Vector2(b[2].x, b[2].y)
	var to_outer := (oa + ob) * 0.5 - (ia + ib) * 0.5
	for i in count:
		var n := (i + 1) % count
		var out := Vector3(0.0, 0.0, -1.0)
		if i == 0:
			out = _perp(ia, ib, -to_outer)
		elif i == 1:
			out = Vector3(0.0, 0.0, 1.0)
		elif i == 2:
			out = _perp(oa, ob, to_outer)
		elif i == 4:
			out = _perp(Vector2(a[4].x, a[4].y), Vector2(b[4].x, b[4].y), to_outer)
		_quad(st, a[i], a[n], b[n], b[i], out, inv)


## Cap of a six-point section as a fan around point 5.
static func _fan(st: SurfaceTool, s: PackedVector3Array, out: Vector3,
		inv: Transform3D) -> void:
	_tri(st, s[4], s[5], s[0], out, inv)
	_tri(st, s[4], s[0], s[1], out, inv)
	_tri(st, s[4], s[1], s[2], out, inv)
	_tri(st, s[4], s[2], s[3], out, inv)


## Axis-aligned closed box, all six faces.
static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3, inv: Transform3D) -> void:
	var x := Vector2(lo.x, hi.x)
	var y := Vector2(lo.y, hi.y)
	var z := Vector2(lo.z, hi.z)
	_quad(st, Vector3(x.x, y.x, z.x), Vector3(x.x, y.y, z.x), Vector3(x.x, y.y, z.y),
		Vector3(x.x, y.x, z.y), Vector3(-1.0, 0.0, 0.0), inv)
	_quad(st, Vector3(x.y, y.x, z.x), Vector3(x.y, y.y, z.x), Vector3(x.y, y.y, z.y),
		Vector3(x.y, y.x, z.y), Vector3(1.0, 0.0, 0.0), inv)
	_quad(st, Vector3(x.x, y.x, z.x), Vector3(x.y, y.x, z.x), Vector3(x.y, y.x, z.y),
		Vector3(x.x, y.x, z.y), Vector3(0.0, -1.0, 0.0), inv)
	_quad(st, Vector3(x.x, y.y, z.x), Vector3(x.y, y.y, z.x), Vector3(x.y, y.y, z.y),
		Vector3(x.x, y.y, z.y), Vector3(0.0, 1.0, 0.0), inv)
	_quad(st, Vector3(x.x, y.x, z.x), Vector3(x.y, y.x, z.x), Vector3(x.y, y.y, z.x),
		Vector3(x.x, y.y, z.x), Vector3(0.0, 0.0, -1.0), inv)
	_quad(st, Vector3(x.x, y.x, z.y), Vector3(x.y, y.x, z.y), Vector3(x.y, y.y, z.y),
		Vector3(x.x, y.y, z.y), Vector3(0.0, 0.0, 1.0), inv)


## In-plane perpendicular of segment a->b, flipped to face along `away`.
static func _perp(a: Vector2, b: Vector2, away: Vector2) -> Vector3:
	var seg := b - a
	var perp := Vector2(seg.y, -seg.x)
	if perp.dot(away) < 0.0:
		perp = -perp
	return Vector3(perp.x, perp.y, 0.0).normalized()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		out: Vector3, inv: Transform3D) -> void:
	_tri(st, a, b, c, out, inv)
	_tri(st, a, c, d, out, inv)


## Godot front faces are clockwise seen from outside, so flip any triangle that isn't.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3,
		inv: Transform3D) -> void:
	var second := b
	var third := c
	if (c - a).cross(b - a).dot(out) < 0.0:
		second = c
		third = b
	_vert(st, a, out, inv)
	_vert(st, second, out, inv)
	_vert(st, third, out, inv)


static func _vert(st: SurfaceTool, p: Vector3, out: Vector3, inv: Transform3D) -> void:
	st.set_normal((inv.basis * out).normalized())
	st.set_uv(Vector2(p.x, p.y))
	st.add_vertex(inv * p)


## The handle mount's steel, else the leaf body's, so the lips match the doors.
static func _material(left_hinge: Node3D) -> Material:
	var mount := left_hinge.get_node_or_null("Handle/Mount")
	if mount != null:
		var mat := mount.get("material") as Material
		if mat != null:
			return mat
	var body := left_hinge.get_node_or_null("CurvedBody") as GeometryInstance3D
	if body != null:
		return body.material_override
	return null
