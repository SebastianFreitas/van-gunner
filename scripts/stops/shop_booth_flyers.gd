extends RefCounted

## Randomly placed sticker/flyer stickers on the shop booth face, plus their pixel-art textures.

var booth: Node3D  # the ShopCounterBooth node; reads its exports and uses its box primitives

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


func _init(owner: Node3D) -> void:
	booth = owner


func build_flyers(
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
		_add_flyer_plane(
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
			return rng.randf_range(booth.viewing_center_y + booth.viewing_height * 0.55, booth.wall_height - 0.55)


func _flyer_in_window(z: float, y: float, w: float, h: float, view_half_w: float, view_bottom: float) -> bool:
	var pad_z := 0.22
	var pad_y := 0.18
	var in_window_z := absf(z) < view_half_w + pad_z + w * 0.25
	var view_top: float = booth.viewing_center_y + booth.viewing_height * 0.5
	var in_window_y := y + h * 0.5 > view_bottom - pad_y and y - h * 0.5 < view_top + pad_y
	return in_window_z and in_window_y


func _flyer_in_transaction(z: float, y: float, w: float, h: float) -> bool:
	var tx_half_w: float = booth.transaction_width * 0.5
	var tx_half_h: float = booth.transaction_height * 0.5
	var pad_z := 0.18
	var pad_y := 0.12
	var in_tx_z := absf(z) < tx_half_w + pad_z + w * 0.2
	var tx_bottom: float = booth.transaction_center_y - tx_half_h
	var tx_top: float = booth.transaction_center_y + tx_half_h
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


func _text_pixel_width(text: String, text_scale: int) -> int:
	var glyph_w := 5 * text_scale
	var gap := 2 * text_scale
	var width := 0
	for ch in text.to_upper():
		var pattern := glyph_pattern(ch)
		if pattern.is_empty():
			width += gap
		else:
			width += glyph_w + gap
	return maxi(width - gap, 0)


func _centered_text_x(text: String, img_w: int, text_scale: int, rng: RandomNumberGenerator) -> int:
	var text_w := _text_pixel_width(text, text_scale)
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
	booth.add_child(mi)
	return mi


func _draw_block_text(img: Image, text: String, origin: Vector2i, color: Color, text_scale: int) -> void:
	var cursor_x := origin.x
	var glyph_w := 5 * text_scale
	var gap := 2 * text_scale
	for ch in text.to_upper():
		var pattern := glyph_pattern(ch)
		if pattern.is_empty():
			cursor_x += gap
			continue
		for row in pattern.size():
			var bits: int = pattern[row]
			for col in 5:
				if (bits >> (4 - col)) & 1:
					for sy in text_scale:
						for sx in text_scale:
							var px := cursor_x + col * text_scale + sx
							var py := origin.y + row * text_scale + sy
							if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
								var existing := img.get_pixel(px, py)
								img.set_pixel(px, py, existing.lerp(color, color.a))
		cursor_x += glyph_w + gap


static func glyph_pattern(ch: String) -> Array[int]:
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
