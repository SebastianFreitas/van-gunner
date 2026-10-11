class_name ArmFingerRoot
extends RefCounted
## Blends the finger tubes' roots into the palm skin without moving a vertex: near the root the
## tube normals lean to the palm's, and CUSTOM0 carries the palm's vein-frame value at the
## crossing; the dirt streak fades to its flat finger value just past the knuckle by the
## per-vertex fade `g` (CUSTOM3), not by moving the coordinates. Static only.

## Normal blend width as a multiple of the root bone's tube radius (look fallback: 1.0).
const BLEND_R := 0.5
## Rings up to this t of the root bone (the thumb's is .02) take the palm normal; t_c may raise it.
const NORMAL_T := 0.30
## How far past the crossing t_c the palm streak takes to fade to the flat value.
const FADE_T := 0.30
## Crossing: tube vertices within this share of the radius of the palm skin.
const CROSS_R := 0.05
## Rings past this t of the root bone are never searched for the crossing (the palm ends
## well before; the search is the build's cost).
const SEARCH_T := 0.8


## `verts`/`indices` are the merged tubes, `parts` one dict per finger: {name, base, count,
## centres, rings, r} (r the root bone's tube radius). Returns {normals, custom0, fade} for
## `ArmSkinMesh.build`, and stores the build ms and per finger {t_c} on the model's
## `finger_roots` meta.
static func build(model: Node3D, mi: MeshInstance3D, sk: Skeleton3D, suffix: String,
		verts: PackedVector3Array, indices: PackedInt32Array, parts: Array) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in range(0, indices.size() - 2, 3):
		var a := indices[i]
		var b := indices[i + 1]
		var c := indices[i + 2]
		var fn := (verts[c] - verts[a]).cross(verts[b] - verts[a])
		normals[a] += fn
		normals[b] += fn
		normals[c] += fn
	for i in normals.size():
		normals[i] = normals[i].normalized()
	var custom0 := PackedFloat32Array()
	custom0.resize(verts.size() * 4)
	var fade := PackedFloat32Array()
	fade.resize(verts.size())
	var heads := _heads(mi, sk, suffix)
	var arm := _arm_mesh(mi.mesh)
	var meta := {}
	if heads.has(&"DEF-thumb.01") and heads.has(&"DEF-hand") and heads.has(&"DEF-upper_arm"):
		var vf := ArmMuscle.frame(heads)
		for part: Dictionary in parts:
			meta[part[&"name"]] = _finger(part, heads, vf, arm, verts, normals, custom0, fade)
	meta[&"ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
	model.set_meta(&"finger_roots", meta)
	return {&"normals": normals, &"custom0": custom0, &"fade": fade}


static func _finger(part: Dictionary, heads: Dictionary, vf: Dictionary, arm: Array,
		verts: PackedVector3Array, normals: PackedVector3Array,
		custom0: PackedFloat32Array, fade: PackedFloat32Array) -> Dictionary:
	var name: StringName = part[&"name"]
	var thumb := name == &"thumb"
	var root := StringName("DEF-%s.0%d" % [name, 2 if thumb else 1])
	var nxt := StringName("DEF-%s.0%d" % [name, 3 if thumb else 2])
	var hd: Vector3 = heads.get(root, Vector3.ZERO)
	var d: Vector3 = Vector3(heads.get(nxt, Vector3.ZERO)) - hd
	var base: int = part[&"base"]
	var count: int = part[&"count"]
	var r: float = part[&"r"]
	var apos: PackedVector3Array = arm[0]
	var aidx: PackedInt32Array = arm[1]
	var tris := ArmSkinNearest.prefilter(apos, aidx, hd - 0.25 * d, 2.0 * r)
	var ts := PackedFloat32Array()
	var near := {}
	var t_c := -INF
	for k in count:
		var t := (verts[base + k] - hd).dot(d) / maxf(d.length_squared(), 1e-12)
		ts.append(t)
		if t >= SEARCH_T:
			continue
		var q := ArmSkinNearest.nearest(apos, aidx, tris, verts[base + k])
		near[k] = q
		if float(q[&"s"]) <= CROSS_R * r:
			t_c = maxf(t_c, t)
	t_c = maxf(t_c, 0.0)
	var limit := maxf(NORMAL_T, t_c) + 1e-4
	for k: int in near:
		if ts[k] > limit:
			continue
		var q: Dictionary = near[k]
		var n_p: Vector3 = q[&"n"]
		if n_p == Vector3.ZERO:
			continue
		var w := 1.0 - smoothstep(0.0, BLEND_R * r, maxf(float(q[&"s"]), 0.0))
		normals[base + k] = (w * n_p + (1.0 - w) * normals[base + k]).normalized()
	for k in count:
		var x := ArmMuscle.frame_xyz(vf, verts[base + k])
		custom0[(base + k) * 4] = x.x
		custom0[(base + k) * 4 + 1] = x.y
		custom0[(base + k) * 4 + 2] = x.z
		fade[base + k] = smoothstep(t_c, t_c + FADE_T, ts[k])
	return {&"t_c": t_c}


## Bone heads in bind space keyed by name without the side suffix.
static func _heads(mi: MeshInstance3D, sk: Skeleton3D, suffix: String) -> Dictionary:
	var heads := {}
	for b in mi.skin.get_bind_count():
		var full := String(mi.skin.get_bind_name(b))
		if full.is_empty():
			full = sk.get_bone_name(mi.skin.get_bind_bone(b))
		if full.ends_with(suffix):
			heads[StringName(full.left(full.length() - suffix.length()))] = \
					mi.skin.get_bind_pose(b).affine_inverse().origin
	return heads


## [positions, indices] of all the arm mesh's surfaces merged.
static func _arm_mesh(mesh: Mesh) -> Array:
	var pos := PackedVector3Array()
	var idx := PackedInt32Array()
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var base := pos.size()
		for i: int in a[Mesh.ARRAY_INDEX]:
			idx.append(base + i)
		pos.append_array(a[Mesh.ARRAY_VERTEX])
	return [pos, idx]
