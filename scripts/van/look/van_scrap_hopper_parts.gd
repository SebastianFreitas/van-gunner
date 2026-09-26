extends RefCounted
## Static dressing for the scrap hopper (frame, hazard band, cage, bin, chain drive, lamp mast, stop button, power port); built by van_scrap_hopper.gd.

const FX0 := 0.26  ## Frame post x, aisle side, in the hopper's local space (+x is toward the left wall).
const FX1 := 1.2  ## Frame post x, wall side.
const FZ := 0.3  ## Frame post |z|.
const TOP := 0.6  ## Frame top in local y; the funnel flares above it.
const FLOOR := -1.44  ## Van floor in local y.
const CX := 0.73  ## Crusher axis x.

var hopper: Node3D
var _ochre: StandardMaterial3D
var _ochre_dark: StandardMaterial3D
var _black: StandardMaterial3D
var _steel: StandardMaterial3D
var _glass: StandardMaterial3D


func _init(owner: Node3D) -> void:
	hopper = owner
	_ochre = MachineParts.dark(Color(0.34, 0.25, 0.09), 0.85)
	_ochre_dark = MachineParts.dark(Color(0.24, 0.17, 0.05), 0.88)
	_black = MachineParts.dark(Color(0.045, 0.04, 0.035), 0.92)
	_steel = MachineParts.dark(Color(0.2, 0.2, 0.19), 0.85)
	_glass = MachineParts.dark(Color(0.03, 0.04, 0.045), 0.8)


func build_frame() -> void:
	var h := TOP - FLOOR + 0.03
	for x: float in [FX0, FX1]:
		for z: float in [-FZ, FZ]:
			_box(hopper, "Post%d%d" % [int(x > 1.0), int(z > 0.0)], _ochre,
					Vector3(x, (TOP + FLOOR) * 0.5 + 0.015, z), Vector3(0.06, h, 0.06))
	var span := FX1 - FX0 + 0.06
	for z: float in [-FZ, FZ]:
		_box(hopper, "TopRail%d" % int(z > 0.0), _ochre, Vector3(CX, TOP + 0.03, z),
				Vector3(span, 0.05, 0.05))
	_box(hopper, "RearMidRail", _ochre, Vector3(CX, -0.9, -FZ), Vector3(span, 0.05, 0.05))
	_box(hopper, "FrontMidRail", _ochre, Vector3(CX, -0.9, FZ), Vector3(span, 0.05, 0.05))
	for x: float in [FX0, FX1]:
		_box(hopper, "SideTopRail%d" % int(x > 1.0), _ochre, Vector3(x, TOP + 0.03, 0.0),
				Vector3(0.05, 0.05, FZ * 2.0))
	_link("BraceA", Vector3(FX0, -0.9, -FZ - 0.035), Vector3(FX1, 0.6, -FZ - 0.035))
	_link("BraceB", Vector3(FX1, -0.9, -FZ - 0.035), Vector3(FX0, 0.6, -FZ - 0.035))
	_box(hopper, "Throat", _ochre, Vector3(CX, 0.47, 0.0), Vector3(0.4, 0.26, 0.4))
	_box(hopper, "Housing", _ochre_dark, Vector3(CX, -0.2, 0.0), Vector3(0.7, 0.5, 0.5))
	_box(hopper, "WindowFrame", _steel, Vector3(CX, -0.2, 0.262), Vector3(0.3, 0.2, 0.024))
	_box(hopper, "WindowGlass", _glass, Vector3(CX, -0.2, 0.278), Vector3(0.24, 0.14, 0.012))
	_build_hazard_band()
	_build_seam()


## Alternating dark ochre and near-black blocks on the frame's front, back and wall faces.
func _build_hazard_band() -> void:
	var n := 12
	var step := (FX1 - FX0) / float(n)
	for i: int in n:
		var x := FX0 + (float(i) + 0.5) * step
		var mat := _ochre_dark if i % 2 == 0 else _black
		for z: float in [-FZ - 0.04, FZ + 0.04]:
			_box(hopper, "Haz%d_%d" % [i, int(z > 0.0)], mat, Vector3(x, 0.53, z),
					Vector3(step, 0.1, 0.02))
	for i: int in 8:
		var z := -FZ + (float(i) + 0.5) * (FZ * 2.0 / 8.0)
		var mat := _ochre_dark if i % 2 == 0 else _black
		_box(hopper, "HazSide%d" % i, mat, Vector3(FX1 + 0.04, 0.53, z),
				Vector3(0.02, 0.1, FZ * 2.0 / 8.0))


## Rivet heads along the funnel's top rim (funnel half-width 0.44 at y 1.04).
func _build_seam() -> void:
	for i: int in 8:
		var t := (float(i) + 0.5) / 8.0
		for side: float in [-1.0, 1.0]:
			_box(hopper, "RivetF%d_%d" % [i, int(side > 0.0)], _steel,
					Vector3(CX + (t - 0.5) * 0.8, 1.03, side * 0.45), Vector3(0.025, 0.025, 0.02))


## Guard bars over the front of the crusher drum (the throat feeds it from above).
func build_cage() -> void:
	var cage := Node3D.new()
	cage.name = "Cage"
	cage.position = Vector3(CX, 0.2, 0.0)
	hopper.add_child(cage)
	for i: int in 6:
		var a := deg_to_rad(-45.0 + 14.0 * float(i))
		_box(cage, "Bar%d" % i, _steel, Vector3(0.0, 0.2 * sin(a), 0.2 * cos(a)),
				Vector3(0.64, 0.02, 0.02))
	for x_sign: float in [-1.0, 1.0]:
		_box(cage, "Upright%d" % int(x_sign > 0.0), _steel, Vector3(0.33 * x_sign, -0.03, 0.19),
				Vector3(0.02, 0.24, 0.02))


## Open catch bin at the floor under the chute, half full of seeded scrap.
func build_bin() -> void:
	var bin := Node3D.new()
	bin.name = "CatchBin"
	bin.position = Vector3(0.4, FLOOR, 0.55)
	hopper.add_child(bin)
	_box(bin, "Base", _steel, Vector3(0.0, 0.015, 0.0), Vector3(0.76, 0.03, 0.4))
	for z: float in [-0.185, 0.185]:
		_box(bin, "Wall%d" % int(z > 0.0), _ochre_dark, Vector3(0.0, 0.15, z),
				Vector3(0.76, 0.3, 0.03))
	for x: float in [-0.365, 0.365]:
		_box(bin, "End%d" % int(x > 0.0), _ochre_dark, Vector3(x, 0.15, 0.0),
				Vector3(0.03, 0.3, 0.34))
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i: int in 9:
		var size := Vector3(rng.randf_range(0.05, 0.14), rng.randf_range(0.03, 0.09),
				rng.randf_range(0.05, 0.12))
		var pos := Vector3(rng.randf_range(-0.28, 0.28), 0.03 + size.y * 0.5,
				rng.randf_range(-0.12, 0.12))
		var heap := _box(bin, "Scrap%d" % i, _black if i % 3 == 0 else _steel, pos, size)
		heap.rotation.y = rng.randf_range(0.0, PI)


## Pedestal, chain drive with its guard, and the motor junction box with the power port.
func build_drive_extras() -> void:
	_box(hopper, "MotorPedestal", _ochre_dark, Vector3(1.38, -1.04, 0.0), Vector3(0.4, 0.8, 0.26))
	var pulley_a := CylinderMesh.new()
	pulley_a.top_radius = 0.06
	pulley_a.bottom_radius = 0.06
	pulley_a.height = 0.04
	pulley_a.radial_segments = 10
	var pulley_b := CylinderMesh.new()
	pulley_b.top_radius = 0.09
	pulley_b.bottom_radius = 0.09
	pulley_b.height = 0.04
	pulley_b.radial_segments = 10
	_mesh(hopper, "SprocketA", pulley_a, _steel, Vector3(1.16, -0.48, 0.0),
			Vector3(0.0, 0.0, PI / 2.0))
	_mesh(hopper, "SprocketB", pulley_b, _steel, Vector3(1.16, 0.2, 0.0),
			Vector3(0.0, 0.0, PI / 2.0))
	for z: float in [-0.075, 0.075]:
		_box(hopper, "Chain%d" % int(z > 0.0), _black, Vector3(1.16, -0.14, z),
				Vector3(0.02, 0.68, 0.02))
	for i: int in 7:
		_box(hopper, "Link%d" % i, _black, Vector3(1.16, -0.45 + 0.1 * float(i), 0.0),
				Vector3(0.03, 0.025, 0.16))
	_box(hopper, "ChainGuard", _ochre, Vector3(1.22, -0.14, 0.0), Vector3(0.02, 0.78, 0.24))
	_box(hopper, "JunctionBox", _steel, Vector3(1.38, -0.32, 0.0), Vector3(0.12, 0.12, 0.12))
	var terminal := CylinderMesh.new()
	terminal.top_radius = 0.012
	terminal.bottom_radius = 0.012
	terminal.height = 0.04
	terminal.radial_segments = 6
	for x_off: float in [-0.03, 0.03]:
		_mesh(hopper, "Terminal%d" % int(x_off > 0.0), terminal, _black,
				Vector3(1.38 + x_off, -0.24, 0.0), Vector3.ZERO)
	# Cable rises at rig x -2.0, outside the frame's wall-side post (rig -1.82) and the funnel.
	var port := Marker3D.new()
	port.name = "PowerPort"
	port.position = Vector3(1.38, -0.21, 0.0)
	port.add_to_group(&"machine_power_ports")
	port.set_meta(&"machine", &"scrap_hopper")
	port.set_meta(&"role", &"load")
	hopper.add_child(port)


## Mushroom stop button on a stalk, and the warning lamp on its mast; returns the lamp's light.
func build_lamp_and_stop() -> OmniLight3D:
	var red := MachineParts.dark(Color(0.4, 0.06, 0.05), 0.85)
	_box(hopper, "StopArm", _steel, Vector3(0.42, 0.0, 0.285), Vector3(0.03, 0.03, 0.08))
	_box(hopper, "StopBox", _ochre, Vector3(0.42, 0.0, 0.36), Vector3(0.12, 0.16, 0.08))
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.02
	stalk.bottom_radius = 0.02
	stalk.height = 0.08
	stalk.radial_segments = 8
	_mesh(hopper, "StopStalk", stalk, _steel, Vector3(0.42, 0.12, 0.36), Vector3.ZERO)
	var head := CylinderMesh.new()
	head.top_radius = 0.05
	head.bottom_radius = 0.05
	head.height = 0.04
	head.radial_segments = 10
	_mesh(hopper, "StopHead", head, red, Vector3(0.42, 0.18, 0.36), Vector3.ZERO)

	var mast_pos := Vector3(1.26, 0.0, -0.3)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.015
	mast.bottom_radius = 0.015
	mast.height = 0.55
	mast.radial_segments = 6
	_mesh(hopper, "LampMast", mast, _steel, mast_pos + Vector3(0.0, 0.905, 0.0), Vector3.ZERO)
	_box(hopper, "LampBase", _steel, mast_pos + Vector3(0.0, 0.64, 0.0), Vector3(0.1, 0.03, 0.1))
	var amber := MachineParts.emissive(Color(1.0, 0.6, 0.2), 1.6)
	_box(hopper, "WarnLamp", amber, mast_pos + Vector3(0.0, 1.2, 0.0), Vector3(0.09, 0.1, 0.09))
	_box(hopper, "LampCapTop", _steel, mast_pos + Vector3(0.0, 1.27, 0.0), Vector3(0.14, 0.02, 0.14))
	_box(hopper, "LampCapBottom", _steel, mast_pos + Vector3(0.0, 1.13, 0.0),
			Vector3(0.14, 0.02, 0.14))
	for sx: float in [-0.06, 0.06]:
		for sz: float in [-0.06, 0.06]:
			_box(hopper, "LampBar%d%d" % [int(sx > 0.0), int(sz > 0.0)], _steel,
					mast_pos + Vector3(sx, 1.2, sz), Vector3(0.01, 0.14, 0.01))
	var light := OmniLight3D.new()
	light.name = "WarnLight"
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 0.5
	light.omni_range = 2.0
	light.shadow_enabled = false
	light.light_cull_mask = VanLighting.LAYER_VAN_INTERIOR
	light.position = mast_pos + Vector3(0.0, 1.2, 0.0)
	hopper.add_child(light)
	return light


## Steel bar between two hopper-local points.
func _link(part_name: String, a: Vector3, b: Vector3) -> void:
	var inst := _box(hopper, part_name, _ochre, (a + b) * 0.5,
			Vector3(0.03, 0.03, a.distance_to(b)))
	inst.basis = Basis.looking_at((b - a).normalized(), Vector3.UP)


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
