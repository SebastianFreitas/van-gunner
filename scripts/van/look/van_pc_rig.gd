class_name VanPcRig
extends Node3D
## The request board dressed as a scrap PC rig (plank desk on crates, towers, three CRTs, one on
## crt_screen.gdshader, keyboard, clutter, a desk lamp and a PowerPort) that stutters on at
## power-up; E still opens the skill tree.

const Parts := preload("res://scripts/van/look/van_pc_rig_parts.gd")

var _screen: ShaderMaterial
var _parts: Parts


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

	# Covers the desk, crates and gear (x -0.405..0.735, z 0..0.52), not the stool or the wall bits.
	var col := body.get_node_or_null("Collision") as CollisionShape3D
	if col:
		var box := BoxShape3D.new()
		box.size = Vector3(1.14, 1.0, 0.52)
		col.shape = box
		col.transform = transform * Transform3D(Basis(), Vector3(0.165, -0.45, 0.26))

	_screen = ShaderMaterial.new()
	_screen.shader = preload("res://scenes/van/crt_screen.gdshader")
	_screen.set_shader_parameter(&"boot", 0.0)

	# Blinks the disk and router LEDs; a separate node so the damage-free rig keeps it simple.
	var led_motion := MachineMotion.new()
	led_motion.name = "LedMotion"
	add_child(led_motion)
	_parts = Parts.new(self, led_motion)
	_parts.build_desk()
	_parts.build_gear(_screen)
	_parts.build_clutter()
	_parts.build_wall()
	_parts.build_stool()
	_parts.build_lamp()

	var stats := VanStatsCrt.new()
	stats.name = "StatsCrt"
	stats.position = Vector3(-0.27, 0.4, 0.26)
	add_child(stats)
	_boot_flicker()


func _boot_flicker() -> void:
	var lamp := _parts.lamp
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_method(func(v: float) -> void:
		_screen.set_shader_parameter(&"boot", v)
		lamp.light_energy = Parts.LAMP_ENERGY * v * (0.8 + 0.2 * sin(v * 60.0)), 0.0, 1.0, 1.4)
	tw.tween_callback(func() -> void: lamp.light_energy = Parts.LAMP_ENERGY)
