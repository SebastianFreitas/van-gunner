extends RefCounted
## Sculpts the back of the palm into four knuckle ridges with tendon grooves between them.
class_name ArmKnuckles

const PEAK := 0.18  ## ridge height at a head, in mean head spacings (~0.3 finger radius)
const GROOVE := 0.16  ## groove depth midway between heads, same unit
const BACK_REACH := 0.75  ## fraction of the palm bone the ridge and groove run back to the wrist
const TENDON := 0.35  ## share of the ridge/groove left at BACK_REACH*0.6 (the tendon line)


static func apply(verts: PackedVector3Array, normals: PackedVector3Array, bones: PackedInt32Array,
		weights: PackedFloat32Array, per: int, bone_names: PackedStringArray,
		inv_poses: Array[Transform3D], side: String) -> void:
	var pb: Array[int] = [-1, -1, -1, -1, -1]
	var hb: Array[int] = [-1, -1, -1, -1, -1]
	for d in range(1, 5):
		var palm_name := "DEF-palm.0%d%s" % [d, side]
		var finger_name := "DEF-%s.01%s" % [ArmBulk.PALM_FINGERS[d - 1], side]
		for b in bone_names.size():
			if bone_names[b] == palm_name:
				pb[d] = b
			elif bone_names[b] == finger_name:
				hb[d] = b
		if pb[d] < 0 or hb[d] < 0:
			push_warning("ArmKnuckles: palm or finger bone missing for digit %d" % d)
			return
	var heads: Array[Vector3] = [Vector3.ZERO]
	var plen: Array[float] = [0.0]
	var dir_sum := Vector3.ZERO
	for d in range(1, 5):
		var head := inv_poses[hb[d]].origin
		var palm := inv_poses[pb[d]].origin
		heads.append(head)
		plen.append((head - palm).length())
		dir_sum += head - palm
	var fwd := dir_sum.normalized()
	var dorsal := (Vector3.UP - fwd * Vector3.UP.dot(fwd)).normalized()
	var lat_raw: Vector3 = heads[4] - heads[1]
	lat_raw -= fwd * lat_raw.dot(fwd)
	lat_raw -= dorsal * lat_raw.dot(dorsal)
	var lateral := lat_raw.normalized()
	var u: Array[float] = [0.0]
	for d in range(1, 5):
		u.append((heads[d] - heads[1]).dot(lateral))
	var spacing := (u[4] - u[1]) / 3.0
	if spacing <= 0.0:
		return
	var peak := PEAK * spacing
	var groove := GROOVE * spacing
	for i in verts.size():
		var hw := 0.0
		for j in per:
			var b := bones[i * per + j]
			if b == pb[1] or b == pb[2] or b == pb[3] or b == pb[4]:
				hw += weights[i * per + j]
		if hw < 0.05:
			continue
		var back := smoothstep(0.15, 0.6, normals[i].dot(dorsal))
		if back <= 0.0:
			continue
		var uv := (verts[i] - heads[1]).dot(lateral)
		var n := 1
		for d in range(2, 5):
			if absf(uv - u[d]) < absf(uv - u[n]):
				n = d
		var m := n + 1 if uv > u[n] else n - 1
		var lat: float
		if m < 1 or m > 4:
			lat = peak * (1.0 - smoothstep(0.0, 0.5 * spacing, absf(uv - u[n])))
		else:
			var x := clampf(absf(uv - u[n]) / (0.5 * absf(u[m] - u[n])), 0.0, 1.0)
			var c := 0.5 + 0.5 * cos(PI * x)
			lat = peak * c - groove * (1.0 - c)
		var a := (verts[i] - heads[n]).dot(fwd)
		var along: float
		if a >= 0.0:
			along = 1.0 - smoothstep(0.0, 0.5 * spacing, a)
		else:
			# Past the head the ridge thins to a tendon line, then dies out toward the wrist.
			var s := -a / (BACK_REACH * plen[n])
			along = lerpf(1.0, TENDON, smoothstep(0.0, 0.6, s)) * (1.0 - smoothstep(0.6, 1.0, s))
		verts[i] += dorsal * lat * along * back * clampf(hw, 0.0, 1.0)
