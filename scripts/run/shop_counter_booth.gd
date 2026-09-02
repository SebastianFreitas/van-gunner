extends Node3D

## Fortified metal shop counter — armored face, cash slot, eye-level grilled window.

const _INDUSTRIAL_SHADER := preload("res://scenes/corridor/industrial_surface.gdshader")

@export var booth_width := 8.2
@export var deck_depth := 1.15
@export var deck_thickness := 0.14
@export var deck_top_y := 1.0
@export var wall_height := 7.15
@export var wall_thickness := 0.22
@export var pillar_size := 0.42
@export var transaction_width := 3.2
@export var transaction_height := 0.28
@export var transaction_center_y := 1.18
@export var viewing_width := 3.6
@export var viewing_height := 1.15
@export var viewing_center_y := 1.9
@export var grill_spacing := 0.22
@export var grill_bar_size := 0.028
@export var lip_depth := 0.34
@export var lip_thickness := 0.1
@export var rivet_size := 0.055
@export var plate_overhang := 0.045

## Tiny lift so stacked counter surfaces do not share the same plane (z-fighting).
const _SURFACE_EPS := 0.004

const _FLYER_TEXTS := [
	"50% OFF!",
	"NEW STOCK",
	"NO REFUNDS",
	"HOT DEALS",
	"CASH ONLY",
	"OPEN LATE",
	"CLOSING OUT",
	"LIMITED",
	"BEST PRICE",
	"TRADE IN",
	"SPECIAL",
	"TODAY ONLY",
	"ROLL BACK",
	"LAST CHANCE",
	"RED TAG",
]

const _FLYER_SUBTEXTS := [
	"TODAY",
	"WEEKEND",
	"BULK",
	"ASK INSIDE",
	"FINAL",
	"CLEARANCE",
	"SAVE",
	"MUST GO",
	"FRESH IN",
	"WHILE LASTS",
	"DEAL",
	"INSIDE",
	"NOW OPEN",
	"2 FOR 1",
	"LOW COST",
]


func _ready() -> void:
	_build()


func _build() -> void:
	var steel := _steel_material()
	var deck_mat := _deck_material()
	var panel_mat := _panel_material()
	var rivet_mat := _rivet_material()
	var grill_mat := _grill_material()
	var lamp_mat := _lamp_material()
	var sign_mat := _sign_material()

	var half_w := booth_width * 0.5
	var wall_x := wall_thickness * 0.5
	var deck_y := deck_top_y - deck_thickness * 0.5
	var face_x := -plate_overhang * 0.5

	var view_half_w := viewing_width * 0.5
	var view_half_h := viewing_height * 0.5
	var tx_half_w := transaction_width * 0.5
	var tx_half_h := transaction_height * 0.5
	var view_bottom := viewing_center_y - view_half_h
	var view_top := viewing_center_y + view_half_h
	var tx_bottom := transaction_center_y - tx_half_h
	var tx_top := transaction_center_y + tx_half_h

	_build_counter(deck_mat, steel, half_w, wall_x, deck_y)
	_build_pillars(steel, rivet_mat, half_w, wall_x)
	_build_wall_panels(panel_mat, steel, half_w, wall_x, face_x, view_bottom, view_top, tx_bottom, tx_top)
	_build_openings(steel, rivet_mat, wall_x, face_x, view_half_w, view_half_h, tx_half_w, tx_half_h, half_w)
	_build_armor_details(steel, rivet_mat, panel_mat, half_w, wall_x, face_x, view_top, tx_bottom)
	_build_viewing_grill(wall_x, view_half_w, view_half_h, grill_mat)
	_build_window_brow(steel, rivet_mat, wall_x, view_top)
	_build_lamps(lamp_mat, steel, wall_x, view_top)
	_build_shop_sign(sign_mat, steel, wall_x, view_top)
	_build_flyers(face_x, half_w, view_half_w, view_bottom, tx_bottom)


func _build_counter(deck_mat: Material, steel: Material, half_w: float, wall_x: float, deck_y: float) -> void:
	_add_box(
		"Deck",
		Vector3(deck_depth, deck_thickness, booth_width),
		Vector3(-deck_depth * 0.5 + wall_x, deck_y, 0.0),
		deck_mat
	)

	var lip_w := booth_width - pillar_size * 1.8
	var lip_base_y := deck_top_y + _SURFACE_EPS
	_add_box(
		"Lip",
		Vector3(lip_depth, lip_thickness, lip_w),
		Vector3(-deck_depth - lip_depth * 0.5 + wall_x, lip_base_y + lip_thickness * 0.5, 0.0),
		deck_mat
	)

	# Raised tray rim so goods sit in a protected niche.
	var rim_h := 0.06
	var rim_t := 0.04
	var lip_x := -deck_depth - lip_depth * 0.5 + wall_x
	var lip_top := lip_base_y + lip_thickness
	_add_box(
		"LipRimFront",
		Vector3(rim_t, rim_h, lip_w),
		Vector3(lip_x - lip_depth * 0.5 + rim_t * 0.5, lip_top + rim_h * 0.5, 0.0),
		steel
	)
	_add_box(
		"LipRimLeft",
		Vector3(lip_depth, rim_h, rim_t),
		Vector3(lip_x, lip_top + rim_h * 0.5, -lip_w * 0.5 + rim_t * 0.5),
		steel
	)
	_add_box(
		"LipRimRight",
		Vector3(lip_depth, rim_h, rim_t),
		Vector3(lip_x, lip_top + rim_h * 0.5, lip_w * 0.5 - rim_t * 0.5),
		steel
	)

	# Underside braces.
	for i in 3:
		var t := lerpf(-0.7, 0.7, float(i) / 2.0)
		_add_box(
			"DeckBrace_%d" % i,
			Vector3(deck_depth * 0.85, 0.08, 0.1),
			Vector3(-deck_depth * 0.45 + wall_x, deck_top_y - deck_thickness - 0.04, half_w * t),
			steel
		)


func _build_pillars(steel: Material, rivet_mat: Material, half_w: float, wall_x: float) -> void:
	var pillar_depth := wall_thickness + deck_depth * 0.45
	var pillar_x := wall_x + deck_depth * 0.12
	for side: float in [-1.0, 1.0]:
		var z: float = side * (half_w - pillar_size * 0.5)
		var name_side: String = "Left" if side < 0.0 else "Right"
		_add_box(
			"Pillar%s" % name_side,
			Vector3(pillar_depth, wall_height, pillar_size),
			Vector3(pillar_x, wall_height * 0.5, z),
			steel
		)
		# Outer armor sleeve.
		_add_box(
			"PillarSleeve%s" % name_side,
			Vector3(pillar_depth * 0.55, wall_height * 0.92, pillar_size * 1.15),
			Vector3(pillar_x - pillar_depth * 0.18, wall_height * 0.46, z),
			steel
		)
		_add_rivet_column(
			"PillarRivets%s" % name_side,
			Vector3(pillar_x - pillar_depth * 0.45, 0.35, z),
			wall_height - 0.7,
			8,
			rivet_mat
		)


func _build_wall_panels(
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
	var center_w := maxf(viewing_width, transaction_width) + 0.2
	var flank_inner := center_w * 0.5
	var flank_w := half_w - flank_inner

	# Header above viewing window (center span only — flanks own the sides).
	var header_h := wall_height - view_top
	if header_h > 0.08:
		_add_box(
			"Header",
			Vector3(wall_thickness, header_h, center_w),
			Vector3(wall_x, view_top + header_h * 0.5, 0.0),
			panel_mat
		)
		_add_box(
			"HeaderFacePlate",
			Vector3(plate_overhang, header_h * 0.96, center_w - 0.12),
			Vector3(face_x, view_top + header_h * 0.5, 0.0),
			panel_mat
		)

	# Thin band between cash slot and viewing window.
	var mid_h := view_bottom - tx_top
	if mid_h > 0.04:
		_add_box(
			"MidPanel",
			Vector3(wall_thickness, mid_h, center_w),
			Vector3(wall_x, (view_bottom + tx_top) * 0.5, 0.0),
			steel
		)

	# Solid armor below the cash slot.
	if tx_bottom > 0.06:
		_add_box(
			"LowerPanel",
			Vector3(wall_thickness, tx_bottom, center_w),
			Vector3(wall_x, tx_bottom * 0.5, 0.0),
			panel_mat
		)
		_add_box(
			"LowerFacePlate",
			Vector3(plate_overhang, tx_bottom * 0.92, center_w - 0.15),
			Vector3(face_x, tx_bottom * 0.46, 0.0),
			panel_mat
		)

	# Full-height armored wings beside the openings.
	if flank_w > 0.12:
		for side: float in [-1.0, 1.0]:
			var z: float = side * (flank_inner + flank_w * 0.5)
			var name_side: String = "L" if side < 0.0 else "R"
			_add_box(
				"Flank_%s" % name_side,
				Vector3(wall_thickness, wall_height, flank_w),
				Vector3(wall_x, wall_height * 0.5, z),
				panel_mat
			)
			_add_box(
				"FlankPlate_%s" % name_side,
				Vector3(plate_overhang * 1.2, wall_height * 0.94, flank_w - 0.08),
				Vector3(face_x - 0.01, wall_height * 0.47, z),
				panel_mat
			)


func _build_openings(
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
	_add_jamb_pair("Tx", wall_x, transaction_center_y, tx_half_w, tx_half_h, half_w, steel)
	_add_jamb_pair("View", wall_x, viewing_center_y, view_half_w, view_half_h, half_w, steel)

	var tx_bottom := transaction_center_y - tx_half_h
	var tx_sill_h := maxf(0.04, tx_bottom - (deck_top_y + _SURFACE_EPS))
	_add_box(
		"TxSill",
		Vector3(wall_thickness * 1.35, tx_sill_h, transaction_width + 0.12),
		Vector3(wall_x - 0.02, deck_top_y + _SURFACE_EPS + tx_sill_h * 0.5, 0.0),
		steel
	)
	_add_box(
		"TxLintel",
		Vector3(wall_thickness * 1.35, 0.08, transaction_width + 0.12),
		Vector3(wall_x - 0.02, transaction_center_y + tx_half_h + 0.04, 0.0),
		steel
	)
	_add_box(
		"ViewSill",
		Vector3(wall_thickness * 1.4, 0.1, viewing_width + 0.16),
		Vector3(wall_x - 0.03, viewing_center_y - view_half_h - 0.05, 0.0),
		steel
	)
	_add_box(
		"ViewLintel",
		Vector3(wall_thickness * 1.4, 0.1, viewing_width + 0.16),
		Vector3(wall_x - 0.03, viewing_center_y + view_half_h + 0.05, 0.0),
		steel
	)

	# Frame rivets around the viewing opening.
	var frame_x := face_x - 0.02
	for side: float in [-1.0, 1.0]:
		var z: float = side * (view_half_w + 0.08)
		_add_rivet_column(
			"ViewFrameRivets_%s" % ("L" if side < 0.0 else "R"),
			Vector3(frame_x, viewing_center_y - view_half_h + 0.1, z),
			viewing_height - 0.2,
			5,
			rivet_mat
		)


func _build_armor_details(
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
		if y >= wall_height - 0.2:
			continue
		_add_box(
			"SeamRib_%d" % i,
			Vector3(plate_overhang * 1.6, 0.07, booth_width - 0.35),
			Vector3(face_x - 0.02, y, 0.0),
			steel
		)

	# Overlapping header plates — staggered so they do not share the same Z span.
	var plate_h := 1.15
	var plate_w := booth_width * 0.38
	var plate_y0 := view_top + 0.85
	for i in 3:
		var y := plate_y0 + float(i) * (plate_h * 0.92)
		if y + plate_h * 0.5 > wall_height:
			break
		var z_off := lerpf(-1.55, 1.55, float(i) / 2.0)
		_add_box(
			"ArmorPlate_%d" % i,
			Vector3(plate_overhang * 1.8, plate_h, plate_w),
			Vector3(face_x - 0.03 - float(i) * 0.008, y, z_off),
			panel_mat
		)
		_add_rivet_row(
			"ArmorPlateRivets_%d" % i,
			Vector3(face_x - 0.06, y + plate_h * 0.38, z_off),
			booth_width * 0.34,
			6,
			rivet_mat
		)
		_add_rivet_row(
			"ArmorPlateRivetsLow_%d" % i,
			Vector3(face_x - 0.06, y - plate_h * 0.38, z_off),
			booth_width * 0.34,
			6,
			rivet_mat
		)

	# Corner gussets at the base.
	for side: float in [-1.0, 1.0]:
		_add_box(
			"Gusset_%s" % ("L" if side < 0.0 else "R"),
			Vector3(0.35, 0.55, 0.35),
			Vector3(wall_x - 0.12, 0.28, side * (half_w - 0.55)),
			steel
		)

	# Kick plate strip along the lower face.
	_add_box(
		"KickPlate",
		Vector3(plate_overhang * 1.4, 0.28, booth_width - 0.5),
		Vector3(face_x - 0.015, 0.16, 0.0),
		steel
	)


func _build_viewing_grill(wall_x: float, half_w: float, half_h: float, material: Material) -> void:
	var usable_w := half_w * 2.0
	var usable_h := half_h * 2.0
	var bar_d := wall_thickness * 0.55
	var grill_x := wall_x - 0.01

	# Vertical bars.
	var v_count := maxi(3, int(ceil(usable_w / grill_spacing)) + 1)
	var v_step := usable_w / float(v_count - 1)
	for i in range(v_count):
		var z := -half_w + float(i) * v_step
		_add_box(
			"GrillV_%d" % i,
			Vector3(bar_d, usable_h + 0.02, grill_bar_size),
			Vector3(grill_x, viewing_center_y, z),
			material
		)

	# Horizontal bars.
	var h_count := maxi(3, int(ceil(usable_h / grill_spacing)) + 1)
	var h_step := usable_h / float(h_count - 1)
	for i in range(h_count):
		var y := viewing_center_y - half_h + float(i) * h_step
		_add_box(
			"GrillH_%d" % i,
			Vector3(bar_d, grill_bar_size, usable_w + 0.02),
			Vector3(grill_x, y, 0.0),
			material
		)


func _build_window_brow(steel: Material, rivet_mat: Material, wall_x: float, view_top: float) -> void:
	var brow_depth := 0.38
	var brow_y := view_top + 0.12
	_add_box(
		"WindowBrow",
		Vector3(brow_depth, 0.12, viewing_width + 0.45),
		Vector3(wall_x - brow_depth * 0.35, brow_y, 0.0),
		steel
	)
	_add_box(
		"WindowBrowLip",
		Vector3(0.08, 0.18, viewing_width + 0.5),
		Vector3(wall_x - brow_depth * 0.7, brow_y - 0.04, 0.0),
		steel
	)
	_add_rivet_row(
		"BrowRivets",
		Vector3(wall_x - brow_depth * 0.55, brow_y + 0.07, 0.0),
		viewing_width + 0.2,
		8,
		rivet_mat
	)


func _build_lamps(lamp_mat: Material, steel: Material, wall_x: float, view_top: float) -> void:
	var lamp_y := view_top + 0.42
	for i in 2:
		var z := lerpf(-1.1, 1.1, float(i))
		_add_box(
			"LampCage_%d" % i,
			Vector3(0.16, 0.14, 0.28),
			Vector3(wall_x - 0.22, lamp_y, z),
			steel
		)
		_add_box(
			"LampBulb_%d" % i,
			Vector3(0.1, 0.08, 0.2),
			Vector3(wall_x - 0.24, lamp_y, z),
			lamp_mat
		)
		var light := OmniLight3D.new()
		light.name = "BoothLampLight_%d" % i
		light.position = Vector3(wall_x - 0.35, lamp_y - 0.05, z)
		light.light_color = Color(1.0, 0.72, 0.42, 1.0)
		light.light_energy = 1.35
		light.omni_range = 4.5
		light.shadow_enabled = false
		add_child(light)


func _build_shop_sign(sign_mat: Material, steel: Material, wall_x: float, view_top: float) -> void:
	var sign_y := view_top + 1.15
	_add_box(
		"ShopSign",
		Vector3(0.06, 0.55, 2.4),
		Vector3(wall_x - 0.18, sign_y, 0.0),
		sign_mat
	)
	_add_box(
		"ShopSignFrame",
		Vector3(0.08, 0.62, 2.55),
		Vector3(wall_x - 0.14, sign_y, 0.0),
		steel
	)
	_add_box(
		"ShopSignChainL",
		Vector3(0.03, 0.35, 0.03),
		Vector3(wall_x - 0.16, sign_y + 0.42, -0.95),
		steel
	)
	_add_box(
		"ShopSignChainR",
		Vector3(0.03, 0.35, 0.03),
		Vector3(wall_x - 0.16, sign_y + 0.42, 0.95),
		steel
	)

	# Stencil-ish letters as raised blocks (SHOP).
	var letter_mat := sign_mat
	var letter_y := sign_y
	var letters_z := [-0.75, -0.25, 0.25, 0.75]
	for i in letters_z.size():
		_add_box(
			"SignLetter_%d" % i,
			Vector3(0.04, 0.28, 0.28),
			Vector3(wall_x - 0.22, letter_y, letters_z[i]),
			letter_mat
		)


func _build_flyers(
	face_x: float,
	half_w: float,
	view_half_w: float,
	view_bottom: float,
	tx_bottom: float
) -> void:
	# Stickers only on solid metal — flanks and header, never in the open window.
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var titles := _FLYER_TEXTS.duplicate()
	_shuffle_array(titles, rng)

	var placed: Array[Dictionary] = []
	var target_count := rng.randi_range(5, 7)
	var flyer_i := 0
	var attempts := 0
	var max_attempts := 80

	while placed.size() < target_count and attempts < max_attempts:
		attempts += 1
		var w := rng.randf_range(0.36, 0.58)
		var h := rng.randf_range(0.44, 0.74)
		var z := rng.randf_range(-half_w + 0.65, half_w - 0.65)
		var y := _pick_flyer_y(rng, view_bottom, tx_bottom)
		var rot := rng.randf_range(-9.0, 9.0)

		if _flyer_in_window(z, y, w, h, view_half_w, view_bottom):
			continue
		if _flyer_in_transaction(z, y, w, h):
			continue
		if _flyer_overlaps(placed, z, y, w, h):
			continue

		placed.append({"z": z, "y": y, "rot": rot, "w": w, "h": h})
		var text: String = titles[flyer_i % titles.size()]
		flyer_i += 1
		var tex := _make_flyer_texture(text, flyer_i, rng)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.roughness = 0.92
		mat.metallic = 0.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

		var depth := face_x - 0.055 - float(placed.size() - 1) * 0.004 - rng.randf_range(0.0, 0.012)
		var mi := _add_flyer_plane(
			"Flyer_%d" % (placed.size() - 1),
			Vector2(w, h),
			Vector3(depth, y, z),
			mat,
			rot
		)


func _pick_flyer_y(rng: RandomNumberGenerator, view_bottom: float, tx_bottom: float) -> float:
	# Weight toward flank/header bands; keep clear of the cash slot midline.
	var band := rng.randi_range(0, 2)
	match band:
		0:
			var y_min := maxf(0.35, tx_bottom * 0.35)
			var y_max := tx_bottom - 0.12
			if y_max <= y_min:
				y_max = y_min + 0.08
			return rng.randf_range(y_min, y_max)
		1:
			return rng.randf_range(view_bottom + 0.55, view_bottom + 1.35)
		_:
			return rng.randf_range(viewing_center_y + viewing_height * 0.55, wall_height - 0.55)


func _flyer_in_window(z: float, y: float, w: float, h: float, view_half_w: float, view_bottom: float) -> bool:
	var pad_z := 0.22
	var pad_y := 0.18
	var in_window_z := absf(z) < view_half_w + pad_z + w * 0.25
	var view_top := viewing_center_y + viewing_height * 0.5
	var in_window_y := y + h * 0.5 > view_bottom - pad_y and y - h * 0.5 < view_top + pad_y
	return in_window_z and in_window_y


func _flyer_in_transaction(z: float, y: float, w: float, h: float) -> bool:
	var tx_half_w := transaction_width * 0.5
	var tx_half_h := transaction_height * 0.5
	var pad_z := 0.18
	var pad_y := 0.12
	var in_tx_z := absf(z) < tx_half_w + pad_z + w * 0.2
	var tx_bottom := transaction_center_y - tx_half_h
	var tx_top := transaction_center_y + tx_half_h
	var in_tx_y := y + h * 0.5 > tx_bottom - pad_y and y - h * 0.5 < tx_top + pad_y
	return in_tx_z and in_tx_y


func _flyer_overlaps(placed: Array[Dictionary], z: float, y: float, w: float, h: float) -> bool:
	var margin := 0.14
	for p in placed:
		var pz: float = p.z
		var py: float = p.y
		var pw: float = p.w
		var ph: float = p.h
		if absf(z - pz) < (w + pw) * 0.5 + margin and absf(y - py) < (h + ph) * 0.5 + margin:
			return true
	return false


func _shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _make_flyer_texture(title: String, seed_i: int, rng: RandomNumberGenerator) -> ImageTexture:
	var w := 192
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	var papers := [
		Color(0.78, 0.7, 0.52, 1.0),
		Color(0.72, 0.62, 0.48, 1.0),
		Color(0.8, 0.74, 0.6, 1.0),
		Color(0.7, 0.55, 0.4, 1.0),
		Color(0.65, 0.68, 0.58, 1.0),
		Color(0.76, 0.58, 0.45, 1.0),
		Color(0.68, 0.72, 0.64, 1.0),
		Color(0.74, 0.66, 0.54, 1.0),
	]
	var inks := [
		Color(0.45, 0.08, 0.06, 0.85),
		Color(0.12, 0.14, 0.28, 0.8),
		Color(0.08, 0.08, 0.08, 0.75),
		Color(0.35, 0.12, 0.05, 0.82),
		Color(0.1, 0.22, 0.12, 0.78),
		Color(0.4, 0.05, 0.2, 0.8),
		Color(0.28, 0.18, 0.08, 0.82),
		Color(0.05, 0.18, 0.32, 0.78),
	]
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 9100 + seed_i * 97 + int(rng.randi())
	var paper: Color = papers[local_rng.randi() % papers.size()]
	var ink: Color = inks[local_rng.randi() % inks.size()]
	img.fill(paper)
	for _i in local_rng.randi_range(80, 140):
		var px := local_rng.randi_range(0, w - 1)
		var py := local_rng.randi_range(0, h - 1)
		var stain := paper.darkened(local_rng.randf_range(0.08, 0.35))
		stain.a = local_rng.randf_range(0.25, 0.7)
		img.set_pixel(px, py, stain)
		if local_rng.randf() < 0.35 and px + 1 < w and py + 1 < h:
			img.set_pixel(px + 1, py, stain)
			img.set_pixel(px, py + 1, stain)

	# Torn / darker edges.
	for x in w:
		for edge_y in [0, 1, 2, h - 1, h - 2, h - 3]:
			var edge := paper.darkened(0.25)
			edge.a = 0.9
			img.set_pixel(x, edge_y, edge)
	for y in h:
		for edge_x in [0, 1, 2, w - 1, w - 2, w - 3]:
			var edge := paper.darkened(0.22)
			edge.a = 0.9
			img.set_pixel(edge_x, y, edge)

	# Crude block-letter headline (intentionally half-legible).
	var headline_scale := local_rng.randi_range(2, 3)
	var headline_y := local_rng.randi_range(58, 88)
	var headline_x := _centered_text_x(title, w, headline_scale, local_rng)
	_draw_block_text(img, title, Vector2i(headline_x, headline_y), ink, headline_scale)

	# One or two varied sub-lines — never the same pair on every flyer.
	var sub_pool := _FLYER_SUBTEXTS.duplicate()
	_shuffle_array(sub_pool, local_rng)
	var sub_count := local_rng.randi_range(1, 2)
	for sub_i in sub_count:
		var sub_text: String = sub_pool[sub_i]
		var sub_scale := local_rng.randi_range(1, 2)
		var sub_x := _centered_text_x(sub_text, w, sub_scale, local_rng)
		var sub_y := headline_y + headline_scale * 28 + sub_i * local_rng.randi_range(28, 38)
		var sub_ink := ink.darkened(local_rng.randf_range(-0.12, 0.18))
		_draw_block_text(img, sub_text, Vector2i(sub_x, sub_y), sub_ink, sub_scale)

	# Fade overall so it reads as old paper from a distance.
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			c.a *= 0.92
			# Mild wash-out toward paper color.
			c = c.lerp(paper, 0.18)
			img.set_pixel(x, y, c)

	return ImageTexture.create_from_image(img)


func _text_pixel_width(text: String, scale: int) -> int:
	var glyph_w := 5 * scale
	var gap := 2 * scale
	var width := 0
	for ch in text.to_upper():
		var pattern := _glyph_pattern(ch)
		if pattern.is_empty():
			width += gap
		else:
			width += glyph_w + gap
	return maxi(width - gap, 0)


func _centered_text_x(text: String, img_w: int, scale: int, rng: RandomNumberGenerator) -> int:
	var text_w := _text_pixel_width(text, scale)
	var margin := 12
	var max_x := img_w - margin - text_w
	if max_x <= margin:
		return margin
	return rng.randi_range(margin, max_x)


func _add_flyer_plane(
	node_name: String,
	size: Vector2,
	pos: Vector3,
	material: Material,
	tilt_deg: float
) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.orientation = PlaneMesh.FACE_X

	if material is BaseMaterial3D:
		(material as BaseMaterial3D).render_priority = 1
	elif material is ShaderMaterial:
		(material as ShaderMaterial).render_priority = 1

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = Vector3(0.0, 180.0, tilt_deg)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = 0.02
	add_child(mi)
	return mi


func _draw_block_text(img: Image, text: String, origin: Vector2i, color: Color, scale: int) -> void:
	var cursor_x := origin.x
	var glyph_w := 5 * scale
	var gap := 2 * scale
	for ch in text.to_upper():
		var pattern := _glyph_pattern(ch)
		if pattern.is_empty():
			cursor_x += gap
			continue
		for row in pattern.size():
			var bits: int = pattern[row]
			for col in 5:
				if (bits >> (4 - col)) & 1:
					for sy in scale:
						for sx in scale:
							var px := cursor_x + col * scale + sx
							var py := origin.y + row * scale + sy
							if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
								var existing := img.get_pixel(px, py)
								img.set_pixel(px, py, existing.lerp(color, color.a))
		cursor_x += glyph_w + gap


func _glyph_pattern(ch: String) -> Array[int]:
	# 5x7 bit rows, MSB left. Sparse / stamped look.
	var empty: Array[int] = []
	match ch:
		"A":
			return [0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001]
		"B":
			return [0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110]
		"C":
			return [0b01111, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b01111]
		"D":
			return [0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110]
		"E":
			return [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111]
		"F":
			return [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000]
		"H":
			return [0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001]
		"I":
			return [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b11111]
		"K":
			return [0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001]
		"L":
			return [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111]
		"N":
			return [0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001]
		"O":
			return [0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110]
		"P":
			return [0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000]
		"R":
			return [0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001]
		"S":
			return [0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110]
		"T":
			return [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100]
		"U":
			return [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110]
		"W":
			return [0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b10101, 0b01010]
		"Y":
			return [0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100]
		"%":
			return [0b11001, 0b11010, 0b00100, 0b01000, 0b10110, 0b10011, 0b00000]
		"!":
			return [0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00000, 0b00100]
		"0":
			return [0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110]
		"5":
			return [0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110]
		" ":
			return empty
		_:
			return [0b01110, 0b10001, 0b00010, 0b00100, 0b00100, 0b00000, 0b00100]


func _add_jamb_pair(
	prefix: String,
	wall_x: float,
	center_y: float,
	half_open_w: float,
	half_open_h: float,
	half_booth_w: float,
	material: Material
) -> void:
	var jamb_w := maxf(0.08, half_booth_w - half_open_w)
	if jamb_w < 0.1:
		return
	var jamb_h := half_open_h * 2.0 + 0.18
	_add_box(
		"%sJambLeft" % prefix,
		Vector3(wall_thickness * 1.15, jamb_h, jamb_w),
		Vector3(wall_x, center_y, -half_open_w - jamb_w * 0.5),
		material
	)
	_add_box(
		"%sJambRight" % prefix,
		Vector3(wall_thickness * 1.15, jamb_h, jamb_w),
		Vector3(wall_x, center_y, half_open_w + jamb_w * 0.5),
		material
	)


func _add_rivet_row(prefix: String, center: Vector3, span: float, count: int, material: Material) -> void:
	var n := maxi(count, 2)
	for i in n:
		var t := lerpf(-0.5, 0.5, float(i) / float(n - 1))
		_add_box(
			"%s_%d" % [prefix, i],
			Vector3(rivet_size * 0.7, rivet_size, rivet_size),
			center + Vector3(0.0, 0.0, span * t),
			material
		)


func _add_rivet_column(prefix: String, bottom: Vector3, height: float, count: int, material: Material) -> void:
	var n := maxi(count, 2)
	for i in n:
		var t := float(i) / float(n - 1)
		_add_box(
			"%s_%d" % [prefix, i],
			Vector3(rivet_size * 0.7, rivet_size, rivet_size),
			bottom + Vector3(0.0, height * t, 0.0),
			material
		)


func _add_box(node_name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi


func _steel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.11, 0.115, 0.11, 1.0)
	mat.metallic = 0.9
	mat.roughness = 0.42
	return mat


func _deck_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.155, 0.14, 1.0)
	mat.metallic = 0.78
	mat.roughness = 0.55
	return mat


func _panel_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _INDUSTRIAL_SHADER
	mat.set_shader_parameter("base_color", Color(0.14, 0.15, 0.14, 1.0))
	mat.set_shader_parameter("seam_color", Color(0.04, 0.045, 0.04, 1.0))
	mat.set_shader_parameter("rust_color", Color(0.32, 0.12, 0.05, 1.0))
	mat.set_shader_parameter("tile_count", Vector2(6.0, 10.0))
	mat.set_shader_parameter("roughness_value", 0.78)
	return mat


func _grill_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.07, 0.075, 0.07, 1.0)
	mat.metallic = 0.92
	mat.roughness = 0.35
	return mat


func _rivet_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.18, 0.1, 1.0)
	mat.metallic = 0.85
	mat.roughness = 0.48
	return mat


func _lamp_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.78, 0.45, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.35, 1.0)
	mat.emission_energy_multiplier = 2.2
	return mat


func _sign_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.12, 0.08, 1.0)
	mat.metallic = 0.2
	mat.roughness = 0.65
	return mat
