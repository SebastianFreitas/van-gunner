class_name GunBoonPieces
extends RefCounted
## The three railgun boon pieces (dynamite bundle, poison jar, cold coil). Builders take the socket,
## the gun's palm length p and an rng, and return a Node3D in Body space. Each stands on the gun
## face; its base may reach 1.5x the socket footprint and its height 2x the socket along the normal.


## Root with its base on the gun face under the socket (snapped sockets sit half their size above
## the face), local +Y along the socket normal and local Z along the gun. `upright` instead keeps
## local +Y on the gun's +Y with local Z toward the normal, and `depth` is how far the piece's
## axis stands off the face along the normal (a standing jar: its radius).
static func _root(socket: Marker3D, id: StringName, p: float, upright: bool = false,
		depth: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Boon_%s_0" % id
	var up: Vector3 = socket.get_meta(&"normal")
	var ref := Vector3.BACK if absf(up.z) < 0.9 else Vector3.RIGHT
	var z := (ref - up * up.dot(ref)).normalized()
	var half := (socket.get_meta(&"size") as Vector3)[up.abs().max_axis_index()] * 0.5
	var at := socket.position - up * (half + 0.025 * p - depth)
	if upright:
		var flat := absf(up.y) < 0.9
		z = up if flat else Vector3.BACK
		at = socket.position - up * (half + 0.025 * p - (depth if flat else 0.0))
		root.transform = Transform3D(Basis(Vector3.UP.cross(z), Vector3.UP, z), at)
	else:
		root.transform = Transform3D(Basis(up.cross(z), up, z), at)
	return root


static func _mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


## A cylinder along local Z (gun axis) when `dir` is BACK, else along `dir`.
static func _rod(root: Node3D, nm: String, r: float, h: float, mat: Material, at: Vector3,
		dir: Vector3 = Vector3.BACK) -> MeshInstance3D:
	return ArmParts.mesh(root, nm, ArmParts.cyl(r, h, r, 10), mat, at, ArmParts.along(dir))


static func explosive(socket: Marker3D, p: float, _rng: RandomNumberGenerator) -> Node3D:
	var root := _root(socket, &"explosive_rounds", p)
	var red := _mat(Color(0.55, 0.14, 0.10))
	var cream := _mat(Color(0.58, 0.53, 0.40))
	var r := 0.08 * p
	# Lies across the gun (local X), sticks side by side along Z; ends poke past the flanks.
	var slen := 0.60 * p
	var spots: Array[Vector3] = [Vector3(0.0, r, -r), Vector3(0.0, r, r),
			Vector3(0.0, r + 1.73 * r, 0.0)]
	for i in range(3):
		_rod(root, "Stick%d" % i, r, slen, red, spots[i], Vector3.RIGHT)
	var cy := 1.58 * r
	for i in range(2):
		var wx := (-0.15 + 0.30 * float(i)) * p
		_rod(root, "Tape%d" % i, 2.25 * r, 0.10 * p, cream, Vector3(wx, cy, 0.0), Vector3.RIGHT)
	# Fuse out of the +X end of the top stick: one stub out, then bent to the gun's up.
	var gup := root.transform.basis.inverse() * Vector3.UP
	var fx := slen * 0.5
	var top := Vector3(0.0, r + 1.73 * r, 0.0)
	_rod(root, "FuseA", 0.014 * p, 0.10 * p, cream, top + Vector3(fx + 0.05 * p, 0.0, 0.0),
			Vector3.RIGHT)
	_rod(root, "FuseB", 0.014 * p, 0.12 * p, cream,
			top + gup * 0.06 * p + Vector3(fx + 0.10 * p, 0.0, 0.0), gup)
	return root


static func poison(socket: Marker3D, p: float, rng: RandomNumberGenerator) -> Node3D:
	var r := 0.11 * p
	var root := _root(socket, &"poison_rounds", p, true, r)
	var glass := _mat(Color(0.75, 0.80, 0.78, 0.75), 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var liquid := _mat(Color(0.20, 0.60, 0.15))
	var cream := _mat(Color(0.58, 0.53, 0.40))
	var paper := _mat(Color(0.62, 0.58, 0.46))
	var h := 0.30 * p
	ArmParts.mesh(root, "Liquid", ArmParts.cyl(r * 0.92, h * 0.667, r * 0.92, 10), liquid,
			Vector3(0.0, h * 0.333 + 0.01 * p, 0.0))
	ArmParts.mesh(root, "Jar", ArmParts.cyl(r, h, r, 10), glass, Vector3(0.0, h * 0.5, 0.0))
	ArmParts.mesh(root, "Lid", ArmParts.cyl(r * 1.05, 0.05 * p, r * 1.05, 10),
			ArmMaterials.rail_steel(rng.randf_range(0.0, 100.0)), Vector3(0.0, h + 0.02 * p, 0.0))
	ArmParts.mesh(root, "Label", ArmParts.box(Vector3(0.14, 0.11, 0.012) * p), paper,
			Vector3(0.0, h * 0.55, r + 0.004 * p))
	_rod(root, "Strap", r * 1.06, 0.05 * p, cream, Vector3(0.0, h * 0.18, 0.0), Vector3.UP)
	return root


static func cold(socket: Marker3D, p: float, rng: RandomNumberGenerator) -> Node3D:
	var root := _root(socket, &"cold_rounds", p)
	var copper := _mat(Color(0.75, 0.42, 0.20))
	var rime := _mat(Color(0.70, 0.80, 0.90))
	var cream := _mat(Color(0.58, 0.53, 0.40))
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var r := 0.15 * p
	var cap := 0.04 * p
	var step := (0.50 * p - 2.0 * cap) / 6.0
	_rod(root, "Core", r * 0.62, 0.50 * p - cap, steel, Vector3(0.0, 0.25 * p, 0.0), Vector3.UP)
	for i in range(6):
		var tor := TorusMesh.new()
		tor.outer_radius = r
		tor.inner_radius = r - step * 1.05
		tor.rings = 10
		tor.ring_segments = 6
		ArmParts.mesh(root, "Winding%d" % i, tor, copper if i % 5 == 0 else rime,
				Vector3(0.0, cap + step * (float(i) + 0.5), 0.0))
	_rod(root, "CapLow", r * 1.05, cap, steel, Vector3(0.0, cap * 0.5, 0.0), Vector3.UP)
	_rod(root, "CapHigh", r * 1.05, cap, steel, Vector3(0.0, 0.50 * p - cap * 0.5, 0.0), Vector3.UP)
	_rod(root, "Tape", r * 1.12, 0.06 * p, cream, Vector3(0.0, 0.10 * p, 0.0), Vector3.UP)
	return root
