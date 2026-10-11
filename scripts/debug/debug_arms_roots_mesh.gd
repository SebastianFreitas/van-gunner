extends RefCounted
## Arm-mesh half of `arms roots`: merged surface arrays and the mask-step and edge-extent meters.

const FINGER_BONES := [&"DEF-f_index.01", &"DEF-f_middle.01", &"DEF-f_ring.01", &"DEF-f_pinky.01"]

var v := PackedVector3Array()
var idx := PackedInt32Array()
var c0 := PackedFloat32Array()
var nrm := PackedVector3Array()
var bones := PackedInt32Array()
var wts := PackedFloat32Array()
var per := 4
var names := PackedStringArray()


## The arm mesh's mask steps and edge extents.
func arm(vf: Dictionary, heads: Dictionary, c_t: Vector3, r_t: float) -> String:
	var up: Vector3 = heads[&"DEF-upper_arm"]
	var x_w: float = (Vector3(heads[&"DEF-hand"]) - up).dot(vf[&"axis"])
	var x_e: float = (Vector3(heads[&"DEF-forearm"]) - up).dot(vf[&"axis"])
	var big_l := -x_w
	for n in FINGER_BONES:
		big_l += (Vector3(heads.get(n, up)) - up).dot(vf[&"axis"]) / FINGER_BONES.size()
	var e_t := 0.0
	var step := {&"thumb": 0.0, &"hand": 0.0, &"elbow": 0.0, &"rest": 0.0}
	var pair := {}
	var e_h := 0.0
	var e_e := 0.0
	var w_far := 0.0
	var xs := PackedFloat32Array()
	for p in v:
		xs.append(ArmMuscle.frame_xyz(vf, p).x)
	for i in v.size():
		if xs[i] > x_w + 0.65 * big_l:
			w_far = maxf(w_far, c0[i * 4 + 3])
	for t in int(idx.size() / 3.0):
		for e in 3:
			var a := idx[t * 3 + e]
			var b := idx[t * 3 + (e + 1) % 3]
			if maxf(v[a].distance_to(c_t), v[b].distance_to(c_t)) <= 3.0 * r_t:
				e_t = maxf(e_t, v[a].distance_to(v[b]))
	for t in int(idx.size() / 3.0):
		for e in 3:
			var a := idx[t * 3 + e]
			var b := idx[t * 3 + (e + 1) % 3]
			var ext := absf(xs[a] - xs[b])
			var near_t := maxf(v[a].distance_to(c_t), v[b].distance_to(c_t))
			var near_e := maxf(absf(xs[a] - x_e), absf(xs[b] - x_e)) <= 0.25 * x_e
			var groups: Array[StringName] = []
			if near_t <= r_t + maxf(2.0 * r_t, 6.0 * e_t):
				groups.append(&"thumb")
			if minf(xs[a], xs[b]) > x_w:
				groups.append(&"hand")
				e_h = maxf(e_h, ext)
			if near_e:
				groups.append(&"elbow")
				e_e = maxf(e_e, ext)
			if groups.is_empty():
				groups.append(&"rest")
			var ds := absf(c0[a * 4 + 3] - c0[b * 4 + 3])
			for grp in groups:
				if ds > float(step[grp]) or not pair.has(grp):
					step[grp] = maxf(ds, float(step[grp]))
					pair[grp] = "%s/%s" % [_dom(a), _dom(b)]
	var out := "\n arm mesh: L %.4f x_w %.4f x_e %.4f Lu %.4f, w past x_w+0.65L %.2f" % [
			big_l, x_w, x_e, x_e, w_far]
	out += "\n  c_t %s r_t %.4f e_t %.4f; e_h %.3f e_e %.3f" % [
			c_t, r_t, e_t, e_h / maxf(big_l, 1e-6), e_e / maxf(x_e, 1e-6)]
	for g: StringName in step:
		out += "\n  max w step %s %.2f (%s)" % [g, step[g], pair.get(g, "-")]
	return out


func load_arm(mesh: Mesh) -> void:
	v = PackedVector3Array()
	idx = PackedInt32Array()
	c0 = PackedFloat32Array()
	nrm = PackedVector3Array()
	bones = PackedInt32Array()
	wts = PackedFloat32Array()
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var base := v.size()
		for i: int in a[Mesh.ARRAY_INDEX]:
			idx.append(base + i)
		v.append_array(a[Mesh.ARRAY_VERTEX])
		nrm.append_array(a[Mesh.ARRAY_NORMAL])
		c0.append_array(a[Mesh.ARRAY_CUSTOM0])
		bones.append_array(a[Mesh.ARRAY_BONES])
		wts.append_array(a[Mesh.ARRAY_WEIGHTS])
	per = int(float(bones.size()) / maxf(v.size(), 1.0))


## Name of the bone with the largest weight at vertex i.
func _dom(i: int) -> String:
	var best := 0
	for k in per:
		if wts[i * per + k] > wts[i * per + best]:
			best = k
	return names[bones[i * per + best]]


## At bind-space point p (on the arm skin): x the interpolated CUSTOM0 w, y the dot of the
## triangle normal `n` with the interpolated stored vertex normal (positive: n points outward).
func interp(p: Vector3, n: Vector3) -> Vector2:
	var best := INF
	var out := Vector2.ZERO
	for t in int(idx.size() / 3.0):
		var ia := idx[t * 3]
		var ib := idx[t * 3 + 1]
		var ic := idx[t * 3 + 2]
		var a := v[ia]
		var e1 := v[ib] - a
		var e2 := v[ic] - a
		var rel := p - a
		var d11 := e1.dot(e1)
		var d12 := e1.dot(e2)
		var d22 := e2.dot(e2)
		var den := d11 * d22 - d12 * d12
		if absf(den) < 1e-12:
			continue
		var bu := (d22 * rel.dot(e1) - d12 * rel.dot(e2)) / den
		var bv := (d11 * rel.dot(e2) - d12 * rel.dot(e1)) / den
		var off := maxf(maxf(-bu, -bv), bu + bv - 1.0)
		var score := maxf(off, 0.0) * 1000.0 + absf(rel.dot(e1.cross(e2).normalized()))
		if score < best:
			best = score
			var wa := 1.0 - bu - bv
			out.x = wa * c0[ia * 4 + 3] + bu * c0[ib * 4 + 3] + bv * c0[ic * 4 + 3]
			out.y = n.dot(wa * nrm[ia] + bu * nrm[ib] + bv * nrm[ic])
	return out
