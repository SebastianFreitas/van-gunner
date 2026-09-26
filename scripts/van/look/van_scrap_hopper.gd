class_name VanScrapHopper
extends Node3D
## The loot hopper dressed as a scrap hopper (funnel, toothed crusher drum, chute, drive motor
## and belt, legs) that churns when loot drops and follows the hopper vital's HP.

var _lamp_mat: StandardMaterial3D
var _tween: Tween
var _drum_kick: Node3D
var _chute: Node3D
var _last_queue: int = 0
var _queue_wired: bool = false


func _ready() -> void:
	var body := get_parent() as StaticBody3D
	if body == null:
		push_warning("VanScrapHopper expects a StaticBody3D parent.")
		return

	var mesh := body.get_node_or_null("Body") as MeshInstance3D
	if mesh:
		mesh.material_override = MachineParts.dark(Color(0.19, 0.17, 0.14), 0.88)

	var steel := MachineParts.dark(Color(0.2, 0.2, 0.19), 0.85)
	var rust := MachineParts.dark(Color(0.3, 0.18, 0.1), 0.9)
	var rubber := MachineParts.dark(Color(0.06, 0.06, 0.06), 0.95)
	var lamp := MachineParts.emissive(Color(1.0, 0.45, 0.15), 1.6)
	_lamp_mat = lamp

	_build(steel, rust, rubber, lamp)

	_last_queue = LootCollector.queue_size()
	if LootCollector.has_method("queue_size"):
		LootCollector.queue_changed.connect(_on_queue_changed)
		_queue_wired = true

	_bind_damage(body)


func _exit_tree() -> void:
	if _queue_wired and LootCollector.queue_changed.is_connected(_on_queue_changed):
		LootCollector.queue_changed.disconnect(_on_queue_changed)


func _build(steel: Material, rust: Material, rubber: Material, lamp: Material) -> void:
	var funnel := MeshInstance3D.new()
	funnel.name = "Funnel"
	var funnel_mesh := CylinderMesh.new()
	funnel_mesh.top_radius = 0.42
	funnel_mesh.bottom_radius = 0.2
	funnel_mesh.height = 0.36
	funnel_mesh.radial_segments = 4
	funnel_mesh.rings = 1
	funnel.mesh = funnel_mesh
	funnel.material_override = rust
	funnel.position = Vector3(0.0, 0.77, 0.0)
	funnel.rotation = Vector3(0.0, PI / 4.0, 0.0)
	funnel.layers = 2
	add_child(funnel)

	_build_drum(steel, rust)
	_build_chute(steel)
	_build_drive(rust, rubber)

	var leg_size := Vector3(0.05, 0.85, 0.05)
	for x_sign: float in [-1.0, 1.0]:
		_box(self, "Leg%s" % ("L" if x_sign < 0.0 else "R"), steel,
				Vector3(0.3 * x_sign, -1.015, -0.2), leg_size)

	var run_lamp := MeshInstance3D.new()
	run_lamp.name = "RunLamp"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.04, 0.04, 0.04)
	run_lamp.mesh = lamp_mesh
	run_lamp.material_override = lamp
	run_lamp.position = Vector3(0.28, 0.5, 0.27)
	run_lamp.layers = 2
	add_child(run_lamp)

	_wire_motion(lamp)


func _build_drum(steel: Material, rust: Material) -> void:
	_drum_kick = Node3D.new()
	_drum_kick.name = "DrumKick"
	_drum_kick.position = Vector3(0.0, 0.44, 0.33)
	add_child(_drum_kick)

	var drum := Node3D.new()
	drum.name = "Drum"
	_drum_kick.add_child(drum)

	var drum_body := MeshInstance3D.new()
	drum_body.name = "DrumBody"
	var drum_mesh := CylinderMesh.new()
	drum_mesh.top_radius = 0.11
	drum_mesh.bottom_radius = 0.11
	drum_mesh.height = 0.62
	drum_mesh.radial_segments = 8
	drum_body.mesh = drum_mesh
	drum_body.material_override = steel
	drum_body.rotation = Vector3(0.0, 0.0, PI / 2.0)
	drum_body.layers = 2
	drum.add_child(drum_body)

	var tooth_size := Vector3(0.6, 0.035, 0.05)
	for i: int in 6:
		var angle := TAU * float(i) / 6.0
		var tooth := _box(drum, "Tooth%d" % i, rust,
				Vector3(0.0, 0.12 * cos(angle), 0.12 * sin(angle)), tooth_size)
		tooth.rotation = Vector3(angle, 0.0, 0.0)


func _build_chute(steel: Material) -> void:
	_chute = Node3D.new()
	_chute.name = "Chute"
	_chute.position = Vector3(0.0, -0.4, 0.3)
	add_child(_chute)

	var tray := _box(_chute, "Tray", steel, Vector3(0.0, -0.05, 0.12), Vector3(0.36, 0.03, 0.36))
	tray.rotation = Vector3(deg_to_rad(-20.0), 0.0, 0.0)

	var lip_size := Vector3(0.02, 0.08, 0.36)
	for x_sign: float in [-1.0, 1.0]:
		var lip := _box(_chute, "Lip%s" % ("L" if x_sign < 0.0 else "R"), steel,
				Vector3(0.18 * x_sign, -0.05, 0.12), lip_size)
		lip.rotation = Vector3(deg_to_rad(-20.0), 0.0, 0.0)


func _build_drive(rust: Material, rubber: Material) -> void:
	MachineParts.motor(self, Vector3(0.55, 0.44, 0.1), rust, 0.28, 0.1)
	MachineParts.belt(self, Vector3(0.55, 0.44, 0.25), Vector3(0.31, 0.44, 0.33), rubber, 0.05, 0.08)


func _box(parent: Node3D, part_name: String, mat: Material, pos: Vector3,
		size: Vector3) -> MeshInstance3D:
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


func _wire_motion(lamp: Material) -> void:
	var motion := MachineMotion.new()
	motion.name = "Motion"
	add_child(motion)

	var drum := _drum_kick.get_node_or_null("Drum") as Node3D
	if drum:
		motion.add_spin(drum, Vector3.RIGHT, 2.5)
	var motor_root := get_node_or_null("Motor") as Node3D
	var shaft: Node3D = null
	if motor_root:
		shaft = motor_root.get_node_or_null("Shaft") as Node3D
	if shaft:
		motion.add_spin(shaft, Vector3.RIGHT, 12.0)
	motion.add_flicker(lamp, &"emission_energy_multiplier", 1.6)


func _bind_damage(body: StaticBody3D) -> void:
	var damage := MachineDamage.new()
	damage.name = "Damage"
	damage.smoke_offset = Vector3(0.0, 1.0, 0.0)
	add_child(damage)
	damage.state_changed.connect(_on_state_changed)
	var vital := body.get_node_or_null("VanVital") as VanVital
	var motion := get_node_or_null("Motion") as MachineMotion
	if vital and motion:
		damage.bind(vital, motion)


func _on_state_changed(state: int) -> void:
	var color := Color(1.0, 0.45, 0.15)
	if state == MachineDamage.State.HURT:
		color = Color(1.0, 0.25, 0.1)
	elif state == MachineDamage.State.DYING:
		color = Color(1.0, 0.1, 0.05)
	_lamp_mat.emission = color


func _on_queue_changed() -> void:
	var n := LootCollector.queue_size()
	if n < _last_queue:
		_churn(true)
	elif n > _last_queue:
		_churn(false)
	_last_queue = n


func _churn(dispense: bool) -> void:
	if _tween:
		_tween.kill()
	_drum_kick.rotation.x = wrapf(_drum_kick.rotation.x, 0.0, TAU)
	var spin := TAU if dispense else PI
	_tween = create_tween()
	_tween.tween_property(_drum_kick, "rotation:x", _drum_kick.rotation.x + spin, 0.35)
	if dispense:
		_tween.parallel().tween_property(_chute, "position:z", 0.34, 0.1)
		_tween.chain().tween_property(_chute, "position:z", 0.3, 0.1)
