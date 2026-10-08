extends RefCounted
## Four welded diagonal braces across the chamfered corners of a rear door window's bars.

const IronCrossGeo := preload("res://scripts/van/iron_cross_geo.gd")

## Brace ends (Vector4 = ax, ay, bx, by) in the left leaf's frame (x toward the centre seam), each
## 9-10 cm past the hole edge so they sit on the steel. The right leaf mirrors x. (A const typed
## Array[PackedVector2Array] of literals silently loads as zeros, so Vector4.)
const BRACES: Array[Vector4] = [
	Vector4(-1.09, 0.38, -0.56, 0.875),
	Vector4(-1.09, -0.38, -0.56, -0.875),
	Vector4(1.09, 0.38, 0.56, 0.875),
	Vector4(1.09, -0.10, 0.40, -0.875),
]
const RADIUS := 0.014
## Along the brace from each end: flat on the skin up to RAMP_FLAT, off the glass by RAMP_LIFT.
const RAMP_FLAT := 0.08
const RAMP_LIFT := 0.14

var _o: Node3D
var _geo: IronCrossGeo
var _rng: RandomNumberGenerator


func _init(owner_cross: Node3D, geo: IronCrossGeo, rng: RandomNumberGenerator) -> void:
	_o = owner_cross
	_geo = geo
	_rng = rng


## `bar_back_z` is the z the main bars start from; the braces' middle runs there, clear of the glass.
func build(bar_back_z: float, skin_z: float, rebar: Material, weld: Material) -> void:
	# The 180 degree turn about Y flips local x, so undo it to keep the chamfer brace on the seam side.
	var mirror := (-1.0 if _o.position.x < 0.0 else 1.0) * signf(_o.transform.basis.x.x)
	var posts := (_o.get(&"standoff") as float) > 0.0
	var zg := bar_back_z + RADIUS
	var z0 := skin_z + RADIUS
	for n in BRACES.size():
		var zn := zg + 0.012 * (n % 2)
		var a := Vector2(BRACES[n].x, BRACES[n].y)
		var b := Vector2(BRACES[n].z, BRACES[n].w)
		a += Vector2(_rng.randf_range(-0.01, 0.01), _rng.randf_range(-0.01, 0.01))
		b += Vector2(_rng.randf_range(-0.01, 0.01), _rng.randf_range(-0.01, 0.01))
		a.x *= mirror
		b.x *= mirror
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		var kink := Vector2(-dir.y, dir.x) * _rng.randf_range(-0.012, 0.012)
		var pts := PackedVector3Array()
		var rads := PackedFloat32Array()
		for s: float in [0.0, RAMP_FLAT, RAMP_LIFT, length * 0.5, length - RAMP_LIFT,
				length - RAMP_FLAT, length]:
			var p := a + dir * s
			if s == length * 0.5:
				p += kink
			var on_steel := s <= RAMP_FLAT or s >= length - RAMP_FLAT
			pts.append(Vector3(p.x, p.y, z0 if on_steel else zn))
			rads.append(RADIUS)
		_geo.add_rod(_o, "CornerBrace%d" % n, pts, rads, 6, 0.0, rebar)
		for end in 2:
			var at := a + dir * RAMP_FLAT if end == 0 else b - dir * RAMP_FLAT
			for k in 2:
				var off := Vector2(_rng.randf_range(-0.012, 0.012), _rng.randf_range(-0.012, 0.012))
				var wp := at + off
				_geo.add_blob(_o, "BraceWeld%d_%d_%d" % [n, end, k],
						Vector3(wp.x, wp.y, skin_z + 0.004), Vector3(0.05, 0.05, 0.03), _rng, weld)
			if posts:
				_geo.add_blob(_o, "BracePost%d_%d" % [n, end], Vector3(at.x, at.y, z0 * 0.5),
						Vector3(0.045, 0.045, z0), _rng, weld)
