class_name VanGunPort
extends Node3D
## A slot gun port on a side door leaf: welded frame and a steel plate sliding in a track, seen from inside and outside.

const EYE_Y := 1.5            ## rig-space height of the slot centre
const PORT_Z := -0.55         ## leaf-local z of the slot centre (toward the cab)
const SLOT_HALF_Z := 0.26
const SLOT_HALF_Y := 0.09
const SLIDE_TIME := 0.25

const DOOR_THICKNESS := 0.14  ## matches side_door_leaf.gd's leaf shell thickness
const BAR := 0.07             ## frame bar cross-section (inner frame)
const OUTER_BAR_THICK := 0.03 ## outer frame bar depth (x)
const INNER_FRAME_THICK := 0.04
const PROUD := 0.01

const PASS_GROUP := &"gun_port_leaf"  ## colliders a shot may pass through when it crosses an open port's slot
const PORT_GROUP := &"gun_ports"

var _plate: Node3D            ## pivot holding the plate + handle; slides along +Z to open
var _open := false
var _tween: Tween
var _layer := 2                ## render layer _box assigns before add_child; 1 while building outer parts
var _slot_y := 0.0             ## local y of the slot centre, set in setup
var _interact: StaticBody3D    ## layer-2 hit target that toggles this port


func setup(wall_sign: float, walls: VanSideWall, leaf_mid_y: float, leaf_x_ref: float) -> void:
	var ly := EYE_Y - leaf_mid_y
	var sx := wall_sign * (walls.wall_x_at(EYE_Y) - leaf_x_ref)
	var inner_x := sx - wall_sign * PROUD
	var outer_x := sx + wall_sign * (DOOR_THICKNESS + PROUD)

	var steel := MachineParts.dark(Color(0.16, 0.16, 0.15), 0.82)
	var weld := MachineParts.dark(Color(0.22, 0.18, 0.13), 0.9)
	var rust := MachineParts.dark(Color(0.24, 0.13, 0.07), 0.93)
	var slot := MachineParts.dark(Color(0.01, 0.01, 0.01), 0.95)

	_build_inner(inner_x, ly, wall_sign, steel, weld, rust, slot)
	_build_outer(outer_x, ly, wall_sign, steel, rust, slot)

	_slot_y = ly
	add_to_group(PORT_GROUP)
	_build_interact(sx, ly, wall_sign)

	var leaf := get_parent()
	if leaf:
		for leaf_part_name in ["Blocker", "Interact"]:
			var leaf_part := leaf.get_node_or_null(leaf_part_name)
			if leaf_part:
				leaf_part.add_to_group(PASS_GROUP)


## Builds the layer-2 hit target the player's interact ray picks before the leaf's own box.
func _build_interact(sx: float, ly: float, wall_sign: float) -> void:
	_interact = StaticBody3D.new()
	_interact.name = "PortInteract"
	_interact.set_script(preload("res://scripts/van/van_gun_port_interact.gd"))
	_interact.collision_layer = 2
	_interact.collision_mask = 0
	_interact.position = Vector3(sx - wall_sign * 0.09, ly, PORT_Z)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.18, 2.0 * SLOT_HALF_Y + 0.2, 2.0 * SLOT_HALF_Z + 0.2)
	shape.shape = box
	_interact.add_child(shape)

	add_child(_interact)
	_interact.add_to_group(PASS_GROUP)


func _build_inner(
	face_x: float, ly: float, wall_sign: float,
	steel: Material, weld: Material, rust: Material, slot: Material
) -> void:
	var full_z := 2.0 * SLOT_HALF_Z + BAR * 2.0
	var full_y := 2.0 * SLOT_HALF_Y + BAR * 2.0
	_frame_bars(self, face_x, ly, INNER_FRAME_THICK, full_z, full_y, steel)

	_box(self, "SlotBack", slot, Vector3(face_x, ly, PORT_Z),
		Vector3(0.005, 2.0 * SLOT_HALF_Y, 2.0 * SLOT_HALF_Z))

	var rail_x := face_x - wall_sign * 0.02
	var rail_z0 := PORT_Z - SLOT_HALF_Z - 0.07
	var rail_z1 := PORT_Z + SLOT_HALF_Z + 0.62
	var rail_len := rail_z1 - rail_z0
	var rail_mid_z := (rail_z0 + rail_z1) * 0.5
	var top_rail_y := ly + SLOT_HALF_Y + 0.015
	var bot_rail_y := ly - SLOT_HALF_Y - 0.015
	_box(self, "RailTop", weld, Vector3(rail_x, top_rail_y, rail_mid_z), Vector3(0.03, 0.03, rail_len))
	_box(self, "RailBottom", weld, Vector3(rail_x, bot_rail_y, rail_mid_z), Vector3(0.03, 0.03, rail_len))

	var nub_count := 5
	for i in range(nub_count):
		var t := float(i) / float(nub_count - 1)
		var nub_z := lerpf(rail_z0 + 0.05, rail_z1 - 0.05, t)
		var nub_y := top_rail_y if i % 2 == 0 else bot_rail_y
		_box(self, "Nub%d" % i, weld, Vector3(rail_x, nub_y, nub_z), Vector3(0.02, 0.02, 0.02))

	_plate = Node3D.new()
	_plate.name = "Plate"
	_plate.position = Vector3(face_x - wall_sign * 0.02, ly, PORT_Z)
	add_child(_plate)

	var plate_size := Vector3(0.03, 2.0 * SLOT_HALF_Y + 0.1, 2.0 * SLOT_HALF_Z + 0.08)
	_box(_plate, "PlateBody", steel, Vector3.ZERO, plate_size)
	_box(_plate, "RustPatch", rust, Vector3(-wall_sign * 0.02, 0.03, -0.04), Vector3(0.005, 0.08, 0.14))

	var handle_z := -(plate_size.z * 0.5) - 0.03 - 0.06
	_box(_plate, "HandleStandoffTop", weld, Vector3(-wall_sign * 0.03, 0.04, handle_z), Vector3(0.03, 0.03, 0.03))
	_box(_plate, "HandleStandoffBottom", weld, Vector3(-wall_sign * 0.03, -0.04, handle_z), Vector3(0.03, 0.03, 0.03))
	_box(_plate, "Handle", weld, Vector3(-wall_sign * 0.06, 0.0, handle_z), Vector3(0.035, 0.12, 0.035))


func _build_outer(face_x: float, ly: float, wall_sign: float, steel: Material, rust: Material, slot: Material) -> void:
	var full_z := 2.0 * SLOT_HALF_Z + BAR * 2.0
	var full_y := 2.0 * SLOT_HALF_Y + BAR * 2.0
	_frame_bars(self, face_x, ly, OUTER_BAR_THICK, full_z, full_y, steel, true)

	_layer = 1
	_box(self, "SlotFront", slot, Vector3(face_x - wall_sign * PROUD, ly, PORT_Z),
		Vector3(0.005, 2.0 * SLOT_HALF_Y, 2.0 * SLOT_HALF_Z))

	var streak_y := ly - SLOT_HALF_Y - BAR - 0.125
	_box(self, "RustStreakLeft", rust, Vector3(face_x, streak_y, PORT_Z - 0.1), Vector3(0.005, 0.25, 0.04))
	_box(self, "RustStreakRight", rust, Vector3(face_x, streak_y, PORT_Z + 0.15), Vector3(0.005, 0.25, 0.04))
	_layer = 2


## Builds the four bars framing the slot, centred at (face_x, ly, PORT_Z).
## Outer bars are built on render layer 1 instead of the default interior layer.
func _frame_bars(
	parent: Node3D, face_x: float, ly: float, thick: float, full_z: float, full_y: float,
	mat: Material, outer: bool = false
) -> void:
	var half_y_out := SLOT_HALF_Y + BAR * 0.5
	var half_z_out := SLOT_HALF_Z + BAR * 0.5
	if outer:
		_layer = 1
	_box(parent, "FrameTop", mat, Vector3(face_x, ly + half_y_out, PORT_Z), Vector3(thick, BAR, full_z))
	_box(parent, "FrameBottom", mat, Vector3(face_x, ly - half_y_out, PORT_Z), Vector3(thick, BAR, full_z))
	_box(parent, "FrameLeft", mat, Vector3(face_x, ly, PORT_Z - half_z_out), Vector3(thick, full_y, BAR))
	_box(parent, "FrameRight", mat, Vector3(face_x, ly, PORT_Z + half_z_out), Vector3(thick, full_y, BAR))
	if outer:
		_layer = 2


func set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	if is_instance_valid(_tween):
		_tween.kill()
	var target_z := PORT_Z + (2.0 * SLOT_HALF_Z + 0.1) if open else PORT_Z
	_tween = create_tween()
	_tween.tween_property(_plate, "position:z", target_z, SLIDE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func is_open() -> bool:
	return _open


func toggle() -> void:
	set_open(not _open)


func get_port_prompt() -> String:
	return "E  CLOSE PORT" if _open else "E  OPEN PORT"


## True when a shot at collider/point should pass through this port's open slot instead of hitting it.
func passes_shot(collider: Object, point: Vector3) -> bool:
	if not _open:
		return false
	if collider == null or not (collider is Node) or not (collider as Node).is_in_group(PASS_GROUP):
		return false
	if collider != _interact and (collider as Node).get_parent() != get_parent():
		return false
	var p := to_local(point)
	return absf(p.y - _slot_y) <= SLOT_HALF_Y and absf(p.z - PORT_Z) <= SLOT_HALF_Z


func _box(parent: Node3D, part_name: String, mat: Material, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.layers = _layer
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
