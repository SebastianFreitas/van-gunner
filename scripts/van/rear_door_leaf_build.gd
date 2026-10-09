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
## Window corner radius (true circular arcs) and curve points per quarter turn.
const WINDOW_ROUND := 0.28
const WINDOW_ROUND_STEPS := 12
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
	# The x<0 leaf is the mismatched donor door, built from its own profile; the x>0 leaf is the
	# stock mesh mirrored so bow/normals match.
	var donor := profile_for(true)
	var stock := profile_for(false)
	_apply_leaf(left, _build_left_leaf_mesh(left, donor), _door_body_material(left, donor), false)
	_apply_leaf(right, _build_left_leaf_mesh(left, stock), _door_body_material(left, stock), true)
	_WindowLip.build(left, left, false, donor)
	_WindowLip.build(left, right, true, stock)
	_fit_donor_window(left, donor)
	_add_astragal(left)


## A leaf's profile with the window hole filled in (the hole stays owned by this script).
static func profile_for(donor: bool) -> RearDoorProfile:
	var profile := RearDoorProfile.donor() if donor else RearDoorProfile.stock()
	if not donor:
		profile.window_hole = WINDOW_HOLE
	return profile


## The window's sharp corners, each filleted with a true circular arc of radius WINDOW_ROUND
## tangent to both edges (tangent length r / tan(half the corner angle)).
static func _rounded_window() -> PackedVector2Array:
	var corners := WINDOW_CORNERS
	var pts := PackedVector2Array()
	for i in corners.size():
		var c: Vector2 = corners[i]
		var u: Vector2 = (corners[(i + corners.size() - 1) % corners.size()] - c).normalized()
		var v: Vector2 = (corners[(i + 1) % corners.size()] - c).normalized()
		var half_angle := absf(u.angle_to(v)) * 0.5
		var centre := c + (u + v).normalized() * (WINDOW_ROUND / sin(half_angle))
		var t1 := c + u * (WINDOW_ROUND / tan(half_angle))
		var t2 := c + v * (WINDOW_ROUND / tan(half_angle))
		var a1 := (t1 - centre).angle()
		var sweep := angle_difference(a1, (t2 - centre).angle())
		var steps := maxi(3, ceili(float(WINDOW_ROUND_STEPS) * absf(sweep) / (PI * 0.5)))
		for k in steps + 1:
			var a := a1 + sweep * float(k) / float(steps)
			pts.append(centre + Vector2(cos(a), sin(a)) * WINDOW_ROUND)
	return pts


static func _build_left_leaf_mesh(left: Node3D, profile: RearDoorProfile) -> ArrayMesh:
	var hinge_x := VanInteriorSize.REAR_DOOR_HALF
	var hinge_y := left.position.y if left else 1.55
	# Hinge-local: x 0 at the hinge to the seam, y from the floor gap to the opening top.
	return _Skin.build(hinge_x - CENTER_GAP, Y_MIN - hinge_y,
			VanInteriorSize.REAR_DOOR_TOP - hinge_y, CABIN_Z,
			STREET_HALF - _Skin.STREET_SETBACK, profile.window_hole,
			Vector2(WINDOW_X, VanOpenings.REAR_WINDOW_Y - hinge_y), profile)


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


static func _door_body_material(left: Node3D, profile: RearDoorProfile) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = DOOR_SHADER
	mat.set_shader_parameter("leaf_offset", profile.leaf_offset)
	if profile.is_donor():
		mat.set_shader_parameter("paint_color", profile.paint_color)
		mat.set_shader_parameter("paint_coverage", profile.paint_coverage)
		mat.set_shader_parameter("paint_island_scale", profile.paint_island_scale)
		mat.set_shader_parameter("roughness_value", profile.roughness)
		mat.set_shader_parameter("metallic_value", profile.metallic)
	mat.set_shader_parameter("leaf_width_m", VanInteriorSize.REAR_DOOR_HALF - CENTER_GAP)
	mat.set_shader_parameter("leaf_bottom_y", Y_MIN - (left.position.y if left else 1.55))
	return mat


## The donor leaf's glass box and bars follow its own hole with the stock leaf's margins, the
## bars seated in the skin (no gussets: the corners are round, not chamfered).
static func _fit_donor_window(left: Node3D, donor: RearDoorProfile) -> void:
	var box := donor.window_bounds().size * 0.5
	var frame_margin := Vector2(0.05, 0.05)
	var glass := left.get_node("WindowGlass") as MeshInstance3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3(box.x * 2.0 - 0.10, box.y * 2.0 - 0.10, (glass.mesh as BoxMesh).size.z)
	glass.mesh = mesh
	(left.get_node("WindowFrame") as Node3D).visible = false
	var cross := left.get_node("IronCross") as Node3D
	cross.set(&"frame_half", box + frame_margin)
	cross.set(&"clear_half", box - Vector2(0.02, 0.025))
	# The audit wants the bars to reach past the opening aabb (the stock box), so x runs that far.
	cross.set(&"skin_reach", Vector2(VanOpenings.REAR_WINDOW_HALF_X + 0.13, box.y + 0.125))
	cross.set(&"gussets", false)
	cross.call(&"rebuild")


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
	var rust := load("res://scenes/van/van_rust_steel_material.tres") as Material
	if rust != null:
		strip.material_override = rust
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	left.add_child(strip)
