extends Interactable

## Cab door leaf in the front wall's doorway (x ±0.775, y 0..2.30): a recessed panel with a barred pass-through window into the cab.
## Interacting talks to the driver / leaves the stop.

const LEAF_HALF_W := 0.755
const LEAF_BOTTOM := 0.02
const LEAF_TOP := 2.28
const LEAF_DEPTH := 0.08
const LEAF_Z := 0.02            ## leaf centre, local; its front face sits at local z 0.06 (Interior z -4.59), 4 cm behind the wall face
const SILL_Y := 1.35
const STILE_W := 0.14
const RAIL_H := 0.14
const BAR_W := 0.03
const BAR_COUNT := 3
const DOORWAY_HALF_W := 0.775
const DOORWAY_TOP := 2.30
const WALL_DEPTH := 0.2
const BUILT_PARTS: Array[StringName] = [
	&"StileLeft", &"StileRight", &"TopRail", &"Glass", &"Bar0", &"Bar1", &"Bar2", &"KickPlate", &"Handle",
]

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _collision: CollisionShape3D = $Collision


func _ready() -> void:
	_build_leaf()


func _build_leaf() -> void:
	var shell := get_parent().get_node_or_null(^"Shell")
	var walls: VanSideWall = null
	if shell != null:
		walls = shell.get_node_or_null(^"SideWalls") as VanSideWall

	var body_mat := _leaf_material(walls)
	var trim_mat: Material
	if shell != null:
		trim_mat = _trim_material(shell)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.09, 0.09, 1)
		mat.metallic = 0.65
		mat.roughness = 0.4
		trim_mat = mat

	for part_name in BUILT_PARTS:
		var node := get_node_or_null(NodePath(part_name))
		if node:
			node.free()

	if _mesh:
		var box := BoxMesh.new()
		box.size = Vector3(LEAF_HALF_W * 2.0, SILL_Y - LEAF_BOTTOM, LEAF_DEPTH)
		_mesh.mesh = box
		_mesh.position = Vector3(0.0, (LEAF_BOTTOM + SILL_Y) * 0.5, LEAF_Z)
		_mesh.material_override = body_mat
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		VanLighting.retarget_layers(_mesh, VanLighting.LAYER_VAN_INTERIOR)

	_add_part(
		&"StileLeft", Vector3(STILE_W, LEAF_TOP - SILL_Y, LEAF_DEPTH),
		Vector3(-(LEAF_HALF_W - STILE_W * 0.5), (SILL_Y + LEAF_TOP) * 0.5, LEAF_Z),
		body_mat
	)
	_add_part(
		&"StileRight", Vector3(STILE_W, LEAF_TOP - SILL_Y, LEAF_DEPTH),
		Vector3(LEAF_HALF_W - STILE_W * 0.5, (SILL_Y + LEAF_TOP) * 0.5, LEAF_Z),
		body_mat
	)
	_add_part(
		&"TopRail", Vector3(2.0 * (LEAF_HALF_W - STILE_W), RAIL_H, LEAF_DEPTH),
		Vector3(0.0, LEAF_TOP - RAIL_H * 0.5, LEAF_Z),
		body_mat
	)

	var wx := LEAF_HALF_W - STILE_W
	var window_top := LEAF_TOP - RAIL_H
	var window_h := window_top - SILL_Y
	var window_mid_y := (SILL_Y + window_top) * 0.5

	_add_part(
		&"Glass", Vector3(2.0 * wx, window_h, 0.01),
		Vector3(0.0, window_mid_y, LEAF_Z),
		_glass_material()
	)

	for i in range(BAR_COUNT):
		var bar_x := -wx + 2.0 * wx * float(i + 1) / float(BAR_COUNT + 1)
		_add_part(
			StringName("Bar%d" % i), Vector3(BAR_W, window_h, 0.025),
			Vector3(bar_x, window_mid_y, LEAF_Z + 0.02),
			trim_mat
		)

	_add_part(
		&"KickPlate", Vector3(2.0 * LEAF_HALF_W - 0.08, 0.26, 0.012),
		Vector3(0.0, LEAF_BOTTOM + 0.17, LEAF_Z + LEAF_DEPTH * 0.5 + 0.006),
		trim_mat
	)
	_add_part(
		&"Handle", Vector3(0.05, 0.16, 0.04),
		Vector3(LEAF_HALF_W - 0.17, 1.05, LEAF_Z + LEAF_DEPTH * 0.5 + 0.02),
		trim_mat
	)

	if _collision:
		var shape := BoxShape3D.new()
		shape.size = Vector3(DOORWAY_HALF_W * 2.0, DOORWAY_TOP, WALL_DEPTH)
		_collision.shape = shape
		_collision.position = Vector3(0.0, DOORWAY_TOP * 0.5, 0.0)


func _leaf_material(walls: VanSideWall) -> Material:
	# Same cargo-liner shader the side doors use.
	var source: Material = null
	if walls != null and walls.wall_material != null:
		source = walls.wall_material
	else:
		var side_doors := get_parent().get_node_or_null(^"Shell/SideDoors")
		if side_doors:
			var side_body := side_doors.get_node_or_null(^"Left/Panel/Body")
			if side_body and side_body.get("material") != null:
				source = side_body.get("material") as Material
	if source == null and _mesh != null:
		source = _mesh.material_override

	if source is ShaderMaterial:
		var mat := (source as ShaderMaterial).duplicate()
		mat.set_shader_parameter("wall_size_m", Vector2(LEAF_HALF_W * 2.0, LEAF_TOP - LEAF_BOTTOM))
		mat.set_shader_parameter("panel_spacing_m", 0.85)
		mat.set_shader_parameter("rib_spacing_m", 0.28)
		mat.set_shader_parameter("kick_height_m", 0.3)
		return mat
	return source


func _glass_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.035, 0.035, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.metallic = 0.3
	return mat


func _add_part(node_name: StringName, size: Vector3, pos: Vector3, mat: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = box
	mi.position = pos
	mi.material_override = mat
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _trim_material(shell: Node) -> Material:
	var side_doors := shell.get_node_or_null("SideDoors")
	if side_doors:
		var skin := side_doors.get_node_or_null("Left/Panel/OuterSkin")
		if skin and skin.get("material") != null:
			return skin.get("material") as Material
	var walls := shell.get_node_or_null("SideWalls") as VanSideWall
	if walls != null and walls.door_jamb_material != null:
		return walls.door_jamb_material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.09, 0.09, 1)
	mat.metallic = 0.65
	mat.roughness = 0.4
	return mat


func get_interaction_prompt() -> String:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return "THE DRIVER DOESN'T ANSWER"
	if GameSession.phase == GameSession.RunPhase.STOP:
		return "E  TELL DRIVER TO CONTINUE"
	return "E  TALK TO THE DRIVER"


func interact(_actor: Node3D) -> void:
	if GameSession.phase == GameSession.RunPhase.GAME_OVER:
		return
	if GameSession.phase == GameSession.RunPhase.STOP:
		var travel := get_tree().get_first_node_in_group(&"travel_controller")
		if travel and travel.has_method(&"leave_stop"):
			travel.leave_stop()
		elif travel and travel.has_method(&"leave_shop"):
			travel.leave_shop()
		return
	var host := owner
	if host and host.has_method(&"open_driver_talk"):
		host.open_driver_talk()
