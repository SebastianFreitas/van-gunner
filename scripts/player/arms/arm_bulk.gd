class_name ArmBulk
extends RefCounted
## Inflates a skinned arm mesh around each bone's axis so the limbs read thick.

## Forearm gains live here once; the builder sizes the sleeve and tattoo from them.
const FOREARM_ELBOW_GAIN := 2.8
## Wrist:palm width should be about 0.75-0.8, not 1.0.
const FOREARM_WRIST_GAIN := 2.1
## Gain the forearm ramp ends at. Aimed at the first hand ring, not at the hand bone's nominal
## gain: hand vertices blend several bones, so their ring sits well under the bone's own gain.
## Raised to 1.8 with the hand gains for the monster hands (2026-10-02), then lowered to 1.45 with
## the hand gains (1.85 -> 1.45) on 2026-10-03: the palm read as an inflated pillow behind the
## fingers.
const WRIST_END_GAIN := 1.45
## Extra on the palm gain over the knuckle half of each palm bone: the knuckle row is the widest
## point of a hand. Only slightly above neutral: the procedural finger tubes' knobs carry most of
## the knuckle swell. Lowered on 2026-10-04: at 1.15 the knuckle half of the palm became a
## flat-topped slab the finger roots stuck out of.
const KNUCKLE_GAIN := 1.05
## Fraction of the palm bone where the knuckle boost starts.
const KNUCKLE_RAMP_START := 0.5
## Glb finger segments shrink to a thin core hidden inside the procedural finger tubes
## (ArmFingers); never bulked, so it stays hidden.
const FINGER_CORE := 0.55
## The glb's own fingertip (".03") collapses to a sliver on its bone line: at FINGER_CORE its tip
## still poked out beside the procedural tube and claw as a second, human nail.
const TIP_CORE := 0.05
## Along a finger's ".01" bone (and the thumb's ".02"), the gain ramps from 1.0 to FINGER_CORE
## between these fractions of the bone length, so the tube's knuckle knob covers the step.
const FINGER_RAMP := Vector2(0.10, 0.35)
## Finger whose ".01" head ends palm bone ".01".. ".04" (Rigify order, index to pinky).
const PALM_FINGERS: Array[String] = ["f_index", "f_middle", "f_ring", "f_pinky"]
## Where along the forearm twist bone (0 head, 1 wrist) the gain starts easing to the hand's, so
## the fat forearm meets the hand ring instead of ending in a step.
const WRIST_RAMP_START := 0.5
## Radial gain per bone-name prefix (bone names look like "DEF-forearm.R", "DEF-f_index.02.L").
## First matching prefix wins, so the longer names come first. Forearms are split in _raw_gain,
## and so are the finger segments after the first (the segment sits after the finger name).
const GAIN: Array = [
	["DEF-forearm", FOREARM_ELBOW_GAIN],
	["DEF-upper_arm", 2.5],
	# Hand and palm gains halved above neutral on 2026-10-03 so the palm matches the finger tubes.
	["DEF-hand", 1.45],
	# ".01" is the metacarpal (thenar mass), tapered to the tip.
	["DEF-thumb.01", 1.5],
	["DEF-thumb.02", FINGER_CORE],
	["DEF-thumb.03", TIP_CORE],
	["DEF-palm.01", 1.45],
	["DEF-palm.04", 1.45],
	["DEF-palm", 1.4],
	["DEF-f_", 1.0],
]


static func _raw_gain(bone_name: String) -> float:
	var g := 1.0
	for entry in GAIN:
		if bone_name.begins_with(entry[0]):
			g = entry[1]
			# The wrist half of the forearm (".001") tapers thinner than the elbow half.
			if entry[0] == "DEF-forearm" and bone_name.contains(".001"):
				g = FOREARM_WRIST_GAIN
			break
	# Fingers taper root to tip; ".02." and ".03." keep the ".001" and side suffix out of it.
	if bone_name.begins_with("DEF-f_"):
		if bone_name.contains(".02."):
			g = FINGER_CORE
		elif bone_name.contains(".03."):
			g = TIP_CORE
	return g


static func _gain_for(bone_name: String, bulk: float) -> float:
	var g := _raw_gain(bone_name)
	# Finger cores and tips must stay thin under any bulk, or they would poke out of their tube.
	if g == FINGER_CORE or g == TIP_CORE:
		return g
	return _bulked(g, bulk)


static func _bulked(g: float, bulk: float) -> float:
	return 1.0 + (g - 1.0) * bulk


## Replaces the mesh with a fresh copy so the shared imported mesh is never touched.
static func inflate(mi: MeshInstance3D, skel: Skeleton3D, bulk: float,
		muscle_seed: int) -> void:
	var src := mi.mesh as ArrayMesh
	var sk_res := mi.skin
	if src == null or sk_res == null or skel == null:
		push_warning("ArmBulk: arm mesh, skin or skeleton missing; arms stay slim")
		return
	var count := sk_res.get_bind_count()
	var gains: Array[float] = []
	var poses: Array[Transform3D] = []
	var inv_poses: Array[Transform3D] = []
	for b in count:
		var bone_name := String(sk_res.get_bind_name(b))
		if bone_name.is_empty():
			bone_name = skel.get_bone_name(sk_res.get_bind_bone(b))
		gains.append(_gain_for(bone_name, bulk))
		var pose := sk_res.get_bind_pose(b)
		poses.append(pose)
		inv_poses.append(pose.affine_inverse())
	var bone_names := PackedStringArray()
	var heads := {}
	var ramp_len := PackedFloat32Array()
	ramp_len.resize(count)
	ramp_len.fill(0.0)
	# Elbow half of the forearm: length to its twist half's head. The gain eases from the elbow
	# gain to the wrist gain across it, so there is no step at the twist boundary (the proximal
	# half tapers like muscle, the distal half stays flat like tendon).
	var elbow_len := PackedFloat32Array()
	elbow_len.resize(count)
	elbow_len.fill(0.0)
	var palm_len := PackedFloat32Array()
	palm_len.resize(count)
	palm_len.fill(0.0)
	# Finger ".01" (and thumb ".02") length to the next segment's head, for the FINGER_RAMP.
	var seg_len := PackedFloat32Array()
	seg_len.resize(count)
	seg_len.fill(0.0)
	var knuckle_gain := PackedFloat32Array()
	knuckle_gain.resize(count)
	knuckle_gain.fill(1.0)
	var side := "." + String(mi.name).right(1)
	for b in count:
		var full := String(sk_res.get_bind_name(b))
		if full.is_empty():
			full = skel.get_bone_name(sk_res.get_bind_bone(b))
		bone_names.append(full)
		var base := full
		if base.ends_with(".L") or base.ends_with(".R"):
			base = base.substr(0, base.length() - 2)
		if full.ends_with(side) and base in ["DEF-upper_arm", "DEF-forearm", "DEF-hand", "DEF-thumb.01"]:
			heads[StringName(base)] = inv_poses[b].origin
	for b in count:
		if not (bone_names[b].begins_with("DEF-forearm") and bone_names[b].contains(".001")):
			continue
		var hand_name := "DEF-hand" + (".L" if bone_names[b].contains(".L") else ".R")
		for hb in count:
			if bone_names[hb] == hand_name:
				ramp_len[b] = (inv_poses[hb].origin - inv_poses[b].origin).length()
				break
	for b in count:
		if not bone_names[b].begins_with("DEF-forearm") or bone_names[b].contains(".001"):
			continue
		var twist_name := bone_names[b] + ".001"
		for tb in count:
			if bone_names[tb] == twist_name:
				elbow_len[b] = (inv_poses[tb].origin - inv_poses[b].origin).length()
				break
	for b in count:
		if not bone_names[b].begins_with("DEF-palm.0"):
			continue
		var digit := bone_names[b].substr("DEF-palm.0".length(), 1).to_int()
		if digit < 1 or digit > PALM_FINGERS.size():
			continue
		var finger_name := "DEF-%s.01%s" % [PALM_FINGERS[digit - 1], bone_names[b].right(2)]
		for fb in count:
			if bone_names[fb] == finger_name:
				palm_len[b] = (inv_poses[fb].origin - inv_poses[b].origin).length()
				knuckle_gain[b] = _bulked(_raw_gain(bone_names[b]) * KNUCKLE_GAIN, bulk)
				break
	for b in count:
		var child_name := ""
		if bone_names[b].begins_with("DEF-f_") and bone_names[b].contains(".01."):
			child_name = bone_names[b].replace(".01.", ".02.")
		elif bone_names[b].begins_with("DEF-thumb.02"):
			child_name = bone_names[b].replace("DEF-thumb.02", "DEF-thumb.03")
		if child_name.is_empty():
			continue
		for cb in count:
			if bone_names[cb] == child_name:
				seg_len[b] = (inv_poses[cb].origin - inv_poses[b].origin).length()
				break
	var wrist_end := _bulked(WRIST_END_GAIN, bulk)
	var wrist_half := _bulked(FOREARM_WRIST_GAIN, bulk)
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		arrays = ArmRefine.refine(arrays)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := int(float(bones.size()) / maxf(verts.size(), 1.0))
		var new_verts := verts.duplicate()
		for i in verts.size():
			var sum := 0.0
			var acc := Vector3.ZERO
			for k in per:
				var w := weights[i * per + k]
				if w <= 0.0:
					continue
				var b := bones[i * per + k]
				var p: Vector3 = poses[b] * verts[i]
				var g: float = gains[b]
				if elbow_len[b] > 0.0:
					g = lerpf(g, wrist_half, clampf(p.y / elbow_len[b], 0.0, 1.0))
				# The wrist half of the forearm eases from its own gain to the hand's over its
				# last stretch, so the forearm's end ring does not stand proud of the hand ring.
				if ramp_len[b] > 0.0:
					var u := clampf((p.y / ramp_len[b] - WRIST_RAMP_START)
							/ (1.0 - WRIST_RAMP_START), 0.0, 1.0)
					g = lerpf(g, wrist_end, u)
				if palm_len[b] > 0.0:
					var kn := clampf((p.y / palm_len[b] - KNUCKLE_RAMP_START)
							/ (1.0 - KNUCKLE_RAMP_START), 0.0, 1.0)
					g = lerpf(g, knuckle_gain[b], kn)
				# The glb finger starts at its own radius and thins to the core past the knuckle.
				if seg_len[b] > 0.0:
					var t := p.y / seg_len[b]
					g = lerpf(1.0, FINGER_CORE, smoothstep(FINGER_RAMP.x, FINGER_RAMP.y, t))
				acc += w * (inv_poses[b] * Vector3(p.x * g, p.y, p.z * g))
				sum += w
			if sum > 0.0:
				new_verts[i] = acc / sum
		ArmMuscle.apply(arrays, new_verts, heads, bone_names, muscle_seed, bulk,
				side == ".L")
		_rest_channels(arrays, mi)
		var flags := src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays, [], {}, flags)
		out.surface_set_material(s, src.surface_get_material(s))
	mi.mesh = out


## Bakes the rest pose into CUSTOM1 (xyz position, w hand weight) and CUSTOM2 (xyz normal). The
## engine skins vertices before the shader's vertex() runs, so VERTEX is already posed there and
## the skin shader needs this unposed chart to keep its patterns glued to the skin.
static func _rest_channels(arrays: Array, mi: MeshInstance3D) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var count := verts.size()
	var per := int(float(bones.size()) / maxf(count, 1.0))
	# ARRAY_BONES index the Skin's binds, so the hand flag is looked up per bind, not per bone.
	var sk_res := mi.skin
	var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	var is_hand := PackedByteArray()
	for b in sk_res.get_bind_count():
		var bone_name := String(sk_res.get_bind_name(b))
		if bone_name.is_empty() and skel != null:
			bone_name = skel.get_bone_name(sk_res.get_bind_bone(b))
		var hand := bone_name.contains("hand") or bone_name.contains("palm") \
				or bone_name.contains("f_") or bone_name.contains("thumb")
		is_hand.append(1 if hand else 0)
	var rest := PackedFloat32Array()
	rest.resize(count * 4)
	var rest_n := PackedFloat32Array()
	rest_n.resize(count * 4)
	for i in count:
		var hand_w := 0.0
		for k in per:
			var w := weights[i * per + k]
			if w > 0.0 and is_hand[bones[i * per + k]] == 1:
				hand_w += w
		rest[i * 4] = verts[i].x
		rest[i * 4 + 1] = verts[i].y
		rest[i * 4 + 2] = verts[i].z
		rest[i * 4 + 3] = clampf(hand_w, 0.0, 1.0)
		rest_n[i * 4] = normals[i].x
		rest_n[i * 4 + 1] = normals[i].y
		rest_n[i * 4 + 2] = normals[i].z
	arrays[Mesh.ARRAY_CUSTOM1] = rest
	arrays[Mesh.ARRAY_CUSTOM2] = rest_n
