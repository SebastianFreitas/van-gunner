class_name ArmFingerJoin
extends RefCounted
## Blends the finger tubes' normals, rest normals and hand weight toward the palm skin's near each root, so the digit and the palm light, relief and lift alike where they cross.

## Ring spacings up the digit, from the emergence ring, over which the palm's values fade out.
const SPAN := 1.5
## Radial growth of the emergence ring, faded by `share`, and the snapped ring's lift off the palm.
const FLARE := 0.35
const HAIR := 0.0004
## Share of the ring centre's rise over the snapped ring removed, for the rings after it.
const SINK: Array[float] = [0.85, 0.5, 0.2]
## Share of the first phalanx where the vein mask starts to fade out.
const FADE_FROM := 0.6


## The inflated palm skin of the glb mesh `mi` as {pos, nrm, rest_n, w} arrays: only vertices that
## are at least half the palm, hand or thumb root (the glb fingers are thinned cores, not palm).
static func palm(mi: MeshInstance3D) -> Dictionary:
	var pos := PackedVector3Array()
	var pnrm := PackedVector3Array()
	var prest := PackedVector3Array()
	var pw := PackedFloat32Array()
	var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	var is_palm := PackedByteArray()
	for b in mi.skin.get_bind_count():
		var n := String(mi.skin.get_bind_name(b))
		if n.is_empty() and skel != null:
			n = skel.get_bone_name(mi.skin.get_bind_bone(b))
		is_palm.append(1 if n.contains("palm") or n.contains("hand")
				or n.contains("thumb.01") else 0)
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var c1: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM1]
		var c2: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM2]
		var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		if verts.is_empty() or c1.size() < verts.size() * 4 or c2.size() < verts.size() * 4:
			continue
		var per := int(float(bones.size()) / float(verts.size()))
		for i in verts.size():
			var pshare := 0.0
			for k in per:
				if weights[i * per + k] > 0.0 and is_palm[bones[i * per + k]] == 1:
					pshare += weights[i * per + k]
			if pshare < 0.5:
				continue
			pos.append(verts[i])
			pnrm.append(nrm[i])
			prest.append(Vector3(c2[i * 4], c2[i * 4 + 1], c2[i * 4 + 2]))
			pw.append(c1[i * 4 + 3])
	return {&"pos": pos, &"nrm": pnrm, &"rest_n": prest, &"w": pw}


## The palm's {n, rest_n, w} at `p`: the three nearest palm vertices, inverse-square distance.
static func sample(pal: Dictionary, p: Vector3) -> Dictionary:
	var pos: PackedVector3Array = pal[&"pos"]
	var best: Array[Vector2] = [Vector2(INF, -1), Vector2(INF, -1), Vector2(INF, -1)]
	for i in pos.size():
		var d := pos[i].distance_squared_to(p)
		if d >= best[2].x:
			continue
		best[2] = Vector2(d, i)
		best.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var n := Vector3.ZERO
	var rn := Vector3.ZERO
	var w := 0.0
	var total := 0.0
	for b in best:
		if b.y < 0.0:
			continue
		var k := 1.0 / (b.x + 1e-7)
		var i := int(b.y)
		n += (pal[&"nrm"] as PackedVector3Array)[i] * k
		rn += (pal[&"rest_n"] as PackedVector3Array)[i] * k
		w += (pal[&"w"] as PackedFloat32Array)[i] * k
		total += k
	return {&"n": n.normalized(), &"rest_n": rn.normalized(), &"w": w / maxf(total, 1e-9)}


## Palm share of ring `ring` of a digit whose tube emerges from the palm at ring `emerge`: 1 up
## to there, then a smoothstep down to 0 over `SPAN` ring spacings.
static func share(ring: int, emerge: int) -> float:
	if ring <= emerge:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, float(ring - emerge) / SPAN)


## Fillets one digit's root: flares the rings of the blend band outward and snaps the emergence
## ring onto the palm surface (nearest palm vertex's tangent plane, plus a hair so it doesn't
## z-fight), so the tube leaves the hand at a shallow angle. Run before the normals are computed.
static func fillet(pal: Dictionary, verts: PackedVector3Array, base: int, rings: int,
		emerge: int) -> void:
	var pos: PackedVector3Array = pal[&"pos"]
	for ring in mini(rings, emerge + 3):
		var t := share(ring, emerge)
		var c := Vector3.ZERO
		for s in ArmFingers.SECTORS:
			c += verts[base + ring * ArmFingers.SECTORS + s] / float(ArmFingers.SECTORS)
		var shift := Vector3.ZERO
		if ring > emerge:
			# Sink the ring's centre toward the palm surface so the tube leaves it at a low angle.
			var c0 := Vector3.ZERO
			for s in ArmFingers.SECTORS:
				c0 += verts[base + emerge * ArmFingers.SECTORS + s] / float(ArmFingers.SECTORS)
			var pn: Vector3 = sample(pal, c0)[&"n"]
			shift = -pn * maxf(pn.dot(c - c0), 0.0) * SINK[ring - emerge - 1]
		for s in ArmFingers.SECTORS:
			var i := base + ring * ArmFingers.SECTORS + s
			var p := c + shift + (verts[i] - c) * (1.0 + FLARE * t)
			if ring == emerge:
				for _pass in 2:
					var k := 0
					var d := INF
					for v in pos.size():
						if pos[v].distance_squared_to(p) < d:
							d = pos[v].distance_squared_to(p)
							k = v
					var pn: Vector3 = sample(pal, p)[&"n"]
					p -= pn * (pn.dot(p - pos[k]) - HAIR)
			verts[i] = p


## Blends one digit's rings (`rings` of SECTORS vertices from `base`) toward the palm. `nrm`,
## `rest_n` and `hand_w` are the whole tube mesh's per-vertex values, edited in place.
static func transfer(pal: Dictionary, verts: PackedVector3Array, nrm: PackedVector3Array,
		rest_n: PackedVector3Array, hand_w: PackedFloat32Array, base: int, rings: int,
		emerge: int) -> void:
	for ring in rings:
		var t := share(ring, emerge)
		if t <= 0.0:
			break
		for s in ArmFingers.SECTORS:
			var i := base + ring * ArmFingers.SECTORS + s
			var pm := sample(pal, verts[i])
			nrm[i] = nrm[i].lerp(pm[&"n"], t).normalized()
			rest_n[i] = rest_n[i].lerp(pm[&"rest_n"], t).normalized()
			hand_w[i] = lerpf(hand_w[i], pm[&"w"], t)


## `vein_mask` for a digit built by `ArmFingers._finger` (its `fg` dictionary).
static func vein_mask_of(fg: Dictionary) -> PackedFloat32Array:
	return vein_mask(fg[&"centres"], fg[&"rings"], fg[&"emerge"], fg[&"lens"])


## Vein mask per vertex of one digit: 1 up to `FADE_FROM` of its first phalanx, 0 by its far joint.
## `lens` are the finger's bone lengths (thumb: .01 is 0, its tube starts at .02).
static func vein_mask(centres: PackedVector3Array, rings: int, emerge: int,
		lens: Array[float]) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var first_len := lens[1] if lens[1] > 0.0 else lens[2]
	var along := 0.0
	for ring in rings:
		if ring > emerge:
			along += centres[ring].distance_to(centres[ring - 1])
		var m := 1.0 - smoothstep(FADE_FROM, 1.0, along / maxf(first_len, 0.0001))
		for s in ArmFingers.SECTORS:
			out.append(m)
	out.append(0.0)  # the tip pole
	return out


## CUSTOM0 (x along the arm, y and z across it, w mask) of the tube vertices `verts`, in the
## hand's own vein frame (ArmMuscle: origin at the upper arm head, axis to the hand head, u toward
## the thumb root), so the chart runs on from the hand back without a jump.
static func chart(mi: MeshInstance3D, sk: Skeleton3D, suffix: String,
		verts: PackedVector3Array, mask: PackedFloat32Array) -> PackedFloat32Array:
	var heads: Array[Vector3] = []
	for n in ["DEF-upper_arm", "DEF-hand", "DEF-thumb.01"]:
		var b := ArmWrap.bind_index(mi, sk, n + suffix)
		if b < 0:
			push_warning("ArmFingerJoin: %s missing, finger tubes carry no veins" % n)
			return PackedFloat32Array()
		heads.append(mi.skin.get_bind_pose(b).affine_inverse().origin)
	var axis := (heads[1] - heads[0]).normalized()
	var thumb_dir := heads[2] - heads[1]
	var u := (thumb_dir - axis * thumb_dir.dot(axis)).normalized()
	var v := axis.cross(u)
	var out := PackedFloat32Array()
	out.resize(verts.size() * 4)
	for i in verts.size():
		var d := verts[i] - heads[0]
		out[i * 4] = d.dot(axis)
		out[i * 4 + 1] = d.dot(u)
		out[i * 4 + 2] = d.dot(v)
		out[i * 4 + 3] = mask[i]
	return out
