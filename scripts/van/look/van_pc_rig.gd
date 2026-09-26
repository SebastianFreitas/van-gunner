class_name VanPcRig
extends Node3D
## The request board dressed as a scrap PC rig (desk on crates, beige towers, a green-phosphor
## CRT on crt_screen.gdshader, keyboard, cables) that stutters on at power-up; E still opens the
## skill tree.

var _screen: ShaderMaterial


func _ready() -> void:
	var body := get_parent() as StaticBody3D
	if body == null:
		push_warning("VanPcRig expects a StaticBody3D parent.")
		return
	var board_mesh := body.get_node_or_null("Board") as Node3D
	if board_mesh:
		board_mesh.visible = false
	var inset_mesh := body.get_node_or_null("Inset") as Node3D
	if inset_mesh:
		inset_mesh.visible = false
	transform = Transform3D(body.transform.basis.inverse(), Vector3.ZERO)

	var col := body.get_node_or_null("Collision") as CollisionShape3D
	if col:
		var box := BoxShape3D.new()
		box.size = Vector3(0.95, 1.0, 0.42)
		col.shape = box
		col.transform = transform * Transform3D(Basis(), Vector3(0.07, -0.45, 0.16))

	var beige := MachineParts.dark(Color(0.42, 0.39, 0.32), 0.85)
	var wood := MachineParts.dark(Color(0.2, 0.15, 0.1), 0.92)
	var crate := MachineParts.dark(Color(0.16, 0.13, 0.09), 0.92)
	var rubber := MachineParts.dark(Color(0.06, 0.06, 0.06), 0.95)
	var led := MachineParts.emissive(Color(0.3, 1.0, 0.4), 1.2)

	var screen := ShaderMaterial.new()
	screen.shader = preload("res://scenes/van/crt_screen.gdshader")
	screen.set_shader_parameter(&"boot", 0.0)
	_screen = screen

	_build(beige, wood, crate, rubber, led, screen)
	_boot_flicker()


## Box mesh helper matching the sibling bench's inline pattern, generalised to any parent.
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


func _build(beige: Material, wood: Material, crate: Material, rubber: Material, led: Material,
		screen: Material) -> void:
	_box(self, "DeskTop", wood, Vector3(0.07, -0.2, 0.16), Vector3(0.9, 0.04, 0.42))

	_box(self, "CrateL", crate, Vector3(-0.25, -0.585, 0.16), Vector3(0.25, 0.73, 0.38))
	_box(self, "CrateR", crate, Vector3(0.39, -0.585, 0.16), Vector3(0.25, 0.73, 0.38))
	var crate_slots: Array[Array] = [["L", -0.25], ["R", 0.39]]
	for slot: Array in crate_slots:
		var label: String = slot[0]
		var crate_x: float = slot[1]
		_box(self, "SlatUpper%s" % label, wood, Vector3(crate_x, -0.45, -0.03), Vector3(0.26, 0.03, 0.39))
		_box(self, "SlatLower%s" % label, wood, Vector3(crate_x, -0.75, -0.03), Vector3(0.26, 0.03, 0.39))

	MachineParts.tower_pc(self, Vector3(-0.25, -0.18, 0.12), beige, led)
	MachineParts.tower_pc(self, Vector3(0.07, -0.95, 0.14), beige, led)

	MachineParts.crt(self, Vector3(0.2, -0.18, 0.14), beige, screen, 0.4)

	MachineParts.keyboard(self, Vector3(0.15, -0.18, 0.31), beige)

	var desk_up_points: PackedVector3Array = [
		Vector3(-0.25, 0.1, 0.02), Vector3(-0.34, 0.5, -0.02), Vector3(-0.34, 1.9, -0.02),
	]
	MachineParts.cable_bundle(self, desk_up_points, rubber, 0.015, 3)

	var floor_to_crt_points: PackedVector3Array = [
		Vector3(0.07, -0.55, 0.05), Vector3(0.1, -0.25, 0.02), Vector3(0.2, -0.1, 0.05),
	]
	MachineParts.cable_bundle(self, floor_to_crt_points, rubber, 0.015, 3)


func _boot_flicker() -> void:
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_method(func(v: float) -> void: _screen.set_shader_parameter(&"boot", v), 0.0, 1.0, 1.4)
