extends RefCounted

## Counter deck, pillars, wall panels and window/transaction openings for the shop booth.

var booth: Node3D  # the ShopCounterBooth node; reads its exports and uses its box primitives


func _init(owner: Node3D) -> void:
	booth = owner


func build_counter(deck_mat: Material, steel: Material, half_w: float, wall_x: float, deck_y: float) -> void:
	booth._add_box(
		"Deck",
		Vector3(booth.deck_depth, booth.deck_thickness, booth.booth_width),
		Vector3(-booth.deck_depth * 0.5 + wall_x, deck_y, 0.0),
		deck_mat
	)

	var lip_w: float = booth.booth_width - booth.pillar_size * 1.8
	var lip_base_y: float = booth.deck_top_y + booth._SURFACE_EPS
	booth._add_box(
		"Lip",
		Vector3(booth.lip_depth, booth.lip_thickness, lip_w),
		Vector3(-booth.deck_depth - booth.lip_depth * 0.5 + wall_x, lip_base_y + booth.lip_thickness * 0.5, 0.0),
		deck_mat
	)

	# Raised tray rim so goods sit in a protected niche.
	var rim_h := 0.06
	var rim_t := 0.04
	var lip_x: float = -booth.deck_depth - booth.lip_depth * 0.5 + wall_x
	var lip_top: float = lip_base_y + booth.lip_thickness
	booth._add_box(
		"LipRimFront",
		Vector3(rim_t, rim_h, lip_w),
		Vector3(lip_x - booth.lip_depth * 0.5 + rim_t * 0.5, lip_top + rim_h * 0.5, 0.0),
		steel
	)
	booth._add_box(
		"LipRimLeft",
		Vector3(booth.lip_depth, rim_h, rim_t),
		Vector3(lip_x, lip_top + rim_h * 0.5, -lip_w * 0.5 + rim_t * 0.5),
		steel
	)
	booth._add_box(
		"LipRimRight",
		Vector3(booth.lip_depth, rim_h, rim_t),
		Vector3(lip_x, lip_top + rim_h * 0.5, lip_w * 0.5 - rim_t * 0.5),
		steel
	)

	# Underside braces.
	for i in 3:
		var t := lerpf(-0.7, 0.7, float(i) / 2.0)
		booth._add_box(
			"DeckBrace_%d" % i,
			Vector3(booth.deck_depth * 0.85, 0.08, 0.1),
			Vector3(-booth.deck_depth * 0.45 + wall_x, booth.deck_top_y - booth.deck_thickness - 0.04, half_w * t),
			steel
		)


func build_pillars(steel: Material, rivet_mat: Material, half_w: float, wall_x: float) -> void:
	var pillar_depth: float = booth.wall_thickness + booth.deck_depth * 0.45
	var pillar_x: float = wall_x + booth.deck_depth * 0.12
	for side: float in [-1.0, 1.0]:
		var z: float = side * (half_w - booth.pillar_size * 0.5)
		var name_side: String = "Left" if side < 0.0 else "Right"
		booth._add_box(
			"Pillar%s" % name_side,
			Vector3(pillar_depth, booth.wall_height, booth.pillar_size),
			Vector3(pillar_x, booth.wall_height * 0.5, z),
			steel
		)
		# Outer armor sleeve.
		booth._add_box(
			"PillarSleeve%s" % name_side,
			Vector3(pillar_depth * 0.55, booth.wall_height * 0.92, booth.pillar_size * 1.15),
			Vector3(pillar_x - pillar_depth * 0.18, booth.wall_height * 0.46, z),
			steel
		)
		booth._add_rivet_column(
			"PillarRivets%s" % name_side,
			Vector3(pillar_x - pillar_depth * 0.45, 0.35, z),
			booth.wall_height - 0.7,
			8,
			rivet_mat
		)


func build_wall_panels(
	panel_mat: Material,
	steel: Material,
	half_w: float,
	wall_x: float,
	face_x: float,
	view_bottom: float,
	view_top: float,
	tx_bottom: float,
	tx_top: float
) -> void:
	var center_w: float = maxf(booth.viewing_width, booth.transaction_width) + 0.2
	var flank_inner := center_w * 0.5
	var flank_w := half_w - flank_inner

	# Header above viewing window (center span only — flanks own the sides).
	var header_h: float = booth.wall_height - view_top
	if header_h > 0.08:
		booth._add_box(
			"Header",
			Vector3(booth.wall_thickness, header_h, center_w),
			Vector3(wall_x, view_top + header_h * 0.5, 0.0),
			panel_mat
		)
		booth._add_box(
			"HeaderFacePlate",
			Vector3(booth.plate_overhang, header_h * 0.96, center_w - 0.12),
			Vector3(face_x, view_top + header_h * 0.5, 0.0),
			panel_mat
		)

	# Thin band between cash slot and viewing window.
	var mid_h := view_bottom - tx_top
	if mid_h > 0.04:
		booth._add_box(
			"MidPanel",
			Vector3(booth.wall_thickness, mid_h, center_w),
			Vector3(wall_x, (view_bottom + tx_top) * 0.5, 0.0),
			steel
		)

	# Solid armor below the cash slot.
	if tx_bottom > 0.06:
		booth._add_box(
			"LowerPanel",
			Vector3(booth.wall_thickness, tx_bottom, center_w),
			Vector3(wall_x, tx_bottom * 0.5, 0.0),
			panel_mat
		)
		booth._add_box(
			"LowerFacePlate",
			Vector3(booth.plate_overhang, tx_bottom * 0.92, center_w - 0.15),
			Vector3(face_x, tx_bottom * 0.46, 0.0),
			panel_mat
		)

	# Full-height armored wings beside the openings.
	if flank_w > 0.12:
		for side: float in [-1.0, 1.0]:
			var z: float = side * (flank_inner + flank_w * 0.5)
			var name_side: String = "L" if side < 0.0 else "R"
			booth._add_box(
				"Flank_%s" % name_side,
				Vector3(booth.wall_thickness, booth.wall_height, flank_w),
				Vector3(wall_x, booth.wall_height * 0.5, z),
				panel_mat
			)
			booth._add_box(
				"FlankPlate_%s" % name_side,
				Vector3(booth.plate_overhang * 1.2, booth.wall_height * 0.94, flank_w - 0.08),
				Vector3(face_x - 0.01, booth.wall_height * 0.47, z),
				panel_mat
			)


func build_openings(
	steel: Material,
	rivet_mat: Material,
	wall_x: float,
	face_x: float,
	view_half_w: float,
	view_half_h: float,
	tx_half_w: float,
	tx_half_h: float,
	half_w: float
) -> void:
	booth._add_jamb_pair("Tx", wall_x, booth.transaction_center_y, tx_half_w, tx_half_h, half_w, steel)
	booth._add_jamb_pair("View", wall_x, booth.viewing_center_y, view_half_w, view_half_h, half_w, steel)

	var tx_bottom: float = booth.transaction_center_y - tx_half_h
	var tx_sill_h: float = maxf(0.04, tx_bottom - (booth.deck_top_y + booth._SURFACE_EPS))
	booth._add_box(
		"TxSill",
		Vector3(booth.wall_thickness * 1.35, tx_sill_h, booth.transaction_width + 0.12),
		Vector3(wall_x - 0.02, booth.deck_top_y + booth._SURFACE_EPS + tx_sill_h * 0.5, 0.0),
		steel
	)
	booth._add_box(
		"TxLintel",
		Vector3(booth.wall_thickness * 1.35, 0.08, booth.transaction_width + 0.12),
		Vector3(wall_x - 0.02, booth.transaction_center_y + tx_half_h + 0.04, 0.0),
		steel
	)
	booth._add_box(
		"ViewSill",
		Vector3(booth.wall_thickness * 1.4, 0.1, booth.viewing_width + 0.16),
		Vector3(wall_x - 0.03, booth.viewing_center_y - view_half_h - 0.05, 0.0),
		steel
	)
	booth._add_box(
		"ViewLintel",
		Vector3(booth.wall_thickness * 1.4, 0.1, booth.viewing_width + 0.16),
		Vector3(wall_x - 0.03, booth.viewing_center_y + view_half_h + 0.05, 0.0),
		steel
	)

	# Frame rivets around the viewing opening.
	var frame_x := face_x - 0.02
	for side: float in [-1.0, 1.0]:
		var z: float = side * (view_half_w + 0.08)
		booth._add_rivet_column(
			"ViewFrameRivets_%s" % ("L" if side < 0.0 else "R"),
			Vector3(frame_x, booth.viewing_center_y - view_half_h + 0.1, z),
			booth.viewing_height - 0.2,
			5,
			rivet_mat
		)
