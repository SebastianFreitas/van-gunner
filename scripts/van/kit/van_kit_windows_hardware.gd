class_name VanKitWindowsHardware
extends RefCounted
## The window pass's hardware: gasket and collar join bands, bolt heads and plexi washers.

const _RUBBER := Color(0.04, 0.04, 0.04)
const _STEEL := Color(0.17, 0.165, 0.155)
const _FACE_M := 0.076
## Collar and gasket band top: 1.2 cm over the ring face, so no two parallel faces sit within 1 cm.
const _LIP_M := 0.088
const _BASE_M := 0.026
const _HEAD_CM := 3.5
const _WASHER_CM := 4.0
const _WASHER_HEAD_CM := 3.0


## `hole` is the window's hole (cm) on its surface, passed in so a flat leaf can give a rear hole.
static func build(ctx: VanKitBuilder.Ctx, entry: Dictionary, outer: PackedVector2Array,
		hole: PackedVector2Array, parent: Node3D, rng: RandomNumberGenerator) -> void:
	var surface: StringName = entry[&"surface"]
	var def := VanKitWindows.def_of(entry)
	var heads: Array[Vector2] = []
	var head_cm := _HEAD_CM
	var band_o := PackedVector2Array()
	var band_i := PackedVector2Array()
	var id: StringName = entry[&"window_id"]
	if def.join == VanWindowAssetDef.Join.GASKET:
		var lip := Geometry2D.offset_polygon(hole, 1.5, Geometry2D.JOIN_MITER)
		if not lip.is_empty():
			band_o = lip[0]
			band_i = hole
			_band(parent, surface, band_o, band_i, _LIP_M, _RUBBER, id)
	elif def.join == VanWindowAssetDef.Join.WELDED_COLLAR:
		var inner := Geometry2D.offset_polygon(outer, -def.bead_width_m * 100.0,
			Geometry2D.JOIN_MITER)
		var shrunk := Geometry2D.offset_polygon(outer, -1.2, Geometry2D.JOIN_MITER)
		if not inner.is_empty() and not shrunk.is_empty():
			band_o = shrunk[0]
			band_i = inner[0]
			_band(parent, surface, band_o, band_i, _LIP_M, _STEEL, id)
	else:
		head_cm = 3.0
	var ob := VanKitSkin._bounds(outer)
	var hb := VanKitSkin._bounds(hole)
	var pitch := maxf(def.bolt_pitch_m, 0.20) * 100.0
	var rows: Array[Array] = [
		[Vector2(ob[0].x + 12.0, (hb[1].y + ob[1].y) * 0.5), Vector2(ob[1].x - 12.0, (hb[1].y + ob[1].y) * 0.5)],
		[Vector2(ob[0].x + 12.0, (hb[0].y + ob[0].y) * 0.5), Vector2(ob[1].x - 12.0, (hb[0].y + ob[0].y) * 0.5)],
		[Vector2((hb[0].x + ob[0].x) * 0.5, hb[0].y + 10.0), Vector2((hb[0].x + ob[0].x) * 0.5, hb[1].y - 10.0)],
		[Vector2((hb[1].x + ob[1].x) * 0.5, hb[0].y + 10.0), Vector2((hb[1].x + ob[1].x) * 0.5, hb[1].y - 10.0)]]
	for row in rows:
		var a: Vector2 = row[0]
		var b: Vector2 = row[1]
		var n := int(floorf(a.distance_to(b) / pitch))
		for i in n + 1:
			if n > 0 or i == 0:
				heads.append(a.lerp(b, float(i) / maxf(n, 1)))
	var st := SurfaceTool.new()
	for h in heads:
		# Heads keep off the join band grown 1 cm (and half a head, since h is a centre).
		if not _in_band(h, band_o, band_i, 1.0 + head_cm * 0.5):
			_box(st, surface, h, _FACE_M, head_cm, _BASE_M)
	_washers(st, entry, hole, rng, band_o, band_i, _FACE_M, 3.5)
	var mesh := st.commit()
	if mesh != null and mesh.get_surface_count() > 0:
		var mi := VanKitWindowsMesh.node(parent, "WindowBolts_" + String(entry[&"window_id"]), mesh)
		VanKitWindowsMesh.style(mi, _STEEL, Color(0.1, 0.09, 0.08), 0.5,
			int(VanDonor.WallStyle.FLAT), 0.0, ctx.van_seed, entry[&"window_id"])


## The rear piece's plexi washers on their own, on the lip `face_m` off the leaf, `ring_cm` out.
static func washers(ctx: VanKitBuilder.Ctx, entry: Dictionary, hole: PackedVector2Array,
		parent: Node3D, rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	_washers(st, entry, hole, rng, PackedVector2Array(), PackedVector2Array(),
		VanKitWindowsRear.WASHER_FACE_M, VanKitWindowsRear.WASHER_RING_CM)
	var mesh := st.commit()
	if mesh != null and mesh.get_surface_count() > 0:
		var mi := VanKitWindowsMesh.node(parent, "WindowBolts_" + String(entry[&"window_id"]), mesh)
		VanKitWindowsMesh.style(mi, _STEEL, Color(0.1, 0.09, 0.08), 0.5,
			int(VanDonor.WallStyle.FLAT), 0.0, ctx.van_seed, entry[&"window_id"])


static func _washers(st: SurfaceTool, entry: Dictionary, hole: PackedVector2Array,
		rng: RandomNumberGenerator, band_o: PackedVector2Array, band_i: PackedVector2Array,
		face_m: float, ring_cm: float) -> void:
	var surface: StringName = entry[&"surface"]
	if surface == &"rear":
		surface = VanKitWindowsRear.leaf_of(entry)
	if entry[&"glazing"] != &"plexi":
		return
	# Washers lap the hole edge on the cabin side; built here so they outlive a shattered pane.
	var ring := Geometry2D.offset_polygon(hole, ring_cm, Geometry2D.JOIN_MITER)
	if ring.is_empty():
		return
	var pts: PackedVector2Array = ring[0]
	var s := 0.0
	var at := rng.randf_range(0.0, 20.0)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var seg := a.distance_to(b)
		while at < s + seg:
			var q := a.lerp(b, (at - s) / maxf(seg, 0.001))
			if not _in_band(q, band_o, band_i, 1.0 + _WASHER_CM * 0.5):
				_box(st, surface, q, face_m, _WASHER_CM, _BASE_M)
				_box(st, surface, q, face_m + _BASE_M, _WASHER_HEAD_CM, _BASE_M)
			at += rng.randf_range(20.0, 25.0)
		s += seg


## A flat band between two polygons (cm): `outer` minus `inner`, 2.4 cm thick under `depth`, as
## one mesh.
static func _band(parent: Node3D, surface: StringName, outer: PackedVector2Array,
		inner: PackedVector2Array, depth: float, paint: Color, id: StringName) -> void:
	# clip_polygons returns a ring as its outline plus its hole, so tile it into strips instead.
	var parts := VanKitWindows.strips(outer, inner)
	VanKitWindowsMesh.ccw(parts)
	var mi := VanKitWindowsMesh.node(parent, "WindowJoin_" + String(id),
		VanKitWindowsMesh.ring(surface, parts, depth, [[parts, depth - 0.024]]))
	VanKitWindowsMesh.style(mi, paint, Color(0.05, 0.05, 0.05), 0.2, int(VanDonor.WallStyle.FLAT),
		0.0, 0, &"")


## Whether `p` lies in the band between `outer` and `inner` (cm) once the band is grown `grow` cm.
static func _in_band(p: Vector2, outer: PackedVector2Array, inner: PackedVector2Array,
		grow: float) -> bool:
	if outer.is_empty():
		return false
	var big := Geometry2D.offset_polygon(outer, grow, Geometry2D.JOIN_MITER)
	if big.is_empty() or not Geometry2D.is_point_in_polygon(p, big[0]):
		return false
	var small := Geometry2D.offset_polygon(inner, -grow, Geometry2D.JOIN_MITER)
	return small.is_empty() or not Geometry2D.is_point_in_polygon(p, small[0])


## A box `size_cm` square and `h_m` tall standing on the face at `depth_m`, added to `st`.
static func _box(st: SurfaceTool, surface: StringName, at_cm: Vector2, depth_m: float,
		size_cm: float, h_m: float) -> void:
	var n := VanKitSurface.normal(surface, at_cm.x, at_cm.y)
	var tangent := n.cross(Vector3.BACK).normalized()
	var basis := Basis(tangent, n, Vector3.BACK)
	if VanKitSurface.is_leaf(surface):
		basis = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	var box := BoxMesh.new()
	# Sunk 2 mm into what it stands on, so no face is coplanar with it.
	box.size = Vector3(size_cm * 0.01, h_m + 0.002, size_cm * 0.01)
	st.append_from(box, 0, Transform3D(basis,
		VanKitSurface.point(surface, at_cm.x, at_cm.y, depth_m + h_m * 0.5 - 0.001)))
