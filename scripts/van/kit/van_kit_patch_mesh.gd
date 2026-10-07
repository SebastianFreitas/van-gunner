class_name VanKitPatchMesh
extends RefCounted
## Meshes of one cut patch: a slab of its outline plus raised plates for its features, one
## grime-shader node per tone. No collider (D7).

## Each raised plate stands this far above the one under it: telling features read from across
## the cabin (plan: patches 3..8 cm off the liner, faces >= 1.2 cm apart).
const RAISE := 0.025
## The base slab's thickness: its back face then clears the odd skin plates' 2.6 cm face by 1 cm.
const WALL_THICK := 0.033
## Each raised plate's back face sits this far further under the base's top, so no two faces share a plane.
const SPACE := 0.011
## On a leaf the skin panels top out at 2.2 cm; at its 7 cm floor the back face clears them by 1.2 cm.
const LEAF_THICK := 0.036
const BORDER_CM := 6.0
const LOZENGE_PITCH_CM := 20.0
const LOZENGE_HALF := Vector2(8.0, 3.5)
const HANDLE_TONE := Color(0.36, 0.36, 0.34)


## `xf` places the patch frame (cm) in the surface frame; `depth_m` is the slab's outer face
## off the liner and its thickness. Returns the nodes added under `parent`.
static func build(parent: Node3D, surface: StringName, def: VanPatchDef,
		res: VanKitPatchCut.Result, xf: Transform2D, depth_m: float, donor_paint: Color,
		rust: float, van_seed: int) -> Array[MeshInstance3D]:
	var field := def.field if def.field != Color(0, 0, 0) else donor_paint
	var tones: Array[Dictionary] = []
	var outline := res.outline
	if def.source == &"road_sign":
		tones.append(_tone(&"Trim", def.trim, [outline], 0))
		var inset := Geometry2D.offset_polygon(outline, -BORDER_CM)
		if not inset.is_empty():
			tones.append(_tone(&"Field", field, [inset[0]], 1))
		tones.append(_tone(&"Symbol", def.trim, _plates(res, &"symbol"), 2))
	else:
		tones.append(_tone(&"Base", field, [outline], 0))
	match def.source:
		&"car_door":
			tones.append(_tone(&"Recess", field * 0.35, _plates(res, &"recess"), 1))
			tones.append(_tone(&"Window", field * 0.5, _plates(res, &"window"), 1))
			tones.append(_tone(&"Handle", HANDLE_TONE, _handle_bars(res), 2))
		&"fridge_door":
			tones.append(_tone(&"Handle", HANDLE_TONE, _plates(res, &"handle"), 1))
		&"chequer_plate":
			tones.append(_tone(&"Lozenges", field * 1.3, _lozenges(outline), 1))
	var out: Array[MeshInstance3D] = []
	for tone in tones:
		var mesh := _merge(surface, tone, xf, depth_m)
		if mesh.get_surface_count() == 0:
			continue
		var mi := VanKitWindowsMesh.node(parent, "Patch" + String(tone.name), mesh)
		var color: Color = tone.color
		VanKitWindowsMesh.style(mi, color, color.darkened(0.3), rust,
				int(VanDonor.WallStyle.FLAT), 1.0, van_seed, def.id)
		out.append(mi)
	return out


static func _tone(tone_name: StringName, color: Color, polys: Array, level: int) -> Dictionary:
	return {&"name": tone_name, &"color": color, &"polys": polys, &"level": level}


## The source plates of `kind`, clipped to the outline; slivers under 9 cm² are dropped.
static func _plates(res: VanKitPatchCut.Result, kind: StringName) -> Array:
	var out: Array = []
	for i in res.plates.size():
		if res.plate_kinds[i] != kind:
			continue
		for part in Geometry2D.intersect_polygons(res.plates[i], res.outline):
			if absf(VanKitPatchCut._area(part)) > 9.0:
				out.append(part)
	return out


## The car door's handle: each recess plate shrunk to a bar standing in it.
static func _handle_bars(res: VanKitPatchCut.Result) -> Array:
	var out: Array = []
	for plate: PackedVector2Array in _plates(res, &"recess"):
		var bar := Geometry2D.offset_polygon(plate, -1.5)
		if not bar.is_empty():
			out.append(bar[0])
	return out


## Diamonds on a 0.20 m grid, alternately turned, that fit wholly inside the outline.
static func _lozenges(outline: PackedVector2Array) -> Array:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in outline:
		lo = lo.min(p)
		hi = hi.max(p)
	var out: Array = []
	var nx := int(floor((hi.x - lo.x) / LOZENGE_PITCH_CM))
	var ny := int(floor((hi.y - lo.y) / LOZENGE_PITCH_CM))
	for i in nx + 1:
		for j in ny + 1:
			var centre := lo + Vector2(i + 0.5, j + 0.5) * LOZENGE_PITCH_CM
			var turn := Transform2D(PI * 0.25 if (i + j) % 2 == 0 else -PI * 0.25, centre)
			var d := turn * _diamond()
			var inside := true
			for p in d:
				inside = inside and Geometry2D.is_point_in_polygon(p, outline)
			if inside:
				out.append(d)
	return out


static func _diamond() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-LOZENGE_HALF.x, 0.0), Vector2(0.0, -LOZENGE_HALF.y),
			Vector2(LOZENGE_HALF.x, 0.0), Vector2(0.0, LOZENGE_HALF.y)])


## One mesh of every poly of `tone`; the base slab reaches the liner, raised plates their own RAISE.
static func _merge(surface: StringName, tone: Dictionary, xf: Transform2D,
		depth_m: float) -> ArrayMesh:
	var level: int = tone.level
	var top := depth_m + level * RAISE
	# The base slab's back face stays off the liner: a face there would be coplanar with the skin
	# plates' and the leaf body's (audit flicker); the plates around hide the gap. A deeper,
	# overlapping patch's back face moves out with it, so no two share a plane.
	var base_thick := LEAF_THICK if VanKitSurface.is_leaf(surface) else WALL_THICK
	var thick := base_thick if level == 0 else (RAISE + SPACE) * level
	var merged := ArrayMesh.new()
	for poly: PackedVector2Array in tone.polys:
		var mesh := VanKitSurface.slab(surface, xf * poly, top, thick)
		if mesh.get_surface_count() > 0:
			merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(0))
	return merged
