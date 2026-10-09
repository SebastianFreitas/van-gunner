class_name VanFloor
extends Node3D

## Worn cargo-van floor with ribbed decking plus flat floor dressing (mats, paper, tape).

## Height of flat floor decals above the deck: clears the geometry audit's 1 cm coplanar tolerance (D42).
const DECAL_LIFT := 0.012
## Decals on the raised mid slab sit at the rib top plus 1.5 cm.
const MID_DECAL_LIFT := 0.335

## Front end of the old y 0 slab: the raised MidSlab covers everything ahead of it.
const DECK_Z0 := 0.90

## Height of the back-room decals (z > 1.0): clears the 0.02 rib top and the 0.035 mat top.
const BACK_DECAL_LIFT := 0.035
## The sheet reaches 2 cm past the wall lip's outer face so the two side faces never coincide (audit FLICKER).
const SHEET_OVERHANG := 0.02
## Rib run on the rear sheet.
const RIB_Z0 := 1.06
const RIB_Z1 := 5.85
## Host ribs are stamped pressings: length, gap between pressings, shortest piece kept.
const RIB_STAMP_LEN := 0.50
const RIB_STAMP_GAP := 0.12
const RIB_STAMP_MIN := 0.12

@export var span_x := VanInteriorSize.FLOOR_WIDTH
@export var span_z := VanInteriorSize.FLOOR_LENGTH
## Z centre of the deck (the front end stays at the cab).
@export var center_z := VanInteriorSize.CENTER_Z
@export var deck_thickness := 0.27
@export var rebuild_on_ready := true

var _built := false


func _ready() -> void:
	if rebuild_on_ready:
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_built = false
	_build()


func _build() -> void:
	if _built:
		return
	_built = true

	# The sheet is built in floor metres as an unscaled child, so the shader's origin stays 0 and
	# the pattern lands where the old Deck's offset put it.
	var sheet_mat := VanFloorSkin.material(VanFloorSkin.TINT_A, 2.0, 0.0)
	var sheet := MeshInstance3D.new()
	sheet.name = "RearSheet"
	sheet.mesh = VanFloorSheet.build_sheet(-span_x * 0.5 - SHEET_OVERHANG,
			span_x * 0.5 + SHEET_OVERHANG, DECK_Z0, center_z + span_z * 0.5, -deck_thickness, 0.0,
			VanFloorPlates.pocket_polygons())
	sheet.material_override = sheet_mat
	sheet.layers = VanLighting.LAYER_VAN_INTERIOR
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(sheet)
	_build_ribs(sheet_mat)

	_add_raised_part(&"MidSlab", VanFloorSlab.build_mid_slab(),
			VanFloorSkin.material(VanFloorSkin.TINT_A, 1.0, 0.5))
	VanFloorMid.add(self)
	VanFloorPlates.add(self)
	VanFloorPlates.add_mid(self)
	VanFloorStairs.add(self)
	VanFloorLamp.build(self)

	_build_threshold_strips()
	_build_rear_entry_ramp()
	_build_entrance_mats()
	_build_scatter_props()


## Adds `Ribs` (26 columns of short stamped ridges) and the two wall lips on the rear sheet.
func _build_ribs(mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for k in 13:
			var x: float = side * (0.125 + 0.25 * k)
			var z0 := RIB_Z0
			var z1 := RIB_Z1
			# Left side: the stair treads and the opening post push the starts back.
			if side < 0.0 and k >= 8:
				z0 = 1.38
			elif side < 0.0 and k == 7:
				z0 = 1.10
			if k <= 2:
				z1 = 5.38
			for seg in _rib_segments(x, z0, z1):
				VanFloorSheet.add_rib(st, Vector2(x, seg.x), Vector2(x, seg.y), 0.0)
	st.generate_tangents()
	var ribs := MeshInstance3D.new()
	ribs.name = "Ribs"
	ribs.mesh = st.commit()
	ribs.material_override = mat
	ribs.layers = VanLighting.LAYER_VAN_INTERIOR
	ribs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(ribs)
	_add_raised_part(&"LipRight", VanFloorSheet.build_lip(1.0, 1.08, 5.85, 0.0), mat)
	_add_raised_part(&"LipLeft", VanFloorSheet.build_lip(-1.0, 1.70, 5.85, 0.0), mat)


## The z ranges (x = start, y = end) of a rib at `x`: stamped 0.50 m pressings 0.12 m apart on one
## grid from RIB_Z0 (so the gaps line up across the width), minus what the plates and pockets block.
func _rib_segments(x: float, z0: float, z1: float) -> Array[Vector2]:
	var runs: Array[Vector2] = []
	var cursor := z0
	for b in VanFloorPlates.rib_blocked(x):
		if b.x > cursor and b.x < z1:
			runs.append(Vector2(cursor, b.x))
		cursor = maxf(cursor, b.y)
	if z1 > cursor:
		runs.append(Vector2(cursor, z1))
	var segs: Array[Vector2] = []
	for run in runs:
		var cs := RIB_Z0
		while cs < run.y:
			var a := maxf(run.x, cs)
			var b := minf(run.y, cs + RIB_STAMP_LEN)
			if b - a >= RIB_STAMP_MIN:
				segs.append(Vector2(a, b))
			cs += RIB_STAMP_LEN + RIB_STAMP_GAP
	return segs


## Adds a raised floor mesh (slab or tread) as an unscaled child on the interior layer.
func _add_raised_part(part_name: StringName, mesh: ArrayMesh, mat: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = mat
	part.layers = VanLighting.LAYER_VAN_INTERIOR
	add_child(part)


func _build_threshold_strips() -> void:
	var metal := _metal_mat(Color(0.12, 0.13, 0.125, 1.0), 0.75, 0.42)
	# Rear door sill
	_add_box(
		"RearThreshold",
		Vector3(2.2, 0.03, 0.08),
		Vector3(0.0, 0.015, center_z + span_z * 0.5 - 0.07),
		metal
	)
	# Cab doorway sill
	_add_box(
		"CabThreshold",
		Vector3(1.45, 0.025, 0.07),
		Vector3(0.0, 0.012, -4.52),
		metal
	)


func _build_rear_entry_ramp() -> void:
	# Cargo vans sit higher than road/shop floor (y=0 vs y=-0.2). A shallow rear
	# ramp lets the player walk back in without step-climb edge cases.
	const RAMP_WIDTH := 2.2
	const RAMP_RUN := 0.65
	const RAMP_RISE := 0.2
	const OUTSIDE_FLOOR_Y := -0.2

	var angle := atan(RAMP_RISE / RAMP_RUN)
	var rear_z := center_z + span_z * 0.5
	var inner_z := rear_z - 0.25
	var outer_z := inner_z + RAMP_RUN
	var ramp_z := (inner_z + outer_z) * 0.5
	var center_y := OUTSIDE_FLOOR_Y + RAMP_RISE * 0.5

	var metal := _metal_mat(Color(0.1, 0.105, 0.1, 1.0), 0.7, 0.5)

	var box := BoxMesh.new()
	box.size = Vector3(RAMP_WIDTH - 0.04, 0.06, RAMP_RUN)
	var mesh := MeshInstance3D.new()
	mesh.name = &"RearEntryRamp"
	mesh.mesh = box
	mesh.material_override = metal
	mesh.position = Vector3(0.0, center_y, ramp_z)
	mesh.rotation.x = angle
	mesh.layers = VanLighting.LAYER_VAN_INTERIOR
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh)

	var shell := get_parent()
	if shell is StaticBody3D:
		var existing := shell.get_node_or_null("RearEntryRamp")
		if existing:
			existing.queue_free()
		var col := CollisionShape3D.new()
		col.name = &"RearEntryRamp"
		var shape := BoxShape3D.new()
		shape.size = Vector3(RAMP_WIDTH, 0.08, RAMP_RUN)
		col.shape = shape
		col.position = Vector3(0.0, center_y, ramp_z)
		col.rotation.x = angle
		shell.add_child.call_deferred(col)


func _build_entrance_mats() -> void:
	var rear_mat := _rubber_mat(
		Color(0.07, 0.075, 0.07, 1.0),
		Color(0.03, 0.032, 0.03, 1.0),
		16.0
	)
	# Main rear entry mat — just inside the back doors.
	# A real box (y -0.02..0.035) so the rib tops never cut through it.
	_add_box(
		"RearEntryMat",
		Vector3(1.55, 0.055, 0.95),
		Vector3(0.0, 0.0075, center_z + span_z * 0.5 - 0.85),
		rear_mat
	)

	# Left side-door mat (player often enters / fights here).
	var side_mat := _rubber_mat(
		Color(0.1, 0.065, 0.045, 1.0),
		Color(0.045, 0.03, 0.02, 1.0),
		12.0
	)
	_add_box(
		"LeftSideMat",
		Vector3(0.72, 0.055, 1.15),
		Vector3(-1.55, 0.3075, -3.35),
		side_mat,
		8.0
	)


func _build_scatter_props() -> void:
	# Keep sparse — dressing, not clutter.
	var paper_a := _paper_shader_mat(Color(0.78, 0.74, 0.62, 1.0), 12.0)
	var paper_b := _paper_shader_mat(Color(0.74, 0.72, 0.68, 1.0), 9.0)
	var paper_c := _paper_shader_mat(Color(0.7, 0.64, 0.5, 1.0), 10.0)
	var cardboard := _mat_shader_or_standard(Color(0.42, 0.30, 0.18, 1.0), 0.94, 0.0, false)
	var tape := _mat_shader_or_standard(Color(0.55, 0.48, 0.22, 1.0), 0.55, 0.05, false)
	var rag := _mat_shader_or_standard(Color(0.28, 0.22, 0.18, 1.0), 0.98, 0.0, true)

	_add_flat("PaperReceipt", Vector2(0.18, 0.26), Vector3(-0.85, BACK_DECAL_LIFT, 1.55), 22.0, paper_a)
	_add_flat("PaperNote", Vector2(0.22, 0.16), Vector3(0.55, MID_DECAL_LIFT, -0.9), -14.0, paper_b)
	_add_flat("PaperFolded", Vector2(0.14, 0.2), Vector3(-1.35, BACK_DECAL_LIFT, 2.6), 41.0, paper_c)
	_add_flat("CardboardScrap", Vector2(0.55, 0.4), Vector3(0.95, BACK_DECAL_LIFT, 2.1), -28.0, cardboard)
	_add_flat("DuctTapeStrip", Vector2(0.42, 0.045), Vector3(-0.2, MID_DECAL_LIFT, -2.15), 7.0, tape)
	_add_flat("RagScrap", Vector2(0.38, 0.28), Vector3(1.35, MID_DECAL_LIFT, -1.75), 33.0, rag)

	# Thin oil-stain decals (dark translucent plates).
	var oil := StandardMaterial3D.new()
	oil.albedo_color = Color(0.04, 0.03, 0.02, 0.55)
	oil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	oil.roughness = 0.35
	oil.metallic = 0.15
	oil.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_flat("OilStainA", Vector2(0.55, 0.32), Vector3(-1.7, MID_DECAL_LIFT, 0.4), 18.0, oil)
	_add_flat("OilStainB", Vector2(0.35, 0.5), Vector3(1.75, BACK_DECAL_LIFT, 3.2), -40.0, oil)


func _add_flat(node_name: String, size: Vector2, pos: Vector3, yaw_deg: float, material: Material) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.orientation = PlaneMesh.FACE_Y

	if material is BaseMaterial3D:
		(material as BaseMaterial3D).render_priority = 1
	elif material is ShaderMaterial:
		(material as ShaderMaterial).render_priority = 1

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = 0.02
	add_child(mi)


func _add_box(node_name: String, size: Vector3, pos: Vector3, material: Material,
		yaw_deg: float = 0.0) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = box
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _rubber_mat(base: Color, groove: Color, groove_scale: float) -> ShaderMaterial:
	var shader := load("res://scenes/van/van_floor_mat.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("groove_color", groove)
	mat.set_shader_parameter("edge_color", base.darkened(0.25))
	mat.set_shader_parameter("groove_scale", groove_scale)
	mat.set_shader_parameter("roughness_value", 0.96)
	return mat


func _paper_shader_mat(color: Color, lines: float) -> ShaderMaterial:
	var shader := load("res://scenes/van/van_floor_paper.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("paper_color", color)
	mat.set_shader_parameter("ink_color", Color(0.22, 0.2, 0.16, 1.0))
	mat.set_shader_parameter("line_count", lines)
	mat.set_shader_parameter("roughness_value", 0.92)
	return mat


func _metal_mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


func _mat_shader_or_standard(color: Color, roughness: float, metallic: float, fabric: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if fabric:
		mat.uv1_scale = Vector3(3.0, 3.0, 3.0)
	return mat
