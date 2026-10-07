class_name VanKitRules
extends RefCounted
## Checks a seed's donor set and placed kit pieces against the plan's rules (spec 2-5).

const _BREAK := "VAN KIT RULE BREAK: "
## Depth bands (m) per kind: skin, floor, lap or patch, brace and arch box.
const _DEPTH := {&"skin": Vector2(0.01, 0.03), &"floor": Vector2(0.024, 0.036),
	&"patch": Vector2(0.03, VanKitPatches.WALL_DEPTH_MAX), &"brace": Vector2(0.0, 0.25), &"arch_box": Vector2(0.0, 0.25),
	&"rib": Vector2(0.06, 0.08), &"bow": Vector2(0.06, 0.08), &"pillar": Vector2(0.06, 0.08),
	&"seam": Vector2(0.03, 0.08), &"window": Vector2(0.03, 0.08),
	&"wear": Vector2(0.0, 0.25)}
const _REACH_MAX := 0.25


## The first line is the summary (`van kit rules: ok <n> dropped <d>`), then paint info lines
## (`paint ...`), then one `VAN KIT RULE BREAK:` line per break.
static func check(placed: Array[VanKitPlaced], donors: VanDonorSet,
		keep_out: VanKitKeepOut) -> PackedStringArray:
	var breaks := PackedStringArray()
	breaks.append_array(VanKitRulesLines.check(donors, placed))
	var info := PackedStringArray()
	info.append(VanKitStructure.summary(placed))
	info.append(VanKitRulesPatches.summary(placed))
	info.append_array(VanKitPatches.dropped)
	var braces := 0
	for p in placed:
		if kind_of(p) == &"brace":
			braces += 1
	info.append("braces %d" % braces)
	info.append_array(VanKitBraces.dropped)
	var arches := 0
	for p in placed:
		if kind_of(p) == &"arch_box":
			arches += 1
	info.append("arch boxes %d" % arches)
	info.append_array(VanKitArch.dropped)
	breaks.append_array(VanKitRulesPatches.check(placed))
	for line in VanKitRulesPaint.check(donors):
		if line.begins_with(_BREAK):
			breaks.append(line)
		else:
			info.append(line)
	breaks.append_array(_pieces(placed, keep_out))
	var out := PackedStringArray()
	var status := "ok" if breaks.is_empty() else "broken %d" % breaks.size()
	out.append("van kit rules: %s %d dropped %d" % [status, placed.size(), donors.dropped_cuts])
	out.append_array(info)
	out.append_array(breaks)
	return out


## Kind of a piece, from its def id prefix; anything else is a wall skin or floor plate.
static func kind_of(p: VanKitPlaced) -> StringName:
	var id := String(p.def_id)
	if p.reason == &"window_piece":
		return &"window"
	if id == "lap_weld":
		return &"seam"
	for kind: StringName in [&"patch", &"brace", &"arch_box", &"rib", &"bow", &"pillar", &"wear"]:
		if id.begins_with(String(kind)) or id.begins_with("structure/" + String(kind)):
			return kind
	return &"floor" if p.surface == &"floor" else &"skin"


## Signed rotation of the piece about its surface normal (its local y), in degrees, measured from
## the van's length axis projected onto the surface, folded into -90..90.
static func tilt_deg(p: VanKitPlaced) -> float:
	var normal := p.transform.basis.y.normalized()
	var ref := (Vector3.BACK - normal * normal.dot(Vector3.BACK))
	if ref.length() < 0.001:
		ref = Vector3.RIGHT - normal * normal.dot(Vector3.RIGHT)
	var deg := rad_to_deg(ref.signed_angle_to(p.transform.basis.z, normal))
	if deg > 90.0:
		deg -= 180.0
	elif deg < -90.0:
		deg += 180.0
	return deg


static func _pieces(placed: Array[VanKitPlaced], keep_out: VanKitKeepOut) -> PackedStringArray:
	var out := PackedStringArray()
	var by_def := {}
	for p in placed:
		var kind := kind_of(p)
		var tag := "%s %s" % [p.def_id, p.surface]
		var box := p.transform * AABB(-p.size * 0.5, p.size)
		var test_kind := kind
		if (kind == &"floor" or VanKitSurface.is_leaf(p.surface)) and not p.outline.is_empty():
			# Floor plates pivot on an edge and leaf pieces sit in leaf space: test the box and
			# kind the cut used.
			box = VanKitClip._box(p.surface, p.outline, p.size.y)
			if VanKitSurface.is_leaf(p.surface):
				test_kind = StringName(VanKitClip.LEAF_PREFIX + String(kind))
		var blocker := keep_out.why_strip(box, test_kind, p.outline) if kind == &"window" \
				else keep_out.why(box, test_kind)
		# A bolt row's bounding box spans the gaps between its heads: test each head instead.
		if p.def_id == &"wear/bolts":
			blocker = ""
			for hd: Dictionary in VanKitWear.made_of(p).get(&"heads", []):
				blocker = keep_out.why(VanKitWear.head_box(hd), test_kind)
				if blocker != "":
					break
		if blocker != "":
			out.append(_BREAK + "keep-out %s: blocked by %s" % [tag, blocker])
		if kind == &"floor" and p.transform.basis.y.dot(Vector3.UP) < 0.9999:
			out.append(_BREAK + "floor plate tilted off the floor: %s" % tag)
		var depth := p.size.y
		var band: Vector2 = _DEPTH[kind]
		if depth < band.x - 0.001 or depth > band.y + 0.001 or depth > _REACH_MAX:
			out.append(_BREAK + "depth %s: %.3f outside %s" % [tag, depth, band])
		if keep_out.walls != null and (p.surface == &"left_wall" or p.surface == &"right_wall"):
			var reach_y := box.end.y if kind == &"arch_box" else box.get_center().y
			var reach := keep_out.walls.wall_x_at(reach_y) \
					- minf(absf(box.position.x), absf(box.end.x))
			if reach > _REACH_MAX + 0.001:
				out.append(_BREAK + "reach %s: %.3f in from the liner over %.2f" % [
					tag, reach, _REACH_MAX])
		var tilt := absf(tilt_deg(p))
		if kind == &"brace":
			# Off the nearest axis: an upright brace is measured from the vertical.
			var off := minf(tilt, 90.0 - tilt)
			if off < 5.0 or off > 20.0:
				out.append(_BREAK + "angle %s: brace %.1f deg outside 5..20" % [tag, off])
		if kind == &"patch":
			var longest := maxf(p.size.x, p.size.z)
			var cap := 6.0 if longest <= 0.4 else 2.0 if longest >= 0.75 \
					else 6.0 - 4.0 * (longest - 0.4) / 0.35
			if tilt > cap + 0.05:
				out.append(_BREAK + "angle %s: patch %.1f deg over %.1f" % [tag, tilt, cap])
		var key := "%s/%s" % [p.def_id, p.surface]
		by_def[key] = by_def.get(key, []) + [p]
	for key: String in by_def:
		out.append_array(_repetition(key, by_def[key]))
	out.append_array(_arch_axles(placed))
	return out


## Each arch box's z span holds a rear axle of the live van's look.
static func _arch_axles(placed: Array[VanKitPlaced]) -> PackedStringArray:
	var out := PackedStringArray()
	var look := Engine.get_main_loop().root.get_tree().get_first_node_in_group(
			VanLook.GROUP) as VanLook
	if look == null:
		return out
	var axles := VanWheels.rear_axles_for(look)
	for p in placed:
		if kind_of(p) != &"arch_box":
			continue
		var z := p.transform.origin.z
		var held := false
		for axle in axles:
			held = held or absf(axle - z) < p.size.z * 0.5
		if not held:
			out.append(_BREAK + "arch %s %s: z span holds no rear axle" % [p.def_id, p.surface])
		if p.size.y > 0.25 + 0.001:
			out.append(_BREAK + "arch %s %s: depth %.3f over 0.25" % [p.def_id, p.surface,
				p.size.y])
	return out


## A def with 3 or more copies on a surface spaces them irregularly (CV >= 0.25); structure and
## rear-leaf pieces (one depth, one z) exempt.
static func _repetition(key: String, copies: Array) -> PackedStringArray:
	var out := PackedStringArray()
	if copies.size() < 3 or key.begins_with("structure/") \
			or key.begins_with("skin/") or key.begins_with("wear/") or key.ends_with("_leaf"):
		return out
	var zs: Array[float] = []
	for p: VanKitPlaced in copies:
		zs.append(p.transform.origin.z)
	zs.sort()
	var gaps: Array[float] = []
	for i in zs.size() - 1:
		gaps.append(zs[i + 1] - zs[i])
	var mean := 0.0
	for g in gaps:
		mean += g
	mean /= gaps.size()
	var variance := 0.0
	for g in gaps:
		variance += (g - mean) * (g - mean)
	var cv := sqrt(variance / gaps.size()) / maxf(mean, 0.001)
	if cv < 0.25:
		out.append(_BREAK + "repetition %s: spacing CV %.2f under 0.25" % [key, cv])
	return out
