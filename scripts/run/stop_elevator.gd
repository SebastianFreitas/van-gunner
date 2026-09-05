class_name StopElevator
extends Node3D

## On-road lift that drops the van to the shared stop vestibule. Content still
## instances in the shop-bay frame behind the roll-up door; only the approach
## changes. Bind a corridor tile so its carriageway can hide while the pad falls.

const DEPTH := 16.0
const RIDE_SECONDS := 3.2
const SHAFT_INNER := Vector3(11.2, 16.0, 15.2)
const WALL_THICK := 0.42
const PAD_CLEAR := 0.18
## Match RoadFloor.road_surface_y so the pad sits under the van deck, not in it.
const ROAD_SURFACE_Y := -0.2
const PLATFORM_SIZE := Vector3(
	SHAFT_INNER.x - PAD_CLEAR * 2.0,
	0.38,
	SHAFT_INNER.z - PAD_CLEAR * 2.0
)
const DOOR_HEIGHT := 6.2
## Godot Yaw +90° maps vestibule +X (into the shop) onto path -Z — the van nose.
## -90° maps +X onto +Z, which is the rear doors.
const VESTIBULE_YAW := -PI * 0.5
## Just aft of the rear doors (hinge z=4.71, deck ends 4.8) so the shop slab
## is on the pad, not under the van floor.
const VESTIBULE_ORIGIN := Vector3(0.0, -DEPTH, 5.35)

const _VestibuleScene := preload("res://scenes/corridor/stop_vestibule.tscn")

var _platform: Node3D
var _pad_body: CollisionObject3D
var _shaft: Node3D
var _vestibule: Node3D
var _host_segment: Node3D
var _hidden_roads: Array[RoadFloor] = []
var _ride_tween: Tween


func _ready() -> void:
	_build_shaft()
	_build_platform()
	_mount_vestibule()


func mount_content(scene: PackedScene) -> void:
	if _vestibule == null:
		_mount_vestibule()
	if _vestibule and _vestibule.has_method(&"mount_content"):
		_vestibule.mount_content(scene)


func open_door() -> void:
	if _vestibule and _vestibule.has_method(&"open_door"):
		_vestibule.open_door()


func close_door() -> void:
	if _vestibule and _vestibule.has_method(&"close_door"):
		_vestibule.close_door()


func bind_host_segment(segment: Node3D) -> void:
	_host_segment = segment
	# Keep the street solid until the ride — hiding early leaves a pit, and
	# hiding only the mesh leaves collision that holds the player at grade.


func open_shaft(world_root: Node = null, van_world: Vector3 = Vector3.ZERO) -> void:
	if _shaft:
		_shaft.visible = true
		_set_tree_solid(_shaft, true)
	_hide_overlapping_roads(world_root, van_world)
	# Pad rides with the van. Keep it solid once the street hole opens so a
	# clip during the drop lands on the platform instead of the shaft void.
	_set_pad_walkable(true)


func restore_road() -> void:
	_restore_hidden_roads_only()
	if is_instance_valid(_host_segment) and _host_segment.has_method(
		&"set_carriageway_visible"
	):
		_host_segment.set_carriageway_visible(true)
	_host_segment = null


func set_docked(docked: bool) -> void:
	if docked:
		_set_pad_walkable(true)


func ride_seconds() -> float:
	return RIDE_SECONDS


func depth() -> float:
	return DEPTH


## Keep the pad on the same Y as PathFollow.v_offset. A second tween drifts
## and leaves the street slab at grade while the van drops through it.
func sync_platform_offset(offset_y: float) -> void:
	if _platform == null:
		return
	if _ride_tween:
		_ride_tween.kill()
		_ride_tween = null
	_platform.position.y = offset_y


## Tween the pad to `offset_y` (0 at the street, -DEPTH below). Does not move the van.
func tween_platform_to(offset_y: float, duration: float) -> void:
	if _platform == null:
		return
	if _ride_tween:
		_ride_tween.kill()
	_ride_tween = create_tween()
	_ride_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_ride_tween.set_trans(Tween.TRANS_CUBIC)
	_ride_tween.set_ease(Tween.EASE_IN_OUT)
	_ride_tween.tween_property(_platform, "position:y", offset_y, duration)


func _mount_vestibule() -> void:
	if _vestibule != null:
		return
	if _VestibuleScene == null:
		push_error("StopElevator: missing stop_vestibule.tscn.")
		return
	_vestibule = _VestibuleScene.instantiate() as Node3D
	if _vestibule == null:
		push_error("StopElevator: vestibule failed to instantiate.")
		return
	_vestibule.name = "Vestibule"
	_vestibule.position = VESTIBULE_ORIGIN
	_vestibule.rotation.y = VESTIBULE_YAW
	add_child(_vestibule)


func _set_pad_walkable(walkable: bool) -> void:
	if _pad_body == null:
		return
	_pad_body.collision_layer = 1 if walkable else 0


func _build_platform() -> void:
	var pad := AnimatableBody3D.new()
	pad.sync_to_physics = true
	_platform = pad
	_pad_body = pad
	_platform.name = "Platform"
	_platform.position = Vector3(0.0, 0.0, 0.0)
	add_child(_platform)

	# Top face at ROAD_SURFACE_Y so it does not occupy the van interior floor.
	var pad_center_y := ROAD_SURFACE_Y - PLATFORM_SIZE.y * 0.5
	var rust := _guide_material()
	_add_box(
		_platform, "Pad", PLATFORM_SIZE, Vector3(0.0, pad_center_y, 0.0), _asphalt_material(), false
	)
	_add_box(
		_platform,
		"EdgeNegZ",
		Vector3(PLATFORM_SIZE.x, 0.1, 0.14),
		Vector3(0.0, ROAD_SURFACE_Y + 0.02, -PLATFORM_SIZE.z * 0.5 + 0.07),
		rust,
		false
	)
	_add_box(
		_platform,
		"EdgePosZ",
		Vector3(PLATFORM_SIZE.x, 0.1, 0.14),
		Vector3(0.0, ROAD_SURFACE_Y + 0.02, PLATFORM_SIZE.z * 0.5 - 0.07),
		rust,
		false
	)

	var shape := BoxShape3D.new()
	shape.size = PLATFORM_SIZE
	var col := CollisionShape3D.new()
	col.name = "PadBlock"
	col.shape = shape
	col.position = Vector3(0.0, pad_center_y, 0.0)
	_platform.add_child(col)
	_set_pad_walkable(false)

	var lamp := OmniLight3D.new()
	lamp.name = "PadGlow"
	lamp.position = Vector3(0.0, 2.4, 0.0)
	lamp.light_color = Color(1.0, 0.82, 0.55, 1.0)
	lamp.light_energy = 1.8
	lamp.omni_range = 10.0
	lamp.shadow_enabled = false
	_platform.add_child(lamp)


func _build_shaft() -> void:
	_shaft = Node3D.new()
	_shaft.name = "Shaft"
	_shaft.visible = false
	add_child(_shaft)
	var shaft := _shaft
	var concrete := _shaft_material()
	var inner := SHAFT_INNER
	# Top of the walls at the road surface so they don't poke through the street
	# while the hole is still closed (shaft stays hidden until open_shaft).
	var wall_y := ROAD_SURFACE_Y - inner.y * 0.5
	var half_x := inner.x * 0.5 + WALL_THICK * 0.5
	var half_z := inner.z * 0.5 + WALL_THICK * 0.5

	_add_box(
		shaft,
		"WallNegX",
		Vector3(WALL_THICK, inner.y, inner.z + WALL_THICK * 2.0),
		Vector3(-half_x, wall_y, 0.0),
		concrete
	)
	_add_box(
		shaft,
		"WallPosX",
		Vector3(WALL_THICK, inner.y, inner.z + WALL_THICK * 2.0),
		Vector3(half_x, wall_y, 0.0),
		concrete
	)
	_add_box(
		shaft,
		"WallNegZ",
		Vector3(inner.x, inner.y, WALL_THICK),
		Vector3(0.0, wall_y, -half_z),
		concrete
	)
	# Street-to-lintel only — the vestibule door needs the bottom +Z open.
	var door_clear := DOOR_HEIGHT + 0.4
	var upper_h := maxf(inner.y - door_clear, 1.0)
	_add_box(
		shaft,
		"WallPosZUpper",
		Vector3(inner.x, upper_h, WALL_THICK),
		Vector3(0.0, ROAD_SURFACE_Y - upper_h * 0.5, half_z),
		concrete
	)

	var rim := OmniLight3D.new()
	rim.name = "ShaftGlow"
	rim.position = Vector3(0.0, -inner.y * 0.45, 2.0)
	rim.light_color = Color(0.85, 0.7, 0.45, 1.0)
	rim.light_energy = 1.4
	rim.omni_range = 12.0
	rim.shadow_enabled = false
	shaft.add_child(rim)
	_set_tree_solid(shaft, false)


func _hide_overlapping_roads(world_root: Node, van_world: Vector3) -> void:
	_restore_hidden_roads_only()
	if world_root == null and is_instance_valid(_host_segment):
		world_root = _host_segment.get_parent()
	if world_root == null:
		if is_instance_valid(_host_segment) and _host_segment.has_method(
			&"set_carriageway_visible"
		):
			_host_segment.set_carriageway_visible(false)
		return
	var center := van_world
	if center == Vector3.ZERO:
		center = global_position
	var roads: Array[RoadFloor] = []
	_collect_road_floors(world_root, roads)
	for road in roads:
		if not is_instance_valid(road):
			continue
		if not _road_overlaps_drop(road, center):
			continue
		road.set_enabled(false)
		_hidden_roads.append(road)
	if is_instance_valid(_host_segment) and _host_segment.has_method(
		&"set_carriageway_visible"
	):
		_host_segment.set_carriageway_visible(false)


func _restore_hidden_roads_only() -> void:
	for road in _hidden_roads:
		if is_instance_valid(road):
			road.set_enabled(true)
	_hidden_roads.clear()


func _collect_road_floors(root: Node, out: Array[RoadFloor]) -> void:
	if root is RoadFloor:
		out.append(root as RoadFloor)
	for child in root.get_children():
		_collect_road_floors(child, out)


func _road_overlaps_drop(road: RoadFloor, van_world: Vector3) -> bool:
	var local := road.to_local(van_world)
	var margin := 2.5
	return (
		absf(local.x) <= road.span_x * 0.5 + margin
		and absf(local.z) <= road.span_z * 0.5 + margin
	)


func _set_tree_solid(root: Node, solid: bool) -> void:
	for child in root.get_children():
		if child is CollisionObject3D:
			(child as CollisionObject3D).collision_layer = 1 if solid else 0
		_set_tree_solid(child, solid)


func _add_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	pos: Vector3,
	material: Material,
	collide: bool = true
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)

	if not collide:
		return
	var body := StaticBody3D.new()
	body.name = "%sBlock" % node_name
	parent.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	body.add_child(col)


func _asphalt_material() -> Material:
	var shader := load("res://scenes/corridor/asphalt_surface.gdshader") as Shader
	if shader == null:
		return _guide_material()
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("washout", 0.32)
	mat.set_shader_parameter("trash", 1.0)
	mat.set_shader_parameter("roughness_value", 0.94)
	return mat


func _guide_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.14, 0.06, 1.0)
	mat.metallic = 0.4
	mat.roughness = 0.7
	return mat


func _shaft_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.075, 1.0)
	mat.metallic = 0.08
	mat.roughness = 0.92
	return mat
