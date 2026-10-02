class_name ArmWrap
extends RefCounted
## Shrinkwrap bands: low-poly tubes built from the skinned arm mesh's own cross-sections, so wraps, gloves, cuffs and rings hug the hand instead of floating as cylinders.

## Bone length used when neither a child bone nor a parent bone can be measured.
const FALLBACK_LEN := 0.1


static func attach(sk: Skeleton3D, bone_name: String, node_name: String) -> BoneAttachment3D:
	if sk == null or sk.find_bone(bone_name) == -1:
		push_warning("ArmWrap: bone %s missing" % bone_name)
		return null
	var att := BoneAttachment3D.new()
	att.name = node_name
	att.bone_name = bone_name
	sk.add_child(att)
	return att


static func bind_index(mi: MeshInstance3D, sk: Skeleton3D, bone_name: String) -> int:
	if mi == null or mi.skin == null or sk == null:
		return -1
	for b in mi.skin.get_bind_count():
		if _bind_name(mi, sk, b) == bone_name:
			return b
	return -1


static func bone_len(mi: MeshInstance3D, sk: Skeleton3D, bone_name: String) -> float:
	var b := bind_index(mi, sk, bone_name)
	var i := sk.find_bone(bone_name) if sk != null else -1
	if b == -1 or i == -1:
		return FALLBACK_LEN
	var head := mi.skin.get_bind_pose(b).affine_inverse().origin
	var kids := sk.get_bone_children(i)
	if not kids.is_empty():
		var cb := bind_index(mi, sk, sk.get_bone_name(kids[0]))
		if cb != -1:
			return head.distance_to(mi.skin.get_bind_pose(cb).affine_inverse().origin)
	# Leaf bone (finger tip): borrow its parent's length.
	var p := sk.get_bone_parent(i)
	if p != -1:
		var pb := bind_index(mi, sk, sk.get_bone_name(p))
		if pb != -1:
			return head.distance_to(mi.skin.get_bind_pose(pb).affine_inverse().origin)
	return FALLBACK_LEN


## Radii per sector at fraction t of the bone, empty when the bone or mesh is unusable. The mesh
## is low-poly (rings far apart), so each sector interpolates between the nearest vertex ring
## below and above t instead of sampling a thin slab that often holds no vertex.
static func section(mi: MeshInstance3D, sk: Skeleton3D, bone_name: String, t: float,
		sectors: int, include: PackedStringArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := maxi(sectors, 3)
	var b := bind_index(mi, sk, bone_name)
	if mi == null or not (mi.mesh is ArrayMesh) or b == -1:
		push_warning("ArmWrap: arm mesh, skin or bone %s missing" % bone_name)
		return out
	var count := mi.skin.get_bind_count()
	var ok := PackedByteArray()
	ok.resize(count)
	for k in count:
		var nm := _bind_name(mi, sk, k)
		ok[k] = 1 if (nm == bone_name or nm in include) else 0
	var pose := mi.skin.get_bind_pose(b)
	var blen := maxf(bone_len(mi, sk, bone_name), 0.001)
	var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	# The mesh keeps 8-bone weights, so the stride comes from the data.
	var per := int(float(bones.size()) / maxf(float(verts.size()), 1.0))
	if per == 0:
		push_warning("ArmWrap: arm mesh has no bone weights")
		return out
	if bones.size() < verts.size() * per or weights.size() < verts.size() * per:
		return out
	var radii := PackedFloat32Array()
	radii.resize(n)
	radii.fill(-1.0)
	# Per sector, the nearest vertex at or below t and the nearest above it.
	var below_u := PackedFloat32Array()
	below_u.resize(n)
	below_u.fill(-INF)
	var below_r := PackedFloat32Array()
	below_r.resize(n)
	var above_u := PackedFloat32Array()
	above_u.resize(n)
	above_u.fill(INF)
	var above_r := PackedFloat32Array()
	above_r.resize(n)
	for k in verts.size():
		# Summed, not dominant: twist and finger .01 bones rarely win a vertex outright.
		var sum_w := 0.0
		for m in per:
			var bi := bones[k * per + m]
			if bi >= 0 and bi < count and ok[bi] == 1:
				sum_w += weights[k * per + m]
		if sum_w < 0.35:
			continue
		var l := pose * verts[k]
		var u := l.y / blen
		var r := Vector2(l.x, l.z).length()
		var a := atan2(l.z, l.x)
		var s := wrapi(int(floor((a + PI) / TAU * n)), 0, n)
		if u <= t:
			if u > below_u[s]:
				below_u[s] = u
				below_r[s] = r
		elif u < above_u[s]:
			above_u[s] = u
			above_r[s] = r
	for s in n:
		var has_below := below_u[s] > -INF
		var has_above := above_u[s] < INF
		if has_below and has_above:
			var span := above_u[s] - below_u[s]
			var f := (t - below_u[s]) / span if span > 0.0 else 0.0
			radii[s] = lerpf(below_r[s], above_r[s], f)
		elif has_below:
			radii[s] = below_r[s]
		elif has_above:
			radii[s] = above_r[s]
	var filled := false
	for r in radii:
		if r >= 0.0:
			filled = true
			break
	if not filled:
		return out
	var src := radii.duplicate()
	for i in n:
		if src[i] >= 0.0:
			continue
		var back := 1
		while src[wrapi(i - back, 0, n)] < 0.0:
			back += 1
		var fwd := 1
		while src[wrapi(i + fwd, 0, n)] < 0.0:
			fwd += 1
		var r0 := src[wrapi(i - back, 0, n)]
		var r1 := src[wrapi(i + fwd, 0, n)]
		radii[i] = lerpf(r0, r1, float(back) / float(back + fwd))
	# Fills dents between neighbours but never cuts into the mesh.
	for i in n:
		radii[i] = maxf(radii[i], 0.5 * (radii[wrapi(i - 1, 0, n)] + radii[wrapi(i + 1, 0, n)]))
	return radii


static func mean_radius(radii: PackedFloat32Array) -> float:
	if radii.is_empty():
		return 0.0
	var sum := 0.0
	for r in radii:
		sum += r
	return sum / float(radii.size())


static func tube(mi: MeshInstance3D, sk: Skeleton3D, bone_name: String, t0: float, t1: float,
		rings: int, sectors: int, offset: float, include: PackedStringArray,
		rng: RandomNumberGenerator, fray: float = 0.0, tilt: float = 0.0) -> ArrayMesh:
	var nr := maxi(rings, 2)
	var ns := maxi(sectors, 3)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = 0
	var blen := bone_len(mi, sk, bone_name)
	var grid: Array[PackedVector3Array] = []
	for j in nr:
		var t := lerpf(t0, t1, float(j) / float(nr - 1))
		var radii := section(mi, sk, bone_name, t, ns, include)
		if radii.is_empty():
			return null
		var ph := rng.randf_range(0.0, TAU)
		var ring := PackedVector3Array()
		for i in ns:
			var a := -PI + (float(i) + 0.5) / float(ns) * TAU
			var r := radii[i] + offset
			var y := t * blen + tilt * blen * sin(a + ph)
			if fray > 0.0 and (j == 0 or j == nr - 1):
				y += rng.randf_range(-fray, fray) * blen
			ring.append(Vector3(r * cos(a), y, r * sin(a)))
		grid.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nr - 1:
		for i in ns:
			var i2 := (i + 1) % ns
			var p00 := grid[j][i]
			var p01 := grid[j][i2]
			var p10 := grid[j + 1][i]
			var p11 := grid[j + 1][i2]
			var out := (p00 + p01 + p10 + p11) * 0.25
			out.y = 0.0
			out = out.normalized()
			_tri(st, p00, p10, p01, out)
			_tri(st, p01, p10, p11, out)
	return st.commit()


static func band(att: Node3D, node_name: String, mi: MeshInstance3D, sk: Skeleton3D,
		bone_name: String, t0: float, t1: float, rings: int, sectors: int, offset: float,
		include: PackedStringArray, mat: Material, rng: RandomNumberGenerator,
		fray := 0.0, tilt := 0.0) -> MeshInstance3D:
	var mesh := tube(mi, sk, bone_name, t0, t1, rings, sectors, offset, include, rng, fray, tilt)
	if mesh == null:
		return null
	return ArmParts.mesh(att, node_name, mesh, mat, Vector3.ZERO)


static func surface_frame(mi: MeshInstance3D, sk: Skeleton3D, bone_name: String, t: float,
		angle_deg: float, offset: float, include: PackedStringArray) -> Transform3D:
	var blen := bone_len(mi, sk, bone_name)
	var radii := section(mi, sk, bone_name, t, 16, include)
	if radii.is_empty():
		return Transform3D(Basis.IDENTITY, Vector3(0.0, t * blen, 0.0))
	var a := deg_to_rad(angle_deg)
	var s := wrapi(int(floor((wrapf(a, -PI, PI) + PI) / TAU * 16.0)), 0, 16)
	var r := radii[s] + offset
	var x := Vector3.UP
	var y := Vector3(cos(a), 0.0, sin(a))
	return Transform3D(Basis(x, y, x.cross(y)), Vector3(r * cos(a), t * blen, r * sin(a)))


static func _bind_name(mi: MeshInstance3D, sk: Skeleton3D, b: int) -> String:
	var nm := String(mi.skin.get_bind_name(b))
	if nm.is_empty():
		nm = sk.get_bone_name(mi.skin.get_bind_bone(b))
	return nm


## Adds one flat-shaded triangle wound clockwise seen from outside (Godot's front face).
static func _tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, out: Vector3) -> void:
	var n := (p1 - p0).cross(p2 - p0)
	if n.dot(out) > 0.0:
		var tmp := p1
		p1 = p2
		p2 = tmp
	var nrm := n.normalized()
	if nrm.dot(out) < 0.0:
		nrm = -nrm
	st.set_normal(nrm)
	st.add_vertex(p0)
	st.set_normal(nrm)
	st.add_vertex(p1)
	st.set_normal(nrm)
	st.add_vertex(p2)
