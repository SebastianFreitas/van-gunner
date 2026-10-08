extends RefCounted
## Relaxes the DEF-thumb weight cliff at the wrist side of the thumb root so a straight thumb pulls a slope, not a spike.
class_name ArmWeightSmooth

const REACH := 0.08  ## verts within this of the thumb.01 head (rest space, m) may be relaxed
const CLIFF := 0.3  ## edge-neighbour thumb-weight gap that marks a cliff
const ITERATIONS := 10  ## Laplacian passes over the cliff zone
const STEP := 0.5  ## share each pass moves a vert's thumb weight toward its neighbours' mean
const AHEAD := 0.02  ## how far past the thumb.01 head plane (m) the wrist-side zone may reach
const ZONE_RINGS := 4  ## edge rings around a cliff vert that join the relaxed zone


static func apply(arrays: Array, bone_names: PackedStringArray, inv_poses: Array[Transform3D],
		side: String) -> void:
	var root := bone_names.find("DEF-thumb.01" + side)
	var next := bone_names.find("DEF-thumb.02" + side)
	var index_v: Variant = arrays[Mesh.ARRAY_INDEX]
	if root < 0 or next < 0 or not (index_v is PackedInt32Array):
		return
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := int(float(bones.size()) / maxf(verts.size(), 1.0))
	var index: PackedInt32Array = index_v
	var is_thumb := PackedByteArray()
	for b in bone_names.size():
		is_thumb.append(1 if bone_names[b].begins_with("DEF-thumb.") else 0)
	var head := inv_poses[root].origin
	var axis := (inv_poses[next].origin - head).normalized()
	var tw := PackedFloat32Array()
	tw.resize(verts.size())
	for i in verts.size():
		for k in per:
			if weights[i * per + k] > 0.0 and is_thumb[bones[i * per + k]] == 1:
				tw[i] += weights[i * per + k]
	var nb: Array[PackedInt32Array] = []
	nb.resize(verts.size())
	for t in range(0, index.size(), 3):
		for e in 3:
			var p := index[t + e]
			var q := index[t + (e + 1) % 3]
			if not nb[p].has(q):
				nb[p].append(q)
			if not nb[q].has(p):
				nb[q].append(p)
	# Wrist side: behind the plane through the thumb.01 head, inside REACH.
	var near := PackedByteArray()
	near.resize(verts.size())
	for i in verts.size():
		var off := verts[i] - head
		near[i] = 1 if off.length() < REACH and off.dot(axis) < AHEAD else 0
	var zone := PackedByteArray()
	zone.resize(verts.size())
	var frontier: Array[int] = []
	for i in verts.size():
		if near[i] == 0:
			continue
		for j in nb[i]:
			if absf(tw[i] - tw[j]) > CLIFF:
				zone[i] = 1
				frontier.append(i)
				break
	for ring in ZONE_RINGS:
		var grown: Array[int] = []
		for i in frontier:
			for j in nb[i]:
				if near[j] == 1 and zone[j] == 0:
					zone[j] = 1
					grown.append(j)
		frontier = grown
	var cur := tw.duplicate()
	for it in ITERATIONS:
		var nxt := cur.duplicate()
		for i in verts.size():
			if zone[i] == 0 or nb[i].is_empty():
				continue
			var mean := 0.0
			for j in nb[i]:
				mean += cur[j]
			nxt[i] = lerpf(cur[i], mean / nb[i].size(), STEP)
		cur = nxt
	for i in verts.size():
		if zone[i] == 1 and absf(cur[i] - tw[i]) > 0.0001:
			_retarget(bones, weights, per, i, root, is_thumb, tw[i], cur[i])
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_BONES] = bones


## Rescales vert i so its thumb-bone weights sum to `to` and the rest to 1 - to, keeping the slot
## count: a vert with no thumb weight yet gives its smallest slot to the thumb root.
static func _retarget(bones: PackedInt32Array, weights: PackedFloat32Array, per: int, i: int,
		root: int, is_thumb: PackedByteArray, from: float, to: float) -> void:
	var base := i * per
	if from <= 0.0001:
		var slot := 0
		for k in per:
			if weights[base + k] <= weights[base + slot]:
				slot = k
		bones[base + slot] = root
		weights[base + slot] = 0.0
		var rest := 0.0
		for k in per:
			rest += weights[base + k]
		for k in per:
			weights[base + k] *= (1.0 - to) / maxf(rest, 0.0001)
		weights[base + slot] = to
		return
	var up := to / from
	var down := (1.0 - to) / maxf(1.0 - from, 0.0001)
	for k in per:
		weights[base + k] *= up if is_thumb[bones[base + k]] == 1 else down
