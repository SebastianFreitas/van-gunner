class_name ArmMuscle
extends RefCounted
## Seeded muscle masses, rebuilt normals and vein coordinates for the inflated arm mesh.

## Lump rows: [t0 along the segment, t width, angle deg around it, angle width deg, amplitude].
## Angle 0 is the thumb side of the arm; aw 1000 means all the way round.
const UPPER: Array = [
	[0.08, 0.12, 0.0, 70.0, 0.30],	# deltoid
	[0.55, 0.22, 90.0, 50.0, 0.40],	# biceps
	[0.40, 0.25, -90.0, 55.0, 0.30],	# triceps
]
const FORE: Array = [
	[0.22, 0.18, 20.0, 50.0, 0.38],	# brachioradialis
	[0.30, 0.20, 110.0, 50.0, 0.28],	# flexors
	[0.35, 0.22, -80.0, 45.0, 0.25],	# extensors
]
const MASK := {&"DEF-forearm": 1.0, &"DEF-upper_arm": 0.6, &"DEF-hand": 0.7}


static func apply(arrays: Array, new_verts: PackedVector3Array, heads: Dictionary,
		bone_names: PackedStringArray, muscle_seed: int, bulk: float,
		mirror: bool) -> void:
	var count := new_verts.size()
	var custom := PackedFloat32Array()
	custom.resize(count * 4)
	var orig_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var heads_ok := true
	for key in [&"DEF-upper_arm", &"DEF-forearm", &"DEF-hand", &"DEF-thumb.01"]:
		if not heads.has(key):
			heads_ok = false
	if not heads_ok:
		push_warning("ArmMuscle: a bone head is missing; arms get normals only")
		arrays[Mesh.ARRAY_VERTEX] = new_verts
		arrays[Mesh.ARRAY_NORMAL] = _normals(arrays, new_verts, orig_normals)
		arrays[Mesh.ARRAY_TANGENT] = null
		arrays[Mesh.ARRAY_CUSTOM0] = custom
		return
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := int(float(bones.size()) / maxf(count, 1.0))
	var h_up: Vector3 = heads[&"DEF-upper_arm"]
	var h_fore: Vector3 = heads[&"DEF-forearm"]
	var h_hand: Vector3 = heads[&"DEF-hand"]
	var thumb_dir: Vector3 = Vector3(heads[&"DEF-thumb.01"]) - h_hand
	# One seed per arm, so the two arms get different lumps.
	var rng := RandomNumberGenerator.new()
	rng.seed = muscle_seed
	var upper := _jitter(UPPER, rng)
	var fore := _jitter(FORE, rng)
	var verts := new_verts.duplicate()
	var families := PackedStringArray()
	for i in count:
		var best := 0
		var best_w := -1.0
		for k in per:
			if weights[i * per + k] > best_w:
				best_w = weights[i * per + k]
				best = bones[i * per + k]
		var fam := _family(bone_names[best])
		families.append(fam)
		if fam == "DEF-upper_arm":
			verts[i] = _lump(new_verts[i], h_up, h_fore, thumb_dir, upper, bulk, mirror)
		elif fam == "DEF-forearm":
			verts[i] = _lump(new_verts[i], h_fore, h_hand, thumb_dir, fore, bulk, mirror)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = _normals(arrays, verts, orig_normals)
	arrays[Mesh.ARRAY_TANGENT] = null
	# Vein frame: origin at the shoulder, axis shoulder -> hand, u toward the thumb side.
	var axis_all := (h_hand - h_up).normalized()
	var u := (thumb_dir - axis_all * thumb_dir.dot(axis_all)).normalized()
	var v := axis_all.cross(u)
	for i in count:
		var d := verts[i] - h_up
		custom[i * 4] = d.dot(axis_all)
		custom[i * 4 + 1] = d.dot(u)
		custom[i * 4 + 2] = d.dot(v)
		custom[i * 4 + 3] = float(MASK.get(StringName(families[i]), 0.0))
	arrays[Mesh.ARRAY_CUSTOM0] = custom


## Bone name without the ".L"/".R" side suffix and without ".001", whichever order they come in.
static func _family(bone_name: String) -> String:
	var n := bone_name
	if n.ends_with(".001"):
		n = n.substr(0, n.length() - 4)
	if n.ends_with(".L") or n.ends_with(".R"):
		n = n.substr(0, n.length() - 2)
	if n.ends_with(".001"):
		n = n.substr(0, n.length() - 4)
	return n


static func _jitter(table: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for row in table:
		out.append([row[0] + rng.randf_range(-0.04, 0.04), row[1],
				row[2] + rng.randf_range(-15.0, 15.0), row[3],
				row[4] * rng.randf_range(0.85, 1.15)])
	return out


static func _lump(p: Vector3, a: Vector3, b: Vector3, thumb_dir: Vector3, lumps: Array,
		bulk: float, mirror: bool) -> Vector3:
	var seg := b - a
	var seg_len := seg.length()
	if seg_len < 0.00001:
		return p
	var axis := seg / seg_len
	var rel := p - a
	var t := clampf(rel.dot(axis) / seg_len, 0.0, 1.0)
	var r := rel - axis * rel.dot(axis)
	var ref := thumb_dir - axis * thumb_dir.dot(axis)
	if ref.length() < 0.00001:
		return p
	ref = ref.normalized()
	var ref2 := axis.cross(ref)
	var ang := rad_to_deg(atan2(r.dot(ref2), r.dot(ref)))
	# The left arm is a mirror image, so the angle around the bone runs the other way.
	if mirror:
		ang = -ang
	var f := 1.0
	for row in lumps:
		var dang := wrapf(ang - float(row[2]), -180.0, 180.0)
		var dt: float = (t - float(row[0])) / float(row[1])
		var da: float = dang / float(row[3])
		f += float(row[4]) * bulk * exp(-dt * dt) * exp(-da * da)
	return p + r * (f - 1.0)


## Smooth normals: area-weighted, merged across vertices sharing a position (UV seams).
static func _normals(arrays: Array, verts: PackedVector3Array,
		orig: PackedVector3Array) -> PackedVector3Array:
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var acc := PackedVector3Array()
	acc.resize(verts.size())
	@warning_ignore("integer_division")
	for f in idx.size() / 3:
		var ia := idx[f * 3]
		var ib := idx[f * 3 + 1]
		var ic := idx[f * 3 + 2]
		var n := (verts[ib] - verts[ia]).cross(verts[ic] - verts[ia])
		acc[ia] += n
		acc[ib] += n
		acc[ic] += n
	var merged := {}
	var keys: Array[Vector3i] = []
	for i in verts.size():
		var key := Vector3i((verts[i] / 0.0001).round())
		keys.append(key)
		merged[key] = Vector3(merged.get(key, Vector3.ZERO)) + acc[i]
	var out := PackedVector3Array()
	out.resize(verts.size())
	for i in verts.size():
		var n: Vector3 = merged[keys[i]]
		n = n.normalized()
		# Godot fronts are clockwise, so never trust winding: follow the original normal.
		if i < orig.size() and n.dot(orig[i]) < 0.0:
			n = -n
		out[i] = n
	return out
