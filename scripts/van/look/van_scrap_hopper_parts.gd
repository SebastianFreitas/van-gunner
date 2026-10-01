extends RefCounted
## Static dressing for the slim scrap hopper stack (skid, tray, cabinet, chute, pull lever, crusher cage, funnel, lamp, power port); built by van_scrap_hopper.gd.

const FLOOR := -1.44  ## Van floor in local y.
const FRONT := 0.215  ## Cabinet front face z; the back face stays at -0.215, off the bulkhead.

var hopper: Node3D
var _ochre: StandardMaterial3D
var _ochre_dark: StandardMaterial3D
var _black: StandardMaterial3D
var _steel: StandardMaterial3D
var _rust: StandardMaterial3D
var _tape: StandardMaterial3D


func _init(owner: Node3D) -> void:
	hopper = owner
	_ochre = MachineParts.dark(Color(0.34, 0.25, 0.09), 0.85)
	_ochre_dark = MachineParts.dark(Color(0.24, 0.17, 0.05), 0.88)
	_black = MachineParts.dark(Color(0.045, 0.04, 0.035), 0.92)
	_steel = MachineParts.dark(Color(0.2, 0.2, 0.19), 0.75)
	_rust = MachineParts.dark(Color(0.3, 0.18, 0.1), 0.9)
	_tape = MachineParts.dark(Color(0.35, 0.35, 0.33), 0.9)


## Two runners on the floor with four angle-iron legs, and the catch tray at the front bottom.
func build_skid_and_tray() -> void:
	for x: float in [-0.32, 0.32]:
		_box(hopper, "Runner%d" % int(x > 0.0), _steel, Vector3(x, FLOOR + 0.04, 0.0),
				Vector3(0.06, 0.08, 0.45))
		for z: float in [-0.17, 0.17]:
			_box(hopper, "Leg%d%d" % [int(x > 0.0), int(z > 0.0)], _steel,
					Vector3(x, -1.28, z), Vector3(0.04, 0.16, 0.04))
	_box(hopper, "TrayFloor", _steel, Vector3(-0.05, -1.17, 0.37), Vector3(0.46, 0.03, 0.28))
	for x: float in [-0.28, 0.18]:
		_box(hopper, "TrayLip%d" % int(x > 0.0), _steel, Vector3(x, -1.12, 0.37),
				Vector3(0.03, 0.07, 0.28))
	_box(hopper, "TrayFront", _steel, Vector3(-0.05, -1.12, 0.485), Vector3(0.46, 0.07, 0.03))
	var n := 9
	var step := 0.46 / float(n)
	for i: int in n:
		_box(hopper, "TrayHaz%d" % i, _ochre if i % 2 == 0 else _black,
				Vector3(-0.28 + (float(i) + 0.5) * step, -1.12, 0.506),
				Vector3(step, 0.05, 0.012))


## Dark steel body with its ochre door frame, seams, rivets, patch, tape, vent, gauge and grille.
func build_cabinet() -> void:
	_box(hopper, "Cabinet", _steel, Vector3(0.0, -0.55, 0.0), Vector3(0.78, 1.3, 0.43))
	_box(hopper, "FrameTop", _ochre, Vector3(0.0, 0.075, 0.27), Vector3(0.46, 0.05, 0.04))
	_box(hopper, "FrameBottom", _ochre, Vector3(0.0, -0.675, 0.27), Vector3(0.46, 0.05, 0.04))
	for x: float in [-0.205, 0.205]:
		_box(hopper, "FrameSide%d" % int(x > 0.0), _ochre, Vector3(x, -0.3, 0.27),
				Vector3(0.05, 0.7, 0.04))
		for y: float in [0.075, -0.675]:
			_cyl(hopper, "Rivet%d%d" % [int(x > 0.0), int(y > 0.0)], 0.01, 0.01, _black,
					Vector3(x, y, 0.295), Vector3(PI / 2.0, 0.0, 0.0))
	for x: float in [-0.37, 0.37]:
		_box(hopper, "SeamV%d" % int(x > 0.0), _black, Vector3(x, -0.55, FRONT + 0.0025),
				Vector3(0.012, 1.28, 0.02))
	for y: float in [0.07, -1.17]:
		_box(hopper, "SeamH%d" % int(y > 0.0), _black, Vector3(0.0, y, FRONT + 0.0025),
				Vector3(0.74, 0.012, 0.02))
	_box(hopper, "Tape", _tape, Vector3(-0.37, -0.8, FRONT + 0.0175), Vector3(0.04, 0.05, 0.025))
	_box(hopper, "Patch", _rust, Vector3(0.396, -0.7, 0.05), Vector3(0.012, 0.3, 0.2))
	MachineParts.vent(hopper, Vector3(0.44, -0.2, -0.05), _steel, 0.1)
	MachineParts.gauge(hopper, Vector3(-0.27, -0.02, 0.235), _steel, _black)
	for x: float in [-0.08, 0.0, 0.08]:
		_box(hopper, "Grille%d" % int(x * 100.0), _black, Vector3(x, -0.31, 0.3),
				Vector3(0.012, 0.68, 0.012))


## Short sloped mouth over the tray with a rubber flap on its lip.
func build_chute() -> void:
	var mouth := _box(hopper, "ChuteMouth", _steel, Vector3(-0.05, -0.98, 0.315),
			Vector3(0.3, 0.05, 0.17))
	mouth.rotation = Vector3(0.35, 0.0, 0.0)
	_box(hopper, "ChuteFlap", _black, Vector3(-0.05, -1.05, 0.395), Vector3(0.28, 0.1, 0.012))


## Hazard-taped ratchet plate, pivot hub and the pull lever on the front face at the right.
func build_lever() -> void:
	_box(hopper, "RatchetPlate", _ochre_dark, Vector3(0.3, -0.55, 0.235), Vector3(0.07, 0.26, 0.03))
	for y: float in [-0.52, -0.46]:
		_box(hopper, "RatchetTape%d" % int(y < -0.49), _black, Vector3(0.3, y, 0.256),
				Vector3(0.07, 0.03, 0.012))
	_cyl(hopper, "LeverHub", 0.04, 0.08, _steel, Vector3(0.3, -0.62, 0.27),
			Vector3(0.0, 0.0, PI / 2.0))
	var pivot := Node3D.new()
	pivot.name = "LeverPivot"
	pivot.position = Vector3(0.3, -0.62, 0.27)
	hopper.add_child(pivot)
	var arm := Node3D.new()
	arm.name = "LeverArm"
	arm.rotation = Vector3(0.35, 0.0, 0.0)
	pivot.add_child(arm)
	_cyl(arm, "Rod", 0.022, 0.34, _steel, Vector3(0.0, 0.17, 0.0), Vector3.ZERO)
	var ball := SphereMesh.new()
	ball.radius = 0.05
	ball.height = 0.1
	ball.radial_segments = 12
	ball.rings = 6
	_mesh(arm, "Grip", ball, _black, Vector3(0.0, 0.36, 0.0), Vector3.ZERO)
	_cyl(arm, "GripBand", 0.05, 0.015, _ochre, Vector3(0.0, 0.38, 0.0), Vector3.ZERO)


## Open cage over the cabinet: four corner angle posts and two ring frames (the drum sits inside).
func build_cage() -> void:
	for x: float in [-0.36, 0.36]:
		for z: float in [-0.19, 0.19]:
			_box(hopper, "CagePost%d%d" % [int(x > 0.0), int(z > 0.0)], _steel,
					Vector3(x, 0.36, z), Vector3(0.04, 0.52, 0.04))
	for y: float in [0.14, 0.58]:
		for z: float in [-0.19, 0.19]:
			_box(hopper, "RingX%d%d" % [int(y > 0.3), int(z > 0.0)], _steel, Vector3(0.0, y, z),
					Vector3(0.68, 0.03, 0.026))
		for x: float in [-0.36, 0.36]:
			_box(hopper, "RingZ%d%d" % [int(y > 0.3), int(x > 0.0)], _steel, Vector3(x, y, 0.0),
					Vector3(0.026, 0.03, 0.34))
	_box(hopper, "MotorMount", _ochre_dark, Vector3(0.33, 0.16, 0.0), Vector3(0.26, 0.12, 0.14))


## Ochre square funnel (a four-sided cone squashed in z to fit the 0.45 depth), rim and shards.
func build_funnel() -> void:
	var root := Node3D.new()
	root.name = "FunnelRoot"
	root.position = Vector3(0.0, 0.91, 0.0)
	root.scale = Vector3(1.0, 1.0, 0.62)
	hopper.add_child(root)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.5
	cone.bottom_radius = 0.24
	cone.height = 0.58
	cone.radial_segments = 4
	cone.rings = 1
	_mesh(root, "Funnel", cone, _ochre, Vector3.ZERO, Vector3(0.0, PI / 4.0, 0.0))
	for z: float in [-0.219, 0.219]:
		_box(hopper, "RimZ%d" % int(z > 0.0), _steel, Vector3(0.0, 1.205, z),
				Vector3(0.74, 0.03, 0.025))
	for x: float in [-0.354, 0.354]:
		_box(hopper, "RimX%d" % int(x > 0.0), _steel, Vector3(x, 1.205, 0.0),
				Vector3(0.025, 0.03, 0.42))
	var shards := [
		[Vector3(-0.12, 1.25, 0.03), Vector3(0.3, 0.4, 0.5), Vector3(0.04, 0.18, 0.02)],
		[Vector3(0.06, 1.26, -0.04), Vector3(-0.2, 0.9, -0.4), Vector3(0.05, 0.2, 0.02)],
		[Vector3(0.18, 1.24, 0.05), Vector3(0.4, -0.5, 0.3), Vector3(0.03, 0.15, 0.02)],
	]
	for i: int in shards.size():
		var s: Array = shards[i]
		_box(hopper, "Shard%d" % i, _black, s[0], s[2]).rotation = s[1]


## Pipe arm up to a caged amber trouble lamp; returns its light.
func build_lamp() -> OmniLight3D:
	var tip := Vector3(0.3, 1.32, 0.08)
	MachineParts.pipe(hopper, Vector3(0.32, 0.95, -0.18), tip, _steel, 0.02)
	var amber := MachineParts.emissive(Color(1.0, 0.6, 0.2), 1.6)
	_box(hopper, "WarnLamp", amber, tip, Vector3(0.06, 0.07, 0.06))
	_box(hopper, "LampCapTop", _steel, tip + Vector3(0.0, 0.055, 0.0), Vector3(0.11, 0.015, 0.11))
	_box(hopper, "LampCapBottom", _steel, tip - Vector3(0.0, 0.055, 0.0),
			Vector3(0.11, 0.015, 0.11))
	for sx: float in [-0.045, 0.045]:
		for sz: float in [-0.045, 0.045]:
			_box(hopper, "LampBar%d%d" % [int(sx > 0.0), int(sz > 0.0)], _steel,
					tip + Vector3(sx, 0.0, sz), Vector3(0.01, 0.095, 0.01))
	var light := OmniLight3D.new()
	light.name = "WarnLight"
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 0.5
	light.omni_range = 2.0
	light.shadow_enabled = false
	light.light_cull_mask = VanLighting.LAYER_VAN_INTERIOR
	light.position = Vector3(0.3, 1.24, 0.14)
	hopper.add_child(light)
	return light


## Junction box on the funnel's back with the power port inside it.
func build_port() -> void:
	_box(hopper, "JunctionBox", _steel, Vector3(0.28, 1.0, -0.195), Vector3(0.1, 0.1, 0.03))
	var port := Marker3D.new()
	port.name = "PowerPort"
	port.position = Vector3(0.28, 1.0, -0.2)
	port.add_to_group(&"machine_power_ports")
	port.set_meta(&"machine", &"scrap_hopper")
	port.set_meta(&"role", &"load")
	hopper.add_child(port)


func _cyl(parent: Node3D, part_name: String, radius: float, height: float, mat: Material,
		pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 10
	return _mesh(parent, part_name, cyl, mat, pos, rot)


func _mesh(parent: Node3D, part_name: String, mesh: Mesh, mat: Material, pos: Vector3,
		rot: Vector3) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = part_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.rotation = rot
	inst.layers = 2
	parent.add_child(inst)
	return inst


func _box(parent: Node3D, part_name: String, mat: Material, pos: Vector3,
		size: Vector3) -> MeshInstance3D:
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	return _mesh(parent, part_name, box_mesh, mat, pos, Vector3.ZERO)
