extends RefCounted
## Part builders for VanRelayRack: angle-iron frame, six car batteries, relay cabinet, fuse board,
## trouble lamp and the two power ports. Coordinates are rack-local (rig axes, origin at the vital).

var switch_root: Node3D
var gauge_root: Node3D
var run_lamp_mat: StandardMaterial3D
var bulb_mat: StandardMaterial3D
var trouble_light: OmniLight3D

var _rack: Node3D
var _steel: StandardMaterial3D
var _board: StandardMaterial3D
var _casing: StandardMaterial3D
var _green: StandardMaterial3D
var _copper: StandardMaterial3D
var _wood: StandardMaterial3D
var _dark: StandardMaterial3D
var _face: StandardMaterial3D
var _ochre: StandardMaterial3D
var _red: StandardMaterial3D
var _tape: StandardMaterial3D


func _init(rack: Node3D) -> void:
	_rack = rack
	_steel = MachineParts.dark(Color(0.2, 0.2, 0.19), 0.85)
	_board = MachineParts.dark(Color(0.16, 0.14, 0.11), 0.92)
	_casing = MachineParts.dark(Color(0.1, 0.1, 0.11), 0.9)
	_green = MachineParts.dark(Color(0.16, 0.25, 0.17), 0.88)
	_copper = MachineParts.dark(Color(0.42, 0.26, 0.16), 0.8)
	_wood = MachineParts.dark(Color(0.24, 0.16, 0.09), 0.92)
	_dark = MachineParts.dark(Color(0.05, 0.05, 0.05), 0.9)
	_face = MachineParts.dark(Color(0.45, 0.43, 0.38), 0.9)
	_ochre = MachineParts.dark(Color(0.42, 0.33, 0.08), 0.85)
	_red = MachineParts.dark(Color(0.4, 0.09, 0.07), 0.85)
	_tape = MachineParts.dark(Color(0.28, 0.27, 0.24), 0.9)
	run_lamp_mat = MachineParts.emissive(Color(1.0, 0.45, 0.15), 1.6)
	bulb_mat = MachineParts.emissive(Color(0.55, 1.0, 0.6), 1.4)


func build() -> void:
	_build_frame()
	_build_batteries()
	_build_cabinet()
	_build_board()
	_build_lamp()
	_build_ports()


func _add(part: String, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3,
		parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	mi.position = pos
	mi.rotation = rot
	var host: Node3D = parent if parent != null else _rack
	host.add_child(mi)
	return mi


func _box(part: String, size: Vector3, pos: Vector3, mat: Material,
		rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(part, mesh, pos, mat, rot, parent)


func _cyl(part: String, radius: float, height: float, pos: Vector3, mat: Material,
		rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return _add(part, mesh, pos, mat, rot, parent)


func _build_frame() -> void:
	_box("Backboard", Vector3(1.24, 1.17, 0.03), Vector3(0.0, -0.465, -0.385), _board)
	for x_sign: float in [-1.0, 1.0]:
		var side := "L" if x_sign < 0.0 else "R"
		_box("Upright" + side, Vector3(0.05, 1.17, 0.012),
				Vector3(0.595 * x_sign, -0.465, -0.364), _steel)
		_box("UprightFlange" + side, Vector3(0.012, 1.17, 0.04),
				Vector3(0.614 * x_sign, -0.465, -0.35), _steel)
		_box("Hanger" + side, Vector3(0.025, 0.18, 0.025), Vector3(0.56 * x_sign, 0.21, -0.35),
				_steel)
		_box("HangerPlate" + side, Vector3(0.07, 0.01, 0.07),
				Vector3(0.56 * x_sign, 0.305, -0.35), _steel)
	_box("TopRail", Vector3(1.24, 0.04, 0.012), Vector3(0.0, 0.1, -0.364), _steel)
	_box("TopRailFlange", Vector3(1.24, 0.012, 0.04), Vector3(0.0, 0.116, -0.35), _steel)
	_box("Shelf", Vector3(0.78, 0.03, 0.26), Vector3(0.21, -0.02, -0.2), _steel)
	_box("ShelfLip", Vector3(0.78, 0.05, 0.012), Vector3(0.21, 0.005, -0.076), _steel)
	var bracket_index := 0
	for bx: float in [-0.12, 0.52]:
		bracket_index += 1
		_box("BracketStrip%d" % bracket_index, Vector3(0.03, 0.2, 0.012),
				Vector3(bx, -0.135, -0.364), _steel)
		_box("BracketBrace%d" % bracket_index, Vector3(0.025, 0.012, 0.297),
				Vector3(bx, -0.135, -0.25), _steel, Vector3(-0.74, 0.0, 0.0))
		for by: float in [-0.07, -0.2]:
			_cyl("BracketBolt", 0.008, 0.008, Vector3(bx, by, -0.356), _copper,
					Vector3(PI / 2.0, 0.0, 0.0))


func _build_batteries() -> void:
	var heights: Array[float] = [0.16, 0.19, 0.15, 0.18, 0.17, 0.19]
	var roots: Array[Node3D] = []
	for i: int in range(6):
		var h := heights[i]
		var root := Node3D.new()
		root.name = "Battery%d" % i
		root.position = Vector3(-0.06 + 0.118 * float(i), -0.005, -0.22)
		if i == 2:
			root.rotation = Vector3(deg_to_rad(6.0), 0.0, 0.0)
		_rack.add_child(root)
		roots.append(root)
		_box("Body", Vector3(0.11, h, 0.2), Vector3(0.0, h * 0.5, 0.0), _casing, Vector3.ZERO, root)
		_box("Lid", Vector3(0.114, 0.012, 0.204), Vector3(0.0, h + 0.006, 0.0), _steel,
				Vector3.ZERO, root)
		for sx: float in [-1.0, 1.0]:
			var post_pos := Vector3(0.03 * sx, h + 0.0245, 0.06)
			_cyl("Post", 0.011, 0.025, post_pos - Vector3(0.0, 0.012, 0.0), _copper,
					Vector3.ZERO, root)
			_cyl("TerminalCap", 0.016, 0.008, post_pos + Vector3(0.0, 0.004, 0.0),
					_red if sx > 0.0 else _dark, Vector3.ZERO, root)
		if i == 4:
			_box("Crack", Vector3(0.006, 0.08, 0.006), Vector3(0.01, h * 0.5, 0.101), _dark,
					Vector3(0.0, 0.0, 0.35), root)
			_box("Tape", Vector3(0.1, 0.022, 0.006), Vector3(0.0, h * 0.45, 0.103), _tape,
					Vector3(0.0, 0.0, 0.44), root)
	for i: int in range(5):
		var a: Vector3 = roots[i].transform * Vector3(0.03, heights[i] + 0.04, 0.06)
		var b: Vector3 = roots[i + 1].transform * Vector3(-0.03, heights[i + 1] + 0.04, 0.06)
		var mid := (a + b) * 0.5 + Vector3(0.0, 0.025, 0.0)
		MachineParts.cable_bundle(_rack, PackedVector3Array([a, mid, b]), _copper, 0.007, 1)
		_box("LugA", Vector3(0.026, 0.006, 0.026), a - Vector3(0.0, 0.006, 0.0), _copper)
		_box("LugB", Vector3(0.026, 0.006, 0.026), b - Vector3(0.0, 0.006, 0.0), _copper)
	var out_l: Vector3 = roots[0].transform * Vector3(-0.03, heights[0] + 0.04, 0.06)
	var out_r: Vector3 = roots[5].transform * Vector3(0.03, heights[5] + 0.04, 0.06)
	MachineParts.cable_bundle(_rack, PackedVector3Array([out_l, Vector3(-0.13, 0.2, -0.16),
			Vector3(-0.17, 0.05, -0.16), Vector3(-0.235, 0.02, -0.16)]), _copper, 0.012, 1)
	_cyl("CabinetGland", 0.02, 0.02, Vector3(-0.23, 0.02, -0.16), _steel,
			Vector3(0.0, 0.0, PI / 2.0))
	# Trunk cable from the last battery, down the right edge to the knife switch.
	var cable := PackedVector3Array([out_r, Vector3(0.635, out_r.y - 0.02, -0.16),
			Vector3(0.635, -0.1, -0.16), Vector3(0.635, -0.3, -0.3), Vector3(0.5, -0.72, -0.35),
			Vector3(0.06, -0.78, -0.35)])
	MachineParts.cable_bundle(_rack, cable, _copper, 0.012, 2)


func _build_cabinet() -> void:
	var cx := -0.42
	_box("Cabinet", Vector3(0.4, 0.74, 0.28), Vector3(cx, -0.23, -0.185), _green)
	_box("CabinetTop", Vector3(0.41, 0.012, 0.29), Vector3(cx, 0.146, -0.185), _steel)
	_box("Door", Vector3(0.37, 0.7, 0.012), Vector3(cx, -0.23, -0.039), _green)
	_box("CutBack", Vector3(0.22, 0.2, 0.004), Vector3(cx, -0.06, -0.031), _dark)
	for fy: float in [-0.107, 0.107]:
		_box("CutFrameH", Vector3(0.24, 0.014, 0.006), Vector3(cx, -0.06 + fy, -0.03), _steel)
	for fx: float in [-0.117, 0.117]:
		_box("CutFrameV", Vector3(0.014, 0.214, 0.006), Vector3(cx + fx, -0.06, -0.03), _steel)
	for kx: float in [-0.055, 0.055]:
		_box("Contactor", Vector3(0.08, 0.13, 0.024), Vector3(cx + kx, -0.06, -0.017), _casing)
		_box("ContactorCap", Vector3(0.07, 0.02, 0.02), Vector3(cx + kx, 0.015, -0.014), _steel)
		_box("ContactBar", Vector3(0.05, 0.012, 0.008), Vector3(cx + kx, -0.08, -0.007), _copper)
		for sx: float in [-0.02, 0.02]:
			_cyl("Screw", 0.008, 0.008, Vector3(cx + kx + sx, -0.03, -0.007), _copper,
					Vector3(PI / 2.0, 0.0, 0.0))
	for hy: float in [-0.5, 0.05]:
		_cyl("Hinge", 0.012, 0.07, Vector3(-0.607, hy, -0.04), _steel)
	_box("LatchHandle", Vector3(0.02, 0.1, 0.014), Vector3(-0.27, -0.23, -0.026), _steel)
	_cyl("Lock", 0.014, 0.01, Vector3(-0.27, -0.32, -0.03), _dark, Vector3(PI / 2.0, 0.0, 0.0))
	for i: int in range(6):
		_box("VentSlot", Vector3(0.012, 0.05, 0.004),
				Vector3(-0.56 + 0.055 * float(i), -0.49, -0.032), _dark)
	# Junction box on top: the power port sits between its two terminals.
	_box("JunctionBox", Vector3(0.12, 0.08, 0.1), Vector3(cx, 0.192, -0.185), _steel)
	for tx: float in [-0.03, 0.03]:
		_cyl("JunctionTerminal", 0.011, 0.022, Vector3(cx + tx, 0.243, -0.185), _copper)
	_cyl("LoadGland", 0.022, 0.03, Vector3(-0.3, -0.615, -0.185), _steel)


func _build_board() -> void:
	gauge_root = MachineParts.gauge(_rack, Vector3(0.38, -0.28, -0.37), _steel, _face)
	_box("RunLamp", Vector3(0.04, 0.04, 0.04), Vector3(0.52, -0.28, -0.355), run_lamp_mat)
	switch_root = MachineParts.knife_switch(_rack, Vector3(0.0, -0.89, -0.37), _steel, _copper)
	var arm := switch_root.get_node_or_null("Blade/BladeArm") as MeshInstance3D
	if arm:
		arm.material_override = _copper
	var handle := switch_root.get_node_or_null("Blade/Handle") as MeshInstance3D
	if handle:
		handle.material_override = _wood
		handle.scale = Vector3(1.6, 1.8, 1.6)
	_box("FusePlate", Vector3(0.39, 0.09, 0.02), Vector3(0.245, -0.55, -0.36), _steel)
	for i: int in range(3):
		var fx := 0.15 + 0.095 * float(i)
		_box("Breaker", Vector3(0.07, 0.06, 0.03), Vector3(fx, -0.55, -0.335), _casing)
		_box("Toggle", Vector3(0.014, 0.03, 0.014), Vector3(fx, -0.53 - 0.01 * float(i % 2),
				-0.318), _face)
	var tri := PrismMesh.new()
	tri.size = Vector3(0.11, 0.1, 0.012)
	_add("WarningTriangle", tri, Vector3(-0.06, -0.5, -0.364), _ochre, Vector3.ZERO, null)
	var tri_in := PrismMesh.new()
	tri_in.size = Vector3(0.07, 0.06, 0.004)
	_add("WarningInner", tri_in, Vector3(-0.06, -0.512, -0.357), _dark, Vector3.ZERO, null)
	_box("WarningBar", Vector3(0.012, 0.028, 0.004), Vector3(-0.06, -0.502, -0.353), _ochre)
	# Jump lead hanging on a hook below the cabinet.
	_cyl("LeadHook", 0.008, 0.06, Vector3(-0.5, -0.66, -0.34), _steel, Vector3(PI / 2.0, 0.0, 0.0))
	_box("LeadHookTip", Vector3(0.012, 0.02, 0.012), Vector3(-0.5, -0.65, -0.31), _steel)
	MachineParts.cable_bundle(_rack, PackedVector3Array([Vector3(-0.52, -0.66, -0.325),
			Vector3(-0.56, -0.82, -0.345), Vector3(-0.53, -0.97, -0.35)]), _red, 0.008, 1)
	MachineParts.cable_bundle(_rack, PackedVector3Array([Vector3(-0.48, -0.66, -0.325),
			Vector3(-0.44, -0.82, -0.345), Vector3(-0.47, -0.97, -0.35)]), _dark, 0.008, 1)
	_box("ClampRed", Vector3(0.035, 0.06, 0.022), Vector3(-0.53, -1.0, -0.35), _red)
	_box("ClampBlack", Vector3(0.035, 0.06, 0.022), Vector3(-0.47, -1.0, -0.35), _dark)


func _build_lamp() -> void:
	var lx := 0.3
	var lz := -0.05
	_box("LampStub", Vector3(0.03, 0.2, 0.03), Vector3(lx, 0.222, -0.35), _steel)
	_box("LampArm", Vector3(0.03, 0.03, 0.33), Vector3(lx, 0.307, -0.185), _steel)
	_cyl("LampChain", 0.004, 0.04, Vector3(lx, 0.272, lz), _steel)
	var hood := CylinderMesh.new()
	hood.top_radius = 0.012
	hood.bottom_radius = 0.045
	hood.height = 0.03
	hood.radial_segments = 8
	hood.rings = 1
	_add("LampHood", hood, Vector3(lx, 0.237, lz), _steel, Vector3.ZERO, null)
	_cyl("LampRingTop", 0.045, 0.008, Vector3(lx, 0.214, lz), _steel)
	_cyl("LampRingBottom", 0.045, 0.008, Vector3(lx, 0.15, lz), _steel)
	for cx: float in [-0.038, 0.038]:
		for cz: float in [-0.038, 0.038]:
			_box("LampBar", Vector3(0.006, 0.07, 0.006), Vector3(lx + cx, 0.182, lz + cz), _steel)
	var bulb := SphereMesh.new()
	bulb.radius = 0.028
	bulb.height = 0.056
	bulb.radial_segments = 8
	bulb.rings = 4
	_add("LampBulb", bulb, Vector3(lx, 0.182, lz), bulb_mat, Vector3.ZERO, null)
	trouble_light = OmniLight3D.new()
	trouble_light.name = "TroubleLight"
	trouble_light.light_color = Color(0.55, 1.0, 0.6)
	trouble_light.light_energy = 0.45
	trouble_light.omni_range = 2.0
	trouble_light.shadow_enabled = false
	trouble_light.light_cull_mask = VanLighting.LAYER_VAN_INTERIOR
	trouble_light.position = Vector3(lx, 0.182, lz)
	_rack.add_child(trouble_light)


func _build_ports() -> void:
	_port("PowerPort", Vector3(-0.42, 0.255, -0.185), &"hub")
	_port("LoadPort", Vector3(-0.3, -0.63, -0.185), &"out")


func _port(port_name: String, pos: Vector3, role: StringName) -> void:
	var port := Marker3D.new()
	port.name = port_name
	port.position = pos
	port.add_to_group(&"machine_power_ports")
	port.set_meta(&"machine", &"relay_rack")
	port.set_meta(&"role", role)
	_rack.add_child(port)
