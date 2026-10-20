class_name DebugArmsHandsMesh
extends RefCounted
## What the `arms hands` finger rows read off the rest mesh (bind space, no skinning): ring radii of
## each finger tube at mid-bone and in the joint zones, and the dorsal knuckle rise. Split from
## `debug_arms_hands_rows.gd` to keep both files under the line cap.
const _FINGERS: Array[StringName] = [&"f_index", &"f_middle", &"f_ring", &"f_pinky"]
## A joint zone spans this share of the shorter bone beside the joint, either way along the finger.
const ZONE := 0.25
## The knuckle rise looks at hand-weighted vertices within this many shafts of the `.01` head.
const RISE_REACH := 1.2


## {finger: {r1, r2, r3, k2, k3}} in rig units, from the finger tube's 12-vertex rings: a ring's
## radius is its vertices' mean distance from their mean, `r_k` the radius of the ring nearest the
## middle of bone k along the bone chain, `k_k` the largest ring radius within `ZONE` of joint k.
func rings(fingers_mi: MeshInstance3D, bind_o: Dictionary, fingers: Dictionary, h: String) -> Dictionary:
	var arrays := (fingers_mi.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ids := ArmFingerInfo.id_map(arrays)
	var out := {}
	for f: StringName in _FINGERS:
		var info: Dictionary = fingers[f]
		var o1: Vector3 = bind_o["DEF-%s.01.%s" % [f, h]]
		var o2: Vector3 = bind_o["DEF-%s.02.%s" % [f, h]]
		var o3: Vector3 = bind_o["DEF-%s.03.%s" % [f, h]]
		var tip := o3 + (o3 - o2).normalized() * float(info[&"tip_len"])
		var pts: Array[Vector3] = [o1, o2, o3, tip]
		var cuts: Array[float] = [0.0]
		for i in 3:
			cuts.append(cuts[i] + pts[i].distance_to(pts[i + 1]))
		var base := int(info[&"vert_base"])
		var at: Array[float] = []
		var rad: Array[float] = []
		for i in int(info[&"rings"]):
			var mean := Vector3.ZERO
			var vs: Array[Vector3] = []
			for s in ArmFingerInfo.SECTORS:
				var vi := base + i * ArmFingerInfo.SECTORS + s
				vs.append(verts[vi if ids.is_empty() else ids[vi]])
				mean += vs[s]
			mean /= float(ArmFingerInfo.SECTORS)
			var r := 0.0
			for v in vs:
				r += v.distance_to(mean)
			rad.append(r / float(vs.size()))
			at.append(_arc(pts, cuts, mean))
		var mids: Array[float] = []
		for k in 3:
			mids.append(0.5 * (cuts[k] + cuts[k + 1]))
		var res := {}
		for k in 3:
			var best := 0
			for i in at.size():
				if absf(at[i] - mids[k]) < absf(at[best] - mids[k]):
					best = i
			res["r%d" % (k + 1)] = rad[best]
		for k in [2, 3]:
			var half := ZONE * minf(cuts[k - 1] - cuts[k - 2], cuts[k] - cuts[k - 1])
			var top := 0.0
			for i in at.size():
				if absf(at[i] - cuts[k - 1]) <= half:
					top = maxf(top, rad[i])
			res["k%d" % k] = top
		out[f] = res
	return out


## Arc length along the chain `pts` (cumulative `cuts`) at the point of the chain nearest `p`.
func _arc(pts: Array[Vector3], cuts: Array[float], p: Vector3) -> float:
	var best := INF
	var arc := 0.0
	for i in 3:
		var seg := pts[i + 1] - pts[i]
		var t := clampf((p - pts[i]).dot(seg) / maxf(seg.length_squared(), 0.000001), 0.0, 1.0)
		var d := p.distance_to(pts[i] + seg * t)
		if d < best:
			best = d
			arc = cuts[i] + t * seg.length()
	return arc


## Per finger the largest dorsal rise (dorsal = UP less its part along head -> middle root) of a
## hand-weighted vertex over the head: a column, its offset from the `.01` head less the dorsal part
## within `RISE_REACH` shafts (D95; a sphere lost the top skin vertex once the knuckle swelled).
func rises(mi: MeshInstance3D, bind_o: Dictionary, fingers: Dictionary, h: String,
		head: Vector3) -> PackedFloat32Array:
	var skin := mi.skin
	var kind: Array[bool] = []
	for b in skin.get_bind_count():
		var name := String(skin.get_bind_name(b))
		kind.append(name == "DEF-hand." + h or name.begins_with("DEF-palm"))
	var roots: Array[Vector3] = []
	for f: StringName in _FINGERS:
		roots.append(bind_o["DEF-%s.01.%s" % [f, h]])
	var axis := (roots[1] - head).normalized()
	var dorsal := (Vector3.UP - axis * Vector3.UP.dot(axis)).normalized()
	var out := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var stride := int(bones.size() / float(maxi(verts.size(), 1)))
		for v in verts.size():
			var wsum := 0.0
			var hand_w := 0.0
			for k in stride:
				wsum += weights[v * stride + k]
				if kind[bones[v * stride + k]]:
					hand_w += weights[v * stride + k]
			if wsum <= 0.0 or hand_w < DebugArmsHandsRows.HAND_SHARE * wsum:
				continue
			for i in 4:
				var reach := RISE_REACH * float(fingers[_FINGERS[i]][&"shaft"])
				var off := verts[v] - roots[i]
				var rise := off.dot(dorsal)
				if (off - dorsal * rise).length() <= reach:
					out[i] = maxf(out[i], rise)
	return out

## Per neighbour pair (index-middle, middle-ring, ring-little): {gap, over} from the rest mesh, the
## bake's definition ported. `gap` is the signed lateral gap (positive = open) between the facing
## lateral vertices (sector 3 or 9, the pair nearest at ring 3) at the first finger's rings 1..3 (`.01`
## t .00 .14 .30), along the line between the two tubes' ring centres. `over` is the highest web
## vertex (`webs_mi`, null = none) above the line between the facing vertices, toward the dorsal
## side, for pairs open at ring 3 (-1 when it has no web vertex).
func webs(fingers_mi: MeshInstance3D, webs_mi: MeshInstance3D, fingers: Dictionary) -> Array:
	var arrays := (fingers_mi.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ids := ArmFingerInfo.id_map(arrays)
	var wv := PackedVector3Array()
	if webs_mi != null and webs_mi.mesh != null and webs_mi.mesh.get_surface_count() > 0:
		wv = webs_mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var out: Array = []
	var anchors: Array = []
	for i in 3:
		var ba := int(fingers[_FINGERS[i]][&"vert_base"])
		var bb := int(fingers[_FINGERS[i + 1]][&"vert_base"])
		var best := Vector2i(3, 9)
		var best_d := INF
		for sa: int in [3, 9]:
			for sb: int in [3, 9]:
				var dd := _vert(verts, ids, ba, 3, sa).distance_squared_to(_vert(verts, ids, bb, 3, sb))
				if dd < best_d:
					best_d = dd
					best = Vector2i(sa, sb)
		var gap := PackedFloat32Array()
		var found: Array = []
		for r in [1, 2, 3]:
			var va := _vert(verts, ids, ba, r, best.x)
			var vb := _vert(verts, ids, bb, r, best.y)
			var ca := _centre(verts, ids, ba, r)
			var cb := _centre(verts, ids, bb, r)
			gap.append((vb - va).dot((cb - ca).normalized()))
			var dors := (_vert(verts, ids, ba, r, 0) - ca).normalized() 					+ (_vert(verts, ids, bb, r, 0) - cb).normalized()
			var line := (vb - va).normalized()
			found.append({&"pair": i, &"p": 0.5 * (va + vb),
					&"dors": (dors - line * dors.dot(line)).normalized()})
		if gap[2] > 0.0:
			anchors.append_array(found)
		out.append({&"gap": gap, &"over": -1.0})
	for w in wv:
		var near := {}
		var near_d := INF
		for a: Dictionary in anchors:
			if w.distance_squared_to(a[&"p"]) < near_d:
				near_d = w.distance_squared_to(a[&"p"])
				near = a
		if not near.is_empty():
			var o: Dictionary = out[int(near[&"pair"])]
			o[&"over"] = maxf(float(o[&"over"]), (w - near[&"p"]).dot(near[&"dors"]))
	return out


func _vert(verts: PackedVector3Array, ids: PackedInt32Array, base: int, ring: int, sector: int) -> Vector3:
	var vi := base + ring * ArmFingerInfo.SECTORS + sector
	return verts[vi if ids.is_empty() else ids[vi]]


func _centre(verts: PackedVector3Array, ids: PackedInt32Array, base: int, ring: int) -> Vector3:
	var c := Vector3.ZERO
	for s in ArmFingerInfo.SECTORS:
		c += _vert(verts, ids, base, ring, s)
	return c / float(ArmFingerInfo.SECTORS)



## Third of the summed area of each vertex's triangles (indices empty: consecutive triples).
func vertex_area(arrays: Array) -> PackedFloat32Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
			else PackedInt32Array()
	var area := PackedFloat32Array()
	area.resize(verts.size())
	var n := idx.size() if idx.size() > 0 else verts.size()
	for t in range(0, n - 2, 3):
		var i0 := idx[t] if idx.size() > 0 else t
		var i1 := idx[t + 1] if idx.size() > 0 else t + 1
		var i2 := idx[t + 2] if idx.size() > 0 else t + 2
		var a := 0.5 * (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]).length() / 3.0
		area[i0] += a
		area[i1] += a
		area[i2] += a
	return area


## The |lateral| where the area weight, summed from the smallest, first reaches 0.95 of the total.
func p95(lats: PackedFloat32Array, areas: PackedFloat32Array) -> float:
	var order: Array[int] = []
	var total := 0.0
	for i in lats.size():
		order.append(i)
		total += areas[i]
	order.sort_custom(func(a: int, b: int) -> bool: return lats[a] < lats[b])
	var acc := 0.0
	for i in order:
		acc += areas[i]
		if acc >= 0.95 * total:
			return lats[i]
	return 0.0


## Largest step over the mean step of W0..7 (a straight ramp reads 1.0).
func jump(w: Array) -> float:
	var step := 0.0
	for k in range(1, 8):
		step = maxf(step, w[k] - w[k - 1])
	return step / maxf((w[7] - w[0]) / 7.0, 0.0001)


## W0..8 as " 0.000" fields.
func fmt(w: Array) -> String:
	var s := ""
	for k in 9:
		s += " %.3f" % w[k]
	return s
