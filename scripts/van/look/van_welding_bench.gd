class_name VanWeldingBench
extends Node3D
## The crafting-bench vital rebuilt as a welding bench (heavy steel bench, gas bottles, welder
## box, vice, grinder with shrouds, pegboard with tools and hood, roof vent, cool arm lamp) whose
## motion, smoke and lamps follow the vital's HP.

const _Parts := preload("res://scripts/van/look/van_welding_bench_parts.gd")

var _lamp_mat: StandardMaterial3D
var _parts: _Parts
var _work_light: OmniLight3D


func _ready() -> void:
	var body := get_parent() as StaticBody3D
	if body == null:
		push_warning("VanWeldingBench expects a StaticBody3D parent.")
		return
	var mesh := body.get_node_or_null("Mesh") as Node3D
	if mesh:
		mesh.visible = false
	transform = Transform3D(body.transform.basis.inverse(), Vector3.ZERO)
	_fit_collision(body)

	var steel := MachineParts.dark(Color(0.2, 0.2, 0.19), 0.85)
	var top := MachineParts.dark(Color(0.13, 0.13, 0.13), 0.8)
	var board := MachineParts.dark(Color(0.24, 0.19, 0.13), 0.92)
	var paint := MachineParts.dark(Color(0.32, 0.22, 0.12), 0.9)
	var face := MachineParts.dark(Color(0.45, 0.43, 0.38), 0.9)
	var lamp := MachineParts.emissive(Color(1.0, 0.45, 0.15), 1.6)
	_lamp_mat = lamp

	_build(steel, top, board, paint, face, lamp)


## Collision box matched to the tabletop footprint (rig x 1.10..2.20, z -0.49..0.73). The body
## is turned 90 degrees, so its local x is rig -z and its local z is rig +x.
func _fit_collision(body: StaticBody3D) -> void:
	var col := body.get_node_or_null("Collision") as CollisionShape3D
	if col == null:
		return
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.22, 0.85, 1.1)
	col.shape = shape
	col.position = Vector3(-0.05, 0.0, 0.02)


## Box mesh helper matching the sibling rack's inline pattern, generalised to any parent.
func _box(parent: Node3D, part_name: String, mat: Material, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = part_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	inst.mesh = box_mesh
	inst.material_override = mat
	inst.position = pos
	inst.layers = 2
	parent.add_child(inst)
	return inst


func _build(steel: Material, top: Material, board: Material, paint: Material, face: Material,
		lamp: Material) -> void:
	_parts = _Parts.new(self)
	var frame := MachineParts.dark(Color(0.26, 0.08, 0.08), 0.9)
	_box(self, "Top", top, Vector3(0.02, 0.395, 0.05), Vector3(1.1, 0.06, 1.22))

	var leg_xs: Array[float] = [-0.495, 0.535]
	var leg_zs: Array[float] = [-0.525, 0.625]
	for leg_x: float in leg_xs:
		for leg_z: float in leg_zs:
			var leg_name := "Leg%s%s" % [("L" if leg_x < 0.0 else "R"), ("F" if leg_z < 0.0 else "B")]
			_box(self, leg_name, steel, Vector3(leg_x, -0.03, leg_z), Vector3(0.07, 0.79, 0.07))

	# Apron under the slab reads as a heavy welded frame; the shelf stays open to the aisle.
	_box(self, "ApronFront", frame, Vector3(0.02, 0.325, -0.525), Vector3(1.0, 0.08, 0.02))
	_box(self, "ApronBack", frame, Vector3(0.02, 0.325, 0.625), Vector3(1.0, 0.08, 0.02))
	_box(self, "ApronL", frame, Vector3(-0.495, 0.325, 0.05), Vector3(0.02, 0.08, 1.2))
	_box(self, "ApronR", frame, Vector3(0.535, 0.325, 0.05), Vector3(0.02, 0.08, 1.2))
	_box(self, "Shelf", steel, Vector3(0.02, -0.3, 0.05), Vector3(1.03, 0.03, 1.15))
	MachineParts.jerry_can(self, Vector3(-0.28, -0.285, -0.3), paint)

	_build_vice(steel)

	var motor_root := MachineParts.motor(self, Vector3(-0.1, 0.425, 0.53), paint, 0.26, 0.07)
	var wheel_a_root := MachineParts.flywheel(self, Vector3(-0.27, 0.435, 0.53), steel, 0.1)
	var wheel_b_root := MachineParts.flywheel(self, Vector3(0.07, 0.435, 0.53), steel, 0.1)

	var gauge_root := _build_pegboard(steel, board, face)
	MachineParts.vent(self, Vector3(-0.03, 2.4, 0.03), steel)

	var run_lamp := MeshInstance3D.new()
	run_lamp.name = "RunLamp"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.04, 0.04, 0.04)
	run_lamp.mesh = lamp_mesh
	run_lamp.material_override = lamp
	run_lamp.position = Vector3(-0.172, -0.16, 0.54)
	run_lamp.layers = 2
	add_child(run_lamp)

	_parts.build_shelf_kit()
	_parts.build_top_kit()
	_parts.build_mask()
	_parts.build_shrouds()
	_work_light = _parts.build_arm_lamp()

	_wire_motion(motor_root, wheel_a_root, wheel_b_root, gauge_root, lamp)


func _build_vice(steel: Material) -> void:
	var vice := Node3D.new()
	vice.name = "Vice"
	vice.position = Vector3(-0.4, 0.425, -0.28)
	add_child(vice)
	_box(vice, "Body", steel, Vector3(0.0, 0.06, 0.0), Vector3(0.16, 0.12, 0.22))
	_box(vice, "FixedJaw", steel, Vector3(0.0, 0.17, 0.1), Vector3(0.16, 0.1, 0.03))
	_box(vice, "MovingJaw", steel, Vector3(0.0, 0.17, -0.08), Vector3(0.16, 0.1, 0.03))
	_box(vice, "Handle", steel, Vector3(-0.1, 0.1, -0.12), Vector3(0.02, 0.02, 0.3))


## Pegboard stands edge-on to the aisle at the bench's front end, so it never blocks the
## windows; tools and the gauge hang on its front face.
func _build_pegboard(steel: Material, board: Material, face: Material) -> Node3D:
	_box(self, "Pegboard", board, Vector3(0.02, 0.875, -0.49), Vector3(0.62, 0.9, 0.03))

	var wrench_xs: Array[float] = [-0.22, -0.15, -0.08]
	for i: int in range(wrench_xs.size()):
		_box(self, "Wrench%d" % i, steel, Vector3(wrench_xs[i], 1.05, -0.5125), Vector3(0.03, 0.22, 0.015))

	_box(self, "HammerHandle", steel, Vector3(0.12, 1.0, -0.5125), Vector3(0.025, 0.28, 0.02))
	_box(self, "HammerHead", steel, Vector3(0.12, 1.14, -0.5125), Vector3(0.1, 0.04, 0.04))

	# Gauge face is on its local +z, so turn it to look out of the front.
	var gauge := MachineParts.gauge(self, Vector3(0.22, 0.6, -0.52), steel, face)
	gauge.rotation.y = PI
	return gauge


func _wire_motion(motor_root: Node3D, wheel_a_root: Node3D, wheel_b_root: Node3D,
		gauge_root: Node3D, lamp: Material) -> void:
	var motion := MachineMotion.new()
	motion.name = "Motion"
	add_child(motion)

	var wheel_a := wheel_a_root.get_node_or_null("Wheel") as Node3D
	if wheel_a:
		motion.add_spin(wheel_a, Vector3.RIGHT, 30.0)
	var wheel_b := wheel_b_root.get_node_or_null("Wheel") as Node3D
	if wheel_b:
		motion.add_spin(wheel_b, Vector3.RIGHT, 30.0)
	var shaft := motor_root.get_node_or_null("Shaft") as Node3D
	if shaft:
		motion.add_spin(shaft, Vector3.RIGHT, 30.0)
	var needle := gauge_root.get_node_or_null("Needle") as Node3D
	if needle:
		motion.add_wobble(needle, 0.3, 1.1)
	motion.add_flicker(lamp, &"emission_energy_multiplier", 1.6)
	motion.add_flicker(_work_light, &"light_energy", 0.5)
	motion.add_flicker(_parts.bulb_mat, &"emission_energy_multiplier", 2.2)

	_bind_damage(motion)


func _bind_damage(motion: MachineMotion) -> void:
	var damage := MachineDamage.new()
	damage.name = "Damage"
	damage.smoke_offset = Vector3(-0.1, 0.6, 0.53)
	add_child(damage)
	damage.state_changed.connect(_on_state_changed)
	var body := get_parent() as StaticBody3D
	var vital: VanVital = null
	if body:
		vital = body.get_node_or_null("VanVital") as VanVital
	if vital:
		damage.bind(vital, motion)


func _on_state_changed(state: int) -> void:
	var color := Color(1.0, 0.45, 0.15)
	if state == MachineDamage.State.HURT:
		color = Color(1.0, 0.25, 0.1)
	elif state == MachineDamage.State.DYING:
		color = Color(1.0, 0.1, 0.05)
	_lamp_mat.emission = color
