class_name VanKitStructureMesh
extends RefCounted
## Builds the structure pieces (ribs, bows, pillars) as chunky 7 cm profiles on the kit grime shader.

const _MATERIAL: ShaderMaterial = preload("res://resources/van_kit/van_kit_grime_material.tres")
## Flange and web thickness; nothing in a profile is thinner than this except the C's lips.
const _T := 0.03

## Profile meshes of length 1 m along local x, keyed by profile and width.
var _meshes := {}


## One MeshInstance3D per placed piece under `parent`, the donor's look on each.
func build(donors: VanDonorSet, placed: Array[VanKitPlaced], parent: Node3D, van_seed: int) -> void:
	for p in placed:
		var donor: VanDonor = null
		for d in donors.donors:
			if d.id == p.origin_id:
				donor = d
		if donor == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Structure_" + String(p.reason)
		mi.mesh = _mesh(donor.rib_profile, p.size.z)
		mi.material_override = _MATERIAL
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = VanLighting.LAYER_VAN_INTERIOR
		mi.transform = Transform3D(p.transform.basis * Basis.from_scale(Vector3(p.size.x, 1.0, 1.0)),
				p.transform.origin)
		parent.add_child(mi)
		VanKitWindowsMesh.style_height(mi)
		mi.set_instance_shader_parameter(&"fastener_era", int(donor.fastener_era))
		mi.set_instance_shader_parameter(&"paint", donor.paint)
		mi.set_instance_shader_parameter(&"primer", donor.primer)
		mi.set_instance_shader_parameter(&"rust_amount", clampf(donor.fade, 0.0, 1.0))
		mi.set_instance_shader_parameter(&"grime_amount", 0.6)
		mi.set_instance_shader_parameter(&"wall_style", int(donor.wall_style))
		mi.set_instance_shader_parameter(&"rib_pitch_m", clampf(donor.rib_pitch_m, 0.0, 1.0))
		mi.set_instance_shader_parameter(&"seed", float(van_seed % 997) + float(hash(p.origin_id) % 97))


func _mesh(profile: int, width: float) -> ArrayMesh:
	var key := "%d/%d" % [profile, roundi(width * 1000.0)]
	if not _meshes.has(key):
		_meshes[key] = _extrude(_profile(profile, width, VanKitStructure.DEPTH))
	return _meshes[key]


## The (z, y) outline, y from the liner (-depth/2) to the face; vertices go around the section.
func _profile(profile: int, width: float, depth: float) -> PackedVector2Array:
	var hw := width * 0.5
	var y0 := -depth * 0.5
	var y1 := depth * 0.5
	match profile:
		VanDonor.RibProfile.Z:
			var w := _T * 0.5
			return PackedVector2Array([Vector2(-hw, y0), Vector2(w, y0), Vector2(w, y1 - _T),
				Vector2(hw, y1 - _T), Vector2(hw, y1), Vector2(-w, y1), Vector2(-w, y0 + _T),
				Vector2(-hw, y0 + _T)])
		VanDonor.RibProfile.C:
			var lip := minf(_T, hw * 0.6)
			return PackedVector2Array([Vector2(-hw, y0), Vector2(-hw, y1), Vector2(hw, y1),
				Vector2(hw, y0), Vector2(hw - lip, y0), Vector2(hw - lip, y1 - _T),
				Vector2(-hw + lip, y1 - _T), Vector2(-hw + lip, y0)])
		_:
			# Top hat: flanges on the liner, a tapering crown, so the sides stay big faces.
			var tw := hw * 0.55
			return PackedVector2Array([Vector2(-hw, y0), Vector2(-hw, y0 + _T),
				Vector2(-tw, y0 + _T), Vector2(-tw, y1), Vector2(tw, y1), Vector2(tw, y0 + _T),
				Vector2(hw, y0 + _T), Vector2(hw, y0)])


## Extrudes the outline along x (-0.5..0.5); skips the face on the liner and adds both end caps.
func _extrude(poly: PackedVector2Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sign_a := signf(_area(poly))
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		if is_equal_approx(a.y, b.y) and is_equal_approx(a.y, -VanKitStructure.DEPTH * 0.5):
			continue
		var edge := b - a
		var out2 := Vector2(edge.y, -edge.x) * sign_a
		# Polygon is (z, y): map to local (x, y, z).
		var out3 := Vector3(0.0, out2.y, out2.x)
		var p0 := Vector3(-0.5, a.y, a.x)
		var p1 := Vector3(0.5, a.y, a.x)
		var p2 := Vector3(0.5, b.y, b.x)
		var p3 := Vector3(-0.5, b.y, b.x)
		_tri(st, p0, p1, p2, out3)
		_tri(st, p0, p2, p3, out3)
	var tris := Geometry2D.triangulate_polygon(poly)
	for sx in [-0.5, 0.5]:
		var out_x := Vector3(signf(sx), 0.0, 0.0)
		for i in range(0, tris.size(), 3):
			var v: Array[Vector3] = []
			for j in 3:
				var q := poly[tris[i + j]]
				v.append(Vector3(sx, q.y, q.x))
			_tri(st, v[0], v[1], v[2], out_x)
	st.generate_normals()
	return st.commit()


## Adds a triangle wound clockwise seen from the side `outward` points to.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var front := -(b - a).cross(c - a)
	if front.dot(outward) < 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a * 0.5
