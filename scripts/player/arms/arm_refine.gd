class_name ArmRefine
extends RefCounted
## Midpoint-subdivides the imported arm mesh once at load, so the gain ramp and the muscle lumps
## have rings to shape instead of one step between the mid-forearm and the wrist.

## Subdivision levels; each splits every triangle into four.
const LEVELS := 1

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _uvs := PackedVector2Array()
var _uv2s := PackedVector2Array()
var _colors := PackedColorArray()
var _bones := PackedInt32Array()
var _weights := PackedFloat32Array()
var _per := 4
var _has_normals := false
var _has_uvs := false
var _has_uv2s := false
var _has_colors := false
## Edge key Vector2i(min, max) to the index of the midpoint vertex already made for it.
var _cache := {}


static func refine(arrays: Array) -> Array:
	var index_v: Variant = arrays[Mesh.ARRAY_INDEX]
	if not (index_v is PackedInt32Array) or (index_v as PackedInt32Array).size() < 3:
		push_warning("ArmRefine: arm surface has no index array; left as imported")
		return arrays
	for level in LEVELS:
		arrays = ArmRefine.new()._subdivide(arrays)
	return arrays


func _subdivide(arrays: Array) -> Array:
	_verts = arrays[Mesh.ARRAY_VERTEX]
	_bones = arrays[Mesh.ARRAY_BONES]
	_weights = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_per = int(float(_bones.size()) / maxf(_verts.size(), 1.0))
	var nrm_v: Variant = arrays[Mesh.ARRAY_NORMAL]
	if nrm_v is PackedVector3Array and (nrm_v as PackedVector3Array).size() == _verts.size():
		_has_normals = true
		_normals = nrm_v
	var uv_v: Variant = arrays[Mesh.ARRAY_TEX_UV]
	if uv_v is PackedVector2Array and (uv_v as PackedVector2Array).size() == _verts.size():
		_has_uvs = true
		_uvs = uv_v
	var uv2_v: Variant = arrays[Mesh.ARRAY_TEX_UV2]
	if uv2_v is PackedVector2Array and (uv2_v as PackedVector2Array).size() == _verts.size():
		_has_uv2s = true
		_uv2s = uv2_v
	var col_v: Variant = arrays[Mesh.ARRAY_COLOR]
	if col_v is PackedColorArray and (col_v as PackedColorArray).size() == _verts.size():
		_has_colors = true
		_colors = col_v
	_cache.clear()
	var out_idx := PackedInt32Array()
	for t in range(0, indices.size() - 2, 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		var ab := _midpoint(a, b)
		var bc := _midpoint(b, c)
		var ca := _midpoint(c, a)
		out_idx.append_array(PackedInt32Array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]))
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_INDEX] = out_idx
	arrays[Mesh.ARRAY_BONES] = _bones
	arrays[Mesh.ARRAY_WEIGHTS] = _weights
	if _has_normals:
		arrays[Mesh.ARRAY_NORMAL] = _normals
	if _has_uvs:
		arrays[Mesh.ARRAY_TEX_UV] = _uvs
	if _has_uv2s:
		arrays[Mesh.ARRAY_TEX_UV2] = _uv2s
	if _has_colors:
		arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TANGENT] = null
	return arrays


func _midpoint(a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if _cache.has(key):
		return _cache[key]
	var idx := _verts.size()
	_verts.append((_verts[a] + _verts[b]) * 0.5)
	if _has_normals:
		var nrm := _normals[a] + _normals[b]
		_normals.append(nrm.normalized() if nrm.length() > 1e-6 else _normals[a])
	if _has_uvs:
		_uvs.append((_uvs[a] + _uvs[b]) * 0.5)
	if _has_uv2s:
		_uv2s.append((_uv2s[a] + _uv2s[b]) * 0.5)
	if _has_colors:
		_colors.append(_colors[a].lerp(_colors[b], 0.5))
	var merged := {}
	for k in _per:
		var wa := _weights[a * _per + k]
		if wa > 0.0:
			var bone_a := _bones[a * _per + k]
			merged[bone_a] = float(merged.get(bone_a, 0.0)) + 0.5 * wa
		var wb := _weights[b * _per + k]
		if wb > 0.0:
			var bone_b := _bones[b * _per + k]
			merged[bone_b] = float(merged.get(bone_b, 0.0)) + 0.5 * wb
	var entries: Array = []
	for bone in merged:
		entries.append([bone, merged[bone]])
	entries.sort_custom(func(x: Array, y: Array) -> bool: return x[1] > y[1])
	var ids: Array[int] = []
	var ws: Array[float] = []
	var total := 0.0
	for k in _per:
		if k < entries.size():
			ids.append(entries[k][0])
			ws.append(entries[k][1])
			total += entries[k][1]
		else:
			ids.append(0)
			ws.append(0.0)
	for k in _per:
		_bones.append(ids[k])
		_weights.append(ws[k] / total if total > 0.0 else ws[k])
	_cache[key] = idx
	return idx
