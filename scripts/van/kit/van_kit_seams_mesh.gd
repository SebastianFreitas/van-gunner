class_name VanKitSeamsMesh
extends RefCounted
## Builds the seam pass's meshes: lap strips as donor skins, weld beads, straps and channels.

const BEAD_PAINT := Color(0.20, 0.15, 0.11)
const _BEAD_PRIMER := Color(0.07, 0.065, 0.06)
## Ridge (gable) bead: crest height range, and the earlier skin and lap tops its feet stand on.
const RIDGE_M := Vector2(0.048, 0.056)
const _LAP_TOP := 0.042
const _SKIN_TOP := 0.02
## Flank tilts, kept off the audit's ~10 degree coplanar tolerance and under 43.
const _TAN_LAP := 0.532
const _TAN_SKIN := 0.781
const _STRAP_PAINT := Color(0.16, 0.15, 0.14)
const _STRAP_THICK := 0.006
const _FLANGE_THICK := 0.04
const _FLANGE_CM := 0.6
const _MATERIAL: ShaderMaterial = preload("res://resources/van_kit/van_kit_grime_material.tres")


static func build(donors: VanDonorSet, placed: Array[VanKitPlaced], parent: Node3D,
		van_seed: int) -> void:
	var laps: Array[VanKitPlaced] = []
	for p in placed:
		if p.origin_kind == &"DONOR":
			laps.append(p)
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Seam_" + String(p.origin_id) + "_" + str(parent.get_child_count())
		mi.mesh = _mesh(p)
		mi.material_override = _MATERIAL
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = VanLighting.LAYER_VAN_INTERIOR
		parent.add_child(mi)
		var bead := p.origin_id == &"weld_bead"
		VanKitWindowsMesh.style_height(mi)
		mi.set_instance_shader_parameter(&"paint", BEAD_PAINT if bead else _STRAP_PAINT)
		mi.set_instance_shader_parameter(&"primer", _BEAD_PRIMER)
		mi.set_instance_shader_parameter(&"rust_amount", 0.7 if bead else 0.5)
		mi.set_instance_shader_parameter(&"grime_amount", 0.6)
		mi.set_instance_shader_parameter(&"wall_style", int(VanDonor.WallStyle.FLAT))
		mi.set_instance_shader_parameter(&"rib_pitch_m", 0.0)
		mi.set_instance_shader_parameter(&"seed",
			float(van_seed % 997) + float(hash(p.origin_id) % 97))
	VanKitSkinMesh.build(donors, laps, parent, van_seed)


## Footprint runs (cm) of a ridge of crest height `h`: [lap side, earlier skin side].
static func ridge_runs(h: float) -> Vector2:
	return Vector2((h - _LAP_TOP) / _TAN_LAP, (h - _SKIN_TOP) / _TAN_SKIN) * 100.0


## Gable along a bead piece whose outline is left chain + reversed right chain (lap foot to
## skin foot); the crest height at each pair is recovered from the pair's width. A piece the
## keep-out clip has reshaped no longer pairs up and gets no mesh.
static func _ridge(p: VanKitPlaced) -> ArrayMesh:
	var o := p.outline
	var m := o.size() >> 1
	var mesh := ArrayMesh.new()
	if o.size() % 2 != 0 or m < 2:
		return mesh
	var lo := ridge_runs(RIDGE_M.x)
	var hi := ridge_runs(RIDGE_M.y)
	var feet: Array[Vector3] = []
	var crest: Array[Vector3] = []
	var top: Array[Vector2] = []
	for i in m:
		var l := o[i]
		var r := o[o.size() - 1 - i]
		var width := l.distance_to(r)
		if width < lo.x + lo.y - 0.1 or width > hi.x + hi.y + 0.1:
			return mesh
		var h := (width * 0.01 + _LAP_TOP / _TAN_LAP + _SKIN_TOP / _TAN_SKIN) \
				/ (1.0 / _TAN_LAP + 1.0 / _TAN_SKIN)
		var c := l.lerp(r, ridge_runs(h).x / width)
		feet.append(VanKitSurface.point(p.surface, l.x, l.y, _LAP_TOP))
		feet.append(VanKitSurface.point(p.surface, r.x, r.y, _SKIN_TOP))
		crest.append(VanKitSurface.point(p.surface, c.x, c.y, h))
		top.append(c)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := VanKitSurface.normal(p.surface, top[0].x, top[0].y)
	for i in m - 1:
		for side in 2:
			var a := feet[i * 2 + side]
			var b := feet[i * 2 + 2 + side]
			var quad: Array[Vector3] = [a, b, crest[i + 1], crest[i]]
			for t: Array in [[0, 1, 2], [0, 2, 3]]:
				var n := (quad[t[1]] - quad[t[0]]).cross(quad[t[2]] - quad[t[0]]).normalized()
				var order: Array = t
				if n.dot(up) <= 0.0:
					n = -n
					order = [t[0], t[2], t[1]]
				for k: int in order:
					st.set_normal(n)
					st.set_uv(Vector2(quad[k].x + quad[k].z, quad[k].y + quad[k].z) * 0.5)
					st.add_vertex(quad[k])
	st.commit(mesh)
	return mesh


static func _mesh(p: VanKitPlaced) -> ArrayMesh:
	if p.origin_id == &"weld_bead":
		return _ridge(p)
	var web := VanKitSurface.slab(p.surface, p.outline, p.size.y, _STRAP_THICK)
	if p.origin_id != &"channel" or p.outline.size() != 4:
		return web
	# U section: the web plus a flange down each long edge.
	var st := SurfaceTool.new()
	st.append_from(web, 0, Transform3D.IDENTITY)
	var o := p.outline
	var flanges: Array[PackedVector2Array] = [
		PackedVector2Array([o[0], o[1], o[1] + (o[3] - o[0]).normalized() * _FLANGE_CM,
			o[0] + (o[3] - o[0]).normalized() * _FLANGE_CM]),
		PackedVector2Array([o[3], o[2], o[2] + (o[0] - o[3]).normalized() * _FLANGE_CM,
			o[3] + (o[0] - o[3]).normalized() * _FLANGE_CM])]
	for flange in flanges:
		if Geometry2D.is_polygon_clockwise(flange):
			flange.reverse()
		st.append_from(VanKitSurface.slab(p.surface, flange, p.size.y, _FLANGE_THICK), 0,
			Transform3D.IDENTITY)
	return st.commit()
