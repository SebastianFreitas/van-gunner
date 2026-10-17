extends RefCounted
## Debug console `arms seam`: per hand, the longest posed edge and the open boundary edges near the wrist, to see a gap between hand and forearm.

## Radius around the hand bone head (m, posed) that counts as the wrist seam.
const NEAR := 0.06


## One line per hand: longest posed edge near the wrist, mean edge there and open edge count.
func run(vm: Node) -> String:
	var roots := vm.get("_roots") as Dictionary
	var lines: Array[String] = []
	for hand: Array in [["R", "right_root"], ["L", "left_root"]]:
		var root := roots.get(hand[1]) as Node3D
		if root == null:
			lines.append("seam %s: no root" % hand[0])
			continue
		for c in root.get_children():
			if c is Node3D and ArmRig.skeleton(c as Node3D) != null:
				lines.append(_measure(c as Node3D, hand[0]))
	return "\n".join(lines)


func _measure(model: Node3D, side: String) -> String:
	var sk := ArmRig.skeleton(model)
	sk.force_update_all_bone_transforms()
	var hb := sk.find_bone("DEF-hand." + side)
	var mi := model.find_child("Arm" + side, true, false) as MeshInstance3D
	if hb < 0 or mi == null or mi.skin == null or mi.mesh == null:
		return "seam %s: no hand or mesh" % side
	var centre := sk.get_bone_global_pose(hb).origin
	var skin := mi.skin
	var xf: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = sk.find_bone(skin.get_bind_name(b))
		xf.append(sk.get_bone_global_pose(bone) * skin.get_bind_pose(b))
	var longest := 0.0
	var total := 0.0
	var count := 0
	var open_edges := 0
	var rad := PackedFloat32Array()
	rad.resize(12 * 12)
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var per := int(float(bones.size()) / maxf(verts.size(), 1.0))
		var posed := PackedVector3Array()
		posed.resize(verts.size())
		for i in verts.size():
			var acc := Vector3.ZERO
			for k in per:
				if weights[i * per + k] > 0.0:
					acc += weights[i * per + k] * (xf[bones[i * per + k]] * verts[i])
			posed[i] = acc
		var uses := {}
		var weld := PackedInt32Array()
		var ids := {}
		for i in verts.size():
			var at := Vector3i((verts[i] * 100000.0).round())
			if not ids.has(at):
				ids[at] = i
			weld.append(ids[at])
		for t in range(0, index.size(), 3):
			for e in 3:
				var p := index[t + e]
				var q := index[t + (e + 1) % 3]
				var wp: int = weld[p]
				var wq: int = weld[q]
				var key := Vector2i(mini(wp, wq), maxi(wp, wq))
				uses[key] = int(uses.get(key, 0)) + 1
				if posed[p].distance_to(centre) > NEAR or posed[q].distance_to(centre) > NEAR:
					continue
				var edge := posed[p].distance_to(posed[q])
				longest = maxf(longest, edge)
				total += edge
				count += 1
		for i in verts.size():
			var lv := sk.get_bone_global_pose(hb).affine_inverse() * posed[i]
			if absf(lv.y + 0.01) < 0.04 and Vector2(lv.x, lv.z).length() < 0.08:
				var slab := int((lv.y + 0.05) / 0.01)
				var bin := int((atan2(lv.z, lv.x) + PI) / (TAU / 12.0)) % 12
				rad[slab * 12 + bin] = maxf(rad[slab * 12 + bin], Vector2(lv.x, lv.z).length())
		for key: Vector2i in uses:
			if uses[key] == 1:
				open_edges += 1
	return "seam %s: longest edge %.4f m, mean %.4f m, open edges %d (within %.2f m of wrist)" % [
			side, longest, total / maxf(count, 1.0), open_edges, NEAR] + _grid(rad)


## Rows by hand-local y slab (0.01 m, from -0.05), 12 angle bins each: max radius in mm.
func _grid(rad: PackedFloat32Array) -> String:
	var out := ""
	for r in 8:
		out += "\n   y%+.2f:" % (-0.05 + r * 0.01)
		for b in 12:
			out += " %3d" % int(rad[r * 12 + b] * 1000.0)
	return out

