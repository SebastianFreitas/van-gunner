extends RefCounted
## Streak meter for `arms roots`: ports the arm skin shader's hash21/noise21 and sk_dirt's `sn` and `streak` lines (sk_fade 1) to measure how the finger roots' flat CUSTOM0 value changes the dirt streaks.

const FADE_T := 0.30


## Scalar maths in doubles: a Vector2 dot rounds to float32 and scrambles the hash.
static func _hash21(x: float, y: float) -> float:
	return fposmod(sin(x * 127.1 + y * 311.7) * 43758.5453, 1.0)


static func _noise21(px: float, py: float) -> float:
	var ix := floorf(px)
	var iy := floorf(py)
	var fx := px - ix
	var fy := py - iy
	var a := _hash21(ix, iy)
	var b := _hash21(ix + 1.0, iy)
	var c := _hash21(ix, iy + 1.0)
	var d := _hash21(ix + 1.0, iy + 1.0)
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy)


## Streak value at the vein frame value `x` (the shader's vein_data.xyz), sk_fade 1.
static func streak(x: Vector3) -> float:
	var wu := absf(x.y) / maxf(absf(x.y) + absf(x.z), 1e-4)
	var sn := wu * _noise21(x.x * 2.0, x.z * 64.0) \
			+ (1.0 - wu) * _noise21(x.x * 2.0 + 5.3, x.y * 64.0 + 8.1)
	return smoothstep(0.50, 0.80, sn)


## Meter text for one finger: `c_f` and `t_c` from the build, `ids` its tube vertices,
## `tv`/`tc` the tube positions and CUSTOM0 (4 floats a vertex), `hd`/`d` the root bone.
static func line(c_f: Vector3, t_c: float, ids: PackedInt32Array, tv: PackedVector3Array,
		tc: PackedFloat32Array, hd: Vector3, d: Vector3) -> String:
	var s0 := streak(Vector3.ZERO)
	var sf := streak(c_f)
	var sweep := 0.0
	for i in ids:
		var t := (tv[i] - hd).dot(d) / maxf(d.length_squared(), 1e-12)
		if t < t_c or t > t_c + FADE_T:
			continue
		sweep = maxf(sweep, maxf(absf(tc[i * 4 + 1] - c_f.y), absf(tc[i * 4 + 2] - c_f.z)) * 64.0)
	var ok := absf(sf - s0) <= 0.1 and sweep <= 1.0
	return "  streak S0 %.2f S_f %.2f |dS| %.2f sweep %.2f%s" % [
			s0, sf, absf(sf - s0), sweep, "" if ok else " FAIL"]
