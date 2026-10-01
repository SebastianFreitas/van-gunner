class_name VanScrapHopper
extends Node3D
## The loot hopper dressed as a slim scrap hopper stack (cabinet, crusher cage with a toothed drum,
## ochre funnel, catch tray, pull lever, warning lamp) that churns when loot drops and follows the
## hopper vital's HP.

const _Parts := preload("res://scripts/van/look/van_scrap_hopper_parts.gd")

var _lamp_mat: StandardMaterial3D
var _tween: Tween
var _lever_tween: Tween
var _drum_kick: Node3D
var _warn_light: OmniLight3D
var _last_queue: int = 0
var _queue_wired: bool = false


func _ready() -> void:
	var body := get_parent() as StaticBody3D
	if body == null:
		push_warning("VanScrapHopper expects a StaticBody3D parent.")
		return

	for hidden: String in ["Body", "Button"]:
		var mesh := body.get_node_or_null(hidden) as MeshInstance3D
		if mesh:
			mesh.visible = false
	# Footprint: the whole slim stack, local x -0.40..0.40, z -0.225..0.225, floor to y 1.40.
	var collision := body.get_node_or_null("Collision") as CollisionShape3D
	if collision:
		var box := BoxShape3D.new()
		box.size = Vector3(0.8, 2.74, 0.45)
		collision.shape = box
		collision.position = Vector3(0.0, -0.07, 0.0)

	var steel := MachineParts.dark(Color(0.2, 0.2, 0.19), 0.75)
	var rust := MachineParts.dark(Color(0.3, 0.18, 0.1), 0.9)
	var lamp := MachineParts.emissive(Color(1.0, 0.45, 0.15), 1.6)
	_lamp_mat = lamp

	_build(steel, rust, lamp)

	_last_queue = LootCollector.queue_size()
	if LootCollector.has_method("queue_size"):
		LootCollector.queue_changed.connect(_on_queue_changed)
		_queue_wired = true

	_bind_damage(body)


func _exit_tree() -> void:
	if _queue_wired and LootCollector.queue_changed.is_connected(_on_queue_changed):
		LootCollector.queue_changed.disconnect(_on_queue_changed)
	if _lever_tween:
		_lever_tween.kill()


func _build(steel: Material, rust: Material, lamp: Material) -> void:
	_build_drum(steel, rust)
	# Turned around so the shaft faces the drum; the axis lines up with the drum's;
	# the belt's first pulley is the drum pulley.
	var motor := MachineParts.motor(self, Vector3(0.33, 0.22, 0.0), rust, 0.26, 0.1)
	motor.rotation.y = PI
	MachineParts.belt(self, Vector3(0.17, 0.36, 0.0), Vector3(0.25, 0.36, 0.0), steel, 0.06, 0.075)

	var run_lamp := MeshInstance3D.new()
	run_lamp.name = "RunLamp"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.04, 0.04, 0.04)
	run_lamp.mesh = lamp_mesh
	run_lamp.material_override = lamp
	run_lamp.position = Vector3(0.27, 0.0, 0.235)
	run_lamp.layers = 2
	add_child(run_lamp)

	var parts: RefCounted = _Parts.new(self)
	parts.build_skid_and_tray()
	parts.build_cabinet()
	parts.build_chute()
	parts.build_lever()
	parts.build_cage()
	parts.build_funnel()
	_warn_light = parts.build_lamp()
	parts.build_port()

	_wire_motion(lamp)


func _build_drum(steel: Material, rust: Material) -> void:
	_drum_kick = Node3D.new()
	_drum_kick.name = "DrumKick"
	_drum_kick.position = Vector3(-0.1, 0.36, 0.0)
	add_child(_drum_kick)

	var drum := Node3D.new()
	drum.name = "Drum"
	_drum_kick.add_child(drum)

	var drum_body := MeshInstance3D.new()
	drum_body.name = "DrumBody"
	var drum_mesh := CylinderMesh.new()
	drum_mesh.top_radius = 0.16
	drum_mesh.bottom_radius = 0.16
	drum_mesh.height = 0.5
	drum_mesh.radial_segments = 8
	drum_body.mesh = drum_mesh
	drum_body.material_override = steel
	drum_body.rotation = Vector3(0.0, 0.0, PI / 2.0)
	drum_body.layers = 2
	drum.add_child(drum_body)

	var tooth_size := Vector3(0.4, 0.04, 0.05)
	for i: int in 6:
		var angle := TAU * float(i) / 6.0
		var tooth := _box(drum, "Tooth%d" % i, rust,
				Vector3(0.0, 0.17 * cos(angle), 0.17 * sin(angle)), tooth_size)
		tooth.rotation = Vector3(angle, 0.0, 0.0)


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
	motion.add_flicker(_warn_light, &"light_energy", 0.5)


func _bind_damage(body: StaticBody3D) -> void:
	var damage := MachineDamage.new()
	damage.name = "Damage"
	damage.smoke_offset = Vector3(0.0, 0.9, 0.0)
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
		_throw_lever()
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


## Yanks the pull lever forward and lets it spring back when an item is dispensed.
func _throw_lever() -> void:
	var pivot := get_node_or_null("LeverPivot") as Node3D
	if pivot == null:
		return
	if _lever_tween:
		_lever_tween.kill()
	_lever_tween = create_tween()
	_lever_tween.tween_property(pivot, "rotation:x", 1.0, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lever_tween.tween_property(pivot, "rotation:x", 0.0, 0.40) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
