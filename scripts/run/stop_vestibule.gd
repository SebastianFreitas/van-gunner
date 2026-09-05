class_name StopVestibule
extends Node3D

## Shared mouth for every roadside stop. Content (shop, garage, mechanic, …)
## instances under ContentMount in the same shop-bay frame. The van docks in the
## first ~5 m, in front of a vertical roll-up door; interiors live behind it.

const DOOR_X := 5.6
const DOOR_WIDTH := 8.2
const DOOR_HEIGHT := 6.2
const DOOR_THICKNESS := 0.14
const SLAT_COUNT := 11
const OPEN_LIFT := 6.45
const OPEN_DURATION := 1.4

var _door_leaf: Node3D
var _door_collision: CollisionShape3D
var _door_tween: Tween
var _door_open := false


func mount_content(scene: PackedScene) -> void:
	var mount := get_node_or_null("ContentMount") as Node3D
	if mount == null:
		mount = self
	if scene == null:
		push_error("StopVestibule: cannot mount stop content.")
		return
	var content := scene.instantiate() as Node3D
	if content == null:
		push_error("StopVestibule: stop content failed to instantiate.")
		return
	mount.add_child(content)


func open_door() -> void:
	_animate_door(true)


func close_door() -> void:
	_animate_door(false)


func _ready() -> void:
	_build_door()
	_build_lights()


func _build_door() -> void:
	var steel := _steel_material()
	var slat := _slat_material()
	var rust := _guide_material()

	var door := Node3D.new()
	door.name = "GarageDoor"
	door.position = Vector3(DOOR_X, 0.0, 0.0)
	add_child(door)

	_add_box(
		door,
		"Lintel",
		Vector3(0.36, 0.28, DOOR_WIDTH + 0.55),
		Vector3(0.0, DOOR_HEIGHT + 0.12, 0.0),
		steel
	)
	_add_box(
		door,
		"GuideNegZ",
		Vector3(0.18, DOOR_HEIGHT + 0.2, 0.16),
		Vector3(0.0, DOOR_HEIGHT * 0.5, -DOOR_WIDTH * 0.5 - 0.08),
		rust
	)
	_add_box(
		door,
		"GuidePosZ",
		Vector3(0.18, DOOR_HEIGHT + 0.2, 0.16),
		Vector3(0.0, DOOR_HEIGHT * 0.5, DOOR_WIDTH * 0.5 + 0.08),
		rust
	)

	_door_leaf = Node3D.new()
	_door_leaf.name = "Leaf"
	_door_leaf.position = Vector3(0.0, 0.0, 0.0)
	door.add_child(_door_leaf)

	var slat_h := DOOR_HEIGHT / float(SLAT_COUNT)
	for i in SLAT_COUNT:
		var y := slat_h * (float(i) + 0.5)
		_add_box(
			_door_leaf,
			"Slat_%d" % i,
			Vector3(DOOR_THICKNESS, slat_h * 0.88, DOOR_WIDTH),
			Vector3(0.0, y, 0.0),
			slat
		)
		_add_box(
			_door_leaf,
			"Rib_%d" % i,
			Vector3(DOOR_THICKNESS + 0.02, 0.04, DOOR_WIDTH + 0.04),
			Vector3(0.0, y + slat_h * 0.38, 0.0),
			steel
		)

	var body := StaticBody3D.new()
	body.name = "DoorBlock"
	_door_leaf.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(DOOR_THICKNESS + 0.04, DOOR_HEIGHT, DOOR_WIDTH)
	_door_collision = CollisionShape3D.new()
	_door_collision.shape = shape
	_door_collision.position = Vector3(0.0, DOOR_HEIGHT * 0.5, 0.0)
	body.add_child(_door_collision)


func _build_lights() -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "MouthGlow"
	lamp.position = Vector3(2.4, 4.6, 0.0)
	lamp.light_color = Color(1.0, 0.86, 0.62, 1.0)
	lamp.light_energy = 1.6
	lamp.omni_range = 8.0
	lamp.shadow_enabled = false
	add_child(lamp)

	var door_lamp := OmniLight3D.new()
	door_lamp.name = "DoorGlow"
	door_lamp.position = Vector3(DOOR_X - 0.6, 4.2, 0.0)
	door_lamp.light_color = Color(0.95, 0.78, 0.48, 1.0)
	door_lamp.light_energy = 1.15
	door_lamp.omni_range = 6.5
	door_lamp.shadow_enabled = false
	add_child(door_lamp)


func _animate_door(open: bool) -> void:
	if _door_leaf == null:
		return
	if _door_open == open:
		return
	_door_open = open
	if _door_tween:
		_door_tween.kill()
	_door_tween = create_tween()
	_door_tween.set_trans(Tween.TRANS_CUBIC)
	_door_tween.set_ease(Tween.EASE_IN_OUT)
	var target_y := OPEN_LIFT if open else 0.0
	_door_tween.tween_property(_door_leaf, "position:y", target_y, OPEN_DURATION)
	if _door_collision:
		_door_collision.disabled = open


func _add_box(
	parent: Node3D, node_name: String, size: Vector3, pos: Vector3, material: Material
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)


func _steel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.09, 0.085, 1.0)
	mat.metallic = 0.82
	mat.roughness = 0.48
	return mat


func _slat_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.15, 0.13, 1.0)
	mat.metallic = 0.62
	mat.roughness = 0.58
	return mat


func _guide_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.12, 0.06, 1.0)
	mat.metallic = 0.35
	mat.roughness = 0.72
	return mat
