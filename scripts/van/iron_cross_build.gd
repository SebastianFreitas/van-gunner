extends RefCounted
## Builds IronCross's scrap +: two bent rebar bars, a pipe sleeve, blobby welds, a seeded centre.

const IronCrossGeo := preload("res://scripts/van/iron_cross_geo.gd")

## A bar end's hammered-thin radius, so it fits the 2 cm gap behind the ring edge.
const HOOK_RADIUS := 0.008

var _o: Node3D
var _geo: IronCrossGeo
var _rng: RandomNumberGenerator
var _skin := false
var _frame := Vector2.ZERO
var _clear := Vector2.ZERO
var _mount_z := 0.0
var _skin_z := 0.0
var _skin_reach := Vector2.ZERO
var _back_z := 0.0
var _end_welds: Array = []


## `owner_cross` is the IronCross; its exports and constants are read through it, so this file
## never names the class (the core preloads this script).
func _init(owner_cross: Node3D) -> void:
	_o = owner_cross
	_skin = (_o.get(&"end_style") as int) == 1
	_frame = _o.get(&"frame_half") as Vector2
	_clear = _o.get(&"clear_half") as Vector2
	_mount_z = _o.get(&"mount_z") as float
	_skin_z = _o.get(&"skin_z") as float
	_skin_reach = _o.get(&"skin_reach") as Vector2
	_back_z = _const(&"BAR_BACK_Z") as float


func build(geo: IronCrossGeo, rng: RandomNumberGenerator, stage: int) -> void:
	_geo = geo
	_rng = rng
	_end_welds.clear()
	var radii: Array = _const(&"REBAR_RADII")
	var rib := _const(&"RIB_STEP") as float
	var pipe_r := _const(&"PIPE_RADIUS") as float
	var rebar := _mat(&"rebar_material")
	var i := rng.randi_range(0, 2)
	var rv := radii[i] as float
	var rh := radii[(i + 1 + rng.randi_range(0, 1)) % 3] as float
	var roll := rng.randf()
	var sleeve := 0 if roll < 0.4 else (1 if roll < 0.8 else 2)
	var flip := rng.randf() < 0.5
	var zv := _back_z + rv
	var zh := zv + rv + rh + 0.002
	var bv := _bar(true, rv, zv)
	var bh := _bar(false, rh, zh)
	geo.add_rod(_o, "VerticalBar", bv[0], bv[1], 6, rib, rebar)
	geo.add_rod(_o, "HorizontalBar", bh[0], bh[1], 6, rib, rebar)
	if sleeve != 2:
		# The sleeve stands 1.4 cm off its bar so their faces never read as coplanar.
		var sleeve_r := maxf(pipe_r, (rv if sleeve == 0 else rh) + 0.014)
		_sleeve(sleeve == 0, bv[2] if sleeve == 0 else bh[2], sleeve_r)
	_crossing(rv, rh, zv, zh, flip)
	var lost: Array = _const(&"STAGE_WELDS_LOST")
	_place_end_welds(lost[stage] as int)


func _const(key: StringName) -> Variant:
	return (_o.get_script() as Script).get_script_constant_map()[key]


func _mat(fn: StringName) -> Material:
	return _o.call(fn) as Material


func _pt(vert: bool, a: float, u: float, z: float) -> Vector3:
	return Vector3(u, a, z) if vert else Vector3(a, u, z)


## One bar: [path, radii, control points as (a, u, z)]; the ends follow the style.
func _bar(vert: bool, r: float, zc: float) -> Array:
	var c := _clear.y if vert else _clear.x
	var kink := [1, 3][_rng.randi_range(0, 1)] as int
	var ctrl: Array[Vector3] = []
	for k in 5:
		var u := 0.0
		var z := zc
		if k != 2:
			u = _rng.randf_range(-0.012, 0.012)
			z += _rng.randf_range(-0.004, 0.004)
		if k == kink:
			u += 0.02 * (1.0 if _rng.randf() < 0.5 else -1.0)
		ctrl.append(Vector3(c * (float(k) - 2.0) * 0.5, u, z))
	var lo := _end(vert, r, ctrl[0], -1.0)
	var hi := _end(vert, r, ctrl[4], 1.0)
	var pts := PackedVector3Array()
	var rads := PackedFloat32Array()
	for k in range(lo.size() - 1, -1, -1):
		var e := lo[k] as Vector4
		pts.append(_pt(vert, -e.x, e.y, e.z))
		rads.append(e.w)
	for p in ctrl:
		pts.append(_pt(vert, p.x, p.y, p.z))
		rads.append(r)
	for e in hi:
		pts.append(_pt(vert, (e as Vector4).x, (e as Vector4).y, (e as Vector4).z))
		rads.append((e as Vector4).w)
	return [pts, rads, ctrl]


## Points (a past the straight part as a magnitude, u, z, radius) from `last` out to the edge;
## also queues three end-weld blobs where the bar first touches the ring or lip.
func _end(vert: bool, r: float, last: Vector3, side: float) -> Array:
	var c := absf(last.x)
	var f := _frame.y if vert else _frame.x
	var u := last.y
	var reach := _skin_reach.y if vert else _skin_reach.x
	var ep := end_path(1 if _skin else 0, c, f, last.z, r, _mount_z, _skin_z, reach)
	var path := ep["points"] as PackedVector3Array
	var rads := ep["radii"] as PackedFloat32Array
	var out: Array = []
	for k in path.size():
		out.append(Vector4(path[k].y, u, path[k].z, rads[k]))
	for k in 3:
		var a := side * ((ep["touch"] as float) + _rng.randf_range(-0.015, 0.015))
		_end_welds.append([_pt(vert, a, u, ep["weld_z"] as float), Vector3(2.4 * r, 2.4 * r, 1.6 * r)])
	return out


## One bar end in a canonical frame: x = 0, running along +y from the clear edge outward.
## `along_clear` / `along_frame` / `skin_reach_along` are magnitudes along the bar, `z_bar` the bar's
## z at the clear edge. Also returns "touch" (where it first meets the ring or lip) and "weld_z".
static func end_path(
	end_style: int, along_clear: float, along_frame: float, z_bar: float, r: float,
	mount_z: float, skin_z: float, skin_reach_along: float
) -> Dictionary:
	var c := along_clear
	var f := along_frame
	var out: Array = []
	var touch := 0.0
	var wz := 0.0
	if end_style == 1:
		out = [
			Vector4(c + 0.03, 0.0, mount_z + r, r), Vector4(f + 0.004, 0.0, mount_z + r, r),
			Vector4(f + 0.02, 0.0, skin_z + r, r), Vector4(skin_reach_along - 0.03, 0.0, skin_z + r, r),
			Vector4(skin_reach_along, 0.0, skin_z + r, r * 0.7),
		]
		touch = c + 0.03
		wz = mount_z + 0.002
	else:
		var ring_z := mount_z + HOOK_RADIUS
		var dz := z_bar - ring_z
		out = [
			Vector4(c + 0.012, 0.0, z_bar - 0.35 * dz, r),
			Vector4(c + 0.025, 0.0, ring_z, HOOK_RADIUS),
			Vector4(f - 0.004, 0.0, ring_z, HOOK_RADIUS),
			Vector4(f + 0.006, 0.0, ring_z - 0.006, HOOK_RADIUS),
			Vector4(f + 0.009, 0.0, 0.012, HOOK_RADIUS),
		]
		touch = c + 0.025
		wz = mount_z + 0.003
	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	for e in out:
		var v := e as Vector4
		points.append(Vector3(0.0, v.x, v.z))
		radii.append(v.w)
	return {"points": points, "radii": radii, "touch": touch, "weld_z": wz}


## (u, z) of a bar at `a`, interpolated between its control points.
func _sample(ctrl: Array[Vector3], a: float) -> Vector2:
	for k in range(4):
		if a <= ctrl[k + 1].x or k == 3:
			var t := clampf(inverse_lerp(ctrl[k].x, ctrl[k + 1].x, a), 0.0, 1.0)
			return Vector2(lerpf(ctrl[k].y, ctrl[k + 1].y, t), lerpf(ctrl[k].z, ctrl[k + 1].z, t))
	return Vector2.ZERO


## A pipe over part of one bar, a hose clamp at each end and a weld joining it to the rebar.
func _sleeve(vert: bool, ctrl: Array[Vector3], pipe_r: float) -> void:
	var c := ctrl[4].x
	var length := minf(_rng.randf_range(0.35, 0.6) * 2.0 * c, c - 0.1)
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var near := _rng.randf_range(0.08, c - length - 0.02)
	var a0 := minf(side * near, side * (near + length))
	var a1 := maxf(side * near, side * (near + length))
	var avals: Array[float] = [a0]
	for p in ctrl:
		if p.x > a0 + 0.01 and p.x < a1 - 0.01:
			avals.append(p.x)
	avals.append(a1)
	var pts := PackedVector3Array()
	var rads := PackedFloat32Array()
	for a in avals:
		var s := _sample(ctrl, a)
		pts.append(_pt(vert, a, s.x, s.y))
		rads.append(pipe_r)
	var name_sfx := "V" if vert else "H"
	_geo.add_rod(_o, "Pipe" + name_sfx, pts, rads, 8, 0.0, _mat(&"pipe_material"))
	var axis := Vector3.UP if vert else Vector3.RIGHT
	var iron := _mat(&"iron_material")
	var weld := _mat(&"weld_material")
	var housing := Vector3(0.018, 0.012, 0.010) if vert else Vector3(0.012, 0.018, 0.010)
	for k in 2:
		var end_a := a0 if k == 0 else a1
		var clamp_a := end_a + (0.02 if k == 0 else -0.02)
		var s := _sample(ctrl, clamp_a)
		var centre := _pt(vert, clamp_a, s.x, s.y)
		var band := IronCrossGeo.ring_path(centre, axis, pipe_r + 0.002, 10)
		var band_r := PackedFloat32Array()
		band_r.resize(band.size())
		band_r.fill(0.003)
		_geo.add_rod(_o, "Clamp%s%d" % [name_sfx, k], band, band_r, 4, 0.0, iron, true)
		var at := Vector2(centre.x, centre.y)
		var back := maxf(s.y - (pipe_r + 0.002 + 0.003) - 0.004, 0.06)
		_geo.add_box(_o, "ClampScrew%s%d" % [name_sfx, k], housing, at, back, iron)
		var se := _sample(ctrl, end_a)
		var tip := _pt(vert, end_a, se.x, se.y)
		_geo.add_blob(
			_o, "PipeWeld%s%d" % [name_sfx, k], tip, Vector3(0.044, 0.044, 0.036), _rng, weld
		)


## A fillet weld bead round the joint, then two chains in an X with a padlock.
func _crossing(rv: float, rh: float, zv: float, zh: float, flip: bool) -> void:
	_fillet(rv, rh, zv, zh)
	_chain(rv, rh, zv, zh, flip)


## One lumpy bead in each corner of the +, on both faces.
func _fillet(rv: float, rh: float, zv: float, zh: float) -> void:
	var weld := _mat(&"weld_material")
	var rho := maxf(rv, rh) + 0.006
	var n := 0
	for z: float in [zh, zv]:
		for q in 4:
			for k in 3:
				var a := q * PI / 2.0 + 0.25 + (PI / 2.0 - 0.5) * float(k) * 0.5
				var at := Vector3(rho * cos(a), rho * sin(a), z)
				_geo.add_blob(_o, "Fillet%d" % n, at, Vector3(0.018, 0.018, 0.014), _rng, weld)
				n += 1


## A point on a squared-off loop in the plane of `d` and z, so wire hugs the bar faces.
func _loop_pt(d: Vector3, half_len: float, zc: float, hz: float, th: float) -> Vector3:
	var c := cos(th)
	var sn := sin(th)
	var z := zc + hz * signf(sn) * sqrt(absf(sn))
	return d * half_len * signf(c) * sqrt(absf(c)) + Vector3(0.0, 0.0, z)


## An oval wire ring in the plane of `long_dir` and `short_dir`.
func _oval(
	center: Vector3, long_dir: Vector3, short_dir: Vector3, a: float, b: float, steps: int
) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in steps:
		var th := TAU * float(i) / float(steps)
		out.append(center + long_dir * a * cos(th) + short_dir * b * sin(th))
	return out


## Two chain loops in an X round the joint, a padlock on the second and a loose end of links.
func _chain(rv: float, rh: float, zv: float, zh: float, flip: bool) -> void:
	var iron := _mat(&"iron_material")
	var nut := _mat(&"rivet_material")
	var a := 0.017
	var b := 0.0085
	var lw := 0.0045
	var steps := 48
	var spacing := 2.0 * a + 0.004
	var zb := maxf(zv - rv - 0.006, 0.058 + b + lw)
	var n := 0
	var first_low := Vector3.ZERO
	var lock_pt := Vector3.ZERO
	for k in 2:
		var d := Vector3(1.0, 1.0 if k == 0 else -1.0, 0.0).normalized()
		var dperp := Vector3(-d.y, d.x, 0.0)
		var zf := zh + rh + 0.006 + float(k) * 2.0 * (b + lw)
		var zc := (zf + zb) * 0.5
		var hz := (zf - zb) * 0.5
		var half_len := rv + rh + 0.02 + 0.012 * float(k)
		var pts := PackedVector3Array()
		for i in steps:
			pts.append(_loop_pt(d, half_len, zc, hz, TAU * float(i) / float(steps)))
		var next := 0.0 if k == 0 else spacing * 0.5
		var acc := 0.0
		var low := Vector3(0.0, INF, 0.0)
		var left := Vector3(INF, 0.0, 0.0)
		for i in steps:
			var p0 := pts[i]
			var p1 := pts[(i + 1) % steps]
			var seg := p0.distance_to(p1)
			if p0.z >= zc:
				if p0.y < low.y:
					low = p0
				if p0.x < left.x:
					left = p0
			while next <= acc + seg and seg > 0.0:
				var at := p0.lerp(p1, (next - acc) / seg)
				var tangent := (p1 - pts[(i + steps - 1) % steps]).normalized()
				var short := tangent.cross(dperp).normalized() if n % 2 == 0 else dperp
				var ring := _oval(at, tangent, short, a, b, 12)
				_geo.add_rod(_o, "ChainLink%d" % n, ring, _fill(12, lw), 6, 0.0, iron, true)
				n += 1
				next += spacing
			acc += seg
		if k == 0:
			first_low = low
		else:
			lock_pt = left if flip else low
	for k in 3:
		var at := first_low + Vector3(0.0, -2.0 * a * float(k + 1), 0.0)
		var short := Vector3.RIGHT if k % 2 == 0 else Vector3.BACK
		var ring := _oval(at, Vector3.UP, short, a, b, 12)
		_geo.add_rod(_o, "ChainLink%d" % n, ring, _fill(12, lw), 6, 0.0, iron, true)
		n += 1
	var arc := PackedVector3Array()
	var centre := lock_pt + Vector3(0.0, -0.011, 0.002)
	for k in 7:
		var th := -PI * float(k) / 6.0
		arc.append(centre + Vector3(0.011 * cos(th), 0.011 * sin(th), 0.0))
	_geo.add_rod(_o, "PadlockShackle", arc, _fill(7, lw), 6, 0.0, iron)
	var body := PackedVector3Array([
		Vector3(centre.x, centre.y - 0.03, centre.z - 0.008),
		Vector3(centre.x, centre.y - 0.03, centre.z + 0.010),
	])
	_geo.add_rod(_o, "PadlockBody", body, _fill(2, 0.017), 14, 0.0, nut)


## Shuffles the queued end welds and builds all but `lost` of them.
func _place_end_welds(lost: int) -> void:
	var order: Array[int] = []
	for k in _end_welds.size():
		order.append(k)
	for k in range(order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, k)
		var tmp := order[k]
		order[k] = order[j]
		order[j] = tmp
	var weld := _mat(&"weld_material")
	for n in range(lost, order.size()):
		var spec: Array = _end_welds[order[n]]
		_geo.add_blob(_o, "EndWeld%d" % order[n], spec[0] as Vector3, spec[1] as Vector3, _rng, weld)


func _fill(n: int, value: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(value)
	return out
