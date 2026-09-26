class_name VanRelayRack
extends Node3D
## The cab-relay vital rebuilt as a relay rack (batteries on a high shelf, a knife switch and
## gauge on a backboard) whose motion, smoke and lamp follow the vital's HP.

var _lamp_mat: StandardMaterial3D


func _ready() -> void:
	var body := get_parent() as StaticBody3D
	if body == null:
		push_warning("VanRelayRack expects a StaticBody3D parent.")
		return
	var mesh := body.get_node_or_null("Mesh") as Node3D
	if mesh:
		mesh.visible = false
	transform = Transform3D(body.transform.basis.inverse(), Vector3.ZERO)

	var col := body.get_node_or_null("Collision") as CollisionShape3D
	if col:
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.15, 1.2, 0.38)
		col.shape = shape
		col.transform = transform * Transform3D(Basis(), Vector3(-0.02, -0.41, -0.21))

	var steel := MachineParts.dark(Color(0.2, 0.2, 0.19), 0.85)
	var board := MachineParts.dark(Color(0.16, 0.14, 0.11), 0.92)
	var casing := MachineParts.dark(Color(0.14, 0.17, 0.13), 0.88)
	var copper := MachineParts.dark(Color(0.42, 0.26, 0.16), 0.8)
	var face := MachineParts.dark(Color(0.45, 0.43, 0.38), 0.9)
	var lamp := MachineParts.emissive(Color(1.0, 0.45, 0.15), 1.6)
	_lamp_mat = lamp

	_build(steel, board, casing, copper, face, lamp)


func _build(steel: Material, board: Material, casing: Material, copper: Material, face: Material,
		lamp: Material) -> void:
	var backboard := MeshInstance3D.new()
	backboard.name = "Backboard"
	var backboard_mesh := BoxMesh.new()
	backboard_mesh.size = Vector3(1.1, 0.95, 0.03)
	backboard.mesh = backboard_mesh
	backboard.material_override = board
	backboard.position = Vector3(0.0, -0.5, -0.385)
	backboard.layers = 2
	add_child(backboard)

	var shelf := MeshInstance3D.new()
	shelf.name = "Shelf"
	var shelf_mesh := BoxMesh.new()
	shelf_mesh.size = Vector3(1.1, 0.04, 0.34)
	shelf.mesh = shelf_mesh
	shelf.material_override = steel
	shelf.position = Vector3(0.0, -0.02, -0.22)
	shelf.layers = 2
	add_child(shelf)

	var bracket_mesh := BoxMesh.new()
	bracket_mesh.size = Vector3(0.03, 0.2, 0.3)
	for x_sign: float in [-1.0, 1.0]:
		var bracket := MeshInstance3D.new()
		bracket.name = "Bracket%s" % ("L" if x_sign < 0.0 else "R")
		bracket.mesh = bracket_mesh
		bracket.material_override = steel
		bracket.position = Vector3(0.5 * x_sign, -0.12, -0.24)
		bracket.layers = 2
		add_child(bracket)

	var battery_xs: Array[float] = [-0.35, 0.0, 0.35]
	for battery_x: float in battery_xs:
		MachineParts.battery(self, Vector3(battery_x, 0.0, -0.22), casing, copper)

	var switch_root := MachineParts.knife_switch(self, Vector3(0.0, -0.89, -0.37), steel, copper)
	var gauge_root := MachineParts.gauge(self, Vector3(-0.35, -0.6, -0.37), steel, face)

	var cable_points := PackedVector3Array([
		Vector3(0.35, 0.05, -0.3),
		Vector3(0.48, -0.3, -0.36),
		Vector3(0.3, -0.75, -0.37),
		Vector3(0.08, -0.85, -0.37),
	])
	MachineParts.cable_bundle(self, cable_points, copper, 0.012, 3)

	var run_lamp := MeshInstance3D.new()
	run_lamp.name = "RunLamp"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.04, 0.04, 0.04)
	run_lamp.mesh = lamp_mesh
	run_lamp.material_override = lamp
	run_lamp.position = Vector3(0.35, -0.6, -0.36)
	run_lamp.layers = 2
	add_child(run_lamp)

	_wire_motion(switch_root, gauge_root, lamp)


func _wire_motion(switch_root: Node3D, gauge_root: Node3D, lamp: Material) -> void:
	var motion := MachineMotion.new()
	motion.name = "Motion"
	add_child(motion)

	var blade := switch_root.get_node_or_null("Blade") as Node3D
	if blade:
		motion.add_wobble(blade, 0.03, 7.0)
	var needle := gauge_root.get_node_or_null("Needle") as Node3D
	if needle:
		motion.add_wobble(needle, 0.35, 0.8)
	motion.add_flicker(lamp, &"emission_energy_multiplier", 1.6)

	_bind_damage(motion)


func _bind_damage(motion: MachineMotion) -> void:
	var damage := MachineDamage.new()
	damage.name = "Damage"
	damage.smoke_offset = Vector3(0.0, 0.1, -0.22)
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
