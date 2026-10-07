class_name RearWindowFit
extends RefCounted
## Refits both rear leaves to their rolled window holes.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const META := &"rear_fit_originals"
const MOVED: Array[String] = ["WindowFrame", "WindowGlass", "BreakableGlass", "IronCross",
	"BrokenIronCross"]
## Today's frame polygons, vertex for vertex with `WINDOW_HOLE`: a grown hole keeps their margins.
const OUTER_TODAY: Array[Vector2] = [
	Vector2(-0.86, -0.845), Vector2(-1, -0.76), Vector2(-1.04, -0.62), Vector2(-1.04, 0.62),
	Vector2(-1, 0.76), Vector2(-0.86, 0.845), Vector2(0.86, 0.845), Vector2(1, 0.76),
	Vector2(1.04, 0.62), Vector2(1.04, -0.62), Vector2(1, -0.76), Vector2(0.86, -0.845),
]
const INNER_TODAY: Array[Vector2] = [
	Vector2(-0.72, -0.705), Vector2(-0.85, -0.64), Vector2(-0.92, -0.52), Vector2(-0.92, 0.52),
	Vector2(-0.85, 0.64), Vector2(-0.72, 0.705), Vector2(0.72, 0.705), Vector2(0.85, 0.64),
	Vector2(0.92, 0.52), Vector2(0.92, -0.52), Vector2(0.85, -0.64), Vector2(0.72, -0.705),
]
const PANE_INSET_M := 0.05
const SHAPE_Y_TRIM_M := 0.01


## `entries_by_leaf`: `&"left"` / `&"right"` -> {hole_grow, glazing}; a missing leaf is a caller bug.
static func fit(doors: Node3D, entries_by_leaf: Dictionary) -> void:
	var left := doors.get_node_or_null("LeftHinge") as Node3D
	var right := doors.get_node_or_null("RightHinge") as Node3D
	if left == null or right == null:
		return
	var holes: Dictionary = {}
	for hinge: Node3D in [left, right]:
		var side: StringName = &"left" if hinge == left else &"right"
		_keep_originals(hinge)
		holes[side] = {}
		if entries_by_leaf.has(side):
			var grow := (entries_by_leaf[side] as Dictionary)[&"hole_grow"] as Vector3
			holes[side] = _LeafBuild.grown_hole(grow)
	_LeafBuild.build(doors, left, right, holes[&"left"], holes[&"right"])
	for hinge: Node3D in [left, right]:
		var side: StringName = &"left" if hinge == left else &"right"
		var entry: Dictionary = entries_by_leaf.get(side, {})
		_fit_leaf(hinge, -1.0 if hinge == right else 1.0, holes[side], entry)
	preload("res://scripts/van/rear_door_lighting.gd").apply(left, right)


static func _keep_originals(hinge: Node3D) -> void:
	if hinge.has_meta(META):
		return
	var orig: Dictionary = {}
	for part in MOVED:
		var node := hinge.get_node_or_null(part) as Node3D
		if node:
			orig[part + "/pos"] = node.position
	var glass := hinge.get_node_or_null("WindowGlass") as MeshInstance3D
	var col := hinge.get_node_or_null("BreakableGlass/Collision") as CollisionShape3D
	var cross := hinge.get_node_or_null("IronCross") as IronCross
	orig[&"mesh"] = glass.mesh
	orig[&"material"] = glass.material_override
	orig[&"shape"] = col.shape
	orig[&"cross"] = [cross.frame_half, cross.clear_half, cross.skin_reach]
	hinge.set_meta(META, orig)


static func _fit_leaf(hinge: Node3D, mirror: float, hole: Dictionary, entry: Dictionary) -> void:
	var orig: Dictionary = hinge.get_meta(META)
	var outer := hinge.get_node("WindowFrame/Outer") as CSGPolygon3D
	var inner := hinge.get_node("WindowFrame/InnerCut") as CSGPolygon3D
	var glass := hinge.get_node("WindowGlass") as MeshInstance3D
	var col := hinge.get_node("BreakableGlass/Collision") as CollisionShape3D
	var cross_fields: Array = orig[&"cross"]
	if hole.is_empty():
		push_error("RearWindowFit: empty hole")
		return
	var shift := hole[&"center"] as Vector2
	var poly := hole[&"poly"] as PackedVector2Array
	outer.polygon = _margin(poly, OUTER_TODAY, mirror)
	inner.polygon = _margin(poly, INNER_TODAY, mirror)
	var size := _size(poly)
	var pane := (orig[&"mesh"] as BoxMesh).duplicate() as BoxMesh
	pane.size = Vector3(size.x - 2.0 * PANE_INSET_M, size.y - 2.0 * PANE_INSET_M, pane.size.z)
	glass.mesh = pane
	var box := (orig[&"shape"] as BoxShape3D).duplicate() as BoxShape3D
	box.size = Vector3(pane.size.x, pane.size.y - SHAPE_Y_TRIM_M, box.size.z)
	col.shape = box
	glass.material_override = VanGlazing.material(
		orig[&"material"] as Material, entry.get(&"glazing", &"") as StringName)
	for part in MOVED:
		var node := hinge.get_node_or_null(part) as Node3D
		# A breach-made BrokenIronCross has no saved pose: it sits where the intact bars do.
		var key := "IronCross" if part == "BrokenIronCross" else part
		if node and orig.has(key + "/pos"):
			var base := orig[key + "/pos"] as Vector3
			node.position = base + Vector3(shift.x * mirror, shift.y, 0.0)
	var ratio := _size(poly) / _size(_LeafBuild.WINDOW_HOLE)
	for part in ["IronCross", "BrokenIronCross"]:
		var cross := hinge.get_node_or_null(part)
		if cross == null:
			continue
		cross.set(&"frame_half", cross_fields[0] * ratio)
		cross.set(&"clear_half", cross_fields[1] * ratio)
		cross.set(&"skin_reach", cross_fields[2] * ratio)
		# Free now, not queue_free, so the rebuilt bars keep their real names.
		for old in cross.get_children():
			cross.remove_child(old)
			old.free()
		cross.call(&"rebuild")


## `poly` plus today's margin at each vertex, x mirrored (and rewound) for the right leaf.
static func _margin(poly: PackedVector2Array, today: Array[Vector2], mirror: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var p := poly[i] + today[i] - _LeafBuild.WINDOW_HOLE[i]
		out.append(Vector2(p.x * mirror, p.y))
	if mirror < 0.0:
		out.reverse()
	return out


static func _size(poly: PackedVector2Array) -> Vector2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r.size
