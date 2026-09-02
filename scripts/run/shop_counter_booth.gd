extends Node3D

## Fortified metal shop counter — deck, teller wall with transaction slot, grilled viewing window.

@export var booth_width := 7.6
@export var deck_depth := 0.95
@export var deck_thickness := 0.14
@export var deck_top_y := 1.0
@export var wall_height := 3.35
@export var wall_thickness := 0.16
@export var pillar_size := 0.2
@export var transaction_width := 5.4
@export var transaction_height := 0.58
@export var transaction_center_y := 1.42
@export var viewing_width := 4.8
@export var viewing_height := 0.22
@export var viewing_center_y := 2.55
@export var grill_spacing := 0.34
@export var grill_bar_size := 0.03
@export var lip_depth := 0.28
@export var lip_thickness := 0.1


func _ready() -> void:
	_build()


func _build() -> void:
	var steel := _steel_material()
	var deck_mat := _deck_material()
	var dark_mat := _dark_panel_material()

	var half_w := booth_width * 0.5
	var wall_x := wall_thickness * 0.5
	var deck_y := deck_top_y - deck_thickness * 0.5

	# Customer-side counter deck.
	_add_box(
		"Deck",
		Vector3(deck_depth, deck_thickness, booth_width),
		Vector3(-deck_depth * 0.5 + wall_x, deck_y, 0.0),
		deck_mat
	)

	# Lip shelf extending toward the customer for displayed goods.
	_add_box(
		"Lip",
		Vector3(lip_depth, lip_thickness, booth_width - pillar_size * 1.6),
		Vector3(-deck_depth - lip_depth * 0.5 + wall_x, deck_top_y + lip_thickness * 0.5, 0.0),
		deck_mat
	)

	# Side pillars frame the booth opening.
	_add_box(
		"PillarLeft",
		Vector3(wall_thickness + deck_depth * 0.35, wall_height, pillar_size),
		Vector3(wall_x + deck_depth * 0.15, wall_height * 0.5, -half_w + pillar_size * 0.5),
		steel
	)
	_add_box(
		"PillarRight",
		Vector3(wall_thickness + deck_depth * 0.35, wall_height, pillar_size),
		Vector3(wall_x + deck_depth * 0.15, wall_height * 0.5, half_w - pillar_size * 0.5),
		steel
	)

	# Top header spanning the pillars.
	var header_bottom := viewing_center_y + viewing_height * 0.5
	var header_h := wall_height - header_bottom
	if header_h > 0.08:
		_add_box(
			"Header",
			Vector3(wall_thickness, header_h, booth_width),
			Vector3(wall_x, header_bottom + header_h * 0.5, 0.0),
			dark_mat
		)

	# Panel between viewing slot and transaction opening.
	var mid_top := viewing_center_y - viewing_height * 0.5
	var mid_bottom := transaction_center_y + transaction_height * 0.5
	var mid_h := mid_top - mid_bottom
	if mid_h > 0.06:
		_add_box(
			"MidPanel",
			Vector3(wall_thickness, mid_h, booth_width),
			Vector3(wall_x, (mid_top + mid_bottom) * 0.5, 0.0),
			dark_mat
		)

	# Solid panels below the transaction slot.
	var low_top := transaction_center_y - transaction_height * 0.5
	if low_top > 0.06:
		_add_box(
			"LowerPanel",
			Vector3(wall_thickness, low_top, booth_width),
			Vector3(wall_x, low_top * 0.5, 0.0),
			dark_mat
		)

	# Side jambs around the transaction opening.
	var tx_half_w := transaction_width * 0.5
	var tx_half_h := transaction_height * 0.5
	_add_jamb_pair(
		"Tx",
		wall_x,
		transaction_center_y,
		tx_half_w,
		tx_half_h,
		half_w,
		steel
	)

	# Side jambs around the viewing slot.
	var view_half_w := viewing_width * 0.5
	var view_half_h := viewing_height * 0.5
	_add_jamb_pair(
		"View",
		wall_x,
		viewing_center_y,
		view_half_w,
		view_half_h,
		half_w,
		steel
	)

	# Horizontal sill and lintel for the transaction slot.
	_add_box(
		"TxSill",
		Vector3(wall_thickness * 1.05, 0.07, transaction_width),
		Vector3(wall_x, transaction_center_y - tx_half_h - 0.035, 0.0),
		steel
	)
	_add_box(
		"TxLintel",
		Vector3(wall_thickness * 1.05, 0.07, transaction_width),
		Vector3(wall_x, transaction_center_y + tx_half_h + 0.035, 0.0),
		steel
	)

	_build_viewing_grill(wall_x, view_half_w, view_half_h, steel)


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
	var jamb_h := half_open_h * 2.0 + 0.14
	_add_box(
		"%sJambLeft" % prefix,
		Vector3(wall_thickness, jamb_h, jamb_w),
		Vector3(wall_x, center_y, -half_open_w - jamb_w * 0.5),
		material
	)
	_add_box(
		"%sJambRight" % prefix,
		Vector3(wall_thickness, jamb_h, jamb_w),
		Vector3(wall_x, center_y, half_open_w + jamb_w * 0.5),
		material
	)


func _build_viewing_grill(wall_x: float, half_w: float, half_h: float, material: Material) -> void:
	var bar_count := maxi(2, int(ceil((half_w * 2.0) / grill_spacing)))
	var usable_w := half_w * 2.0
	var step := usable_w / float(bar_count - 1)
	var bar_h := half_h * 2.0 + 0.04
	for i in range(bar_count):
		var z := -half_w + float(i) * step
		_add_box(
			"GrillBar_%d" % i,
			Vector3(wall_thickness * 0.7, bar_h, grill_bar_size),
			Vector3(wall_x, viewing_center_y, z),
			material
		)


func _add_box(node_name: String, size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _steel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.105, 0.1, 1.0)
	mat.metallic = 0.88
	mat.roughness = 0.38
	return mat


func _deck_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.145, 0.14, 1.0)
	mat.metallic = 0.82
	mat.roughness = 0.48
	return mat


func _dark_panel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.065, 0.062, 1.0)
	mat.metallic = 0.9
	mat.roughness = 0.55
	return mat
