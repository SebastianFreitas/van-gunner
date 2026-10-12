class_name RailgunReceiver
extends RefCounted
## The railgun's boxy panelled receiver (top panels, vents, breech channel, flank plates, ribs, bolts) and its stock with the charge window.

const D := preload("res://scripts/player/arms/railgun_barrel_detail.gd")
const HW := 0.22


## Builds the receiver and stock under `body` (gun space, -Z forward). Units are palm lengths `p`,
## y above the guard top `ya`. Shape never reads `rng`; only the materials do.
static func build(body: Node3D, p: float, rng: RandomNumberGenerator, _zf: float,
		ya: float) -> void:
	var rust := ArmMaterials.rust(rng.randf_range(0.0, 100.0))
	var steel := ArmMaterials.steel(rng.randf_range(0.0, 100.0))
	var paint := ArmMaterials.gun_paint(rng.randf_range(0.0, 100.0))
	var dark := ArmMaterials.surface(Color(0.02, 0.018, 0.016), Color(0.015, 0.015, 0.015),
			Color(0.02, 0.02, 0.02), 60.0, 6.0, 0.0, 0.6, 0.9, 0.0, 0.0)
	D.section(body, "Receiver", HW * p, 0.545 * p, 0.32 * p, -1.28 * p, ya + 0.405 * p, rust, p)
	_panels(body, p, ya, rust)
	_vents(body, p, ya, dark, steel)
	_box(body, "BreechFloor", dark, Vector3(0.30, 0.017, 0.47), Vector3(0.0, 0.9535, 0.085), p, ya)
	ArmParts.limb(body, "SlugRod", Vector3(0.0, ya + 0.97 * p, -0.10 * p),
			Vector3(0.0, ya + 0.97 * p, 0.30 * p), 0.018 * p, 0.018 * p, steel, 8)
	_flanks(body, p, ya, dark, paint, steel)
	_bolts(body, p, ya, steel)
	_stock(body, p, ya, rust, steel)
	_wear(body, p, ya, rust)


## Soot, rust and a tape band painted by the shader on the receiver and stock (they share `rust`),
## as soft ragged masks the player view reads as burn, corrosion and cloth (D42). Positions are in
## body space; each mesh passes its own position as `wear_origin`. The boxes are unrotated except
## the four tiny corner bars, which keep an offset of at most 0.05p. Shape never reads rng.
static func _wear(body: Node3D, p: float, ya: float, rust: ShaderMaterial) -> void:
	var spots := PackedVector4Array([
			Vector4(-0.20 * p, ya + 0.72 * p, 0.56 * p, 0.20 * p),
			Vector4(-0.20 * p, ya + 0.30 * p, 0.50 * p, 0.15 * p),
			Vector4(-0.22 * p, ya + 0.52 * p, -0.05 * p, 0.10 * p),
			Vector4(0.0, 0.0, 0.0, 0.0),
			Vector4(-0.22 * p, ya + 0.62 * p, 0.22 * p, 0.24 * p),
			Vector4(-0.22 * p, ya + 0.36 * p, 0.12 * p, 0.2 * p)])
	var info := PackedVector4Array([Vector4(0.0, 0.0, 0.0, 0.0), Vector4(1.0, 0.0, 0.0, 0.0),
			Vector4(1.0, 0.0, 0.0, 0.0), Vector4(2.0, 0.86 * p, 1.08 * p, 0.0),
			Vector4(1.0, 0.0, 0.0, 0.0), Vector4(1.0, 0.0, 0.0, 0.0)])
	rust.set_shader_parameter(&"specular_value", 0.15)
	ArmMaterials.with_wear(rust, spots, info)
	for c: Node in body.get_children():
		var mi := c as MeshInstance3D
		if mi != null and mi.material_override == rust:
			mi.set_instance_shader_parameter(&"wear_origin", mi.position)


## A box of size `s` centred at `c` (both in p, y above `ya`).
static func _box(body: Node3D, node_name: String, mat: Material, s: Vector3, c: Vector3,
		p: float, ya: float) -> void:
	ArmParts.mesh(body, node_name, ArmParts.box(s * p), mat, Vector3(c.x * p, ya + c.y * p, c.z * p))


## The seven top panels, y ya+0.935..1.05: [name, x0, x1, z0, z1] in p.
static func _panels(body: Node3D, p: float, ya: float, rust: Material) -> void:
	var rows := [["TopFront", -HW, HW, -1.28, -1.00], ["VentMid", -0.06, 0.06, -1.00, -0.60],
			["VentEdgeL", -HW, -0.20, -1.00, -0.60], ["VentEdgeR", 0.20, HW, -1.00, -0.60],
			["TopMid", -HW, HW, -0.60, -0.15], ["TopRearL", -HW, -0.15, -0.15, 0.32],
			["TopRearR", 0.15, HW, -0.15, 0.32]]
	for r: Array in rows:
		var x0: float = r[1]
		var x1: float = r[2]
		var z0: float = r[3]
		var z1: float = r[4]
		_box(body, r[0] as String, rust, Vector3(x1 - x0, 0.115, z1 - z0),
				Vector3((x0 + x1) * 0.5, 0.9925, (z0 + z1) * 0.5), p, ya)


## Both vent openings: a dark floor and three steel slats each.
static func _vents(body: Node3D, p: float, ya: float, dark: Material, steel: Material) -> void:
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		_box(body, "VentFloor" + tag, dark, Vector3(0.14, 0.075, 0.40),
				Vector3(side * 0.13, 0.9725, -0.80), p, ya)
		for k: int in range(3):
			_box(body, "VentSlat%s%d" % [tag, k], steel, Vector3(0.14, 0.012, 0.03),
					Vector3(side * 0.13, 1.02, -0.90 + 0.10 * k), p, ya)


## Flank plates, pits, ribs and slots.
static func _flanks(body: Node3D, p: float, ya: float, dark: Material, paint: Material,
		steel: Material) -> void:
	# Left plate: face at x -0.232, sunk 0.01 into the flank, corners cut 45 degrees by 0.06.
	var c := 0.06
	var z0 := -1.20
	var z1 := -0.65
	var y0 := 0.15
	var y1 := 0.65
	var poly: Array[Vector2] = [Vector2(z0 + c, y0), Vector2(z1 - c, y0), Vector2(z1, y0 + c),
			Vector2(z1, y1 - c), Vector2(z1 - c, y1), Vector2(z0 + c, y1), Vector2(z0, y1 - c),
			Vector2(z0, y0 + c)]
	ArmParts.mesh(body, "FlankPlateL", prism(poly, -0.232, -0.21, p, ya), dark, Vector3.ZERO)
	# Right donor plate: face at x +0.228, two pits 0.002 proud of it.
	_box(body, "FlankPlateR", paint, Vector3(0.018, 0.40, 0.55), Vector3(0.219, 0.40, -0.825),
			p, ya)
	for k: int in range(2):
		ArmParts.mesh(body, "PlatePit%d" % k, ArmParts.cyl(0.015 * p, 0.004 * p, 0.015 * p, 8),
				dark, Vector3(0.228 * p, ya + (0.23 + 0.34 * k) * p, -1.07 * p),
				ArmParts.along(Vector3.RIGHT))
	var ribs := [["RibL0", -1.0, -0.65, -0.25], ["RibL1", -1.0, -0.15, 0.20],
			["RibR0", 1.0, -0.50, 0.20]]
	for r: Array in ribs:
		var s: float = r[1]
		var za: float = r[2]
		var zb: float = r[3]
		_box(body, r[0] as String, steel, Vector3(0.02, 0.02, zb - za),
				Vector3(s * HW, 0.345, (za + zb) * 0.5), p, ya)
	# Slots straddle the top chamfer: 0.01 proud of the flank line, sunk behind the chamfer.
	for side: float in [-1.0, 1.0]:
		for k: int in range(2):
			_box(body, "RecSlot%s%d" % ["L" if side < 0.0 else "R", k], dark,
					Vector3(0.03, 0.04, 0.12), Vector3(side * 0.215, 0.92, -1.20 + 0.40 * k),
					p, ya)


## The ten hex bolt heads (axis along x), in the order the spec names them.
static func _bolts(body: Node3D, p: float, ya: float, steel: Material) -> void:
	var rows := [["RecBoltL0", -0.227, 0.28, -0.98], ["RecBoltL1", -0.215, 0.28, -0.35],
			["RecBoltL2", -0.215, 0.95, -0.98], ["RecBoltL3", -0.215, 0.95, -0.35],
			["RecBoltR0", 0.215, 0.28, -0.45], ["RecBoltR1", 0.215, 0.28, -0.35],
			["RecBoltR2", 0.215, 0.95, -0.98], ["RecBoltR3", 0.215, 0.95, -0.35]]
	for r: Array in rows:
		var x: float = r[1]
		ArmParts.mesh(body, r[0] as String, ArmParts.cyl(0.03 * p, 0.03 * p, 0.03 * p, 6), steel,
				Vector3(x * p, ya + (r[2] as float) * p, (r[3] as float) * p),
				ArmParts.along(Vector3(signf(x), 0.0, 0.0)))


## The stock: a chamfered upper block, a lower block with the rear corner cut, a rubber pad and
## the charge window.
static func _stock(body: Node3D, p: float, ya: float, rust: Material, steel: Material) -> void:
	D.section(body, "Stock", 0.20 * p, 0.205 * p, 1.13 * p, 0.32 * p, ya + 0.765 * p, rust, p)
	var low: Array[Vector2] = [Vector2(0.32, 0.36), Vector2(0.93, 0.36), Vector2(1.13, 0.56),
			Vector2(1.13, 0.61), Vector2(0.32, 0.61)]
	ArmParts.mesh(body, "StockLow", prism(low, -0.20, 0.20, p, ya), rust, Vector3.ZERO)
	_box(body, "StockPad", ArmMaterials.grip_rubber(), Vector3(0.30, 0.27, 0.02),
			Vector3(0.0, 0.695, 1.14), p, ya)
	_box(body, "WindowFrame", steel, Vector3(0.20, 0.12, 0.012), Vector3(0.0, 0.90, 1.13), p, ya)
	_box(body, "Lamp0", ArmMaterials.ember(0.0), Vector3(0.14, 0.08, 0.012),
			Vector3(0.0, 0.90, 1.136), p, ya)


## A convex prism: `poly` is the side profile as (z, y) in p (y above `ya`), extruded from x0 to
## x1 (p). Front faces are clockwise, as Godot wants.
static func prism(poly: Array[Vector2], x0: float, x1: float, p: float, ya: float) -> ArrayMesh:
	var n := poly.size()
	var v: Array[Vector3] = []
	for x: float in [x0, x1]:
		for q: Vector2 in poly:
			v.append(Vector3(x * p, ya + q.y * p, q.x * p))
	var c := Vector3.ZERO
	for q: Vector3 in v:
		c += q / float(v.size())
	var tris: Array = []
	for i: int in range(1, n - 1):
		tris.append([0, i, i + 1])
		tris.append([n, n + i, n + i + 1])
	for i: int in range(n):
		var j := (i + 1) % n
		tris.append([i, j, n + j])
		tris.append([i, n + j, n + i])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for t: Array in tris:
		var a: Vector3 = v[t[0] as int]
		var b: Vector3 = v[t[1] as int]
		var d: Vector3 = v[t[2] as int]
		# Flip any triangle that is counter-clockwise seen from outside.
		if (b - a).cross(d - a).dot((a + b + d) / 3.0 - c) > 0.0:
			var tmp := b
			b = d
			d = tmp
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(d)
	st.generate_normals()
	return st.commit()
