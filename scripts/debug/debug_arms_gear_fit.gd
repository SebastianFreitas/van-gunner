extends RefCounted
## Debug `arms gear`: poses both arms through the weave, the shot kick and the reload, skins the
## arm and its sleeve on the CPU and counts skin vertices that poke through the sleeve.

const WEAVE_TIMES: Array[float] = [0.0, 0.9, 1.8, 2.7, 3.6, 4.5, 5.4, 6.3]
const RELOAD_AT: Array[float] = [0.25, 0.5, 0.75]
## Seconds after the shot where the arm envelope peaks (ENV_ARM attack).
const KICK_PEAK := 0.045
## Kick pinned long after its shot (fully settled), as the smoke pins it.
const SETTLED := 10.0
const REST_WEAVE_T := 1.1
const CLEARANCE := 0.02  ## of the ring radius
## Skin further than this (in ring radii) outside a ring belongs to some other part of the arm.
const REACH := 0.25
## Least weight on a piece's own bones for skin to count as under it (`ArmWrap.section` rule).
const OWN_MIN := 0.35

var host: Node


func _init(owner: Node) -> void:
	host = owner


func run(vm: Node) -> String:
	var weave: RefCounted = vm.get("_weave")
	var kick: RefCounted = vm.get("_kick")
	var roots := vm.get("_roots") as Dictionary
	var pieces: Array[Dictionary] = []
	for side in ["right", "left"]:
		var root := roots.get(side + "_root") as Node3D
		if root == null:
			continue
		for c in root.get_children():
			var sk := ArmRig.skeleton(c as Node3D) if c is Node3D else null
			if sk != null:
				_gather(sk, side, pieces)
	if weave == null or pieces.is_empty():
		var skip := "GEAR SKIP (dress %s)" % ArmsBuilder.dress_style
		print(skip)
		return skip
	var lines: Array[String] = []
	var poses: Array[Dictionary] = []
	for t in WEAVE_TIMES:
		poses.append({&"w": t, &"k": SETTLED, &"r": -1.0, &"n": "weave %.2f" % t})
	if kick != null:
		poses.append({&"w": REST_WEAVE_T, &"k": KICK_PEAK, &"r": -1.0, &"n": "kick peak"})
		for f in RELOAD_AT:
			poses.append({&"w": REST_WEAVE_T, &"k": SETTLED, &"r": f,
					&"n": "reload %.2f" % f})
	else:
		lines.append("GEAR NOTE: kick/reload not reachable")
	var saved_reload: float = vm.debug_reload_t
	for pose in poses:
		weave.call(&"update", pose[&"w"])
		if kick != null:
			kick.call(&"pin", pose[&"k"])
		vm.debug_reload_t = pose[&"r"]
		vm.call(&"_apply")
		for piece in pieces:
			var globals := _globals(piece[&"sk"] as Skeleton3D)
			var posed := _skin(piece[&"arm"] as MeshInstance3D, globals,
					piece[&"own"] as PackedStringArray)
			_check(piece, globals, posed[0] as PackedVector3Array, posed[1] as PackedFloat32Array,
					posed[2] as PackedStringArray, pose[&"n"] as String)
	_restore(vm, weave, kick, saved_reload)
	var clips := 0
	var worst := -INF
	for piece in pieces:
		var hits := piece[&"hits"] as Dictionary
		var deepest := float(hits.values().max()) if not hits.is_empty() else -INF
		clips += hits.size()
		worst = maxf(worst, deepest)
		var line := "gear %s: clips %d worst %s r" % [piece[&"name"], hits.size(),
				"%.2f" % deepest if not hits.is_empty() else "-"]
		if not hits.is_empty():
			line += " (ring %d, %s, sector %d, bone %s)" % [piece[&"worst_ring"],
					piece[&"worst_pose"], piece[&"worst_sector"], piece[&"worst_bone"]]
		lines.append(line)
	lines.append("GEAR OK" if clips == 0 else "GEAR CLIP %d (worst %.2f)" % [clips, worst])
	var text := "\n".join(lines)
	print(text)
	return text


## Puts the viewmodel back to the pose its own `_process` would have set.
func _restore(vm: Node, weave: RefCounted, kick: RefCounted, reload: float) -> void:
	vm.debug_reload_t = reload
	var consts: Dictionary = (vm.get_script() as Script).get_script_constant_map()
	var sandbox_t: float = consts.get("WEAVE_SANDBOX_T", REST_WEAVE_T)
	var at := vm.debug_weave_t as float
	if at < 0.0:
		at = sandbox_t if SaveSandbox.enabled else float(vm.get("_weave_t"))
	weave.call(&"update", at)
	if kick != null:
		if vm.debug_shot_t >= 0.0:
			kick.call(&"pin", vm.debug_shot_t)
		elif SaveSandbox.enabled:
			kick.call(&"pin", SETTLED)
		else:
			kick.call(&"sample", vm.get("_kick_clock"))
	vm.call(&"_apply")


## One entry per gear piece on `sk` (the sleeve): its cloth tube list and running totals.
func _gather(sk: Skeleton3D, side: String, out: Array[Dictionary]) -> void:
	var arm_mi: MeshInstance3D = null
	for c in sk.get_children():
		var nm := String(c.name)
		if c is MeshInstance3D and not nm.begins_with("Gear_") and not nm.begins_with("Dress_"):
			arm_mi = c as MeshInstance3D
			break
	if arm_mi == null or arm_mi.skin == null:
		return
	var suf := ".L" if side == "left" else ".R"
	var sleeve := sk.get_node_or_null(^"Gear_sleeve") as MeshInstance3D
	if sleeve != null:
		# The sleeve ends above the elbow, so only upper-arm skin belongs under it; forearm
		# skin near the hem at a tight bend lies outside the cloth.
		var upper := PackedStringArray(["DEF-upper_arm" + suf, "DEF-upper_arm" + suf + ".001"])
		out.append(_entry(sk, arm_mi, side, sleeve, [[0, ArmSleeve.RINGS, ArmSleeve.SECTORS]],
				upper))


## `own`: the bones this piece rides on; only arm skin weighted on them counts as under it.
func _entry(sk: Skeleton3D, arm_mi: MeshInstance3D, side: String, mi: MeshInstance3D,
		tubes: Array, own: PackedStringArray) -> Dictionary:
	return {&"sk": sk, &"arm": arm_mi, &"mi": mi, &"tubes": tubes, &"own": own, &"hits": {},
			&"name": "%s/%s" % [side, mi.name], &"worst": -INF, &"worst_ring": -1,
			&"worst_pose": "", &"worst_sector": -1, &"worst_bone": ""}


## Bone global poses composed from the local poses, since the skeleton's cache can be stale.
func _globals(sk: Skeleton3D) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i in sk.get_bone_count():
		var parent := sk.get_bone_parent(i)
		var local := sk.get_bone_pose(i)
		out.append(out[parent] * local if parent >= 0 and parent < i else local)
	return out


## [posed skeleton-space vertices (sum of weight x bone global x bind pose x vertex), each
## vertex's summed weight on the bones named in `own`, each vertex's heaviest bone name].
func _skin(mi: MeshInstance3D, globals: Array[Transform3D], own := PackedStringArray()) -> Array:
	var sk := mi.get_parent() as Skeleton3D
	var skin := mi.skin
	var mats: Array[Transform3D] = []
	var mine: Array[bool] = []
	var names := PackedStringArray()
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		var nm := String(skin.get_bind_name(b))
		if bone < 0:
			bone = sk.find_bone(nm)
		elif nm.is_empty():
			nm = sk.get_bone_name(bone)
		mats.append(globals[bone] * skin.get_bind_pose(b) if bone >= 0 else Transform3D.IDENTITY)
		mine.append(nm in own)
		names.append(nm)
	var out := PackedVector3Array()
	var owned := PackedFloat32Array()
	var dominant := PackedStringArray()
	var mesh := mi.mesh
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		@warning_ignore("integer_division")
		var per := bones.size() / maxi(verts.size(), 1)
		for k in verts.size():
			var p := Vector3.ZERO
			var own_w := 0.0
			var top_w := 0.0
			var top := ""
			for m in per:
				var w := weights[k * per + m]
				if w > 0.0:
					p += (mats[bones[k * per + m]] * verts[k]) * w
					if mine[bones[k * per + m]]:
						own_w += w
					if w > top_w:
						top_w = w
						top = names[bones[k * per + m]]
			out.append(p)
			owned.append(own_w)
			dominant.append(top)
	return [out, owned, dominant]


## Adds the skin (index -> depth in r) that pokes through one gear piece to its `hits`.
func _check(piece: Dictionary, globals: Array[Transform3D], skin: PackedVector3Array,
		own: PackedFloat32Array, dominant: PackedStringArray, pose_name: String) -> void:
	var mi := piece[&"mi"] as MeshInstance3D
	var hits := piece[&"hits"] as Dictionary
	var cloth := _skin(mi, globals)[0] as PackedVector3Array
	for tube: Array in piece[&"tubes"]:
		if int(tube[0]) + int(tube[1]) * int(tube[2]) > cloth.size():
			continue
		var found := _tube_clips(cloth, int(tube[0]), int(tube[1]), int(tube[2]), skin, own,
				dominant, hits)
		if float(found[&"depth"]) > float(piece[&"worst"]):
			piece[&"worst"] = found[&"depth"]
			piece[&"worst_ring"] = found[&"ring"]
			piece[&"worst_pose"] = pose_name
			piece[&"worst_sector"] = found[&"sector"]
			piece[&"worst_bone"] = found[&"bone"]


## Own skin vertices in a ring's slab that lie outside its posed polygon (less the clearance),
## added to `hits`. Returns the deepest clip of this call as {&"depth": r, &"ring": k,
## &"sector": the nearest sector j, &"bone": the clipping vertex's heaviest bone} (depth -INF,
## ring and sector -1 and bone "" when there is none).
func _tube_clips(cloth: PackedVector3Array, first: int, rings: int, sectors: int,
		skin: PackedVector3Array, own: PackedFloat32Array, dominant: PackedStringArray,
		hits: Dictionary) -> Dictionary:
	var centres: Array[Vector3] = []
	var box := AABB(cloth[first], Vector3.ZERO)
	var mean_r := 0.0
	for k in rings:
		var c := Vector3.ZERO
		for j in sectors:
			c += cloth[first + k * sectors + j]
			box = box.expand(cloth[first + k * sectors + j])
		c /= float(sectors)
		var rr := 0.0
		for j in sectors:
			rr += cloth[first + k * sectors + j].distance_to(c)
		centres.append(c)
		mean_r += rr / float(sectors) / float(rings)
	box = box.grow(REACH * mean_r)
	var cand := PackedInt32Array()
	for i in skin.size():
		if own[i] >= OWN_MIN and box.has_point(skin[i]):
			cand.append(i)
	var worst_depth := -INF
	var worst_ring := -1
	var worst_sector := -1
	var worst_bone := ""
	# the torn hem ring is pulled back up the arm, so the slab past it is not covered
	for k in rings - 1:
		var k0 := maxi(k - 1, 0)
		var k1 := mini(k + 1, rings - 1)
		var axis := (centres[k1] - centres[k0]).normalized()
		var half := 0.5 * centres[k1].distance_to(centres[k0]) / float(maxi(k1 - k0, 1))
		var u := cloth[first + k * sectors] - centres[k]
		u = (u - axis * u.dot(axis)).normalized()
		var w := axis.cross(u)
		var ang := PackedFloat32Array()
		var rad := PackedFloat32Array()
		for j in sectors:
			var d := cloth[first + k * sectors + j] - centres[k]
			ang.append(atan2(d.dot(w), d.dot(u)))
			rad.append(Vector2(d.dot(u), d.dot(w)).length())
		for i in cand:
			var d := skin[i] - centres[k]
			if absf(d.dot(axis)) > half:
				continue
			var flat := Vector2(d.dot(u), d.dot(w))
			var depth := (flat.length() - _edge(ang, rad, flat.angle())) / mean_r
			if depth > -CLEARANCE and depth < REACH:
				hits[i] = maxf(float(hits.get(i, -INF)), depth)
				if depth > worst_depth:
					worst_depth = depth
					worst_ring = k
					worst_bone = dominant[i]
					worst_sector = 0
					var best := INF
					for j in sectors:
						var gap := absf(wrapf(ang[j] - flat.angle(), -PI, PI))
						if gap < best:
							best = gap
							worst_sector = j
	return {&"depth": worst_depth, &"ring": worst_ring, &"sector": worst_sector,
			&"bone": worst_bone}


## Polygon radius at angle `theta`, interpolated between the two sectors that bracket it.
func _edge(ang: PackedFloat32Array, rad: PackedFloat32Array, theta: float) -> float:
	var n := ang.size()
	for j in n:
		var j1 := (j + 1) % n
		var span := wrapf(ang[j1] - ang[j], -PI, PI)
		var off := wrapf(theta - ang[j], -PI, PI)
		if (span >= 0.0 and off >= 0.0 and off <= span) \
				or (span < 0.0 and off <= 0.0 and off >= span):
			return lerpf(rad[j], rad[j1], off / span if absf(span) > 0.000001 else 0.0)
	return rad[0]
