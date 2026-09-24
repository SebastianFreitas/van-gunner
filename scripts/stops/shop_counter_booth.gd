extends Node3D

## Fortified metal shop counter — armored face, cash slot, eye-level grilled window.

const _BoothMaterials := preload("res://scripts/stops/shop_booth_materials.gd")
const _BoothFlyers := preload("res://scripts/stops/shop_booth_flyers.gd")
const _BoothFrame := preload("res://scripts/stops/shop_booth_frame.gd")
const _BoothTrim := preload("res://scripts/stops/shop_booth_trim.gd")

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


func _ready() -> void:
	_build()


func _exit_tree() -> void:
	# Force Forward+ to unpair before lights leave the scenario (Godot #121989-adjacent).
	for child in get_children():
		if child is Light3D:
			(child as Light3D).visible = false


func _build() -> void:
	var steel := _BoothMaterials.steel_material()
	var deck_mat := _BoothMaterials.deck_material()
	var panel_mat := _BoothMaterials.panel_material()
	var rivet_mat := _BoothMaterials.rivet_material()
	var grill_mat := _BoothMaterials.grill_material()
	var lamp_mat := _BoothMaterials.lamp_material()
	var sign_mat := _BoothMaterials.sign_material()

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

	# Lights must enter the tree before booth meshes so teardown frees geometry first.
	_register_booth_lights(wall_x, view_top)

	var frame := _BoothFrame.new(self)
	frame.build_counter(deck_mat, steel, half_w, wall_x, deck_y)
	frame.build_pillars(steel, rivet_mat, half_w, wall_x)
	frame.build_wall_panels(panel_mat, steel, half_w, wall_x, face_x, view_bottom, view_top, tx_bottom, tx_top)
	frame.build_openings(steel, rivet_mat, wall_x, face_x, view_half_w, view_half_h, tx_half_w, tx_half_h, half_w)

	var trim := _BoothTrim.new(self)
	trim.build_armor_details(steel, rivet_mat, panel_mat, half_w, wall_x, face_x, view_top, tx_bottom)
	trim.build_viewing_grill(wall_x, view_half_w, view_half_h, grill_mat)
	trim.build_window_brow(steel, rivet_mat, wall_x, view_top)
	trim.build_lamp_visuals(lamp_mat, steel, wall_x, view_top)
	trim.build_shop_sign(sign_mat, steel, wall_x, view_top)

	var flyers := _BoothFlyers.new(self)
	flyers.build_flyers(face_x, half_w, view_half_w, view_bottom, tx_bottom)


func _register_booth_lights(wall_x: float, view_top: float) -> void:
	var lamp_y := view_top + 0.42
	for i in 2:
		var z := lerpf(-1.1, 1.1, float(i))
		var light := OmniLight3D.new()
		light.name = "BoothLampLight_%d" % i
		light.position = Vector3(wall_x - 0.35, lamp_y - 0.05, z)
		light.light_color = Color(1.0, 0.72, 0.42, 1.0)
		light.light_energy = 1.35
		light.omni_range = 4.5
		light.shadow_enabled = false
		add_child(light)


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
