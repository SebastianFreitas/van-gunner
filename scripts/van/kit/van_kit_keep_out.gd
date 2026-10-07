class_name VanKitKeepOut
extends RefCounted
## Volumes no kit piece may block: window climb gaps and raider lanes, door bays, the rear-door
## swing, the aisle, machines and cables. Pure geometry in van-local metres; dressing is not here.

const _Router := preload("res://scripts/van/look/van_cable_router.gd")
const _WALLS_PATH := ^"Interior/Shell/SideWalls"
const _PROPS_PATH := ^"Interior/Props"
const _CABLES_PATH := ^"VanLook/Cables"
const _REAR_PATH := "Interior/Shell/RearWall/"
## SideWindows.GLASS_POLY (window-local z, y), copied because that one is a node field.
const _GLASS_M: Array[Vector2] = [
	Vector2(-0.861, -0.617), Vector2(-1.017, -0.56), Vector2(-1.1, -0.455),
	Vector2(-1.1, 0.455), Vector2(-1.017, 0.56), Vector2(-0.861, 0.617),
	Vector2(0.861, 0.617), Vector2(1.017, 0.56), Vector2(1.1, 0.455),
	Vector2(1.1, -0.455), Vector2(1.017, -0.56), Vector2(0.861, -0.617),
]
const _PIECE_KINDS: Array[StringName] = [&"patch", &"brace", &"arch_box"]
const _TALL := 3.2
const STRIP_TOL_M := 0.001

## Each: {name, box: AABB, poly: PackedVector2Array (wall z, y; empty = the whole box),
## pieces_only: bool (only patch, brace and arch_box are refused)}.
var _volumes: Array[Dictionary] = []
## The van's side walls, for the rules check's inward reach; null when the rig has none.
var walls: VanSideWall


static func build(van_rig: Node3D, donors: VanDonorSet) -> VanKitKeepOut:
	var out := VanKitKeepOut.new()
	out._add_windows(donors)
	out._add_doors_and_aisle()
	out._add_rear(van_rig)
	out._add_machines_and_cables(van_rig)
	return out


func volume_count() -> int:
	return _volumes.size()


## True when no volume blocks the box for this kind.
func allows(aabb: AABB, kind: StringName) -> bool:
	return why(aabb, kind) == ""


## Name of the first volume blocking the box, "" when it is allowed.
func why(aabb: AABB, kind: StringName) -> String:
	var vol := _blocker(aabb, kind)
	return vol[&"name"] if not vol.is_empty() else ""


## Like `why`, for a window ring strip: wall-side volumes are tested against its cm outline.
func why_strip(aabb: AABB, kind: StringName, strip_cm: PackedVector2Array) -> String:
	var vol := _blocker(aabb, kind, strip_cm)
	return vol[&"name"] if not vol.is_empty() else ""


## The AABB of the first volume blocking the box (a zero AABB when it is allowed).
func blocker_box(aabb: AABB, kind: StringName, strip := PackedVector2Array()) -> AABB:
	var vol := _blocker(aabb, kind, strip)
	return vol[&"box"] if not vol.is_empty() else AABB()


func _blocker(aabb: AABB, kind: StringName, strip := PackedVector2Array()) -> Dictionary:
	# VanKitClip tests kinds on a rear-door leaf as "leaf:<kind>".
	var leaf := String(kind).begins_with(VanKitClip.LEAF_PREFIX)
	var base := StringName(String(kind).trim_prefix(VanKitClip.LEAF_PREFIX))
	for vol: Dictionary in _volumes:
		var vol_name: String = vol[&"name"]
		# Floor plates are flat, collider-free and walkable (D3); leaf pieces ride the swing and sit
		# in the rear lane when the leaf is closed.
		if kind == &"floor" and (vol_name == "aisle" or vol_name.begins_with("door_bay")):
			continue
		if leaf and vol_name.begins_with("rear_"):
			continue
		if vol[&"pieces_only"] and not _PIECE_KINDS.has(base):
			continue
		var box: AABB = vol[&"box"]
		if not box.intersects(aabb) or _flush(box, aabb):
			continue
		var poly: PackedVector2Array = vol[&"poly"]
		if poly.is_empty():
			return vol
		# A window ring strip (cm outline) is tested as its own polygon, not its AABB.
		if not strip.is_empty():
			# A strip lying on the hole edge only grazes the climb gap: overlaps thinner than 1 mm
			# do not count (D43), so the strip is tested shrunk by 1 mm on each side.
			for core: PackedVector2Array in Geometry2D.offset_polygon(
					_cm_to_m(strip), -STRIP_TOL_M, Geometry2D.JOIN_MITER):
				for hit: PackedVector2Array in Geometry2D.intersect_polygons(core, poly):
					if absf(_area(hit)) > 1e-8:
						return vol
		elif _poly_hit(poly, aabb):
			return vol
	return {}


## Rig-space boxes come through the van's moving world pose (about 300 m out, scale 0.999997 and
## drifting per run), so they carry 0.03 mm of float noise that flips cm roundings; 0.1 mm snaps it.
static func snap_box(box: AABB) -> AABB:
	return AABB(box.position.snappedf(0.0001), box.size.snappedf(0.0001))


## A placed piece later patches and braces keep off.
func add_piece(piece_name: String, aabb: AABB) -> void:
	_add(piece_name, aabb, PackedVector2Array(), true)


func _add(vol_name: String, box: AABB, poly := PackedVector2Array(),
		pieces_only := false) -> void:
	box = VanKitKeepOut.snap_box(box)
	_volumes.append({&"name": vol_name, &"box": box,&"poly": poly, &"pieces_only": pieces_only})


func _add_windows(donors: VanDonorSet) -> void:
	for id: StringName in VanKitFootprint.WINDOW_ZC:
		var zc: float = VanKitFootprint.WINDOW_ZC[id]
		var sign_x := -1.0 if String(id).begins_with("left") else 1.0
		var gap := PackedVector2Array()
		var piece := PackedVector2Array()
		var entry := _donor_window(donors, id)
		if entry.is_empty():
			for p: Vector2 in _GLASS_M:
				gap.append(Vector2(zc + p.x, VanKitFootprint.WINDOW_Y + p.y))
		else:
			gap = _cm_to_m(entry[&"opening"])
			piece = _cm_to_m(entry[&"piece_outline"])
		_add_side("climb_gap_%s" % id, sign_x, _grown(gap, VanKitFootprint.CLEAR_M))
		_add_side("lane_%s" % id, sign_x, gap)
		if not piece.is_empty():
			_add_side("piece_%s" % id, sign_x, _grown(piece, VanKitFootprint.CLEAR_M), true)


func _add_doors_and_aisle() -> void:
	var bay := VanKitFootprint.door_bay()
	for sign_x: float in [-1.0, 1.0]:
		_add_side("door_bay_%s" % ("left" if sign_x < 0.0 else "right"), sign_x,
			PackedVector2Array([Vector2(bay.x, 0.0), Vector2(bay.y, 0.0),
				Vector2(bay.y, _TALL), Vector2(bay.x, _TALL)]))
	var z0 := VanKitFootprint.KIT_Z_MIN - 1.0
	var z1 := VanKitFootprint.KIT_Z_MAX + 1.0
	var half := VanKitFootprint.AISLE_HALF_X
	_add("aisle", AABB(Vector3(-half, -1.0, z0), Vector3(half * 2.0,
		VanKitFootprint.AISLE_Y + 1.0, z1 - z0)))
	# VanFloor's CabThreshold (1.45 x 0.025 x 0.07 at z -4.52), grown 0.5 cm so skins stop short.
	_add("cab_threshold", AABB(Vector3(-0.73, 0.0, -4.56), Vector3(1.46, 0.03, 0.08)))


func _add_rear(van_rig: Node3D) -> void:
	var swing_z0 := 4.63
	var width := 2.38
	var hy := 1.55
	for side: String in ["LeftHinge", "RightHinge"]:
		var hinge := van_rig.get_node_or_null(_REAR_PATH + side) as Node3D
		if hinge == null:
			continue
		var body := hinge.get_node_or_null("Panel/Body") as CSGBox3D
		if body:
			width = body.size.x
		var h := van_rig.to_local(hinge.global_position)
		hy = h.y
		swing_z0 = h.z - 0.08
		var sx := signf(h.x)
		var box := AABB(Vector3(minf(h.x, h.x - sx * width), 0.0, swing_z0),
			Vector3(width, hy + 1.55, width + 0.08))
		_add("rear_swing_%s" % side.trim_suffix("Hinge").to_lower(), box)
	# The rear door mouths: from the rear face in to the Entry markers at z 3.9.
	_add("rear_lane", AABB(Vector3(-2.4, 0.0, 3.9), Vector3(4.8, _TALL, swing_z0 - 3.9 + 0.05)))


func _add_machines_and_cables(van_rig: Node3D) -> void:
	walls = van_rig.get_node_or_null(_WALLS_PATH) as VanSideWall
	var props := van_rig.get_node_or_null(_PROPS_PATH)
	var boxes: Array[AABB] = _Router.new(walls).build_keepouts(props, van_rig)
	for i: int in range(boxes.size()):
		# The router grows each collider 5 cm for cables; the kit keeps 2 cm.
		_add("machine_%d" % i, boxes[i].grow(-0.03))
	var cables := van_rig.get_node_or_null(_CABLES_PATH)
	if cables == null:
		return
	var to_rig := van_rig.global_transform.affine_inverse()
	for child in cables.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box: AABB = (to_rig * mi.global_transform) * mi.mesh.get_aabb()
		_add("cable_%s" % mi.name, box.grow(VanKitFootprint.CLEAR_M))


## A wall-side volume from a (wall z, y) poly, extruded from the liner to the Entry x.
func _add_side(vol_name: String, sign_x: float, poly: PackedVector2Array,
		pieces_only := false) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Vector2 in poly:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var x0 := VanKitFootprint.ENTRY_X
	var x1 := VanKitFootprint.WALL_X_OUT
	var x_min := x0 if sign_x > 0.0 else -x1
	var box := AABB(Vector3(x_min, lo.y, lo.x), Vector3(x1 - x0, hi.y - lo.y, hi.x - lo.x))
	_add(vol_name, box, poly, pieces_only)


func _donor_window(donors: VanDonorSet, id: StringName) -> Dictionary:
	if donors == null:
		return {}
	for entry: Dictionary in donors.windows:
		if entry[&"window_id"] == id and not (entry[&"opening"] as PackedVector2Array).is_empty():
			return entry
	return {}


func _cm_to_m(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in poly:
		out.append(p * 0.01)
	return out


func _grown(poly: PackedVector2Array, by: float) -> PackedVector2Array:
	var res := Geometry2D.offset_polygon(poly, by, Geometry2D.JOIN_MITER)
	return res[0] if not res.is_empty() else poly


## Boxes that only touch (zero overlap) do not block, so a piece flush on a volume is allowed.
func _flush(box: AABB, other: AABB) -> bool:
	var inter := box.intersection(other)
	return inter.size.x <= 0.0 or inter.size.y <= 0.0 or inter.size.z <= 0.0


## The box's (z, y) rectangle overlaps the poly.
func _poly_hit(poly: PackedVector2Array, aabb: AABB) -> bool:
	var rect := PackedVector2Array([
		Vector2(aabb.position.z, aabb.position.y), Vector2(aabb.end.z, aabb.position.y),
		Vector2(aabb.end.z, aabb.end.y), Vector2(aabb.position.z, aabb.end.y)])
	for hit: PackedVector2Array in Geometry2D.intersect_polygons(rect, poly):
		if absf(_area(hit)) > 1e-8:
			return true
	return false


func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i: int in range(poly.size()):
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5
