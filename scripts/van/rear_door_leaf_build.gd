extends RefCounted
## Builds the rear leaves' pressed-steel bodies, their liner material and the centre-seam astragal (D55).

const _WindowLip := preload("res://scripts/van/rear_window_lip.gd")
const _Skin := preload("res://scripts/van/rear_door_skin.gd")
const DOOR_SHADER := preload("res://scenes/van/van_rear_door.gdshader")
const DOOR_THICKNESS := 0.16
const CENTER_GAP := 0.012
const Y_MIN := 0.02
## Window centre distance from the hinge.
const WINDOW_X := VanInteriorSize.REAR_WINDOW_X
## Window outline (XY offsets from window center): a rounded rectangle whose lower corner toward
## the centre seam is cut off at an angle (reference image 1). Same bounding size as before, so the
## bars still cover it.
static var WINDOW_HOLE: PackedVector2Array = PackedVector2Array([
	Vector2(-0.79, -0.775), Vector2(-0.92, -0.7), Vector2(-0.99, -0.575),
	Vector2(-0.99, 0.575), Vector2(-0.92, 0.7), Vector2(-0.79, 0.775),
	Vector2(0.79, 0.775), Vector2(0.92, 0.7), Vector2(0.99, 0.575),
	Vector2(0.99, -0.30), Vector2(0.55, -0.775),
])
## Astragal: a trim strip on the left leaf's cabin face covering the 2.4 cm centre seam, 10 cm wide
## (vangapfix D24). The lift keeps its street face 1.1 cm clear of the handle mounts (D28).
const ASTRAGAL_HALF_W := 0.05
const ASTRAGAL_T := 0.012
const ASTRAGAL_LIFT := 0.036
const ASTRAGAL_END_GAP := 0.0


static func build(_doors: Node3D, left: Node3D, right: Node3D) -> void:
	# One canonical left leaf — mirror for the right so bow/normals match.
	var mesh := _build_left_leaf_mesh(left)
	var mat := _door_body_material()
	_apply_leaf(left, mesh, mat, false)
	_apply_leaf(right, mesh, mat, true)
	_WindowLip.build(left, left, false)
	_WindowLip.build(left, right, true)
	_add_astragal(left)


static func _build_left_leaf_mesh(left: Node3D) -> ArrayMesh:
	var hinge_x := VanInteriorSize.REAR_DOOR_HALF
	var hinge_y := left.position.y if left else 1.55
	# Hinge-local: x 0 at the hinge to the seam, y from the floor gap to the opening top.
	return _Skin.build(hinge_x - CENTER_GAP, Y_MIN - hinge_y,
			VanInteriorSize.REAR_DOOR_TOP - hinge_y, DOOR_THICKNESS * 0.5,
			WINDOW_HOLE, Vector2(WINDOW_X, 1.775 - hinge_y))


static func _apply_leaf(hinge: Node3D, mesh: ArrayMesh, mat: Material, mirror_x: bool) -> void:
	if hinge == null or mesh == null:
		return
	# Hinge / window frame / glass / handle locals stay put — body only.
	var panel := hinge.get_node_or_null("Panel") as Node3D
	if panel:
		panel.visible = false

	var existing := hinge.get_node_or_null("CurvedBody")
	if existing:
		existing.free()

	var body := MeshInstance3D.new()
	body.name = "CurvedBody"
	body.mesh = mesh
	body.material_override = mat
	if mirror_x:
		# Flips geometry + normals together (avoids the right-leaf winding bug).
		body.scale = Vector3(-1.0, 1.0, 1.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	hinge.add_child(body)
	hinge.move_child(body, 0)


static func _door_body_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = DOOR_SHADER
	mat.set_shader_parameter("leaf_width_m", VanInteriorSize.REAR_DOOR_HALF - CENTER_GAP)
	mat.set_shader_parameter("leaf_height_m", VanInteriorSize.REAR_DOOR_TOP - Y_MIN)
	return mat


static func _add_astragal(left: Node3D) -> void:
	if left == null:
		return
	var existing := left.get_node_or_null("Astragal")
	if existing:
		existing.free()
	var hinge_x := VanInteriorSize.REAR_DOOR_HALF
	var hinge_y := left.position.y
	var y_bot := Y_MIN + ASTRAGAL_END_GAP
	# 0.025 is the slab's y_inset; the leaf top follows the vault.
	var y_top := VanInteriorSize.REAR_DOOR_TOP - ASTRAGAL_END_GAP
	var strip := MeshInstance3D.new()
	strip.name = "Astragal"
	var box := BoxMesh.new()
	box.size = Vector3(ASTRAGAL_HALF_W * 2.0, y_top - y_bot, ASTRAGAL_T)
	strip.mesh = box
	strip.position = Vector3(
		hinge_x,
		(y_bot + y_top) * 0.5 - hinge_y,
		-DOOR_THICKNESS * 0.5 - ASTRAGAL_LIFT - ASTRAGAL_T * 0.5
	)
	var mount := left.get_node_or_null("Handle/Mount")
	if mount:
		strip.material_override = mount.get("material") as Material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	left.add_child(strip)
