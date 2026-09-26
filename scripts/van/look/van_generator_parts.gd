extends RefCounted
## Builds the generator set's welded skid, oil pan, radiator, tank, manifold, control gantry, junction box, trouble lamp and rust patches; the core script keeps the motor, flywheel, belt, fan, gauge and their motion.

const LAYER := 2

## Read by van_generator.gd to wire the lamp's flicker.
var trouble_light: OmniLight3D
var bulb_mat: StandardMaterial3D

var _machine: Node3D
var _steel: Material
var _paint: Material
var _rubber: Material
var _face: Material
var _rust: Material


func _init(machine: Node3D, steel: Material, paint: Material, rubber: Material,
		face: Material, rust: Material) -> void:
	_machine = machine
	_steel = steel
	_paint = paint
	_rubber = rubber
	_face = face
	_rust = rust


func build() -> void:
	_skid()
	_engine_top()
	_radiator()
	_gantry()
	_control_box()
	_trouble_lamp()
	_rust_patches()


func _add(part_name: String, mesh: Mesh, mat: Material, pos: Vector3,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = LAYER
	mi.position = pos
	mi.rotation = rot
	_machine.add_child(mi)
	return mi


func _box(part_name: String, size: Vector3, mat: Material, pos: Vector3,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(part_name, mesh, mat, pos, rot)


func _cyl(part_name: String, radius: float, height: float, mat: Material, pos: Vector3,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return _add(part_name, mesh, mat, pos, rot)


## Two channel rails, cross members, four rubber feet and the oil drip pan under the motor.
func _skid() -> void:
	for s: float in [-1.0, 1.0]:
		_box("RailWeb", Vector3(0.82, 0.08, 0.02), _steel, Vector3(0.29, -0.41, s * 0.27))
		_box("RailFlangeTop", Vector3(0.82, 0.02, 0.05), _steel, Vector3(0.29, -0.38, s * 0.245))
		_box("RailFlangeBottom", Vector3(0.82, 0.02, 0.05), _steel,
				Vector3(0.29, -0.44, s * 0.245))
		for x: float in [0.0, 0.6]:
			_box("Foot", Vector3(0.12, 0.04, 0.08), _rubber, Vector3(x, -0.47, s * 0.26))
	for x: float in [-0.09, 0.1, 0.34, 0.67]:
		_box("CrossMember", Vector3(0.05, 0.04, 0.52), _steel, Vector3(x, -0.42, 0.0))
	_box("PanFloor", Vector3(0.5, 0.012, 0.38), _steel, Vector3(0.2, -0.484, 0.0))
	for s: float in [-1.0, 1.0]:
		_box("PanRimSide", Vector3(0.5, 0.035, 0.012), _steel, Vector3(0.2, -0.4635, s * 0.19))
		_box("PanRimEnd", Vector3(0.012, 0.035, 0.38), _steel, Vector3(0.2 + s * 0.25, -0.4635, 0.0))
	_box("OilPuddle", Vector3(0.18, 0.006, 0.12), _rubber, Vector3(0.15, -0.474, 0.02))


## Cylinder head, three-stub manifold under the existing exhaust pipe, fuel tank and hose.
func _engine_top() -> void:
	_box("Head", Vector3(0.26, 0.12, 0.28), _paint, Vector3(-0.07, -0.06, -0.2))
	_cyl("Manifold", 0.04, 0.26, _steel, Vector3(-0.15, 0.1, -0.2), Vector3(PI / 2.0, 0.0, 0.0))
	for z: float in [-0.28, -0.2, -0.12]:
		_cyl("ManifoldStub", 0.03, 0.1, _steel, Vector3(-0.15, 0.05, z))
	_box("Tank", Vector3(0.34, 0.14, 0.22), _paint, Vector3(0.28, 0.12, 0.06))
	for x: float in [0.16, 0.4]:
		_box("TankSaddle", Vector3(0.05, 0.05, 0.16), _steel, Vector3(x, 0.035, 0.06))
	_cyl("FillerNeck", 0.03, 0.03, _steel, Vector3(0.36, 0.205, 0.06))
	_cyl("FillerCap", 0.04, 0.03, _steel, Vector3(0.36, 0.235, 0.06))
	_cyl("Injector", 0.022, 0.05, _steel, Vector3(0.02, 0.025, -0.1))
	MachineParts.pipe(_machine, Vector3(0.11, 0.09, 0.03), Vector3(0.02, 0.09, 0.03),
			_rubber, 0.012)
	MachineParts.pipe(_machine, Vector3(0.02, 0.09, 0.03), Vector3(0.02, 0.045, -0.1),
			_rubber, 0.012)


## Radiator core with a header tank and finned grille facing the wall, plus the fan's legs.
func _radiator() -> void:
	_box("RadiatorCore", Vector3(0.06, 0.34, 0.3), _steel, Vector3(-0.12, -0.16, 0.12))
	_box("RadiatorTank", Vector3(0.08, 0.04, 0.3), _paint, Vector3(-0.12, 0.03, 0.12))
	_cyl("RadiatorCap", 0.025, 0.03, _steel, Vector3(-0.12, 0.065, 0.22))
	for i: int in range(8):
		_box("Fin", Vector3(0.02, 0.3, 0.012), _steel, Vector3(-0.165, -0.16, 0.01 + i * 0.036))
	for x: float in [0.04, 0.36]:
		_box("FanLeg", Vector3(0.02, 0.31, 0.02), _steel, Vector3(x, -0.215, 0.27))


## Welded uprights, braces and two beams that carry the control box over the engine.
func _gantry() -> void:
	for x: float in [0.1, 0.34]:
		for z: float in [-0.27, 0.2]:
			_box("Post", Vector3(0.04, 0.86, 0.04), _steel, Vector3(x, 0.03, z))
		_box("Beam", Vector3(0.04, 0.04, 0.51), _steel, Vector3(x, 0.48, -0.035))
	for z: float in [-0.27, 0.2]:
		_box("Brace", Vector3(0.26, 0.03, 0.03), _steel, Vector3(0.22, 0.1, z))


## Breaker panel: painted box, face plate, two levers, junction box with the PowerPort.
func _control_box() -> void:
	_box("ControlBox", Vector3(0.4, 0.36, 0.26), _paint, Vector3(0.16, 0.68, 0.0))
	_box("FacePlate", Vector3(0.012, 0.3, 0.22), _face, Vector3(0.366, 0.68, 0.0))
	for z: float in [-0.07, -0.01]:
		_box("LeverBase", Vector3(0.02, 0.05, 0.04), _steel, Vector3(0.375, 0.6, z))
		_box("Lever", Vector3(0.02, 0.05, 0.015), _steel, Vector3(0.39, 0.625, z),
				Vector3(0.0, 0.0, -0.4))
	_box("JunctionBox", Vector3(0.12, 0.07, 0.12), _steel, Vector3(0.01, 0.895, 0.06))
	for x: float in [-0.02, 0.04]:
		_cyl("Terminal", 0.012, 0.03, _steel, Vector3(x, 0.945, 0.06))
	var port := Marker3D.new()
	port.name = "PowerPort"
	port.position = Vector3(0.01, 0.96, 0.06)
	port.add_to_group(&"machine_power_ports")
	port.set_meta(&"machine", &"generator")
	port.set_meta(&"role", &"source")
	_machine.add_child(port)


## Caged bulb on a bracket arm above the control box, with its warm amber light.
func _trouble_lamp() -> void:
	var lamp_pos := Vector3(0.42, 1.02, -0.08)
	_box("LampMast", Vector3(0.03, 0.3, 0.03), _steel, Vector3(0.3, 1.01, -0.08))
	_box("LampArm", Vector3(0.16, 0.025, 0.025), _steel, Vector3(0.37, 1.15, -0.08))
	_box("LampHanger", Vector3(0.012, 0.06, 0.012), _steel, Vector3(0.42, 1.11, -0.08))
	_cyl("CageTop", 0.06, 0.012, _steel, lamp_pos + Vector3(0.0, 0.05, 0.0))
	_cyl("CageBottom", 0.055, 0.012, _steel, lamp_pos + Vector3(0.0, -0.05, 0.0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box("CageBar", Vector3(0.008, 0.1, 0.008), _steel,
					lamp_pos + Vector3(sx * 0.05, 0.0, sz * 0.05))
	bulb_mat = MachineParts.emissive(Color(1.0, 0.55, 0.22), 1.6)
	var bulb := SphereMesh.new()
	bulb.radius = 0.035
	bulb.height = 0.07
	bulb.radial_segments = 8
	bulb.rings = 4
	_add("LampBulb", bulb, bulb_mat, lamp_pos)
	trouble_light = OmniLight3D.new()
	trouble_light.name = "TroubleLamp"
	trouble_light.light_color = Color(1.0, 0.55, 0.22)
	trouble_light.light_energy = 0.7
	trouble_light.omni_range = 2.2
	trouble_light.shadow_enabled = false
	trouble_light.light_cull_mask = VanLighting.LAYER_VAN_INTERIOR
	trouble_light.position = lamp_pos
	_machine.add_child(trouble_light)


## Thin dark-orange boxes laid on the flat faces of the paint and rails.
func _rust_patches() -> void:
	_box("Rust", Vector3(0.006, 0.07, 0.1), _rust, Vector3(0.452, 0.13, 0.06))
	_box("Rust", Vector3(0.1, 0.006, 0.07), _rust, Vector3(0.22, 0.192, 0.05))
	_box("Rust", Vector3(0.14, 0.1, 0.006), _rust, Vector3(0.12, 0.66, 0.1325))
	_box("Rust", Vector3(0.1, 0.006, 0.08), _rust, Vector3(0.24, 0.862, -0.03))
	_box("Rust", Vector3(0.22, 0.05, 0.006), _rust, Vector3(0.3, -0.41, 0.281))
	_box("Rust", Vector3(0.22, 0.05, 0.006), _rust, Vector3(0.5, -0.41, -0.281))
