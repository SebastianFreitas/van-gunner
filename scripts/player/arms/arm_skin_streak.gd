class_name ArmSkinStreak
extends RefCounted
## GDScript port of the arm skin shader's dirt streak (hash21/noise21, `sk_streak` and the finger
## fade mix in `sk_dirt`, sk_fade 1), so `arms roots` can measure the palm-to-finger fade. Static only.


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


## Unfaded streak value at the vein frame value `x` (the shader's vein_data.xyz).
static func raw(x: Vector3) -> float:
	var wu := absf(x.y) / maxf(absf(x.y) + absf(x.z), 1e-4)
	var sn := wu * _noise21(x.x * 2.0, x.z * 64.0) \
			+ (1.0 - wu) * _noise21(x.x * 2.0 + 5.3, x.y * 64.0 + 8.1)
	return smoothstep(0.50, 0.80, sn)


## Faded streak at frame value `x` and per-vertex fade `g` (0 palm, 1 flat finger value, the
## streak at xyz 0).
static func streak(x: Vector3, g: float) -> float:
	return lerpf(raw(x), raw(Vector3.ZERO), g)
