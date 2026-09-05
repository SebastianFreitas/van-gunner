extends Node3D

## Flared warehouse bay: shell, wrapped dressing, table + chest, one hide layout.


func _ready() -> void:
	_build_shell()
	_build_dressing()
	_build_table()
	_build_lights()
	var director := WarehouseDirector.new()
	director.name = "Director"
	add_child(director)
	director.setup()
	var chest := get_node_or_null("Chest") as WarehouseChest
	if chest:
		chest.bind(director)


func _exit_tree() -> void:
	for child in get_children():
		if child is Light3D:
			(child as Light3D).visible = false


func _build_shell() -> void:
	var floor_mat := WarehouseLook.dust_floor_material()
	var wall_mat := WarehouseLook.plaster_material()
	var rib := WarehouseLook.rib_material()
	var lamp := WarehouseLook.lamp_material()

	var surfaces := StaticBody3D.new()
	surfaces.name = "Surfaces"
	add_child(surfaces)

	var bay := Node3D.new()
	bay.name = "Bay"
	add_child(bay)

	# Mouth (vestibule overlap) stays door-width; room flares after the roll-up.
	_shell_box(
		bay,
		surfaces,
		"MouthFloor",
		Vector3(WarehouseLook.MOUTH_LEN, 0.2, WarehouseLook.MOUTH_WIDTH),
		Vector3(WarehouseLook.MOUTH_LEN * 0.5, WarehouseLook.FLOOR_Y, 0.0),
		floor_mat
	)
	_shell_box(
		bay,
		surfaces,
		"RoomFloor",
		Vector3(WarehouseLook.ROOM_DEPTH, 0.2, WarehouseLook.ROOM_WIDTH),
		Vector3(
			WarehouseLook.ROOM_START_X + WarehouseLook.ROOM_DEPTH * 0.5,
			WarehouseLook.FLOOR_Y,
			0.0
		),
		floor_mat
	)

	_shell_box(
		bay,
		surfaces,
		"MouthWallNegZ",
		Vector3(WarehouseLook.MOUTH_LEN, WarehouseLook.HEIGHT, 0.4),
		Vector3(WarehouseLook.MOUTH_LEN * 0.5, 3.7, -WarehouseLook.HALF_MOUTH),
		wall_mat
	)
	_shell_box(
		bay,
		surfaces,
		"MouthWallPosZ",
		Vector3(WarehouseLook.MOUTH_LEN, WarehouseLook.HEIGHT, 0.4),
		Vector3(WarehouseLook.MOUTH_LEN * 0.5, 3.7, WarehouseLook.HALF_MOUTH),
		wall_mat
	)

	var shoulder_z := (WarehouseLook.HALF_MOUTH + WarehouseLook.HALF_ROOM) * 0.5
	var shoulder_depth := WarehouseLook.HALF_ROOM - WarehouseLook.HALF_MOUTH
	_shell_box(
		bay,
		surfaces,
		"ShoulderNegZ",
		Vector3(0.4, WarehouseLook.HEIGHT, shoulder_depth),
		Vector3(WarehouseLook.ROOM_START_X, 3.7, -shoulder_z),
		wall_mat
	)
	_shell_box(
		bay,
		surfaces,
		"ShoulderPosZ",
		Vector3(0.4, WarehouseLook.HEIGHT, shoulder_depth),
		Vector3(WarehouseLook.ROOM_START_X, 3.7, shoulder_z),
		wall_mat
	)

	var room_mid_x := WarehouseLook.ROOM_START_X + WarehouseLook.ROOM_DEPTH * 0.5
	_shell_box(
		bay,
		surfaces,
		"RoomWallNegZ",
		Vector3(WarehouseLook.ROOM_DEPTH, WarehouseLook.HEIGHT, 0.4),
		Vector3(room_mid_x, 3.7, -WarehouseLook.HALF_ROOM),
		wall_mat
	)
	_shell_box(
		bay,
		surfaces,
		"RoomWallPosZ",
		Vector3(WarehouseLook.ROOM_DEPTH, WarehouseLook.HEIGHT, 0.4),
		Vector3(room_mid_x, 3.7, WarehouseLook.HALF_ROOM),
		wall_mat
	)
	_shell_box(
		bay,
		surfaces,
		"BackWall",
		Vector3(0.4, WarehouseLook.HEIGHT, WarehouseLook.ROOM_WIDTH),
		Vector3(WarehouseLook.BACK_X, 3.7, 0.0),
		wall_mat
	)

	_shell_box(
		bay,
		surfaces,
		"MouthFrameNegZ",
		Vector3(1.2, WarehouseLook.HEIGHT, 2.4),
		Vector3(0.2, 3.7, -5.5),
		wall_mat
	)
	_shell_box(
		bay,
		surfaces,
		"MouthFramePosZ",
		Vector3(1.2, WarehouseLook.HEIGHT, 2.4),
		Vector3(0.2, 3.7, 5.5),
		wall_mat
	)
	_shell_box(
		bay,
		surfaces,
		"Lintel",
		Vector3(1.2, 1.2, WarehouseLook.MOUTH_WIDTH),
		Vector3(0.2, 5.4, 0.0),
		rib
	)

	_shell_box(
		bay,
		surfaces,
		"MouthCeiling",
		Vector3(WarehouseLook.MOUTH_LEN, 0.35, WarehouseLook.MOUTH_WIDTH),
		Vector3(WarehouseLook.MOUTH_LEN * 0.5, WarehouseLook.CEILING_Y, 0.0),
		rib
	)
	_shell_box(
		bay,
		surfaces,
		"RoomCeiling",
		Vector3(WarehouseLook.ROOM_DEPTH, 0.35, WarehouseLook.ROOM_WIDTH),
		Vector3(room_mid_x, WarehouseLook.CEILING_Y, 0.0),
		rib
	)

	WarehouseLook.add_box(bay, "MouthLamp", Vector3(1.3, 0.42, 0.12), Vector3(3.0, 7.2, 0.0), lamp)
	WarehouseLook.add_box(bay, "RoomLampA", Vector3(1.6, 0.42, 0.12), Vector3(12.0, 7.2, 0.0), lamp)
	WarehouseLook.add_box(bay, "RoomLampB", Vector3(1.6, 0.42, 0.12), Vector3(20.0, 7.2, 0.0), lamp)


func _shell_box(
	visual_parent: Node3D,
	body: StaticBody3D,
	node_name: String,
	size: Vector3,
	pos: Vector3,
	material: Material
) -> void:
	WarehouseLook.add_box(visual_parent, node_name, size, pos, material)
	WarehouseLook.add_collision(body, size, pos)


func _build_dressing() -> void:
	var tarp := WarehouseLook.tarp_material()
	var tarp_dark := WarehouseLook.tarp_dark_material()
	var canvas := WarehouseLook.canvas_material()
	var wood := WarehouseLook.wood_material()
	var crate := WarehouseLook.crate_material()
	var rope := WarehouseLook.rope_material()

	# Packed walls, empty aisle. Layouts add their own special hides on top.
	_wrapped_stack(tarp, rope, Vector3(8.4, 0.0, -4.85), Vector3(1.7, 1.25, 1.4), 2)
	_wrapped_stack(canvas, rope, Vector3(11.6, 0.0, -4.95), Vector3(1.4, 1.55, 1.2), 1)
	_wrapped_stack(tarp_dark, rope, Vector3(15.2, 0.0, -4.8), Vector3(1.9, 1.1, 1.5), 2)
	_wrapped_stack(tarp, rope, Vector3(19.4, 0.0, -4.9), Vector3(1.5, 1.7, 1.3), 1)
	_wrapped_stack(canvas, rope, Vector3(23.1, 0.0, -4.7), Vector3(1.6, 1.35, 1.45), 2)

	_wrapped_stack(tarp_dark, rope, Vector3(8.6, 0.0, 4.85), Vector3(1.55, 1.4, 1.35), 1)
	_wrapped_stack(tarp, rope, Vector3(12.2, 0.0, 4.9), Vector3(1.8, 1.15, 1.5), 2)
	_wrapped_stack(canvas, rope, Vector3(16.4, 0.0, 4.8), Vector3(1.45, 1.65, 1.25), 1)
	_wrapped_stack(tarp, rope, Vector3(20.5, 0.0, 4.95), Vector3(1.7, 1.3, 1.4), 2)
	_wrapped_stack(tarp_dark, rope, Vector3(23.4, 0.0, 4.75), Vector3(1.5, 1.5, 1.35), 1)

	_sofa_lump(tarp, wood, Vector3(24.4, 0.0, -2.15))
	_crate_cluster(crate, tarp, rope, Vector3(24.5, 0.0, 2.2))
	_tall_wardrobe(canvas, rope, Vector3(9.2, 0.0, 3.35))
	_tall_wardrobe(tarp_dark, rope, Vector3(9.0, 0.0, -3.4))


func _wrapped_stack(
	tarp: Material, rope: Material, origin: Vector3, size: Vector3, extra: int
) -> void:
	var body := StaticBody3D.new()
	body.name = "Wrap"
	body.position = origin
	add_child(body)
	WarehouseLook.add_box(body, "Bulk", size, Vector3(0.0, size.y * 0.5, 0.0), tarp)
	WarehouseLook.add_box(
		body,
		"Tie",
		Vector3(size.x + 0.04, 0.05, 0.05),
		Vector3(0.0, size.y * 0.62, 0.0),
		rope
	)
	if extra > 0:
		var small := Vector3(size.x * 0.55, size.y * 0.45, size.z * 0.5)
		WarehouseLook.add_box(
			body,
			"Top",
			small,
			Vector3(size.x * 0.12, size.y + small.y * 0.5, size.z * 0.08),
			tarp
		)
	WarehouseLook.add_collision(
		body, Vector3(size.x + 0.1, size.y + 0.4, size.z + 0.1), Vector3(0.0, size.y * 0.5, 0.0)
	)


func _sofa_lump(tarp: Material, wood: Material, origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "WrappedSofa"
	body.position = origin
	add_child(body)
	WarehouseLook.add_box(body, "Seat", Vector3(2.1, 0.55, 0.85), Vector3(0.0, 0.4, 0.0), tarp)
	WarehouseLook.add_box(body, "Back", Vector3(2.1, 0.7, 0.18), Vector3(0.35, 0.85, -0.32), tarp)
	WarehouseLook.add_box(body, "Leg", Vector3(0.08, 0.18, 0.08), Vector3(-0.85, 0.09, 0.3), wood)
	WarehouseLook.add_collision(body, Vector3(2.2, 1.05, 0.95), Vector3(0.1, 0.52, 0.0))


func _crate_cluster(crate: Material, tarp: Material, rope: Material, origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "CrateCluster"
	body.position = origin
	add_child(body)
	WarehouseLook.add_box(body, "A", Vector3(0.85, 0.7, 0.8), Vector3(0.0, 0.35, 0.0), crate)
	WarehouseLook.add_box(body, "B", Vector3(0.7, 0.55, 0.65), Vector3(0.55, 0.28, 0.35), tarp)
	WarehouseLook.add_box(body, "Tie", Vector3(0.9, 0.04, 0.04), Vector3(0.0, 0.62, 0.0), rope)
	WarehouseLook.add_collision(body, Vector3(1.5, 0.75, 1.2), Vector3(0.25, 0.38, 0.15))


func _tall_wardrobe(tarp: Material, rope: Material, origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Wardrobe"
	body.position = origin
	add_child(body)
	WarehouseLook.add_box(body, "Case", Vector3(0.7, 2.15, 1.05), Vector3(0.0, 1.08, 0.0), tarp)
	WarehouseLook.add_box(body, "Tie", Vector3(0.74, 0.05, 0.05), Vector3(0.0, 1.35, 0.0), rope)
	WarehouseLook.add_collision(body, Vector3(0.78, 2.2, 1.1), Vector3(0.0, 1.1, 0.0))


func _build_table() -> void:
	var wood := WarehouseLook.wood_material()
	var table := StaticBody3D.new()
	table.name = "Table"
	table.position = WarehouseLook.TABLE
	add_child(table)
	WarehouseLook.add_box(table, "Top", Vector3(1.35, 0.07, 0.78), Vector3(0.0, 0.78, 0.0), wood)
	WarehouseLook.add_box(table, "LegFL", Vector3(0.07, 0.75, 0.07), Vector3(-0.55, 0.375, 0.28), wood)
	WarehouseLook.add_box(table, "LegFR", Vector3(0.07, 0.75, 0.07), Vector3(0.55, 0.375, 0.28), wood)
	WarehouseLook.add_box(table, "LegBL", Vector3(0.07, 0.75, 0.07), Vector3(-0.55, 0.375, -0.28), wood)
	WarehouseLook.add_box(table, "LegBR", Vector3(0.07, 0.75, 0.07), Vector3(0.55, 0.375, -0.28), wood)
	WarehouseLook.add_collision(table, Vector3(1.4, 0.82, 0.82), Vector3(0.0, 0.41, 0.0))

	var chest := WarehouseChest.new()
	chest.name = "Chest"
	chest.position = WarehouseLook.TABLE + Vector3(0.0, 0.82, 0.0)
	add_child(chest)


func _build_lights() -> void:
	_omni("MouthGlow", Vector3(3.2, 4.8, 0.0), Color(1.0, 0.86, 0.62, 1.0), 1.5, 8.0)
	_omni("AisleGlow", Vector3(16.0, 5.2, 0.0), Color(0.95, 0.82, 0.58, 1.0), 2.6, 14.0)
	_omni("BackGlow", Vector3(23.5, 4.4, 0.0), Color(0.85, 0.72, 0.48, 1.0), 1.6, 9.0)
	_omni("ChestGlow", Vector3(16.0, 2.2, 0.0), Color(0.95, 0.78, 0.42, 1.0), 0.85, 4.5)


func _omni(light_name: String, pos: Vector3, color: Color, energy: float, omni_range: float) -> void:
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = omni_range
	light.shadow_enabled = false
	add_child(light)
