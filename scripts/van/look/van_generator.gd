class_name VanGenerator
extends Node3D
## The fuse-box vital rebuilt as a scrap generator (motor, flywheel and belt, fan, gauge, jerry cans, exhaust to a roof vent) whose motion and smoke follow the vital's HP.

var _lamp_mat: StandardMaterial3D


func _ready() -> void:
	var body := get_parent() as StaticBody3D
	if body == null:
		push_warning("VanGenerator expects a StaticBody3D parent.")
		return
	var mesh := body.get_node_or_null("Mesh") as Node3D
	if mesh:
		mesh.visible = false
	var collision := body.get_node_or_null("Collision") as CollisionShape3D
	if collision:
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.75, 1.0, 0.8)
		collision.shape = shape
		collision.position = Vector3(0.17, 0.01, 0.0)

	var steel := MachineParts.dark(Color(0.2, 0.2, 0.19), 0.85)
	var paint := MachineParts.dark(Color(0.32, 0.22, 0.12), 0.9)
	var rubber := MachineParts.dark(Color(0.06, 0.06, 0.06), 0.95)
	var face := MachineParts.dark(Color(0.45, 0.43, 0.38), 0.9)
	var lamp := MachineParts.emissive(Color(1.0, 0.45, 0.15), 1.6)
	_lamp_mat = lamp

	_build(steel, paint, rubber, face, lamp)


func _build(steel: Material, paint: Material, rubber: Material, face: Material,
		lamp: Material) -> void:
	var skid := MeshInstance3D.new()
	skid.name = "Skid"
	var skid_mesh := BoxMesh.new()
	skid_mesh.size = Vector3(0.72, 0.08, 0.78)
	skid.mesh = skid_mesh
	skid.material_override = steel
	skid.position = Vector3(0.17, -0.45, 0.0)
	skid.layers = 2
	add_child(skid)

	var motor_root := MachineParts.motor(self, Vector3(0.0, -0.41, 0.0), paint, 0.55, 0.2)
	var flywheel_pos := Vector3(0.36, -0.41 + 0.3 + 0.02, -0.1)
	var flywheel_root := MachineParts.flywheel(self, flywheel_pos, steel, 0.3)
	var hub_pos := flywheel_pos + Vector3(0.0, 0.3, 0.0)
	MachineParts.belt(self, Vector3(0.3, -0.17, 0.0), hub_pos, rubber, 0.06, 0.22)
	var fan_root := MachineParts.fan(self, Vector3(0.0, 0.1, 0.32), steel, 0.16)
	var gauge_root := MachineParts.gauge(self, Vector3(0.2, 0.2, 0.3), steel, face)
	MachineParts.jerry_can(self, Vector3(0.42, -0.49, 0.28), paint)
	MachineParts.jerry_can(self, Vector3(0.42, -0.49, -0.34), paint)
	MachineParts.pipe(self, Vector3(-0.15, 0.1, -0.2), Vector3(-0.15, 2.4, -0.2), steel, 0.05)
	MachineParts.vent(self, Vector3(-0.15, 2.4, -0.2), steel, 0.28)

	var run_lamp := MeshInstance3D.new()
	run_lamp.name = "RunLamp"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.04, 0.04, 0.04)
	run_lamp.mesh = lamp_mesh
	run_lamp.material_override = lamp
	run_lamp.position = Vector3(0.2, 0.05, 0.38)
	run_lamp.layers = 2
	add_child(run_lamp)

	_wire_motion(motor_root, flywheel_root, fan_root, gauge_root, lamp)


func _wire_motion(motor_root: Node3D, flywheel_root: Node3D, fan_root: Node3D,
		gauge_root: Node3D, lamp: Material) -> void:
	var motion := MachineMotion.new()
	motion.name = "Motion"
	add_child(motion)

	var shaft := motor_root.get_node_or_null("Shaft") as Node3D
	if shaft:
		motion.add_spin(shaft, Vector3.RIGHT, 18.0)
	var wheel := flywheel_root.get_node_or_null("Wheel") as Node3D
	if wheel:
		motion.add_spin(wheel, Vector3.RIGHT, 6.0)
	var blades := fan_root.get_node_or_null("Blades") as Node3D
	if blades:
		motion.add_spin(blades, Vector3.FORWARD, 14.0)
	motion.add_pump(motor_root, Vector3.UP, 0.004, 22.0)
	var needle := gauge_root.get_node_or_null("Needle") as Node3D
	if needle:
		motion.add_wobble(needle, 0.25, 1.3)
	motion.add_flicker(lamp, &"emission_energy_multiplier", 1.6)

	_bind_damage(motion)


func _bind_damage(motion: MachineMotion) -> void:
	var damage := MachineDamage.new()
	damage.name = "Damage"
	damage.smoke_offset = Vector3(-0.15, 2.3, -0.2)
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
