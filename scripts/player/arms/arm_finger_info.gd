class_name ArmFingerInfo
extends Resource
## One finger's baked claw and probe data (the `info` dictionary the claws and probes read): design constants kept as values, geometry the mesh owns kept as vertex indices into the baked `<S>_fingers` part and recomputed by `resolve`.

## Vertices around every finger-tube ring of the baked `<S>_fingers` part.
const SECTORS := 12

## "L" or "R".
@export var side: StringName = &""
@export var finger: StringName = &""

@export_group("Design constants")
@export var bed_r := 0.0
@export var crook := 0.0
@export var knots := 0
@export var rings := 0
@export var shaft := 0.0
@export var length := 0.0
@export var r2 := 0.0
@export var r3 := 0.0
@export var k2 := 0.0
@export var k3 := 0.0
## First vertex of the finger's tube in the `<S>_fingers` part.
@export var vert_base := 0
@export var emerge := 0
## Tip ring parameter along the `.03` bone and the half widths the profile gave it.
@export var tip_t := PackedFloat32Array()
@export var tip_half_w := PackedFloat32Array()
@export var tip_half_h := PackedFloat32Array()
## Direction the pad faces, in mesh space (DOWN, or toward the index for the thumb).
@export var pad := Vector3.DOWN
## Degrees the claw frame is turned about the lateral axis (positive: the tip bends palmward), for a
## tip the weld's wreck rotated away from the unmoved `.03` bone frame.
@export var tip_tilt := 0.0

@export_group("Mesh indices")
## First vertex of each tip ring (the ring is SECTORS consecutive vertices).
@export var tip_first := PackedInt32Array()
## Live ring centre minus the ring's vertex mean, in `.03` bone-local axes: the ring shape's own skew, so
## the centre follows the ring when the mesh moves.
@export var tip_skew := PackedVector3Array()
## The tip pole vertex, which sits 1.06 tip lengths along the bone, `tip_off` to the side.
@export var pole := 0

@export_group("Web")
## Only the first finger of each pair has these (the web between neighbouring fingers): gap to the next finger at three
## ring heights (empty when the finger has no web entry), the web's top parameter (-1 = no web)
## and how far its sag sits above the lateral line. Kept as values: only the probes read them.
@export var gap1 := PackedFloat32Array()
@export var web := -1.0
@export var web_over := 0.0


## Baked vertex index -> index in the imported surface `arrays`. The editor import reorders
## vertices, so the bake wrote each one's baked index into CUSTOM2.w (exact in float32). Empty
## when the surface has no such channel (the baked order is then the loaded order).
static func id_map(arrays: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	if arrays[Mesh.ARRAY_CUSTOM2] == null:
		return out
	var c2: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM2]
	@warning_ignore("integer_division")
	var n := c2.size() / 4
	out.resize(n)
	for i in n:
		out[int(roundf(c2[i * 4 + 3]))] = i
	return out


## The `info` dictionary the claws and probes read, with the mesh-owned values read from `arrays` (the
## surface arrays of the baked `<S>_fingers` part). `frame` is the `.03` bone's frame in mesh space
## (`ArmSkinMesh.ring_frame(mi, sk, bone, 0.0)`). `ids` is `id_map(arrays)`; stored vertex indices
## are baked ones and go through it.
static func resolve(info: ArmFingerInfo, arrays: Array, frame: Transform3D,
		ids := PackedInt32Array()) -> Dictionary:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var y := frame.basis.y.normalized()
	var pad_p := (info.pad - y * info.pad.dot(y)).normalized()
	var dor := -pad_p
	var lat := y.cross(pad_p).normalized()
	var inv := frame.basis.inverse()
	var lat_n := (inv * lat).normalized()
	var dor_n := (inv * dor).normalized()
	var up_n := Vector3.UP
	if info.tip_tilt != 0.0:
		var c := cos(deg_to_rad(info.tip_tilt))
		var sn := sin(deg_to_rad(info.tip_tilt))
		up_n = Vector3.UP * c - dor_n * sn
		dor_n = dor_n * c + Vector3.UP * sn
	var rel := verts[info.pole if ids.is_empty() else ids[info.pole]] - frame.origin
	var tip_len := rel.dot(y) / 1.06
	var tip_rings: Array = []
	for i in info.tip_t.size():
		var mean := Vector3.ZERO
		for s in SECTORS:
			var vi: int = info.tip_first[i] + s
			mean += verts[vi if ids.is_empty() else ids[vi]]
		mean /= float(SECTORS)
		var v := inv * (mean + frame.basis * info.tip_skew[i] - frame.origin)
		tip_rings.append({&"t": info.tip_t[i], &"centre": Vector3(lat_n.dot(v), up_n.dot(v), dor_n.dot(v)),
				&"half_w": info.tip_half_w[i], &"half_h": info.tip_half_h[i]})
	var out := {
		&"tip_rings": tip_rings, &"tip_len": tip_len, &"bed_r": info.bed_r,
		&"dorsal": dor_n, &"lateral": lat_n, &"along": up_n, &"crook": info.crook,
		&"tip_off": lat.dot(rel), &"knots": info.knots, &"rings": info.rings,
		&"shaft": info.shaft, &"length": info.length, &"r2": info.r2, &"r3": info.r3,
		&"k2": info.k2, &"k3": info.k3, &"vert_base": info.vert_base, &"emerge": info.emerge,
	}
	if not info.gap1.is_empty():
		out[&"gap1"] = info.gap1
		out[&"web"] = info.web
		if info.web >= 0.0:
			out[&"web_over"] = info.web_over
	return out
