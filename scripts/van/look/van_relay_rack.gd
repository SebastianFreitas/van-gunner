class_name VanRelayRack
extends Node3D
## The cab-relay vital rebuilt as an angle-iron relay rack (six batteries on a high shelf, a
## green relay cabinet, knife switch, fuses, gauge, a caged trouble lamp and power ports) whose
## motion, smoke and lamps follow the vital's HP.

const _Parts := preload("res://scripts/van/look/van_relay_rack_parts.gd")

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

	# Rack-local axes equal rig axes, so the box is sized and placed in rig terms: x -0.62..0.66,
	# y -1.0..0.315, z -0.40..-0.005 (the rack's parts, minus the bottom 5 cm of backboard).
	var col := body.get_node_or_null("Collision") as CollisionShape3D
	if col:
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.28, 1.315, 0.395)
		col.shape = shape
		col.transform = transform * Transform3D(Basis(), Vector3(0.02, -0.3425, -0.2025))

	var parts: RefCounted = _Parts.new(self)
	parts.build()
	_lamp_mat = parts.run_lamp_mat
	_wire_motion(parts.switch_root, parts.gauge_root, parts.run_lamp_mat, parts.bulb_mat,
			parts.trouble_light)


func _wire_motion(switch_root: Node3D, gauge_root: Node3D, lamp: Material, bulb: Material,
		light: Light3D) -> void:
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
	motion.add_flicker(bulb, &"emission_energy_multiplier", 1.4)
	motion.add_flicker(light, &"light_energy", 0.45)

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
