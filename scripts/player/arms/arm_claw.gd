class_name ArmClaw
extends RefCounted
## Claw-nail mesh: a rounded plate sunk into the top of the fingertip that grows past the tip into a tapered point curving slightly toward the pad.

## Half-angle (from the dorsal line) the nail wraps around the finger.
const ARC := deg_to_rad(70.0)
const ARC_SEGS := 12
## Sections on the finger (the nail bed) and past its tip (the free claw).
const BED_RINGS := 9
const FREE_RINGS := 12
## Share of the tip bone (t) where the bed starts and where the free claw leaves the finger.
const BED_FROM := 0.40
const BED_TO := 0.90
## Inner face scale: 3 % inside the skin, so there is never a gap between nail and finger.
const SINK := 0.97
## Plate thickness as a share of the finger's half size.
const THICK := 0.14


## `rings` are `ArmFingers.build`'s tip rings ({t, centre, half_w, half_h}, centre x lateral, y
## along the bone, z dorsal). Origin and axes are those of the rings; `reach` is how far the
## point clears the finger's pole and `curve_deg` how far it hooks toward the pad (-Z).
static func mesh(rings: Array, reach: float, curve_deg: float) -> ArrayMesh:
	var first: Dictionary = rings[0]
	var last: Dictionary = rings[rings.size() - 1]
	var span := float(last[&"t"]) - float(first[&"t"])
	var tip_len := 0.0
	if span > 0.0:
		var dy: float = (last[&"centre"] as Vector3).y - (first[&"centre"] as Vector3).y
		tip_len = dy / span
	# Sections: {c, hw, hh, k_out, k_in}.
	var secs: Array[Dictionary] = []
	for i in BED_RINGS:
		var t := lerpf(BED_FROM, BED_TO, float(i) / float(BED_RINGS - 1))
		var r := _lerp_ring(rings, t)
		var s := minf(float(i), 1.0)
		secs.append({&"c": r[&"centre"], &"hw": r[&"half_w"], &"hh": r[&"half_h"],
				&"k_out": SINK + THICK * s, &"k_in": SINK})
	var c0: Vector3 = secs[secs.size() - 1][&"c"]
	var w0: float = secs[secs.size() - 1][&"hw"]
	var h0: float = secs[secs.size() - 1][&"hh"]
	var th := deg_to_rad(curve_deg)
	var len_free := reach + (1.06 - BED_TO) * tip_len
	var p1 := c0 + Vector3(0.0, 0.6 * len_free, 0.0)
	var p2 := c0 + Vector3(0.0, len_free * cos(th), -len_free * sin(th))
	for i in range(1, FREE_RINGS):
		var s := float(i) / float(FREE_RINGS)
		var f := pow(1.0 - s, 0.7)
		var c := (1.0 - s) * (1.0 - s) * c0 + 2.0 * (1.0 - s) * s * p1 + s * s * p2
		secs.append({&"c": c, &"hw": w0 * f, &"hh": h0 * f, &"k_out": SINK + THICK,
				&"k_in": lerpf(SINK, 0.45, smoothstep(0.0, 0.5, s))})
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outs: Array[PackedVector3Array] = []
	var ins: Array[PackedVector3Array] = []
	for sec in secs:
		outs.append(_arc(sec, float(sec[&"k_out"])))
		ins.append(_arc(sec, float(sec[&"k_in"])))
	# Godot front faces are clockwise seen from outside: a section's arc runs from -X toward +X
	# over the dorsal line and sections step toward the tip, so outer quads are (A, D, B) and
	# inner quads the reverse (A, B, D); edge strips at +ARC and -ARC wind opposite to each other.
	for i in secs.size() - 1:
		for s in ARC_SEGS:
			var a := outs[i][s]
			var b := outs[i][s + 1]
			var c := outs[i + 1][s + 1]
			var d := outs[i + 1][s]
			_tris(st, 0, [a, d, b, b, d, c])
			a = ins[i][s]
			b = ins[i][s + 1]
			c = ins[i + 1][s + 1]
			d = ins[i + 1][s]
			_tris(st, 1, [a, b, d, b, c, d])
		var oa := outs[i]
		var ob := outs[i + 1]
		var ia := ins[i]
		var ib := ins[i + 1]
		_tris(st, -1, [oa[ARC_SEGS], ob[ARC_SEGS], ia[ARC_SEGS],
				ia[ARC_SEGS], ob[ARC_SEGS], ib[ARC_SEGS]])
		_tris(st, -1, [oa[0], ia[0], ob[0], ia[0], ib[0], ob[0]])
	var lo := outs[outs.size() - 1]
	var li := ins[ins.size() - 1]
	for s in ARC_SEGS:
		_tris(st, 0, [lo[s], p2, lo[s + 1]])
		_tris(st, 1, [li[s], li[s + 1], p2])
	_tris(st, -1, [lo[ARC_SEGS], p2, li[ARC_SEGS]])
	_tris(st, -1, [lo[0], li[0], p2])
	st.generate_normals()
	return st.commit()


## Ring at tip parameter `t`, interpolated between the two rings around it (clamped at the ends).
static func _lerp_ring(rings: Array, t: float) -> Dictionary:
	var first: Dictionary = rings[0]
	if t <= float(first[&"t"]):
		return first
	for i in range(1, rings.size()):
		var b: Dictionary = rings[i]
		if t <= float(b[&"t"]):
			var a: Dictionary = rings[i - 1]
			var span := float(b[&"t"]) - float(a[&"t"])
			var u := 0.0 if span <= 0.0 else (t - float(a[&"t"])) / span
			return {
				&"t": t,
				&"centre": (a[&"centre"] as Vector3).lerp(b[&"centre"], u),
				&"half_w": lerpf(float(a[&"half_w"]), float(b[&"half_w"]), u),
				&"half_h": lerpf(float(a[&"half_h"]), float(b[&"half_h"]), u),
			}
	return rings[rings.size() - 1]


## The `ARC_SEGS + 1` points of one section's arc at scale `k`.
static func _arc(sec: Dictionary, k: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var c: Vector3 = sec[&"c"]
	var hw: float = sec[&"hw"]
	var hh: float = sec[&"hh"]
	for s in ARC_SEGS + 1:
		var a := lerpf(-ARC, ARC, float(s) / float(ARC_SEGS))
		pts.append(c + Vector3(sin(a) * hw * k, 0.0, cos(a) * hh * k))
	return pts


## Adds the vertices of `verts` (a triangle list) in smooth group `group` (-1 is flat).
static func _tris(st: SurfaceTool, group: int, verts: Array) -> void:
	st.set_smooth_group(group)
	for v: Vector3 in verts:
		st.add_vertex(v)
