extends RefCounted
## Builds the rear leaves' pressed-steel bodies, their liner material and the centre-seam astragal (D55).

const _WindowLip := preload("res://scripts/van/rear_window_lip.gd")
const _Skin := preload("res://scripts/van/rear_door_skin.gd")
const DOOR_SHADER := preload("res://scenes/van/van_rear_door.gdshader")
## Leaf slab depth from the cabin face (CABIN_Z) to the nominal street plane (STREET_HALF).
const DOOR_THICKNESS := 0.25
## The street side of the slab, where the old 0.16 leaf ended; the extra depth grows cabin-ward.
const STREET_HALF := 0.08
const CABIN_Z := STREET_HALF - DOOR_THICKNESS
const CENTER_GAP := 0.012
const Y_MIN := 0.02
## Window centre distance from the hinge.
const WINDOW_X := VanInteriorSize.REAR_WINDOW_X
## Window corner cut-back (about the round radius) and curve points per corner.
const WINDOW_ROUND := 0.09
const WINDOW_ROUND_STEPS := 6
## Window outline (XY offsets from window center): a rounded rectangle whose lower corner toward
## the centre seam is cut off along a long diagonal with rounded ends (reference image 1). Same
## bounding size as before, so the bars still cover it.
static var WINDOW_HOLE: PackedVector2Array = _rounded_window()
## The window's sharp corners before rounding (the last two are the cut diagonal's ends).
const WINDOW_CORNERS: Array[Vector2] = [
		Vector2(-VanOpenings.REAR_WINDOW_HALF_X, -VanOpenings.REAR_WINDOW_HALF_Y),
		Vector2(-VanOpenings.REAR_WINDOW_HALF_X, VanOpenings.REAR_WINDOW_HALF_Y),
		Vector2(VanOpenings.REAR_WINDOW_HALF_X, VanOpenings.REAR_WINDOW_HALF_Y),
		Vector2(VanOpenings.REAR_WINDOW_HALF_X, -0.30),
		Vector2(0.55, -VanOpenings.REAR_WINDOW_HALF_Y)]
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


## The window's sharp corners, each cut back WINDOW_ROUND along both edges and joined by a
## quadratic curve (corner as control point), so every corner reads as a soft round.
static func _rounded_window() -> PackedVector2Array:
	var corners := WINDOW_CORNERS
	var pts := PackedVector2Array()
	for i in corners.size():
		var c: Vector2 = corners[i]
		var a: Vector2 = c + (corners[(i + corners.size() - 1) % corners.size()] - c).normalized() * WINDOW_ROUND
		var b: Vector2 = c + (corners[(i + 1) % corners.size()] - c).normalized() * WINDOW_ROUND
		for k in WINDOW_ROUND_STEPS + 1:
			var t := float(k) / float(WINDOW_ROUND_STEPS)
			pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return pts


static func _build_left_leaf_mesh(left: Node3D) -> ArrayMesh:
	var hinge_x := VanInteriorSize.REAR_DOOR_HALF
	var hinge_y := left.position.y if left else 1.55
	# Hinge-local: x 0 at the hinge to the seam, y from the floor gap to the opening top.
	return _Skin.build(hinge_x - CENTER_GAP, Y_MIN - hinge_y,
			VanInteriorSize.REAR_DOOR_TOP - hinge_y, CABIN_Z,
			STREET_HALF - _Skin.STREET_SETBACK, WINDOW_HOLE, Vector2(WINDOW_X, VanOpenings.REAR_WINDOW_Y - hinge_y))


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
		CABIN_Z - ASTRAGAL_LIFT - ASTRAGAL_T * 0.5
	)
	var mount := left.get_node_or_null("Handle/Mount")
	if mount:
		strip.material_override = mount.get("material") as Material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	left.add_child(strip)
