extends RefCounted
## Builds one building's body: SurfaceTool quads with UV in metres (u along the facade, v up),
## end returns, a roof plate, the stop-bay header / flank cut, and the flank collision that keeps
## bullets bouncing beside a bay mouth.


const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")

const RETURN_DEPTH := 0.8
const ROOF_DEPTH := 1.2
const MOUTH_REVEAL_X := 9.6
const FLANK_COLLISION_THICKNESS := 0.4


## Builds one non-mouth body, or (mouth) the header/flank/flank trio that frames a stop-bay
## opening; returns the header node for a mouth body so callers keep a single MeshInstance3D.
static func build(host: Node3D, plan: Dictionary, side_sign: float, index: int) -> MeshInstance3D:
	var x_face := _FacadePlan.face_x(plan, side_sign)
	var x_back := side_sign * 9.6
	var y0 := _FacadePlan.BASE_Y
	var y1 := y0 + float(plan[&"height"])
	var z0 := float(plan[&"z0"])
	var z1 := float(plan[&"z1"])
	var w := z1 - z0
	var n_face := Vector3(-side_sign, 0.0, 0.0)
	var mouth := bool(plan.get(&"mouth", false))
	var material := _FacadeMaterials.facade_material(plan[&"params"])

	if not mouth:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		add_quad(
			st,
			Vector3(x_face, y0, z0), Vector3(x_face, y0, z1),
			Vector3(x_face, y1, z1), Vector3(x_face, y1, z0),
			Vector2(_u(z0, z0, z1, side_sign), 0.0), Vector2(_u(z1, z0, z1, side_sign), 0.0),
			Vector2(_u(z1, z0, z1, side_sign), y1 - y0), Vector2(_u(z0, z0, z1, side_sign), y1 - y0),
			n_face
		)
		_add_end_return(st, x_face, x_back, z0, y0, y1, y0, w, -1.0)
		_add_end_return(st, x_face, x_back, z1, y0, y1, y0, w, 1.0)
		_add_roof(st, x_face, side_sign, y1, z0, z1)
		return _commit_body(host, st, "Body%d" % index, material)

	# The mouth needs three separate AABBs (header, flank, flank) so the smoke test's keep-out
	# audit can clear the opening between them instead of one box that necessarily covers it.
	var header_y := _FacadePlan.BAY_HEADER_Y
	var flank_half_z := _FacadePlan.BAY_FLANK_HALF_Z
	var x_reveal := side_sign * MOUTH_REVEAL_X

	var st_header := SurfaceTool.new()
	st_header.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Header above the mouth.
	add_quad(
		st_header,
		Vector3(x_face, header_y, z0), Vector3(x_face, header_y, z1),
		Vector3(x_face, y1, z1), Vector3(x_face, y1, z0),
		Vector2(_u(z0, z0, z1, side_sign), header_y - y0),
		Vector2(_u(z1, z0, z1, side_sign), header_y - y0),
		Vector2(_u(z1, z0, z1, side_sign), y1 - y0), Vector2(_u(z0, z0, z1, side_sign), y1 - y0),
		n_face
	)
	# Soffit under the header, from the face out to the mouth reveal.
	add_quad(
		st_header,
		Vector3(x_face, header_y, -flank_half_z), Vector3(x_face, header_y, flank_half_z),
		Vector3(x_reveal, header_y, flank_half_z), Vector3(x_reveal, header_y, -flank_half_z),
		Vector2(0.0, 0.0), Vector2(flank_half_z * 2.0, 0.0),
		Vector2(flank_half_z * 2.0, absf(x_reveal - x_face)), Vector2(0.0, absf(x_reveal - x_face)),
		Vector3(0.0, -1.0, 0.0)
	)
	_add_roof(st_header, x_face, side_sign, y1, z0, z1)
	_add_end_return(st_header, x_face, x_back, z0, header_y, y1, y0, w, -1.0)
	_add_end_return(st_header, x_face, x_back, z1, header_y, y1, y0, w, 1.0)
	var header_node := _commit_body(host, st_header, "Body%dHeader" % index, material)

	var st_flank_neg := SurfaceTool.new()
	st_flank_neg.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Flank beside the mouth, up to the header.
	add_quad(
		st_flank_neg,
		Vector3(x_face, y0, z0), Vector3(x_face, y0, -flank_half_z),
		Vector3(x_face, header_y, -flank_half_z), Vector3(x_face, header_y, z0),
		Vector2(_u(z0, z0, z1, side_sign), 0.0),
		Vector2(_u(-flank_half_z, z0, z1, side_sign), 0.0),
		Vector2(_u(-flank_half_z, z0, z1, side_sign), header_y - y0),
		Vector2(_u(z0, z0, z1, side_sign), header_y - y0),
		n_face
	)
	# Reveal at the mouth's flank wall, facing the mouth centre.
	add_quad(
		st_flank_neg,
		Vector3(x_face, y0, -flank_half_z), Vector3(x_reveal, y0, -flank_half_z),
		Vector3(x_reveal, header_y, -flank_half_z), Vector3(x_face, header_y, -flank_half_z),
		Vector2(w + 0.0, 0.0), Vector2(w + absf(x_reveal - x_face), 0.0),
		Vector2(w + absf(x_reveal - x_face), header_y - y0), Vector2(w + 0.0, header_y - y0),
		Vector3(0.0, 0.0, 1.0)
	)
	_add_end_return(st_flank_neg, x_face, x_back, z0, y0, header_y, y0, w, -1.0)
	_commit_body(host, st_flank_neg, "Body%dFlankNeg" % index, material)

	var st_flank_pos := SurfaceTool.new()
	st_flank_pos.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Flank beside the mouth, up to the header.
	add_quad(
		st_flank_pos,
		Vector3(x_face, y0, flank_half_z), Vector3(x_face, y0, z1),
		Vector3(x_face, header_y, z1), Vector3(x_face, header_y, flank_half_z),
		Vector2(_u(flank_half_z, z0, z1, side_sign), 0.0), Vector2(_u(z1, z0, z1, side_sign), 0.0),
		Vector2(_u(z1, z0, z1, side_sign), header_y - y0),
		Vector2(_u(flank_half_z, z0, z1, side_sign), header_y - y0),
		n_face
	)
	# Reveal at the mouth's flank wall, facing the mouth centre.
	add_quad(
		st_flank_pos,
		Vector3(x_face, y0, flank_half_z), Vector3(x_reveal, y0, flank_half_z),
		Vector3(x_reveal, header_y, flank_half_z), Vector3(x_face, header_y, flank_half_z),
		Vector2(w + 0.0, 0.0), Vector2(w + absf(x_reveal - x_face), 0.0),
		Vector2(w + absf(x_reveal - x_face), header_y - y0), Vector2(w + 0.0, header_y - y0),
		Vector3(0.0, 0.0, -1.0)
	)
	_add_end_return(st_flank_pos, x_face, x_back, z1, y0, header_y, y0, w, 1.0)
	_commit_body(host, st_flank_pos, "Body%dFlankPos" % index, material)

	return header_node


## Roof plate from the face out to ROOF_DEPTH, at a body's top.
static func _add_roof(
	st: SurfaceTool, x_face: float, side_sign: float, y1: float, z0: float, z1: float
) -> void:
	var x_roof := side_sign * (absf(x_face) + ROOF_DEPTH)
	add_quad(
		st,
		Vector3(x_face, y1, z0), Vector3(x_face, y1, z1),
		Vector3(x_roof, y1, z1), Vector3(x_roof, y1, z0),
		Vector2(0.0, 0.0), Vector2(z1 - z0, 0.0),
		Vector2(z1 - z0, absf(x_roof - x_face)), Vector2(0.0, absf(x_roof - x_face)),
		Vector3(0.0, 1.0, 0.0)
	)


## An end return closing the face back to the wall plane, from y_a to y_b; v is measured from y0
## so a mouth's split header/flank pieces still line up with the header/flank quads above them.
static func _add_end_return(
	st: SurfaceTool, x_face: float, x_back: float, z: float, y_a: float, y_b: float, y0: float,
	w: float, normal_z: float
) -> void:
	add_quad(
		st,
		Vector3(x_face, y_a, z), Vector3(x_back, y_a, z),
		Vector3(x_back, y_b, z), Vector3(x_face, y_b, z),
		Vector2(w + 0.0, y_a - y0), Vector2(w + absf(x_back - x_face), y_a - y0),
		Vector2(w + absf(x_back - x_face), y_b - y0), Vector2(w + 0.0, y_b - y0),
		Vector3(0.0, 0.0, normal_z)
	)


## Commits a SurfaceTool into a shadow-casting MeshInstance3D under host.
static func _commit_body(
	host: Node3D, st: SurfaceTool, node_name: String, material: ShaderMaterial
) -> MeshInstance3D:
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	host.add_child(mi)
	return mi


## u along the facade, measured from the building's left end as seen from the road.
static func _u(z: float, z0: float, z1: float, side_sign: float) -> float:
	if side_sign > 0.0:
		return z - z0
	return z1 - z


## Restores the bounce surfaces around a bay mouth; the tile disables its own wall collision
## on that side so the van can reverse-park through the opening.
static func build_flank_collision(host: Node3D, side_sign: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "BayFlankSurfaces"

	var flank_neg := CollisionShape3D.new()
	flank_neg.name = "FlankNeg"
	var flank_neg_shape := BoxShape3D.new()
	flank_neg_shape.size = Vector3(0.4, 8.4, 5.5)
	flank_neg.shape = flank_neg_shape
	flank_neg.position = Vector3(side_sign * 9.0, 3.8, -7.25)
	body.add_child(flank_neg)

	var flank_pos := CollisionShape3D.new()
	flank_pos.name = "FlankPos"
	var flank_pos_shape := BoxShape3D.new()
	flank_pos_shape.size = Vector3(0.4, 8.4, 5.5)
	flank_pos.shape = flank_pos_shape
	flank_pos.position = Vector3(side_sign * 9.0, 3.8, 7.25)
	body.add_child(flank_pos)

	var header := CollisionShape3D.new()
	header.name = "Header"
	var header_shape := BoxShape3D.new()
	header_shape.size = Vector3(0.4, 32.0, 20.0)
	header.shape = header_shape
	header.position = Vector3(side_sign * 9.0, 24.0, 0.0)
	body.add_child(header)

	host.add_child(body)
	return body


## Sign of cross(b - a, c - a).dot(normal) for a Godot front-facing triangle, read once from a
## BoxMesh so this file never assumes a winding convention.
static var _front_sign := 0.0


## Reads the front-face winding sign from a BoxMesh's first triangle and caches it.
static func front_sign() -> float:
	if _front_sign == 0.0:
		var box := BoxMesh.new()
		var arrays: Array = box.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var i0 := indices[0]
		var i1 := indices[1]
		var i2 := indices[2]
		var c := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
		_front_sign = signf(c.dot(normals[i0]))
		if _front_sign == 0.0:
			_front_sign = -1.0
			push_warning("facade_body: winding oracle degenerate, assuming clockwise front faces")
	return _front_sign


## a-b-c-d must be CCW as seen from the side normal points to; emitted as triangles a-b-c and
## a-c-d. Guarded so a wrong winding (invisible with cull_back) can't happen: the oracle decides
## which cross-product sign is front-facing, and if the first triangle disagrees, the quad is
## emitted reversed (a, d, c, b).
static func add_quad(
	st: SurfaceTool,
	a: Vector3, b: Vector3, c: Vector3, d: Vector3,
	uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, uv_d: Vector2,
	normal: Vector3
) -> void:
	var verts: Array[Vector3] = [a, b, c, d]
	var uvs: Array[Vector2] = [uv_a, uv_b, uv_c, uv_d]
	var s := signf((b - a).cross(c - a).dot(normal))
	if s != 0.0 and s != front_sign():
		verts = [a, d, c, b]
		uvs = [uv_a, uv_d, uv_c, uv_b]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(verts[i])
