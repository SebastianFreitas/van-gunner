class_name VanKitWindowsMesh
extends RefCounted
## Builds the window pass's meshes: the ring strips as donor or bus paint, joins, bolts, washers.

const BUS_PAINT_PRIMER := Color(0.2, 0.19, 0.16)
## Where the skins run under the ring (VanKitSkin._holes): the ring back clears their faces by 1.2 cm.
const LAP_CM := 4.0
const LAP_BACK_M := 0.042
## Rabbet over the window stop (side_window_fit.gd, side_window_fixtures.gd): it reaches
## STOP_OUT_M - 0.02 past the hole and stands STOP_LIFT + STOP_THICKNESS off the liner; the rabbet
## band is 0.5 cm wider and its back face 0.5 cm deeper.
const RABBET_CM := (0.06 - 0.02 + 0.005) * 100.0
const RABBET_BACK_M := 0.015 + 0.008 + 0.005
const _MATERIAL: ShaderMaterial = preload("res://resources/van_kit/van_kit_grime_material.tres")


static func build(ctx: VanKitBuilder.Ctx, placed: Array[VanKitPlaced], parent: Node3D) -> void:
	var skins: Array[VanKitPlaced] = []
	for p in placed:
		if p.reason == VanKitWindows.REASON:
			skins.append(p)
	var by_window: Dictionary = {}
	for p in skins:
		var id: StringName = _nearest(ctx, p).get(&"window_id", &"")
		if not by_window.has(id):
			by_window[id] = []
		by_window[id].append(p)
	for id: StringName in by_window:
		var group: Array = by_window[id]
		var first: VanKitPlaced = group[0]
		var def := load("res://resources/van/kit/windows/%s.tres" % first.def_id) as VanWindowAssetDef
		# The inner edge has a rabbet over the window stop's band, so the ring clears the stop (D44).
		var fronts: Array[PackedVector2Array] = []
		var zones: Array = []
		for p: VanKitPlaced in group:
			fronts.append(p.outline)
			zones.append_array(_rabbet(ctx, p))
		var mi := node(parent, "Window_" + String(id),
			ring(first.surface, fronts, VanKitWindows.DEPTH, zones))
		var paint := def.paint
		var primer := BUS_PAINT_PRIMER
		var rust := 0.3
		var wall_style := int(VanDonor.WallStyle.FLAT)
		var pitch := 0.0
		for d in ctx.donors.donors:
			if def.use_region_paint and d.id == first.origin_id:
				paint = d.paint
				primer = d.primer
				rust = clampf(d.fade, 0.0, 1.0)
				wall_style = int(d.wall_style)
				pitch = clampf(d.rib_pitch_m, 0.0, 1.0)
		style(mi, paint, primer, rust, wall_style, pitch, ctx.van_seed, first.origin_id)
	var rng := ctx.rng(&"windows", &"hardware")
	for entry: Dictionary in ctx.donors.windows:
		var outer := VanKitWindows.ring_outline(entry)
		if entry[&"surface"] == &"rear" or outer.size() < 3:
			continue
		VanKitWindowsHardware.build(ctx, entry, outer,
			VanKitWindows.hole_cm(ctx.keep_out.walls, entry), parent, rng)


## The strip split into [polys, back depth] zones: over the skins' lap band, over the stop band
## (rabbet) and elsewhere; the whole strip when no window hole is near it.
static func _rabbet(ctx: VanKitBuilder.Ctx, p: VanKitPlaced) -> Array:
	var entry := _nearest(ctx, p)
	var best := PackedVector2Array()
	var best_outer := PackedVector2Array()
	if not entry.is_empty():
		best = VanKitWindows.hole_cm(ctx.keep_out.walls, entry)
		best_outer = VanKitWindows.ring_outline(entry)
	var grown := Geometry2D.offset_polygon(best, RABBET_CM, Geometry2D.JOIN_MITER)
	if grown.is_empty():
		return [[[p.outline], VanKitWindows.BACK_M]]
	var lap: Array[PackedVector2Array] = []
	var cores: Array[PackedVector2Array] = []
	var core_poly := Geometry2D.offset_polygon(best_outer, -LAP_CM, Geometry2D.JOIN_MITER)
	if core_poly.is_empty():
		lap.append(p.outline)
	else:
		lap.assign(ccw(Geometry2D.clip_polygons(p.outline, core_poly[0])))
		cores.assign(ccw(Geometry2D.intersect_polygons(p.outline, core_poly[0])))
	var shallow: Array[PackedVector2Array] = []
	var deep: Array[PackedVector2Array] = []
	for core in cores:
		shallow.append_array(ccw(Geometry2D.clip_polygons(core, grown[0])))
		deep.append_array(ccw(Geometry2D.intersect_polygons(core, grown[0])))
	return [[lap, LAP_BACK_M], [shallow, VanKitWindows.BACK_M], [deep, RABBET_BACK_M]]


static func ccw(polys: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	for i in polys.size():
		if Geometry2D.is_polygon_clockwise(polys[i]):
			var flipped := polys[i]
			flipped.reverse()
			polys[i] = flipped
	return polys


## The window entry on the strip's surface whose hole is nearest to it; empty when none.
static func _nearest(ctx: VanKitBuilder.Ctx, p: VanKitPlaced) -> Dictionary:
	var pb := VanKitSkin._bounds(p.outline)
	var best := {}
	var best_d := INF
	for entry: Dictionary in ctx.donors.windows:
		if entry[&"surface"] != p.surface:
			continue
		var hb := VanKitSkin._bounds(VanKitWindows.hole_cm(ctx.keep_out.walls, entry))
		var d := ((hb[0] + hb[1]) * 0.5).distance_to((pb[0] + pb[1]) * 0.5)
		if d < best_d:
			best_d = d
			best = entry
	return best


## One mesh for a whole ring of `fronts` (ccw cm polygons that tile it): the front at `depth`, the
## backs of `zones` ([polys, back depth] pairs) and side walls on the ring's outer and inner edges
## only. Every polygon is cut at the same y lines, so neighbours share their vertices and no strip
## folds over another on the curved wall.
static func ring(surface: StringName, fronts: Array[PackedVector2Array], depth: float,
		zones: Array) -> ArrayMesh:
	ccw(fronts)
	var ys := _cuts(surface, fronts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for poly in _cut(fronts, ys):
		_faces(st, surface, poly, depth, 1.0)
	var back := INF
	for zone: Array in zones:
		var polys: Array[PackedVector2Array] = []
		polys.assign(zone[0])
		for poly in _cut(polys, ys):
			_faces(st, surface, poly, float(zone[1]), -1.0)
		back = minf(back, float(zone[1]))
	for seg in _boundary(fronts, ys):
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var mid := (a + b) * 0.5
		var out2 := Vector2((b - a).y, -(b - a).x).normalized()
		var depth_back := back
		for zone: Array in zones:
			for poly: PackedVector2Array in zone[0]:
				if Geometry2D.is_point_in_polygon(mid - out2 * 0.3, poly):
					depth_back = float(zone[1])
		var out3 := (VanKitSurface.point(surface, mid.x + out2.x * 0.1, mid.y + out2.y * 0.1, depth)
				- VanKitSurface.point(surface, mid.x, mid.y, depth)).normalized()
		var v: Array[Vector3] = [VanKitSurface.point(surface, a.x, a.y, depth),
			VanKitSurface.point(surface, b.x, b.y, depth),
			VanKitSurface.point(surface, b.x, b.y, depth_back),
			VanKitSurface.point(surface, a.x, a.y, depth_back)]
		VanKitSurface._quad(st, v, [a, b, b, a], out3)
	var mesh := ArrayMesh.new()
	if st.get_primitive_type() == Mesh.PRIMITIVE_TRIANGLES:
		st.commit(mesh)
	return mesh


## The y lines (cm) every polygon of the ring is cut at: bands of STRIP across the bend; empty on
## the flat surfaces.
static func _cuts(surface: StringName, polys: Array[PackedVector2Array]) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if surface != VanKitSurface.LEFT_WALL and surface != VanKitSurface.RIGHT_WALL \
			and surface != VanKitSurface.CEILING:
		return out
	var lo := INF
	var hi := -INF
	for poly in polys:
		for p in poly:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
	var n := maxi(1, ceili((hi - lo) / (VanKitSurface.STRIP * 100.0)))
	for i in n + 1:
		out.append(lo + (hi - lo) * i / n)
	return out


static func _cut(polys: Array[PackedVector2Array], ys: PackedFloat32Array
		) -> Array[PackedVector2Array]:
	if ys.is_empty():
		return polys
	var out: Array[PackedVector2Array] = []
	for poly in polys:
		var b := VanKitSkin._bounds(poly)
		for i in ys.size() - 1:
			if ys[i + 1] <= b[0].y or ys[i] >= b[1].y:
				continue
			var rect := PackedVector2Array([Vector2(b[0].x - 1.0, ys[i]),
				Vector2(b[1].x + 1.0, ys[i]), Vector2(b[1].x + 1.0, ys[i + 1]),
				Vector2(b[0].x - 1.0, ys[i + 1])])
			for part in Geometry2D.intersect_polygons(poly, rect):
				if part.size() >= 3:
					out.append(part)
	return ccw(out)


static func _faces(st: SurfaceTool, surface: StringName, poly: PackedVector2Array,
		depth: float, side: float) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	for i in range(0, tris.size(), 3):
		var uv: Array = [poly[tris[i]], poly[tris[i + 1]], poly[tris[i + 2]]]
		var at: Vector2 = uv[0]
		VanKitSurface._tri(st, surface, uv, depth, VanKitSurface.normal(surface, at.x, at.y) * side)


## The ring's outer and inner edge segments [a, b]: each strip edge minus the parts another strip
## shares, split at the cut lines.
static func _boundary(polys: Array[PackedVector2Array], ys: PackedFloat32Array) -> Array:
	var out: Array = []
	for s in polys.size():
		var poly := polys[s]
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			var d := b - a
			var len2 := d.length_squared()
			if len2 < 1e-6:
				continue
			var covered: Array[Vector2] = []
			for t in polys.size():
				if t == s:
					continue
				var other := polys[t]
				for j in other.size():
					var q0 := other[j]
					var q1 := other[(j + 1) % other.size()]
					if (q1 - q0).dot(d) >= 0.0:
						continue
					if absf(d.cross(q0 - a)) > 0.02 * sqrt(len2) \
							or absf(d.cross(q1 - a)) > 0.02 * sqrt(len2):
						continue
					var t0 := (q0 - a).dot(d) / len2
					var t1 := (q1 - a).dot(d) / len2
					covered.append(Vector2(minf(t0, t1), maxf(t0, t1)))
			covered.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.x < y.x)
			var cursor := 0.0
			var free: Array[Vector2] = []
			for c in covered:
				if c.x > cursor:
					free.append(Vector2(cursor, minf(c.x, 1.0)))
				cursor = maxf(cursor, c.y)
			if cursor < 1.0:
				free.append(Vector2(cursor, 1.0))
			for f in free:
				if (f.y - f.x) * sqrt(len2) > 0.05:
					_split(out, a + d * f.x, a + d * f.y, ys)
	return out


## Appends [a, b] to `out`, cut wherever it crosses one of the y lines.
static func _split(out: Array, a: Vector2, b: Vector2, ys: PackedFloat32Array) -> void:
	var ts: Array[float] = [0.0, 1.0]
	for y in ys:
		if (a.y < y and b.y > y) or (a.y > y and b.y < y):
			ts.append((y - a.y) / (b.y - a.y))
	ts.sort()
	for k in ts.size() - 1:
		if ts[k + 1] - ts[k] > 1e-4:
			out.append([a.lerp(b, ts[k]), a.lerp(b, ts[k + 1])])


static func node(parent: Node3D, node_name: String, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = _MATERIAL
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	parent.add_child(mi)
	return mi


static func style(mi: MeshInstance3D, paint: Color, primer: Color, rust: float, wall_style: int,
		pitch: float, van_seed: int, id: StringName, era: int = -1) -> void:
	style_height(mi)
	mi.set_instance_shader_parameter(&"fastener_era", era)
	mi.set_instance_shader_parameter(&"paint", paint)
	mi.set_instance_shader_parameter(&"primer", primer)
	mi.set_instance_shader_parameter(&"rust_amount", rust)
	mi.set_instance_shader_parameter(&"grime_amount", 0.6)
	mi.set_instance_shader_parameter(&"wall_style", wall_style)
	mi.set_instance_shader_parameter(&"rib_pitch_m", pitch)
	mi.set_instance_shader_parameter(&"seed", float(van_seed % 997) + float(hash(id) % 97))


## Sets `up_obj` (van up in the mesh's own frame), `y_base_m` (van-local y of the mesh origin)
## and `top_y_m` (the piece top in van-local y) for the kit shader, taking the kit root at the
## van origin. Pieces under a rear-door hinge add the hinge's transform.
static func style_height(mi: MeshInstance3D) -> void:
	var xf := mi.transform
	var hinge := mi.get_parent() as Node3D
	if hinge != null and String(hinge.name).ends_with("Hinge"):
		xf = hinge.transform * xf
	var box := mi.mesh.get_aabb()
	var top := -INF
	for c in 8:
		top = maxf(top, (xf * box.get_endpoint(c)).y)
	mi.set_instance_shader_parameter(&"up_obj",
		Vector3(xf.basis.x.y, xf.basis.y.y, xf.basis.z.y))
	mi.set_instance_shader_parameter(&"y_base_m", xf.origin.y)
	mi.set_instance_shader_parameter(&"top_y_m", top)
