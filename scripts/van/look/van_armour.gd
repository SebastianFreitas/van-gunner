class_name VanArmour
extends Node3D
## The van's seeded outer armour: plates, rebar, spikes, road signs and a car-door shield, placed from slots clear of every opening and merged per material.

const HULL_PATH := ^"../Hull"
const FACE_X := 2.6
const _Pieces := preload("res://scripts/van/look/van_armour_pieces.gd")

## Slots armour may fill, kept clear of the side windows, side door and rear wheel arches.
const SLOTS: Array[Dictionary] = [
	{"id": &"low_front", "z": Vector2(-2.1, -0.05), "y": Vector2(0.05, 1.0)},
	{"id": &"low_mid", "z": Vector2(0.05, 1.45), "y": Vector2(0.05, 1.0)},
	{"id": &"pillar", "z": Vector2(0.9, 1.55), "y": Vector2(1.1, 2.95)},
	{"id": &"top", "z": Vector2(-2.1, 4.55), "y": Vector2(2.55, 3.02)},
	{"id": &"tail", "z": Vector2(4.12, 4.62), "y": Vector2(1.1, 2.95)},
]

## The hull material duplicated with plate_mode = true, plate_size_m = Vector2(1.0, 0.6); null if the hull has no shader material.
var plate_material: ShaderMaterial
## Crooked-plate tilts left to spend on the side currently being built.
var _crooked_left := 0


func rebuild_look(look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var hull := get_node_or_null(HULL_PATH) as VanHull
	var hull_mat: Material = null
	if hull != null:
		hull_mat = hull.material
	plate_material = null
	if hull_mat is ShaderMaterial:
		plate_material = (hull_mat as ShaderMaterial).duplicate() as ShaderMaterial
		plate_material.set_shader_parameter(&"plate_mode", true)
		plate_material.set_shader_parameter(&"plate_size_m", Vector2(1.0, 0.6))

	var rebar_mat := StandardMaterial3D.new()
	rebar_mat.albedo_color = Color(0.09, 0.085, 0.08)
	rebar_mat.roughness = 0.8
	rebar_mat.metallic = 0.3

	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.03, 0.035, 0.04)
	glass_mat.roughness = 0.78

	var rng := look.rng_for(&"armour")

	var sign_colors: Array[Color] = [Color(0.36, 0.30, 0.14), Color(0.33, 0.12, 0.10), Color(0.12, 0.24, 0.20)]
	var sign_mat := StandardMaterial3D.new()
	sign_mat.roughness = 0.86
	sign_mat.albedo_color = sign_colors[rng.randi_range(0, 2)]

	var pieces: RefCounted = _Pieces.new()
	for side: float in [-1.0, 1.0]:
		_crooked_left = rng.randi_range(1, 2)
		for slot: Dictionary in SLOTS:
			_fill_slot(pieces, slot, side, rng)

	var fallback_plate := StandardMaterial3D.new()
	fallback_plate.albedo_color = Color(0.18, 0.18, 0.18)
	fallback_plate.roughness = 0.85
	var plate_mat: Material = fallback_plate
	if plate_material != null:
		plate_mat = plate_material

	if pieces.has_geometry(&"plate"):
		_add_merged("ArmourPlates", pieces.tools[&"plate"], plate_mat)
	if pieces.has_geometry(&"rebar"):
		_add_merged("ArmourRebar", pieces.tools[&"rebar"], rebar_mat)
	if pieces.has_geometry(&"sign"):
		_add_merged("ArmourSigns", pieces.tools[&"sign"], sign_mat)
	if pieces.has_geometry(&"glass"):
		_add_merged("ArmourGlass", pieces.tools[&"glass"], glass_mat)


func _fill_slot(pieces: RefCounted, slot: Dictionary, side: float, rng: RandomNumberGenerator) -> void:
	var zr: Vector2 = slot["z"]
	var yr: Vector2 = slot["y"]
	var w := zr.y - zr.x
	var h := yr.y - yr.x
	var cz := (zr.x + zr.y) * 0.5
	var cy := (yr.x + yr.y) * 0.5
	match slot["id"]:
		&"low_front":
			if rng.randf() < 0.55:
				pieces.add_car_door(side, cz, cy)
			else:
				var pw := (w + 0.1) / 2.0
				var wa := pw * rng.randf_range(0.9, 1.0)
				var wb := pw * rng.randf_range(0.9, 1.0)
				var ha := h * rng.randf_range(0.8, 1.0)
				var hb := h * rng.randf_range(0.8, 1.0)
				var za := zr.x + wa / 2.0 - 0.05
				var zb := zr.y - wb / 2.0 + 0.05
				_place_plate(pieces, side, za, cy, wa, ha, 0, rng)
				_place_plate(pieces, side, zb, cy, wb, hb, 1, rng)
		&"low_mid":
			if rng.randf() < 0.4:
				pieces.add_plate(side, cz, cy, w, h, 0.0, 0)
				pieces.add_sign(side, cz, cy, minf(w, h) * 0.8, rng.randi_range(0, 2))
			else:
				_place_plate(pieces, side, cz, cy, w, h, 0, rng)
		&"pillar":
			if rng.randf() < 0.5:
				var x := side * (FACE_X + 0.05)
				for zbar: float in [zr.x + 0.08, cz, zr.y - 0.08]:
					pieces.add_bar(&"rebar", Vector3(x, yr.x, zbar), Vector3(x, yr.y, zbar), 0.03)
				var step := h / 3.0
				for i: int in range(4):
					var ybar := yr.x + step * float(i)
					pieces.add_bar(&"rebar", Vector3(x, ybar, zr.x), Vector3(x, ybar, zr.y), 0.03)
			else:
				_place_plate(pieces, side, cz, cy, w, h, 0, rng)
		&"top":
			var n := rng.randi_range(2, 4)
			var seg := (w + 0.12 * float(n - 1)) / float(n)
			for i: int in range(n):
				var pz := zr.x + seg / 2.0 + float(i) * (seg - 0.12)
				var p_h := h * rng.randf_range(0.75, 1.0)
				_place_plate(pieces, side, pz, cy, seg, p_h, i % 2, rng)
			if rng.randf() < 0.5:
				var count := rng.randi_range(4, 8)
				for i2: int in range(count):
					var t := (float(i2) + 0.5) / float(count)
					pieces.add_spike(side, Vector3(side * FACE_X, cy, zr.x + t * w), 0.22)
		&"tail":
			_place_plate(pieces, side, cz, cy, w, h, 0, rng)
			if rng.randf() < 0.4:
				var ystep := h / 3.0
				for i3: int in range(3):
					var sy := yr.x + ystep * (float(i3) + 0.5)
					pieces.add_spike(side, Vector3(side * FACE_X, sy, cz), 0.22)


## Rolls the crooked-plate budget for this side and returns a tilt in degrees, 0.0 if not crooked.
func _plate_tilt(rng: RandomNumberGenerator) -> float:
	var roll := rng.randf()
	if _crooked_left > 0 and roll < 0.45:
		_crooked_left -= 1
		var tilt_sign := 1.0 if rng.randf() < 0.5 else -1.0
		return tilt_sign * rng.randf_range(3.0, 8.0)
	return 0.0


## Places a plate, shrinking it 12% when crooked so a tilted plate still fits its slot box.
func _place_plate(pieces: RefCounted, side: float, z: float, y: float, w: float, h: float, layer: int,
		rng: RandomNumberGenerator) -> void:
	var tilt := _plate_tilt(rng)
	var pw := w
	var ph := h
	if tilt != 0.0:
		pw *= 0.88
		ph *= 0.88
	pieces.add_plate(side, z, y, pw, ph, tilt, layer)


func _add_merged(mesh_name: String, st: SurfaceTool, mat: Material) -> void:
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.material_override = mat
	add_child(mi)
