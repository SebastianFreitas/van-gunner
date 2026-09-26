extends RefCounted
## Part builders for VanPcRig (desk, PCs, CRTs, clutter, shelf, stool, lamp, power strip); rig-local metres, desk top y -0.18, partition face z 0, floor y -0.95.

const LAMP_ENERGY := 0.4
## Share of a disk or network LED's brightness that MachineMotion randomly drops per frame.
const LED_BLINK := 0.6

## The desk lamp's light; the rig flickers it at power-up like the CRT.
var lamp: OmniLight3D

var _rig: Node3D
var _motion: MachineMotion
var _beige: StandardMaterial3D
var _wood: StandardMaterial3D
var _wood_dark: StandardMaterial3D
var _crate: StandardMaterial3D
var _rubber: StandardMaterial3D
var _key: StandardMaterial3D
var _steel: StandardMaterial3D
var _paper: StandardMaterial3D
var _glass: StandardMaterial3D
var _crack: StandardMaterial3D
var _lamp_metal: StandardMaterial3D
var _green: StandardMaterial3D


## `motion` drives the blinking LEDs (its flicker_amount is set here).
func _init(rig: Node3D, motion: MachineMotion) -> void:
	_rig = rig
	_motion = motion
	_motion.flicker_amount = LED_BLINK
	_beige = MachineParts.dark(Color(0.42, 0.39, 0.32), 0.85)
	_wood = MachineParts.dark(Color(0.2, 0.15, 0.1), 0.92)
	_wood_dark = MachineParts.dark(Color(0.1, 0.075, 0.05), 0.95)
	_crate = MachineParts.dark(Color(0.16, 0.13, 0.09), 0.92)
	_rubber = MachineParts.dark(Color(0.06, 0.06, 0.06), 0.95)
	_key = MachineParts.dark(Color(0.05, 0.05, 0.055), 0.9)
	_steel = MachineParts.dark(Color(0.24, 0.24, 0.22), 0.8)
	_paper = MachineParts.dark(Color(0.4, 0.39, 0.33), 0.95)
	_glass = MachineParts.dark(Color(0.02, 0.025, 0.025), 0.78)
	_crack = MachineParts.dark(Color(0.3, 0.32, 0.3), 0.8)
	_lamp_metal = MachineParts.dark(Color(0.14, 0.14, 0.13), 0.85)
	_green = MachineParts.emissive(Color(0.3, 1.0, 0.4), 1.2)


func _add(parent: Node3D, part_name: String, mesh: Mesh, mat: Material, pos: Vector3,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = part_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.rotation = rot
	inst.layers = 2
	parent.add_child(inst)
	return inst


func _box(parent: Node3D, part_name: String, mat: Material, pos: Vector3, size: Vector3,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, part_name, mesh, mat, pos, rot)


func _cyl(parent: Node3D, part_name: String, mat: Material, pos: Vector3, radius: float,
		height: float, rot: Vector3 = Vector3.ZERO, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return _add(parent, part_name, mesh, mat, pos, rot)


func _cable(points: PackedVector3Array, radius: float = 0.008) -> void:
	MachineParts.cable_bundle(_rig, points, _rubber, radius, 1)


## A blinking emissive LED: its own material, flickered by the rig's LED motion.
func _led(parent: Node3D, part_name: String, color: Color, pos: Vector3, size: Vector3) -> void:
	var mat := MachineParts.emissive(color, 1.6)
	_box(parent, part_name, mat, pos, size)
	_motion.add_flicker(mat, &"emission_energy_multiplier", 1.6)


## Plank desk on two crates with a drawer between them, chipped edge and diagonal braces.
func build_desk() -> void:
	_box(_rig, "DeskTop", _wood, Vector3(0.165, -0.2, 0.275), Vector3(1.11, 0.045, 0.49))
	_box(_rig, "ChipTop", _wood_dark, Vector3(0.69, -0.1745, 0.5), Vector3(0.06, 0.006, 0.035),
			Vector3(0.0, 0.4, 0.0))
	_box(_rig, "ChipFront", _wood_dark, Vector3(0.55, -0.205, 0.5215), Vector3(0.07, 0.022, 0.006))
	_box(_rig, "ChipSplinter", _wood, Vector3(0.717, -0.19, 0.44), Vector3(0.008, 0.02, 0.05),
			Vector3(0.0, 0.0, 0.15))
	for crate_x: float in [-0.25, 0.55]:
		_box(_rig, "Crate", _crate, Vector3(crate_x, -0.585, 0.24), Vector3(0.25, 0.73, 0.38))
		for slat_y: float in [-0.45, -0.75]:
			_box(_rig, "Slat", _wood, Vector3(crate_x, slat_y, 0.24), Vector3(0.26, 0.03, 0.39))
		for tilt: float in [0.35, -0.35]:
			_box(_rig, "Brace", _wood, Vector3(crate_x, -0.585, 0.442), Vector3(0.03, 0.66, 0.015),
					Vector3(0.0, 0.0, tilt))
	_box(_rig, "CleatL", _wood, Vector3(-0.077, -0.25, 0.24), Vector3(0.1, 0.03, 0.38))
	_box(_rig, "CleatR", _wood, Vector3(0.38, -0.25, 0.24), Vector3(0.1, 0.03, 0.38))
	_box(_rig, "Drawer", _crate, Vector3(0.15, -0.31, 0.25), Vector3(0.36, 0.13, 0.4))
	_box(_rig, "DrawerFront", _wood, Vector3(0.15, -0.31, 0.4575), Vector3(0.34, 0.11, 0.015))
	_box(_rig, "DrawerHandle", _steel, Vector3(0.15, -0.31, 0.475), Vector3(0.12, 0.014, 0.02))
	for post_x: float in [0.1, 0.2]:
		_box(_rig, "HandlePost", _steel, Vector3(post_x, -0.31, 0.4675), Vector3(0.014, 0.014, 0.02))


## Towers, the three CRTs, the mechanical keyboard and the mouse.
func build_gear(screen: Material) -> void:
	var tower := MachineParts.tower_pc(_rig, Vector3(-0.27, -0.18, 0.25), _beige, _green)
	for bay_y: float in [0.375, 0.27]:
		_box(tower, "DriveBay", _beige, Vector3(0.0, bay_y, 0.226), Vector3(0.18, 0.04, 0.02))
	for slot_y: float in [0.32, 0.375, 0.27]:
		_box(tower, "BaySlot", _rubber, Vector3(0.0, slot_y, 0.238), Vector3(0.14, 0.008, 0.004))
	for vent_y: float in [0.06, 0.09, 0.12]:
		_box(tower, "Vent", _rubber, Vector3(0.0, vent_y, 0.228), Vector3(0.14, 0.008, 0.004))
	_cyl(tower, "PowerButton", _steel, Vector3(0.06, 0.16, 0.23), 0.014, 0.01,
			Vector3(PI / 2.0, 0.0, 0.0))
	_led(tower, "DiskLed", Color(1.0, 0.6, 0.15), Vector3(0.06, 0.22, 0.232),
			Vector3(0.014, 0.014, 0.006))
	MachineParts.tower_pc(_rig, Vector3(0.15, -0.95, 0.26), _beige, _green)

	_box(_rig, "StatsFoot", _steel, Vector3(-0.27, 0.25, 0.26), Vector3(0.16, 0.03, 0.14))

	_box(_rig, "MainPlinth", _steel, Vector3(0.08, -0.165, 0.2), Vector3(0.26, 0.03, 0.26))
	_box(_rig, "MainNeck", _steel, Vector3(0.08, -0.12, 0.22), Vector3(0.12, 0.06, 0.1))
	MachineParts.crt(_rig, Vector3(0.08, 0.07, 0.28), _beige, screen, 0.4)

	_box(_rig, "SmallPlinth", _steel, Vector3(0.45, -0.165, 0.2), Vector3(0.18, 0.03, 0.18))
	_box(_rig, "SmallNeck", _steel, Vector3(0.45, -0.12, 0.17), Vector3(0.09, 0.06, 0.07))
	var small_screen := ShaderMaterial.new()
	small_screen.shader = preload("res://scenes/van/crt_screen.gdshader")
	small_screen.set_shader_parameter(&"brightness", 0.5)
	MachineParts.crt(_rig, Vector3(0.45, 0.01, 0.25), _beige, small_screen, 0.24)

	_box(_rig, "DeadBoard", _wood, Vector3(0.45, 0.1475, 0.22), Vector3(0.26, 0.015, 0.2))
	var dead := MachineParts.crt(_rig, Vector3(0.45, 0.265, 0.24), _steel, _glass, 0.2)
	dead.rotation = Vector3(0.0, 0.15, 0.06)
	_box(dead, "CrackA", _crack, Vector3(0.05, -0.04, 0.0625), Vector3(0.06, 0.003, 0.001),
			Vector3(0.0, 0.0, 0.6))
	_box(dead, "CrackB", _crack, Vector3(0.06, -0.025, 0.0625), Vector3(0.04, 0.003, 0.001),
			Vector3(0.0, 0.0, -0.5))
	_box(dead, "CrackC", _crack, Vector3(0.035, -0.05, 0.0625), Vector3(0.04, 0.003, 0.001),
			Vector3(0.0, 0.0, 1.5))
	_box(dead, "BrokenCorner", _rubber, Vector3(0.07, -0.05, 0.063), Vector3(0.03, 0.025, 0.002))

	var pivot := Node3D.new()
	pivot.name = "Keyboard"
	pivot.position = Vector3(0.12, -0.16, 0.435)
	pivot.rotation = Vector3(deg_to_rad(6.0), 0.0, 0.0)
	_box(pivot, "Slab", _beige, Vector3.ZERO, Vector3(0.44, 0.025, 0.15))
	var key_mesh := BoxMesh.new()
	key_mesh.size = Vector3(0.03, 0.014, 0.03)
	for row: int in range(3):
		for col: int in range(10):
			_add(pivot, "Key%d_%d" % [row, col], key_mesh, _key,
					Vector3(-0.18 + float(col) * 0.04, 0.02, -0.045 + float(row) * 0.04))
	_box(pivot, "Spacebar", _key, Vector3(-0.02, 0.02, 0.062), Vector3(0.22, 0.014, 0.024))
	_rig.add_child(pivot)
	_cable(PackedVector3Array([Vector3(-0.09, -0.172, 0.37), Vector3(-0.1, -0.175, 0.3),
			Vector3(-0.165, -0.175, 0.2)]))

	_box(_rig, "MouseMat", _rubber, Vector3(0.45, -0.175, 0.41), Vector3(0.17, 0.006, 0.16))
	_box(_rig, "Mouse", _beige, Vector3(0.45, -0.165, 0.44), Vector3(0.045, 0.02, 0.07))
	_cable(PackedVector3Array([Vector3(0.45, -0.17, 0.405), Vector3(0.42, -0.176, 0.365),
			Vector3(0.35, -0.176, 0.33)]))


## Desk-end clutter, the power strip with its junction box and PowerPort, and the cable runs.
func build_clutter() -> void:
	var tape_x := 0.65
	_box(_rig, "TapeUnit", _crate, Vector3(tape_x, -0.11, 0.18), Vector3(0.13, 0.14, 0.2))
	for reel_x: float in [tape_x - 0.033, tape_x + 0.033]:
		_cyl(_rig, "Reel", _steel, Vector3(reel_x, -0.075, 0.283), 0.028, 0.006,
				Vector3(PI / 2.0, 0.0, 0.0))
	_box(_rig, "TapeColumn", _rubber, Vector3(tape_x, -0.14, 0.283), Vector3(0.1, 0.03, 0.006))
	_box(_rig, "Router", _rubber, Vector3(tape_x, -0.02, 0.18), Vector3(0.11, 0.04, 0.11))
	_led(_rig, "RouterLedA", Color(0.3, 1.0, 0.4), Vector3(tape_x - 0.02, -0.02, 0.2355),
			Vector3(0.012, 0.012, 0.004))
	_led(_rig, "RouterLedB", Color(1.0, 0.6, 0.15), Vector3(tape_x + 0.02, -0.02, 0.2355),
			Vector3(0.012, 0.012, 0.004))
	_cyl(_rig, "Antenna", _rubber, Vector3(tape_x + 0.045, 0.045, 0.14), 0.005, 0.09)

	for i: int in range(5):
		var sleeve_mat: Material = _rubber if i != 2 else _crate
		_box(_rig, "Floppy%d" % i, sleeve_mat, Vector3(tape_x, -0.1755 + float(i) * 0.0045, 0.37),
				Vector3(0.12, 0.004, 0.12), Vector3(0.0, 0.1 * float(i - 2), 0.0))
	_box(_rig, "FloppyLabel", _paper, Vector3(tape_x, -0.1535, 0.39), Vector3(0.05, 0.001, 0.03))

	_cyl(_rig, "Mug", _beige, Vector3(tape_x, -0.14, 0.475), 0.035, 0.08)
	_cyl(_rig, "Coffee", _wood_dark, Vector3(tape_x, -0.1005, 0.475), 0.03, 0.002)
	_box(_rig, "MugHandle", _beige, Vector3(tape_x + 0.045, -0.14, 0.475), Vector3(0.012, 0.05, 0.02))
	_box(_rig, "MugStain", _wood_dark, Vector3(tape_x - 0.01, -0.125, 0.5105),
			Vector3(0.008, 0.05, 0.004))

	_box(_rig, "PowerStrip", _rubber, Vector3(0.42, -0.155, 0.03), Vector3(0.28, 0.05, 0.06))
	for plug_x: float in [0.34, 0.42, 0.5]:
		_box(_rig, "Plug", _key, Vector3(plug_x, -0.1125, 0.03), Vector3(0.03, 0.035, 0.035))
	_box(_rig, "StripSwitch", MachineParts.dark(Color(0.45, 0.06, 0.05), 0.85),
			Vector3(0.3, -0.127, 0.03), Vector3(0.02, 0.012, 0.03))

	_box(_rig, "JunctionBox", _steel, Vector3(0.5, -0.03, 0.03), Vector3(0.12, 0.1, 0.06))
	for term_x: float in [0.47, 0.53]:
		_cyl(_rig, "Terminal", _steel, Vector3(term_x, 0.035, 0.03), 0.012, 0.03)
	var port := Marker3D.new()
	port.name = "PowerPort"
	port.position = Vector3(0.5, 0.06, 0.03)
	port.add_to_group(&"machine_power_ports")
	port.set_meta(&"machine", &"pc_rig")
	port.set_meta(&"role", &"load")
	_rig.add_child(port)
	# The junction box feeds the strip; the ceiling run comes down the partition at x 0.5, behind
	# every CRT.
	_cable(PackedVector3Array([Vector3(0.44, -0.03, 0.03), Vector3(0.3, -0.03, 0.015),
			Vector3(0.28, -0.13, 0.015)]))
	_cable(PackedVector3Array([Vector3(0.5, 0.06, 0.03), Vector3(0.5, 0.5, 0.03),
			Vector3(0.5, 1.9, 0.03)]), 0.015)
	_cable(PackedVector3Array([Vector3(0.15, -0.75, 0.012), Vector3(0.15, -0.17, 0.012),
			Vector3(0.09, -0.05, 0.035)]))


## Sticky notes on the partition and a crooked shelf with a clock-radio and paper stacks.
func build_wall() -> void:
	var notes: Array[Array] = [
		[Vector3(0.0, 0.42, 0.0), Color(0.4, 0.36, 0.16), 0.08],
		[Vector3(0.07, 0.36, 0.0), Color(0.36, 0.3, 0.32), -0.12],
		[Vector3(0.15, 0.45, 0.0), Color(0.3, 0.36, 0.3), 0.15],
		[Vector3(0.22, 0.38, 0.0), Color(0.4, 0.36, 0.16), -0.06],
	]
	for note: Array in notes:
		var pos: Vector3 = note[0]
		var col: Color = note[1]
		var tilt: float = note[2]
		_box(_rig, "StickyNote", MachineParts.dark(col, 0.95), pos + Vector3(0.0, 0.0, 0.003),
				Vector3(0.06, 0.06, 0.003), Vector3(0.0, 0.0, tilt))
	var shelf := Node3D.new()
	shelf.name = "Shelf"
	shelf.position = Vector3(-0.22, 0.74, 0.08)
	shelf.rotation = Vector3(0.0, 0.0, 0.05)
	_box(shelf, "Plank", _wood, Vector3.ZERO, Vector3(0.4, 0.025, 0.16))
	for bracket_x: float in [-0.15, 0.15]:
		_box(shelf, "Bracket", _steel, Vector3(bracket_x, -0.06, -0.02), Vector3(0.02, 0.09, 0.12))
	_box(shelf, "ClockRadio", _key, Vector3(-0.11, 0.0525, 0.0), Vector3(0.15, 0.08, 0.09))
	_box(shelf, "ClockDisplay", MachineParts.emissive(Color(1.0, 0.15, 0.1), 1.0),
			Vector3(-0.13, 0.06, 0.0475), Vector3(0.05, 0.02, 0.004))
	for knob_x: float in [-0.07, -0.045]:
		_cyl(shelf, "Knob", _steel, Vector3(knob_x, 0.05, 0.0475), 0.01, 0.008,
				Vector3(PI / 2.0, 0.0, 0.0))
	_box(shelf, "PaperStackA", _paper, Vector3(0.08, 0.0425, 0.0), Vector3(0.11, 0.06, 0.09))
	_box(shelf, "PaperStackB", _paper, Vector3(0.16, 0.0275, 0.01), Vector3(0.09, 0.03, 0.08),
			Vector3(0.0, 0.2, 0.0))
	_rig.add_child(shelf)


## Swivel stool: a cylinder seat on a post and a tripod, in front of the desk.
func build_stool() -> void:
	var stool := Node3D.new()
	stool.name = "Stool"
	stool.position = Vector3(0.12, 0.0, 0.74)
	_cyl(stool, "Seat", _crate, Vector3(0.0, -0.525, 0.0), 0.17, 0.05)
	_cyl(stool, "Cushion", _rubber, Vector3(0.0, -0.495, 0.0), 0.15, 0.015)
	_cyl(stool, "Post", _steel, Vector3(0.0, -0.7, 0.0), 0.02, 0.3)
	_cyl(stool, "Hub", _steel, Vector3(0.0, -0.82, 0.0), 0.04, 0.03)
	for i: int in range(3):
		var ang := TAU * float(i) / 3.0 + 0.4
		var foot := Vector3(cos(ang) * 0.19, -0.94, sin(ang) * 0.19)
		MachineParts.cable_bundle(stool, PackedVector3Array([Vector3(0.0, -0.82, 0.0), foot]),
				_steel, 0.014, 1)
		_box(stool, "Foot", _rubber, foot, Vector3(0.04, 0.02, 0.04))
	_rig.add_child(stool)


## Gooseneck lamp clamped left of the keyboard; its warm OmniLight hangs under the shade.
func build_lamp() -> void:
	_cyl(_rig, "LampBase", _lamp_metal, Vector3(-0.14, -0.17, 0.4), 0.03, 0.02)
	_cable(PackedVector3Array([Vector3(-0.14, -0.16, 0.4), Vector3(-0.14, 0.0, 0.4),
			Vector3(-0.14, 0.1, 0.41), Vector3(-0.13, 0.15, 0.43)]), 0.01)
	var head := Node3D.new()
	head.name = "LampHead"
	head.position = Vector3(-0.125, 0.13, 0.45)
	head.rotation = Vector3(0.25, 0.0, 0.0)
	_cyl(head, "Shade", _lamp_metal, Vector3.ZERO, 0.05, 0.07, Vector3.ZERO, 0.02)
	_cyl(head, "Bulb", MachineParts.emissive(Color(1.0, 0.85, 0.6), 2.0),
			Vector3(0.0, -0.04, 0.0), 0.018, 0.02)
	_rig.add_child(head)
	lamp = OmniLight3D.new()
	lamp.name = "LampLight"
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = LAMP_ENERGY
	lamp.omni_range = 1.8
	lamp.shadow_enabled = false
	lamp.light_cull_mask = VanLighting.LAYER_VAN_INTERIOR
	lamp.position = Vector3(-0.125, 0.075, 0.455)
	_rig.add_child(lamp)
