class_name ArmFingerGlb
extends RefCounted
## What the finger build reads off the glb hand skin: its mesh, the vertices each finger bone owns, and a finger's tip length and root radius measured from them.


## The arm skeleton's glb mesh: first skinned MeshInstance3D child (as ArmSkinMesh._arm_mesh).
static func glb_mesh(sk: Skeleton3D) -> MeshInstance3D:
	if sk == null:
		return null
	for c in sk.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).skin != null:
			return c as MeshInstance3D
	return null


## Glb vertices in bone space per bind index, those the bind holds at weight 0.5 or more.
static func owned(mi: MeshInstance3D) -> Dictionary:
	var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := int(float(bones.size()) / maxf(float(verts.size()), 1.0))
	var out := {}
	if per == 0 or weights.size() < verts.size() * per:
		return out
	for k in verts.size():
		for m in per:
			if weights[k * per + m] >= 0.5:
				var b := bones[k * per + m]
				var pts: PackedVector3Array = out.get(b, PackedVector3Array())
				pts.append(mi.skin.get_bind_pose(b) * verts[k])
				out[b] = pts
	return out


## The leaf bone's length: its highest owned vertex, or 0.8 x the parent's with too few.
static func tip_len(pts: PackedVector3Array, len02: float) -> float:
	if pts.size() < 3:
		return 0.8 * len02
	var top := pts[0].y
	for p in pts:
		top = maxf(top, p.y)
	return top


## The un-shrunk root's radius: 90th percentile of the owned vertices just past the head.
static func root_radius(pts: PackedVector3Array, length: float) -> float:
	var rs: Array[float] = []
	for p in pts:
		var u := p.y / length
		if u >= 0.02 and u <= 0.10:
			rs.append(Vector2(p.x, p.z).length())
	if rs.size() < 6:
		return 0.26 * length
	rs.sort()
	return rs[int(0.9 * float(rs.size() - 1))]
