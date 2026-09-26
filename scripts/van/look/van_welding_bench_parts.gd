extends RefCounted
## Prop builders for the welding bench (gas bottles, welder box with torch and power port, anvil,
## clamps, rod can, offcuts, scorch marks, hood, grinder shrouds, arm lamp with its light).
## All positions are bench-node local: rig-local minus (1.629, 0.425, 0.067).

const _SHELF_TOP := -0.285
const _TABLE_TOP := 0.425

## Emissive bulb of the arm lamp; the core flickers it with the bench's damage state.
var bulb_mat: StandardMaterial3D

var _bench: Node3D
var _steel: StandardMaterial3D
var _dark: StandardMaterial3D
var _soot: StandardMaterial3D
var _oxblood: StandardMaterial3D
var _red: StandardMaterial3D
var _green: StandardMaterial3D
var _brass: StandardMaterial3D
var _rust: StandardMaterial3D
var _scrap: StandardMaterial3D
var _face: StandardMaterial3D


func _init(bench: Node3D) -> void:
	_bench = bench
	_steel = MachineParts.dark(Color(0.2, 0.2, 0.19), 0.85)
	_dark = MachineParts.dark(Color(0.09, 0.09, 0.09), 0.85)
	_soot = MachineParts.dark(Color(0.02, 0.02, 0.02), 0.95)
	_oxblood = MachineParts.dark(Color(0.26, 0.08, 0.08), 0.9)
	_red = MachineParts.dark(Color(0.34, 0.09, 0.07), 0.85)
	_green = MachineParts.dark(Color(0.1, 0.26, 0.14), 0.85)
	_brass = MachineParts.dark(Color(0.4, 0.32, 0.12), 0.8)
	_rust = MachineParts.dark(Color(0.3, 0.17, 0.1), 0.92)
	_scrap = MachineParts.dark(Color(0.32, 0.3, 0.28), 0.85)
	_face = MachineParts.dark(Color(0.45, 0.43, 0.38), 0.9)


func _add(parent: Node3D, part_name: String, mesh: Mesh, mat: Material, pos: Vector3,
		rot: Vector3) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = part_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.rotation = rot
	inst.layers = VanLighting.LAYER_VAN_INTERIOR
	parent.add_child(inst)
	return inst


func _box(parent: Node3D, part_name: String, mat: Material, pos: Vector3, size: Vector3,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, part_name, mesh, mat, pos, rot)


func _cyl(parent: Node3D, part_name: String, mat: Material, pos: Vector3, radius: float,
		height: float, rot: Vector3 = Vector3.ZERO, bottom_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius if bottom_radius < 0.0 else bottom_radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return _add(parent, part_name, mesh, mat, pos, rot)


## Cylinder between two points (hoses, arm, torch nozzle).
func _segment(parent: Node3D, part_name: String, mat: Material, a: Vector3, b: Vector3,
		radius: float) -> void:
	var dir := b - a
	var up := Vector3.UP
	if absf(dir.normalized().dot(Vector3.UP)) > 0.99:
		up = Vector3.RIGHT
	var inst := _cyl(parent, part_name, mat, (a + b) * 0.5, radius, dir.length())
	inst.basis = Basis.looking_at(dir.normalized(), up) * Basis(Vector3.RIGHT, -PI / 2.0)


func _root(part_name: String, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = part_name
	root.position = pos
	_bench.add_child(root)
	return root


## Lower shelf load: chained gas bottles, welder box (dial, stubs, torch on a hook) and the
## junction that carries the PowerPort.
func build_shelf_kit() -> void:
	_bottle("BottleAcetylene", 0.36, -0.38, _red)
	_bottle("BottleOxygen", 0.36, -0.2, _green)
	_build_chain()
	_build_welder_box()
	_build_junction()
	_box(_bench, "ShelfScrapA", _scrap, Vector3(0.0, _SHELF_TOP + 0.01, -0.3),
			Vector3(0.16, 0.02, 0.06), Vector3(0.0, 0.6, 0.0))
	_box(_bench, "ShelfScrapB", _scrap, Vector3(0.1, _SHELF_TOP + 0.008, -0.05),
			Vector3(0.1, 0.016, 0.07), Vector3(0.0, -0.4, 0.0))


func _bottle(part_name: String, x: float, z: float, paint: Material) -> void:
	var root := _root(part_name, Vector3(x, _SHELF_TOP, z))
	_cyl(root, "Body", paint, Vector3(0.0, 0.26, 0.0), 0.075, 0.52)
	_cyl(root, "Shoulder", paint, Vector3(0.0, 0.545, 0.0), 0.03, 0.05, Vector3.ZERO, 0.075)
	_cyl(root, "Band", _steel, Vector3(0.0, 0.36, 0.0), 0.079, 0.02)
	_cyl(root, "Valve", _brass, Vector3(0.0, 0.585, 0.0), 0.02, 0.03)
	_box(root, "Wheel", _brass, Vector3(0.0, 0.605, 0.0), Vector3(0.07, 0.01, 0.014))


## Chain round both bottles, staple-bolted to the front wall-side leg.
func _build_chain() -> void:
	_box(_bench, "ChainStaple", _steel, Vector3(0.49, 0.035, -0.5), Vector3(0.06, 0.02, 0.02))
	for i: int in range(14):
		var flat := i % 2 == 0
		var size := Vector3(0.012, 0.02, 0.03) if flat else Vector3(0.02, 0.012, 0.03)
		_box(_bench, "ChainLink%d" % i, _dark, Vector3(0.455, 0.035, -0.5 + float(i) * 0.03), size)


func _build_welder_box() -> void:
	var y := _SHELF_TOP + 0.17
	_box(_bench, "WelderBody", _oxblood, Vector3(0.15, y, 0.46), Vector3(0.6, 0.34, 0.32))
	_box(_bench, "WelderHandle", _steel, Vector3(0.15, 0.085, 0.46), Vector3(0.3, 0.02, 0.02))
	_box(_bench, "WelderPost0", _steel, Vector3(0.02, 0.07, 0.46), Vector3(0.02, 0.03, 0.02))
	_box(_bench, "WelderPost1", _steel, Vector3(0.28, 0.07, 0.46), Vector3(0.02, 0.03, 0.02))
	_box(_bench, "Panel", _steel, Vector3(-0.155, -0.115, 0.46), Vector3(0.01, 0.24, 0.26))
	var side := Vector3(0.0, 0.0, PI / 2.0)
	_cyl(_bench, "Dial", _steel, Vector3(-0.166, -0.06, 0.38), 0.04, 0.012, side)
	_cyl(_bench, "DialFace", _face, Vector3(-0.1725, -0.06, 0.38), 0.033, 0.003, side)
	_box(_bench, "DialNeedle", _soot, Vector3(-0.175, -0.05, 0.38), Vector3(0.004, 0.03, 0.006),
			Vector3(0.0, 0.0, 0.6))
	_cyl(_bench, "Knob", _dark, Vector3(-0.168, -0.06, 0.54), 0.022, 0.02, side)
	for i: int in range(2):
		var z := 0.38 + float(i) * 0.16
		_cyl(_bench, "Socket%d" % i, _brass, Vector3(-0.165, -0.22, z), 0.028, 0.02, side)
		_cyl(_bench, "Stub%d" % i, _soot, Vector3(-0.2, -0.22, z), 0.017, 0.1, side)
		_cyl(_bench, "StubEnd%d" % i, _brass, Vector3(-0.265, -0.22, z), 0.022, 0.03, side)
	_build_torch()


func _build_torch() -> void:
	_box(_bench, "TorchHook", _steel, Vector3(-0.185, 0.02, 0.46), Vector3(0.05, 0.015, 0.015))
	_cyl(_bench, "TorchHandle", _brass, Vector3(-0.205, -0.09, 0.46), 0.014, 0.2)
	_segment(_bench, "TorchNozzle", _steel, Vector3(-0.205, -0.19, 0.46),
			Vector3(-0.25, -0.26, 0.46), 0.008)
	var hose: Array[Vector3] = [Vector3(-0.205, 0.01, 0.46), Vector3(-0.23, 0.06, 0.46),
			Vector3(-0.15, 0.1, 0.46), Vector3(-0.08, 0.055, 0.46)]
	for i: int in range(hose.size() - 1):
		_segment(_bench, "Hose%d" % i, _soot, hose[i], hose[i + 1], 0.011)


## Junction box on a shelf tab past the tabletop's +z end so a cable can rise straight up.
func _build_junction() -> void:
	_box(_bench, "JunctionTab", _steel, Vector3(0.42, -0.3, 0.69), Vector3(0.2, 0.03, 0.14))
	_box(_bench, "JunctionLink", _steel, Vector3(0.42, -0.215, 0.645), Vector3(0.06, 0.06, 0.05))
	_box(_bench, "JunctionBox", _dark, Vector3(0.42, -0.215, 0.7), Vector3(0.14, 0.14, 0.1))
	for i: int in range(2):
		_cyl(_bench, "Terminal%d" % i, _brass, Vector3(0.39 + float(i) * 0.06, -0.125, 0.7),
				0.014, 0.04)
	var port := Marker3D.new()
	port.name = "PowerPort"
	port.position = Vector3(0.42, -0.1, 0.7)
	port.add_to_group(&"machine_power_ports")
	port.set_meta(&"machine", &"welding_bench")
	port.set_meta(&"role", &"load")
	_bench.add_child(port)


## Tabletop clutter: anvil, clamp row, rod can, offcuts and scorch marks.
func build_top_kit() -> void:
	_build_anvil()
	for i: int in range(4):
		_build_clamp(i, Vector3(0.5, _TABLE_TOP, -0.16 + float(i) * 0.075))
	_build_rod_can()
	var offcuts: Array[Array] = [
		[Vector3(-0.2, 0.1, 0.0), Vector3(0.14, 0.02, 0.05), 0.5],
		[Vector3(-0.05, 0.22, 0.0), Vector3(0.09, 0.03, 0.04), -0.3],
		[Vector3(0.02, -0.05, 0.0), Vector3(0.06, 0.012, 0.1), 0.9],
		[Vector3(-0.35, 0.2, 0.0), Vector3(0.12, 0.015, 0.12), 0.2],
	]
	for i: int in range(offcuts.size()):
		var c: Array = offcuts[i]
		var p: Vector3 = c[0]
		var size: Vector3 = c[1]
		var yaw: float = c[2]
		_box(_bench, "Offcut%d" % i, _scrap, Vector3(p.x, _TABLE_TOP + size.y * 0.5, p.y), size,
				Vector3(0.0, yaw, 0.0))
	var scorches: Array[Array] = [
		[Vector2(-0.05, 0.1), Vector2(0.16, 0.12), 0.3],
		[Vector2(0.1, 0.0), Vector2(0.12, 0.09), -0.5],
		[Vector2(-0.3, 0.3), Vector2(0.1, 0.14), 0.2],
		[Vector2(0.2, 0.45), Vector2(0.1, 0.08), 0.8],
	]
	for i: int in range(scorches.size()):
		var s: Array = scorches[i]
		var at: Vector2 = s[0]
		var span: Vector2 = s[1]
		var turn: float = s[2]
		_box(_bench, "Scorch%d" % i, _soot, Vector3(at.x, _TABLE_TOP + 0.002, at.y),
				Vector3(span.x, 0.004, span.y), Vector3(0.0, turn, 0.0))


func _build_anvil() -> void:
	var root := _root("Anvil", Vector3(0.25, _TABLE_TOP, -0.3))
	_box(root, "Base", _dark, Vector3(0.0, 0.025, 0.0), Vector3(0.16, 0.05, 0.12))
	_box(root, "Waist", _dark, Vector3(0.0, 0.085, 0.0), Vector3(0.09, 0.07, 0.09))
	_box(root, "Face", _steel, Vector3(0.0, 0.145, 0.0), Vector3(0.28, 0.05, 0.12))
	_box(root, "Horn", _steel, Vector3(0.17, 0.14, 0.0), Vector3(0.1, 0.03, 0.06))


func _build_clamp(index: int, pos: Vector3) -> void:
	var root := _root("Clamp%d" % index, pos)
	_box(root, "Back", _steel, Vector3(0.0285, 0.065, 0.0), Vector3(0.012, 0.13, 0.03))
	_box(root, "Lower", _steel, Vector3(0.0, 0.007, 0.0), Vector3(0.07, 0.014, 0.03))
	_box(root, "Upper", _steel, Vector3(0.0, 0.123, 0.0), Vector3(0.07, 0.014, 0.03))
	_cyl(root, "Screw", _dark, Vector3(-0.015, 0.06, 0.0), 0.006, 0.1)
	_box(root, "Grip", _dark, Vector3(-0.015, 0.108, 0.0), Vector3(0.008, 0.008, 0.035))


func _build_rod_can() -> void:
	var root := _root("RodCan", Vector3(0.45, _TABLE_TOP, 0.28))
	_cyl(root, "Can", _rust, Vector3(0.0, 0.065, 0.0), 0.055, 0.13)
	for i: int in range(7):
		var a := float(i) * TAU / 7.0
		_cyl(root, "Rod%d" % i, _scrap, Vector3(cos(a) * 0.025, 0.13, sin(a) * 0.025), 0.005, 0.24,
				Vector3(sin(a) * 0.2, 0.0, -cos(a) * 0.2))


## Welding hood on the pegboard's front face (pegboard sits at z -0.49).
func build_mask() -> void:
	var root := _root("HoodMask", Vector3(-0.12, 0.66, -0.53))
	_box(root, "Shell", _dark, Vector3.ZERO, Vector3(0.2, 0.24, 0.05))
	_box(root, "Crown", _dark, Vector3(0.0, 0.14, 0.0025), Vector3(0.18, 0.05, 0.055))
	_box(root, "Visor", _soot, Vector3(0.0, 0.02, -0.0275), Vector3(0.13, 0.045, 0.005))
	_box(root, "Strap", _steel, Vector3(0.0, -0.13, 0.0), Vector3(0.12, 0.02, 0.03))


## Half-shell spark guards over both grinding wheels (wheel centres z 0.53, y 0.535).
func build_shrouds() -> void:
	for wheel_x: float in [-0.27, 0.07]:
		var tag := "L" if wheel_x < 0.0 else "R"
		_box(_bench, "ShroudTop" + tag, _steel, Vector3(wheel_x, 0.6625, 0.575),
				Vector3(0.05, 0.015, 0.14))
		_box(_bench, "ShroudBack" + tag, _steel, Vector3(wheel_x, 0.585, 0.64),
				Vector3(0.05, 0.14, 0.015))


## Clamp-on arm lamp with a cool white-blue light hung under its shade; returns the light.
func build_arm_lamp() -> OmniLight3D:
	var clamp_at := Vector3(0.53, _TABLE_TOP, 0.15)
	_box(_bench, "LampClampPlate", _steel, Vector3(0.575, 0.395, 0.15), Vector3(0.015, 0.09, 0.05))
	_box(_bench, "LampClampJaw", _steel, Vector3(0.535, 0.435, 0.15), Vector3(0.07, 0.02, 0.05))
	_segment(_bench, "LampPost", _steel, clamp_at + Vector3(0.0, 0.02, 0.0),
			Vector3(0.53, 0.98, 0.15), 0.012)
	_box(_bench, "LampElbow", _dark, Vector3(0.53, 0.98, 0.15), Vector3(0.035, 0.035, 0.035))
	_segment(_bench, "LampArm", _steel, Vector3(0.53, 0.98, 0.15), Vector3(0.2, 1.08, 0.15), 0.01)
	_cyl(_bench, "LampShade", _dark, Vector3(0.2, 1.02, 0.15), 0.03, 0.11, Vector3.ZERO, 0.085)
	bulb_mat = MachineParts.emissive(Color(0.7, 0.9, 1.0), 2.2)
	_cyl(_bench, "LampBulb", bulb_mat, Vector3(0.2, 0.965, 0.15), 0.03, 0.04)
	var light := OmniLight3D.new()
	light.name = "WorkLamp"
	light.light_color = Color(0.7, 0.9, 1.0)
	light.light_energy = 0.5
	light.omni_range = 2.0
	light.shadow_enabled = false
	light.light_cull_mask = VanLighting.LAYER_VAN_INTERIOR
	light.position = Vector3(0.2, 0.9, 0.15)
	_bench.add_child(light)
	return light
