class_name ArmVeinRelief
extends RefCounted
## Raises the arm skin into real geometry along the authored veins: splits only the triangles
## near a vein until a vein is several vertices wide, pushes each vertex out along its normal by
## the sampled vein height, and corrects the normals so the bulge shades.

## How far the fattest vein stands proud of the skin, in mesh units (the arm mesh is about 0.22
## of a world metre, so 0.014 is about 2.8 mm).
const RELIEF_M := 0.014
## Edge length the refined triangles are cut down to near a vein.
const TARGET_EDGE := 0.003
## A triangle is refined while any of it is within the widest vein plus this margin.
const NEAR := ArmVeinSet.MAX_R + 0.002
const MAX_PASSES := 5
## Edge keys are low * KEY_SPAN + high; the mesh has far fewer vertices than this.
const KEY_SPAN := 1 << 24
## How much of the displaced surface's tilt the normals take; above 1 reads the ridge harder.
const TILT_GAIN := 1.5

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _bones := PackedInt32Array()
var _weights := PackedFloat32Array()
var _custom := PackedFloat32Array()
var _uvs := PackedVector2Array()
var _uv2s := PackedVector2Array()
var _colors := PackedColorArray()
var _height := PackedFloat32Array()
var _dist := PackedFloat32Array()
var _per := 4
var _exact_d := PackedFloat32Array()
var _field: ArmVeinField
## Edge key (see `_key`) to the midpoint vertex made for it in the current pass.
var _cache := {}


## Refines and displaces `arrays` (CUSTOM0 already written) with the arm's own vein set.
## The finished arrays are cached in `user://` under `cache_name`, keyed on a hash of the vein set,
## the relief constants and the incoming mesh, so a hit skips the whole refine.
static func apply(arrays: Array, vein_set: ArmVeinSet, cache_name: String) -> void:
	if arrays[Mesh.ARRAY_CUSTOM0] == null or not (arrays[Mesh.ARRAY_INDEX] is PackedInt32Array):
		return
	var key := hash([vein_set.pack(), RELIEF_M, TARGET_EDGE, NEAR, MAX_PASSES, TILT_GAIN,
			ArmVeinField.BLEND, arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL],
			arrays[Mesh.ARRAY_CUSTOM0], arrays[Mesh.ARRAY_INDEX], arrays[Mesh.ARRAY_BONES],
			arrays[Mesh.ARRAY_WEIGHTS]])
	var path := "user://arm_vein_cache/%s.bin" % cache_name
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var saved: Variant = f.get_var(false) if f != null else null
		if _valid(saved, key):
			for slot: int in saved["arrays"]:
				arrays[slot] = saved["arrays"][slot]
			return
	ArmVeinRelief.new()._run(arrays, vein_set)
	var out := {}
	for slot: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS,
			Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_INDEX, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2,
			Mesh.ARRAY_COLOR, Mesh.ARRAY_TANGENT]:
		out[slot] = arrays[slot]
	DirAccess.make_dir_recursive_absolute("user://arm_vein_cache")
	# Written under a temp name and renamed, so a kill mid-write never leaves a half file.
	var w := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if w != null:
		var header := {"key": key, "verts": (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
				"indices": (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()}
		w.store_var({"header": header, "arrays": out}, false)
		w.close()
		DirAccess.remove_absolute(path)
		DirAccess.rename_absolute(path + ".tmp", path)


## True when `saved` is a whole cache file for `key`: header counts match every array's length
## and every index is a valid vertex.
static func _valid(saved: Variant, key: int) -> bool:
	if not (saved is Dictionary and saved.get("header") is Dictionary
			and saved.get("arrays") is Dictionary):
		return false
	var header: Dictionary = saved["header"]
	var arrs: Dictionary = saved["arrays"]
	if header.get("key") != key or not (header.get("verts") is int) 			or not (header.get("indices") is int):
		return false
	var vc: int = header["verts"]
	var ic: int = header["indices"]
	var v: Variant = arrs.get(Mesh.ARRAY_VERTEX)
	var n: Variant = arrs.get(Mesh.ARRAY_NORMAL)
	var c: Variant = arrs.get(Mesh.ARRAY_CUSTOM0)
	var idx: Variant = arrs.get(Mesh.ARRAY_INDEX)
	var b: Variant = arrs.get(Mesh.ARRAY_BONES)
	var wt: Variant = arrs.get(Mesh.ARRAY_WEIGHTS)
	if not (v is PackedVector3Array and n is PackedVector3Array and c is PackedFloat32Array
			and idx is PackedInt32Array and b is PackedInt32Array and wt is PackedFloat32Array):
		return false
	if vc <= 0 or v.size() != vc or n.size() != vc or c.size() != vc * 4 or idx.size() != ic 			or ic % 3 != 0 or b.is_empty() or b.size() % vc != 0 or wt.size() != b.size():
		return false
	for e: int in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
		if arrs.get(e) != null and arrs[e].size() != vc:
			return false
	if arrs.get(Mesh.ARRAY_TANGENT) != null and arrs[Mesh.ARRAY_TANGENT].size() != vc * 4:
		return false
	for i: int in idx:
		if i < 0 or i >= vc:
			return false
	return true


func _run(arrays: Array, vein_set: ArmVeinSet) -> void:
	_field = ArmVeinField.new(vein_set.pack())
	_verts = arrays[Mesh.ARRAY_VERTEX]
	_normals = arrays[Mesh.ARRAY_NORMAL]
	_bones = arrays[Mesh.ARRAY_BONES]
	_weights = arrays[Mesh.ARRAY_WEIGHTS]
	_custom = arrays[Mesh.ARRAY_CUSTOM0]
	var count := _verts.size()
	_per = int(float(_bones.size()) / maxf(count, 1.0))
	if arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
		_uvs = arrays[Mesh.ARRAY_TEX_UV]
	if arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array:
		_uv2s = arrays[Mesh.ARRAY_TEX_UV2]
	if arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
		_colors = arrays[Mesh.ARRAY_COLOR]
	_height.resize(count)
	_dist.resize(count)
	for i in count:
		_measure(i, i)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for pass_i in MAX_PASSES:
		var marked := _mark(idx)
		if marked.is_empty():
			break
		idx = _split(idx, marked)
	var before := _face_sums(idx)
	for i in _verts.size():
		if _height[i] > 0.0:
			_verts[i] += _normals[i] * (_height[i] * RELIEF_M)
	var after := _face_sums(idx)
	var tilts := PackedVector3Array()
	tilts.resize(_verts.size())
	for i in _verts.size():
		var pre := before[i]
		var post := after[i]
		if pre.length_squared() < 1e-18 or post.length_squared() < 1e-18:
			continue
		# The tilt is the displaced face normal's change from the flat one. Godot's front faces
		# wind clockwise, so these face sums point into the skin: the change in the outward
		# normal is the negative of the change in the sums.
		tilts[i] = pre.normalized() - post.normalized()
	# One pass over each vertex's one-ring: per-triangle tilts on the fine mesh crinkle.
	var ring := tilts.duplicate()
	var counts := PackedFloat32Array()
	counts.resize(_verts.size())
	counts.fill(1.0)
	for t in range(0, idx.size() - 2, 3):
		for e in 3:
			ring[idx[t + e]] += tilts[idx[t + (e + 1) % 3]]
			counts[idx[t + e]] += 1.0
			ring[idx[t + e]] += tilts[idx[t + (e + 2) % 3]]
			counts[idx[t + e]] += 1.0
	for i in _verts.size():
		# Displaced vertices follow the bump, faded in by height so the ridge foot joins the
		# untouched skin smoothly. Others keep their exact normal.
		if _height[i] <= 0.0:
			continue
		var tilt := ring[i] / counts[i]
		var w := smoothstep(0.0, 0.35, _height[i])
		var tilted := (_normals[i] + tilt * TILT_GAIN).normalized()
		_normals[i] = _normals[i].lerp(tilted, w).normalized()
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_BONES] = _bones
	arrays[Mesh.ARRAY_WEIGHTS] = _weights
	arrays[Mesh.ARRAY_CUSTOM0] = _custom
	arrays[Mesh.ARRAY_INDEX] = idx
	if _uvs.size() == _verts.size():
		arrays[Mesh.ARRAY_TEX_UV] = _uvs
	if _uv2s.size() == _verts.size():
		arrays[Mesh.ARRAY_TEX_UV2] = _uv2s
	if _colors.size() == _verts.size():
		arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TANGENT] = null


## Vein height (scaled by the back-of-arm mask) and centreline distance of vertex `i`; `slot` is
## where they are stored, which is `i` except while the arrays are still being filled.
func _measure(i: int, slot: int) -> void:
	var mask := _custom[i * 4 + 3]
	if mask <= 0.0:
		_height[slot] = 0.0
		_dist[slot] = INF
		return
	var s := _field.sample(ArmVeinSet.chart_of(
			Vector3(_custom[i * 4], _custom[i * 4 + 1], _custom[i * 4 + 2])))
	_height[slot] = s.x * mask
	_dist[slot] = s.y


## Edges of every triangle that is near a vein and too long, as a set of edge keys.
func _mark(idx: PackedInt32Array) -> Dictionary:
	var marked := {}
	for t in range(0, idx.size() - 2, 3):
		var a := idx[t]
		var b := idx[t + 1]
		var c := idx[t + 2]
		# Only the skin that carries veins: splitting finger-bone triangles adds vertices the
		# finger tubes read back from this mesh (radii, owned points) and deforms the hands.
		if _custom[a * 4 + 3] <= 0.0 or _custom[b * 4 + 3] <= 0.0 or _custom[c * 4 + 3] <= 0.0:
			continue
		var emax := maxf(_verts[a].distance_to(_verts[b]), maxf(
				_verts[b].distance_to(_verts[c]), _verts[c].distance_to(_verts[a])))
		if emax <= TARGET_EDGE:
			continue
		var dmin := minf(_dist[a], minf(_dist[b], _dist[c]))
		# The grid sampler only knows distances below FAR; a long edge near that bound needs the
		# true distance of its corners.
		if dmin >= ArmVeinField.FAR and ArmVeinField.FAR - emax <= NEAR:
			dmin = minf(_exact(a), minf(_exact(b), _exact(c)))
		if dmin - emax > NEAR:
			continue
		marked[_key(a, b)] = true
		marked[_key(b, c)] = true
		marked[_key(c, a)] = true
	return marked


## Splits each triangle along its marked edges; a neighbour sharing a marked edge takes the same
## midpoint, so no T-junction opens.
func _split(idx: PackedInt32Array, marked: Dictionary) -> PackedInt32Array:
	_cache.clear()
	var out := PackedInt32Array()
	for t in range(0, idx.size() - 2, 3):
		var v0 := idx[t]
		var v1 := idx[t + 1]
		var v2 := idx[t + 2]
		var f0 := marked.has(_key(v0, v1))
		var f1 := marked.has(_key(v1, v2))
		var f2 := marked.has(_key(v2, v0))
		var n := (1 if f0 else 0) + (1 if f1 else 0) + (1 if f2 else 0)
		if n == 0:
			out.append(v0)
			out.append(v1)
			out.append(v2)
			continue
		var tri: PackedInt32Array
		if n == 3:
			var ab := _midpoint(v0, v1)
			var bc := _midpoint(v1, v2)
			var ca := _midpoint(v2, v0)
			tri = PackedInt32Array([v0, ab, ca, v1, bc, ab, v2, ca, bc, ab, bc, ca])
		elif n == 1:
			var r := 0 if f0 else (1 if f1 else 2)
			var a := v0 if r == 0 else (v1 if r == 1 else v2)
			var b := v1 if r == 0 else (v2 if r == 1 else v0)
			var c := v2 if r == 0 else (v0 if r == 1 else v1)
			var m := _midpoint(a, b)
			tri = PackedInt32Array([a, m, c, m, b, c])
		else:
			var r := ((0 if not f0 else (1 if not f1 else 2)) + 1) % 3
			var a := v0 if r == 0 else (v1 if r == 1 else v2)
			var b := v1 if r == 0 else (v2 if r == 1 else v0)
			var c := v2 if r == 0 else (v0 if r == 1 else v1)
			var m1 := _midpoint(a, b)
			var m2 := _midpoint(b, c)
			tri = PackedInt32Array([m1, b, m2, a, m1, m2, a, m2, c])
		out.append_array(tri)
	return out


## Exact centreline distance of vertex `i` (only called on masked skin).
func _exact(i: int) -> float:
	if _exact_d.size() <= i:
		var from := _exact_d.size()
		_exact_d.resize(_verts.size())
		for k in range(from, _exact_d.size()):
			_exact_d[k] = -1.0
	if _exact_d[i] >= 0.0:
		return _exact_d[i]
	_exact_d[i] = _field.exact_dist(ArmVeinSet.chart_of(
			Vector3(_custom[i * 4], _custom[i * 4 + 1], _custom[i * 4 + 2])))
	return _exact_d[i]


func _key(a: int, b: int) -> int:
	return mini(a, b) * KEY_SPAN + maxi(a, b)


func _midpoint(a: int, b: int) -> int:
	var key := _key(a, b)
	if _cache.has(key):
		return _cache[key]
	var idx := _verts.size()
	_verts.append((_verts[a] + _verts[b]) * 0.5)
	var nrm := _normals[a] + _normals[b]
	_normals.append(nrm.normalized() if nrm.length() > 1e-6 else _normals[a])
	for k in 4:
		_custom.append((_custom[a * 4 + k] + _custom[b * 4 + k]) * 0.5)
	if _uvs.size() == idx:
		_uvs.append((_uvs[a] + _uvs[b]) * 0.5)
	if _uv2s.size() == idx:
		_uv2s.append((_uv2s[a] + _uv2s[b]) * 0.5)
	if _colors.size() == idx:
		_colors.append(_colors[a].lerp(_colors[b], 0.5))
	_height.append(0.0)
	_dist.append(INF)
	_measure(idx, idx)
	_append_weights(a, b)
	_cache[key] = idx
	return idx


## Skin weights of the midpoint: the two ends' weights halved and merged, strongest bones kept.
func _append_weights(a: int, b: int) -> void:
	var merged := {}
	for src in [a, b]:
		for k in _per:
			var w := _weights[src * _per + k]
			if w > 0.0:
				var bone := _bones[src * _per + k]
				merged[bone] = float(merged.get(bone, 0.0)) + 0.5 * w
	var entries: Array = []
	for bone in merged:
		entries.append([bone, merged[bone]])
	entries.sort_custom(func(x: Array, y: Array) -> bool: return x[1] > y[1])
	var total := 0.0
	for k in mini(_per, entries.size()):
		total += entries[k][1]
	for k in _per:
		if k < entries.size():
			_bones.append(entries[k][0])
			_weights.append(entries[k][1] / total)
		else:
			_bones.append(0)
			_weights.append(0.0)


## Area-weighted sum of the face normals around each vertex.
func _face_sums(idx: PackedInt32Array) -> PackedVector3Array:
	var sums := PackedVector3Array()
	sums.resize(_verts.size())
	for t in range(0, idx.size() - 2, 3):
		var a := idx[t]
		var b := idx[t + 1]
		var c := idx[t + 2]
		var f := (_verts[b] - _verts[a]).cross(_verts[c] - _verts[a])
		sums[a] += f
		sums[b] += f
		sums[c] += f
	return sums
