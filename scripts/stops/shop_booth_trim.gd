extends RefCounted

## Armor plating, viewing grill, window brow, lamp visuals and shop sign for the shop booth.

const _BoothMaterials := preload("res://scripts/stops/shop_booth_materials.gd")
const _BoothFlyers := preload("res://scripts/stops/shop_booth_flyers.gd")

var booth: Node3D  # the ShopCounterBooth node; reads its exports and uses its box primitives


func _init(owner: Node3D) -> void:
	booth = owner


func build_armor_details(
	steel: Material,
	rivet_mat: Material,
	panel_mat: Material,
	half_w: float,
	wall_x: float,
	face_x: float,
	view_top: float,
	tx_bottom: float
) -> void:
	# Horizontal seam ribs across the booth face.
	var rib_depths: Array[float] = [
		tx_bottom * 0.55,
		view_top + 0.55,
		view_top + 1.8,
		view_top + 3.2,
		view_top + 4.6,
	]
	for i in rib_depths.size():
		var y: float = rib_depths[i]
		if y >= booth.wall_height - 0.2:
			continue
		booth._add_box(
			"SeamRib_%d" % i,
			Vector3(booth.plate_overhang * 1.6, 0.07, booth.booth_width - 0.35),
			Vector3(face_x - 0.02, y, 0.0),
			steel
		)

	# Overlapping header plates — staggered so they do not share the same Z span.
	var plate_h := 1.15
	var plate_w: float = booth.booth_width * 0.38
	var plate_y0 := view_top + 0.85
	for i in 3:
		var y := plate_y0 + float(i) * (plate_h * 0.92)
		if y + plate_h * 0.5 > booth.wall_height:
			break
		var z_off := lerpf(-1.55, 1.55, float(i) / 2.0)
		booth._add_box(
			"ArmorPlate_%d" % i,
			Vector3(booth.plate_overhang * 1.8, plate_h, plate_w),
			Vector3(face_x - 0.03 - float(i) * 0.008, y, z_off),
			panel_mat
		)
		booth._add_rivet_row(
			"ArmorPlateRivets_%d" % i,
			Vector3(face_x - 0.06, y + plate_h * 0.38, z_off),
			booth.booth_width * 0.34,
			6,
			rivet_mat
		)
		booth._add_rivet_row(
			"ArmorPlateRivetsLow_%d" % i,
			Vector3(face_x - 0.06, y - plate_h * 0.38, z_off),
			booth.booth_width * 0.34,
			6,
			rivet_mat
		)

	# Corner gussets at the base.
	for side: float in [-1.0, 1.0]:
		booth._add_box(
			"Gusset_%s" % ("L" if side < 0.0 else "R"),
			Vector3(0.35, 0.55, 0.35),
			Vector3(wall_x - 0.12, 0.28, side * (half_w - 0.55)),
			steel
		)

	# Kick plate strip along the lower face.
	booth._add_box(
		"KickPlate",
		Vector3(booth.plate_overhang * 1.4, 0.28, booth.booth_width - 0.5),
		Vector3(face_x - 0.015, 0.16, 0.0),
		steel
	)


func build_viewing_grill(wall_x: float, half_w: float, half_h: float, material: Material) -> void:
	var usable_w := half_w * 2.0
	var usable_h := half_h * 2.0
	var bar_d: float = booth.wall_thickness * 0.55
	var grill_x := wall_x - 0.01

	# Vertical bars.
	var v_count: int = maxi(3, int(ceil(usable_w / booth.grill_spacing)) + 1)
	var v_step := usable_w / float(v_count - 1)
	for i in range(v_count):
		var z := -half_w + float(i) * v_step
		booth._add_box(
			"GrillV_%d" % i,
			Vector3(bar_d, usable_h + 0.02, booth.grill_bar_size),
			Vector3(grill_x, booth.viewing_center_y, z),
			material
		)

	# Horizontal bars.
	var h_count: int = maxi(3, int(ceil(usable_h / booth.grill_spacing)) + 1)
	var h_step := usable_h / float(h_count - 1)
	for i in range(h_count):
		var y: float = booth.viewing_center_y - half_h + float(i) * h_step
		booth._add_box(
			"GrillH_%d" % i,
			Vector3(bar_d, booth.grill_bar_size, usable_w + 0.02),
			Vector3(grill_x, y, 0.0),
			material
		)


func build_window_brow(steel: Material, rivet_mat: Material, wall_x: float, view_top: float) -> void:
	var brow_depth := 0.38
	var brow_y := view_top + 0.12
	booth._add_box(
		"WindowBrow",
		Vector3(brow_depth, 0.12, booth.viewing_width + 0.45),
		Vector3(wall_x - brow_depth * 0.35, brow_y, 0.0),
		steel
	)
	booth._add_box(
		"WindowBrowLip",
		Vector3(0.08, 0.18, booth.viewing_width + 0.5),
		Vector3(wall_x - brow_depth * 0.7, brow_y - 0.04, 0.0),
		steel
	)
	booth._add_rivet_row(
		"BrowRivets",
		Vector3(wall_x - brow_depth * 0.55, brow_y + 0.07, 0.0),
		booth.viewing_width + 0.2,
		8,
		rivet_mat
	)


func build_lamp_visuals(lamp_mat: Material, steel: Material, wall_x: float, view_top: float) -> void:
	var lamp_y := view_top + 0.42
	for i in 2:
		var z := lerpf(-1.1, 1.1, float(i))
		booth._add_box(
			"LampCage_%d" % i,
			Vector3(0.16, 0.14, 0.28),
			Vector3(wall_x - 0.22, lamp_y, z),
			steel
		)
		booth._add_box(
			"LampBulb_%d" % i,
			Vector3(0.1, 0.08, 0.2),
			Vector3(wall_x - 0.24, lamp_y, z),
			lamp_mat
		)


func build_shop_sign(sign_mat: Material, steel: Material, wall_x: float, view_top: float) -> void:
	var sign_y := view_top + 1.15
	booth._add_box(
		"ShopSign",
		Vector3(0.06, 0.55, 2.4),
		Vector3(wall_x - 0.18, sign_y, 0.0),
		sign_mat
	)
	booth._add_box(
		"ShopSignFrame",
		Vector3(0.08, 0.62, 2.55),
		Vector3(wall_x - 0.14, sign_y, 0.0),
		steel
	)
	booth._add_box(
		"ShopSignChainL",
		Vector3(0.03, 0.35, 0.03),
		Vector3(wall_x - 0.16, sign_y + 0.42, -0.95),
		steel
	)
	booth._add_box(
		"ShopSignChainR",
		Vector3(0.03, 0.35, 0.03),
		Vector3(wall_x - 0.16, sign_y + 0.42, 0.95),
		steel
	)

	var letter_mat := _BoothMaterials.sign_letter_material()
	var face_x := wall_x - 0.18 - 0.03
	build_sign_letters(face_x, sign_y, letter_mat)


func build_sign_letters(face_x: float, sign_y: float, letter_mat: Material) -> void:
	var text := "SHOP"
	var cell := 0.066
	var gap := 0.095
	var depth := 0.038
	var glyph_cols := 5
	var glyph_rows := 7

	var total_z := 0.0
	for ch in text:
		if not _BoothFlyers.glyph_pattern(ch).is_empty():
			total_z += glyph_cols * cell
		total_z += gap
	total_z -= gap

	var cursor_z := -total_z * 0.5
	for ch in text:
		var pattern := _BoothFlyers.glyph_pattern(ch)
		if pattern.is_empty():
			cursor_z += gap
			continue
		for row in pattern.size():
			var bits: int = pattern[row]
			for col in glyph_cols:
				if (bits >> (glyph_cols - 1 - col)) & 1:
					var cy := sign_y + (float(glyph_rows) * 0.5 - float(row) - 0.5) * cell
					var cz := cursor_z + (float(col) + 0.5) * cell
					booth._add_box(
						"SignLetter_%s_%d_%d" % [ch, row, col],
						Vector3(depth, cell * 0.94, cell * 0.94),
						Vector3(face_x - depth * 0.5 - 0.004, cy, cz),
						letter_mat
					)
		cursor_z += glyph_cols * cell + gap
