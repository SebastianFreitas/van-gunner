class_name DebugArmsHandsRows
extends RefCounted
## The finger rows and the hand growth (slab widths) of the `arms hands` bar, split from
## `debug_arms_hands.gd` to keep both files under the line cap.
const _FINGERS: Array[StringName] = [&"f_index", &"f_middle", &"f_ring", &"f_pinky"]
var _mesh := DebugArmsHandsMesh.new()
## Per hand and finger: `r_ratio` scales r1 against the middle finger, `r21` and `r31` are r2/r1 and
## r3/r1 (all three one measurement of the pre-phase-5 mesh, D93: phase 5 leaves mid-bone radii alone;
## the r_ratio gate is +-0.02, the r2/r1 and r3/r1 bands `_R21_BAND` and `_R31_BAND` wide), `tip_off` is the tip pole's
## lateral offset (m), `knob` the joint swell as a fraction of the shaft radius it sits on.
const _DIGITS := {
	&"R": {
		&"f_index": {&"r_ratio": 0.8446, &"r21": 0.7833, &"r31": 0.5436, &"tip_off": -0.0020207, &"knob": 1.22},
		&"f_middle": {&"r_ratio": 1.0, &"r21": 0.7814, &"r31": 0.555, &"tip_off": -0.0163481, &"knob": 1.24},
		&"f_ring": {&"r_ratio": 0.8299, &"r21": 0.7707, &"r31": 0.5191, &"tip_off": 0.0080549, &"knob": 1.26},
		&"f_pinky": {&"r_ratio": 0.7266, &"r21": 0.783, &"r31": 0.5129, &"tip_off": 0.0019330, &"knob": 1.28},
	},
	&"L": {
		&"f_index": {&"r_ratio": 0.8446, &"r21": 0.7833, &"r31": 0.5436, &"tip_off": -0.0205900, &"knob": 1.22},
		&"f_middle": {&"r_ratio": 1.0, &"r21": 0.7814, &"r31": 0.555, &"tip_off": -0.0066347, &"knob": 1.24},
		&"f_ring": {&"r_ratio": 0.8299, &"r21": 0.7707, &"r31": 0.5191, &"tip_off": -0.0109400, &"knob": 1.26},
		&"f_pinky": {&"r_ratio": 0.7266, &"r21": 0.783, &"r31": 0.5129, &"tip_off": 0.0092982, &"knob": 1.28},
	},
}
## Knots over the four fingers of a hand (+-20 percent): phase 1's R total, 9+11+13+13. A finger's
## own count is hash noise, so only the sum is checked.
const _R21_BAND := 0.065
const _R31_BAND := 0.05
const _KNOTS_TOTAL := 46.0
## Phase 5's targets (D26) over one measurement of the pre-phase-5 mesh (`_TODAY`: `knuckle` the
## rise over the middle shaft, `k2`/`k3` the joint swell over the bone's mid radius, as measured by
## `DebugArmsHandsMesh`). Target = today x `_KNUCKLE_K`, and today x (1 + g/4) with g from
## `_GROWTH` (at `.02`, `.03`); every band is +-`_BAND`.
const _BAND := 0.02
const _KNUCKLE_K := {&"f_index": 1.10, &"f_middle": 1.08, &"f_ring": 1.06, &"f_pinky": 1.09}
const _GROWTH := {
	&"f_index": [0.04, 0.06], &"f_middle": [0.06, 0.03],
	&"f_ring": [0.03, 0.05], &"f_pinky": [0.05, 0.02],
}
const _TODAY := {
	&"R": {
		&"f_index": {&"knuckle": 1.34, &"k2": 1.329, &"k3": 1.572},
		&"f_middle": {&"knuckle": 1.19, &"k2": 1.414, &"k3": 1.494},
		&"f_ring": {&"knuckle": 1.14, &"k2": 1.373, &"k3": 1.578},
		&"f_pinky": {&"knuckle": 1.25, &"k2": 1.378, &"k3": 1.605},
	},
	&"L": {
		&"f_index": {&"knuckle": 1.34, &"k2": 1.329, &"k3": 1.572},
		&"f_middle": {&"knuckle": 1.19, &"k2": 1.414, &"k3": 1.494},
		&"f_ring": {&"knuckle": 1.14, &"k2": 1.373, &"k3": 1.578},
		&"f_pinky": {&"knuckle": 1.25, &"k2": 1.378, &"k3": 1.605},
	},
}
## A vertex is hand-weighted for `shape` when hand and palm weights are at least this share of
## its total. The old largest-weight pick sat on a three-way tie (forearm, palm.01, thumb.01 near
## 0.34 each) at the thumb side of slab 0, so which side counted it hung on how finely the vein
## relief had cut that arm's mesh (R has far more vertices there than L), not on the weights.
const HAND_SHARE := 0.30
## The web's rise over the finger roots (`over`, m). Webs read at the start of phase 5 (D94; the
## old bake's 0 was another definition); L index-middle uses R's start value (D97); the three pairs
## the blended knuckle lift raises (R index-middle, R ring-pinky, L ring-pinky) take its readings
## after the D98 rework (D100). Still a regression gate for later steps: webs must not ride higher.
const _WEB_OVER := {
	&"R": {&"f_index-f_middle": 0.01243, &"f_ring-f_pinky": 0.01131},
	&"L": {&"f_index-f_middle": 0.01182, &"f_ring-f_pinky": 0.01149},
}
## The index side's knuckle-row width W8 (m) and its band.
const _INDEX_W8 := 0.088
const _INDEX_W8_TOL := 0.002
## Pinky-side bars: largest step over the mean step on slabs 0..7, and W7 over the earlier slabs.
const _PINKY_JUMP := 1.7
const _PINKY_PEAK := 0.002


## {text, ok}: per finger the r1 ratio, tip pole offset, claw length and knot count against
## `_DIGITS`, and the finger length over the middle's (reported only).
func rows(fingers: Dictionary, h: String, meas: Dictionary) -> Dictionary:
	if meas.is_empty():
		return {&"text": "\nhands %s: finger mesh missing" % h, &"ok": false}
	var digits: Dictionary = _DIGITS[StringName(h)]
	var today: Dictionary = _TODAY[StringName(h)]
	var rises: PackedFloat32Array = meas[&"rises"]
	var mid: Dictionary = fingers[&"f_middle"]
	var text := ""
	var ok := true
	var knots_sum := 0
	for f: StringName in _FINGERS:
		var info: Dictionary = fingers[f]
		var d: Dictionary = digits[f]
		var t: Dictionary = today[f]
		var m: Dictionary = meas[f]
		var r1 := float(m["r1"]) / maxf(float(meas[&"f_middle"]["r1"]), 0.0001)
		var off := float(info[&"tip_off"])
		var tip_len := float(info[&"tip_len"])
		var horn := ArmRig.horn_length(info, false, ArmsBuilder.CLAW_K) + 0.16 * tip_len
		var claw := horn / maxf(tip_len, 0.0001)
		var len_r := float(info[&"length"]) / maxf(float(mid[&"length"]), 0.0001)
		var s1 := maxf(float(m["r1"]), 0.0001)
		var r2 := float(m["r2"])
		var r3 := float(m["r3"])
		var r2_r1 := r2 / s1
		var r3_r1 := r3 / s1
		var k2_r2 := float(m["k2"]) / maxf(r2, 0.0001)
		var k3_r3 := float(m["k3"]) / maxf(r3, 0.0001)
		var k2_r1 := float(m["k2"]) / s1
		var knob := float(d[&"knob"])
		var g: Array = _GROWTH[f]
		var t2 := float(t["k2"]) * (1.0 + float(g[0]) / 4.0)
		var t3 := float(t["k3"]) * (1.0 + float(g[1]) / 4.0)
		var row_ok := absf(r1 - float(d[&"r_ratio"])) <= 0.02 \
				and absf(off - float(d[&"tip_off"])) <= 0.002 and claw >= 0.88 - 0.0001
		var knob_ok := absf(r2_r1 - float(d[&"r21"])) <= _R21_BAND 				and absf(r3_r1 - float(d[&"r31"])) <= _R31_BAND \
				and absf(k2_r2 - t2) <= _BAND and absf(k3_r3 - t3) <= _BAND
		knots_sum += int(info[&"knots"])
		var tris := (int(info[&"rings"]) - 1) * ArmFingerInfo.SECTORS * 2 + ArmFingerInfo.SECTORS \
				+ (8 if float(info.get(&"web", -1.0)) >= 0.0 else 0)
		var fi := _FINGERS.find(f)
		var knuckle := rises[fi] / maxf(float(mid[&"shaft"]), 0.0001) if fi >= 0 and fi < rises.size() else -1.0
		var t_knuckle := float(t["knuckle"]) * float(_KNUCKLE_K[f])
		var knuckle_ok := absf(knuckle - t_knuckle) <= _BAND
		ok = ok and row_ok and knob_ok and knuckle_ok
		text += "\nhands %s %s: r1 %.4f (%.4f) tip_off %.5f (%.5f) len x%.2f claw_len %.2f knots %d%s" \
				% [h, f, r1, d[&"r_ratio"], off, d[&"tip_off"], len_r, claw, info[&"knots"],
				"" if row_ok else " ROW CHECK"]
		text += "\nhands %s %s: tris %d" % [h, f, tris]
		text += ("\nhands %s %s: r2/r1 %.4f (%.4f±%.3f) r3/r1 %.4f (%.4f±%.3f) knob %.2f"
				+ " k2/r2 %.3f (%.3f±%.2f, was %.3f) k3/r3 %.3f (%.3f±%.2f, was %.3f)"
				+ " k2/r1 %.2f%s") % [h, f, r2_r1, d[&"r21"], _R21_BAND, r3_r1, d[&"r31"], _R31_BAND, knob, k2_r2, t2, _BAND, t["k2"],
				k3_r3, t3, _BAND, t["k3"], k2_r1, "" if knob_ok else " ROW CHECK"]
		text += "\nhands %s %s: knuckle %.2f (%.2f±%.2f, was %.2f)%s" \
				% [h, f, knuckle, t_knuckle, _BAND, t["knuckle"], "" if knuckle_ok else " ROW CHECK"]
	var knots_ok := absf(float(knots_sum) - _KNOTS_TOTAL) <= 0.2 * _KNOTS_TOTAL
	text += "\nhands %s: knots total %d (%d, +-20%%)%s" \
			% [h, knots_sum, int(_KNOTS_TOTAL), "" if knots_ok else " ROW CHECK"]
	var web_ok := true
	var webs: Array = meas[&"webs"]
	for i in _FINGERS.size() - 1:
		var info: Dictionary = fingers[_FINGERS[i]]
		var gap1: PackedFloat32Array = webs[i][&"gap"]
		var old: PackedFloat32Array = info.get(&"gap1", PackedFloat32Array([0.0, 0.0, 0.0]))
		var pair := "%s-%s" % [_FINGERS[i], _FINGERS[i + 1]]
		text += "\nhands %s %s: gap1 %.4f %.4f %.4f (t .00 .14 .30; was %.4f %.4f %.4f)" \
				% [h, pair, gap1[0], gap1[1], gap1[2], old[0], old[1], old[2]]
		if float(info.get(&"web", -1.0)) < 0.0:
			text += "\nhands %s %s: web none (gap1 .30 <= 0)" % [h, pair]
			continue
		var over := maxf(float(webs[i][&"over"]), 0.0)
		var was: float = _WEB_OVER[h].get(pair, 0.0)
		var over_ok := over <= maxf(0.0001 * float(info[&"shaft"]), was) + 0.0002
		web_ok = web_ok and over_ok
		text += "\nhands %s %s: web top t %.2f over %.5f (was %.5f, res %.5f)%s" \
				% [h, pair, info[&"web"], over, was, float(info[&"web_over"]),
				"" if over_ok else " ROW CHECK"]
	return {&"text": text, &"ok": ok and knots_ok and web_ok}



## {text, ok}: how the hand grows out of the wrist, in bind space with `wrist`'s frame.
## Hand verts (hand + palm weight share, thumb out) fall in nine slabs
## s = k/8 * L along head -> middle root (L = finger-root centre along it), +-L/16 thick. `growth`
## prints each slab's W_k (area-weighted 95th percentile of |lateral|, W0..8), `mono` (no W_k under
## 0.99 of the last) and `jump` (largest step over the mean step, a straight ramp reads 1.0), both
## on slabs 0..7 only (the knuckle row may taper, D59), then the same W0..8 per side (index side,
## pinky side = the lat side of the pinky root). Gated per side: the pinky side's W rises slab by
## slab over 0..7, its jump is at most `_PINKY_JUMP` and W7 tops W0..6 by `_PINKY_PEAK`; the index
## side's W8 sits within `_INDEX_W8_TOL` of `_INDEX_W8`. `dome` and `palm_depth` are slab 4's
## largest dorsal and palmar offsets from the axis line over W_4 (dorsal = UP less its axis part).
func shape(mi: MeshInstance3D, h: String) -> Dictionary:
	var skin := mi.skin
	var bind_o := {}
	for b in skin.get_bind_count():
		bind_o[String(skin.get_bind_name(b))] = skin.get_bind_pose(b).affine_inverse().origin
	var roots: Array[Vector3] = []
	for f: StringName in _FINGERS:
		var fname := "DEF-%s.01.%s" % [f, h]
		if not bind_o.has(fname):
			return {&"text": "\nhands %s: shape bone missing" % h, &"ok": true}
		roots.append(bind_o[fname])
	var seam: Dictionary = mi.get_meta(&"wrist_seam", {})
	if seam.is_empty():
		return {&"text": "\nhands %s: shape bone missing" % h, &"ok": true}
	var head: Vector3 = seam["hand_head"]
	var axis2 := (roots[1] - head).normalized()
	var centre := (roots[0] + roots[1] + roots[2] + roots[3]) * 0.25
	var span := (centre - head).dot(axis2)
	var lat := (roots[3] - roots[0])
	lat = (lat - axis2 * lat.dot(axis2)).normalized()
	var pinky_sign := signf((roots[3] - head).dot(lat))
	var dorsal := (Vector3.UP - axis2 * Vector3.UP.dot(axis2)).normalized()
	var kind: Array[bool] = []
	for b in skin.get_bind_count():
		var name := String(skin.get_bind_name(b))
		kind.append(name == "DEF-hand." + h or name.begins_with("DEF-palm"))
	# Index 0 all, 1 index side, 2 pinky side.
	var slab_l: Array[Array] = [[], [], []]
	var slab_a: Array[Array] = [[], [], []]
	for side in 3:
		for k in 9:
			slab_l[side].append(PackedFloat32Array())
			slab_a[side].append(PackedFloat32Array())
	var up_max := -INF
	var down_max := -INF
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var stride := int(bones.size() / float(maxi(verts.size(), 1)))
		var area := _mesh.vertex_area(arrays)
		for v in verts.size():
			var wsum := 0.0
			var hand_w := 0.0
			for k in stride:
				wsum += weights[v * stride + k]
				if kind[bones[v * stride + k]]:
					hand_w += weights[v * stride + k]
			if wsum <= 0.0 or hand_w < HAND_SHARE * wsum:
				continue
			var d := verts[v] - head
			var ax := d.dot(axis2)
			var k := roundi(ax / span * 8.0)
			if k < 0 or k > 8 or absf(ax - float(k) / 8.0 * span) > span / 16.0:
				continue
			var dl := d.dot(lat)
			var side := 2 if signf(dl) == pinky_sign else 1
			for t: int in [0, side]:
				var sl: PackedFloat32Array = slab_l[t][k]
				var sa: PackedFloat32Array = slab_a[t][k]
				sl.append(absf(dl))
				sa.append(area[v])
				slab_l[t][k] = sl
				slab_a[t][k] = sa
			if k == 4:
				var dor := (d - axis2 * ax).dot(dorsal)
				up_max = maxf(up_max, dor)
				down_max = maxf(down_max, -dor)
	var ws: Array[Array] = [[], [], []]
	for side in 3:
		for k in 9:
			ws[side].append(_mesh.p95(slab_l[side][k], slab_a[side][k]))
	var text := ""
	var w: Array = ws[0]
	var mono := true
	var jump := _mesh.jump(w)
	var wtext := ""
	for k in 9:
		wtext += " %.3f" % w[k]
		if k > 0 and k <= 7:
			mono = mono and w[k] >= 0.99 * w[k - 1]
	text += "\nhands %s: growth W0..8%s mono %s jump %.2f" % [h, wtext, str(mono).to_lower(), jump]
	var ix: Array = ws[1]
	var pk: Array = ws[2]
	var ix_ok := absf(float(ix[8]) - _INDEX_W8) <= _INDEX_W8_TOL
	text += "\nhands %s: growth index W0..8%s (W8 %.3f, %.3f +-%.3f)%s" \
			% [h, _mesh.fmt(ix), ix[8], _INDEX_W8, _INDEX_W8_TOL, "" if ix_ok else " ROW CHECK W8 off"]
	var pk_mono := true
	var pk_peak := -INF
	for k in 8:
		if k > 0:
			pk_mono = pk_mono and pk[k] >= pk[k - 1]
		if k < 7:
			pk_peak = maxf(pk_peak, pk[k])
	var pk_jump := _mesh.jump(pk)
	var pk_over: float = pk[7] - pk_peak
	var why := ""
	if not pk_mono:
		why += " not monotone"
	if pk_jump > _PINKY_JUMP:
		why += " jump over %.1f" % _PINKY_JUMP
	if pk_over < _PINKY_PEAK:
		why += " W7 under peak+%.3f" % _PINKY_PEAK
	text += "\nhands %s: growth pinky W0..8%s mono %s jump %.2f W7-max %.3f%s" \
			% [h, _mesh.fmt(pk), str(pk_mono).to_lower(), pk_jump, pk_over,
			"" if why.is_empty() else " ROW CHECK" + why]
	var w4 := maxf(w[4], 0.0001)
	text += "\nhands %s: dome %.3f palm_depth %.3f" % [h, up_max / w4, down_max / w4]
	return {&"text": text, &"ok": ix_ok and why.is_empty()}
