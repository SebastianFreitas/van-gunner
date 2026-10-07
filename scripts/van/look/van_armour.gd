class_name VanArmour
extends Node3D
## The van's seeded outer armour: plates, rebar and spikes on the real hull skin, placed from slots clear of every opening and merged per material.

const HULL_PATH := ^"../Hull"
const SIDE_WALLS_PATH := ^"../../Interior/Shell/SideWalls"
## Skin x used when no side wall is set.
const FACE_X := VanInteriorSize.BOTTOM_HALF + 0.22
## How far the side door leaf slides open along z. Keep in step with `slide_distance` in
## side_doors.gd (neither script has a class_name to read it from).
const DOOR_SLIDE_M := 2.45
## Half length of the side door leaf. Keep in step with `DOOR_HALF_Z` in side_door_leaf.gd.
const DOOR_LEAF_HALF_Z := 1.105
## Plates stand this far off the skin so their inner face never shares its plane (D7).
const TRIM_LIFT := 0.01
## Belt line band (y 2.595..2.645) padded 2 cm, and the top of the drip rail band (3.01) less
## 2 cm. Keep in step with the rails in van_hull_lines.gd.
const BELT_BAND_Y := Vector2(2.575, 2.665)
const DRIP_BAND_Y := VanInteriorSize.WALL_HEIGHT - 0.09
const _Pieces := preload("res://scripts/van/look/van_armour_pieces.gd")

## Slots armour may fill, kept clear of the side windows, the side door's slide path and the
## belt line / drip rail (2 cm each).
const SLOTS: Array[Dictionary] = [
	{"id": &"pillar", "z": Vector2(0.9, 1.55), "y": Vector2(1.1, 2.575)},
	{"id": &"top", "z": Vector2(0.16, VanInteriorSize.REAR_Z - 0.15), "y": Vector2(2.665, DRIP_BAND_Y)},
	{"id": &"tail", "z": Vector2(VanInteriorSize.REAR_Z - 0.58, VanInteriorSize.REAR_Z - 0.08), "y": Vector2(1.1, 2.575)},
]

## The hull material duplicated with plate_mode = true, plate_size_m = Vector2(1.0, 0.6); null if the hull has no shader material.
var plate_material: ShaderMaterial
## Crooked-plate tilts left to spend on the side currently being built.
var _crooked_left := 0
## The side wall, read for the body's lean so the pillar rebar grid can hug the skin.
var _walls: VanSideWall


func rebuild_look(look: VanLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var hull := get_node_or_null(HULL_PATH) as VanHull
	_walls = get_node_or_null(SIDE_WALLS_PATH) as VanSideWall
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

	var rng := look.rng_for(&"armour")

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


func _fill_slot(pieces: RefCounted, slot: Dictionary, side: float, rng: RandomNumberGenerator) -> void:
	var zr: Vector2 = slot["z"]
	var yr: Vector2 = slot["y"]
	var w := zr.y - zr.x
	var h := yr.y - yr.x
	var cz := (zr.x + zr.y) * 0.5
	var cy := (yr.x + yr.y) * 0.5
	match slot["id"]:
		&"pillar":
			if rng.randf() < 0.5:
				var step := h / 3.0
				var levels: Array[float] = [yr.x, yr.x + step, yr.x + step * 2.0, yr.y]
				for zbar: float in [zr.x + 0.08, cz, zr.y - 0.08]:
					for i: int in range(3):
						var y0 := levels[i]
						var y1 := levels[i + 1]
						_place_bar(
							pieces, Vector3(_bar_x(side, y0), y0, zbar),
							Vector3(_bar_x(side, y1), y1, zbar), 0.03
						)
					for y_end: float in [yr.x, yr.y]:
						_place_bar(
							pieces, Vector3(side * (_skin_x(y_end) - 0.02), y_end, zbar),
							Vector3(_bar_x(side, y_end), y_end, zbar), 0.035
						)
				for i2: int in range(4):
					var ybar := levels[i2]
					_place_bar(
						pieces, Vector3(_bar_x(side, ybar), ybar, zr.x),
						Vector3(_bar_x(side, ybar), ybar, zr.y), 0.03
					)
			else:
				_place_plate(pieces, side, cz, cy, w, h, 0, rng)
		&"top":
			var n := rng.randi_range(2, 4)
			var seg := (w + 0.12 * float(n - 1)) / float(n)
			var top_plates: Array[Dictionary] = []
			for i: int in range(n):
				var pz := zr.x + seg / 2.0 + float(i) * (seg - 0.12)
				var p_h := h * rng.randf_range(0.75, 1.0)
				var info := _place_plate(pieces, side, pz, cy, seg, p_h, i % 2, null)
				if not info.is_empty():
					top_plates.append(info)
			if rng.randf() < 0.5:
				var count := rng.randi_range(4, 8)
				for i2: int in range(count):
					var t := (float(i2) + 0.5) / float(count)
					var sz := zr.x + t * w
					# Later plates are the outer layer where two overlap; take the last one under sz.
					for k: int in range(top_plates.size() - 1, -1, -1):
						var plate := top_plates[k]
						if sz >= float(plate["z0"]) and sz <= float(plate["z1"]):
							_place_spike(pieces, side, cy, sz, plate)
							break
		&"tail":
			var tail_plate := _place_plate(pieces, side, cz, cy, w, h, 0, rng)
			if rng.randf() < 0.4 and not tail_plate.is_empty():
				var ystep := h / 3.0
				for i3: int in range(3):
					var sy := yr.x + ystep * (float(i3) + 0.5)
					_place_spike(pieces, side, sy, cz, tail_plate)


## Skin x at height y (the wall's lean plus the hull skin's outer face); FACE_X if no wall is set.
func _skin_x(y: float) -> float:
	if _walls == null:
		return FACE_X
	return _walls.wall_x_at(y) + VanHull.SIDE_SKIN_OUTER_M


## Inner-face x of a plate spanning y0..y1, at its bottom (x) and top (y). A straight line
## between the two ends is pushed out until it clears the bowed skin at 9 samples, plus TRIM_LIFT.
func _plate_x(y0: float, y1: float) -> Vector2:
	var b := _skin_x(y0)
	var t := _skin_x(y1)
	var push := 0.0
	for i: int in range(9):
		var f := float(i) / 8.0
		var chord := lerpf(b, t, f)
		push = maxf(push, _skin_x(lerpf(y0, y1, f)) - chord)
	return Vector2(b + push + TRIM_LIFT, t + push + TRIM_LIFT)


## Rebar bar x at height y, standing a hair proud of the skin so it reads as bolted on.
func _bar_x(side: float, y: float) -> float:
	return side * (_skin_x(y) + 0.045)


## Whether the box z0..z1, y0..y1 stays out of the side door's slide path (2 cm margin), the
## window cuts (3 cm pad: the casings sit inside the skin), the belt line / drip rail bands
## and the roof cap.
func _clear_of_openings(z0: float, z1: float, y0: float, y1: float) -> bool:
	if _walls == null:
		return true
	var margin := 0.02
	var pad := 0.03
	if y1 > _walls.wall_height - 0.06 or y1 > DRIP_BAND_Y + 0.0005:
		return false
	if y1 > BELT_BAND_Y.x + 0.0005 and y0 < BELT_BAND_Y.y - 0.0005:
		return false
	var door_z0 := _walls.door_center_z - _walls.door_half_length
	var door_z1 := _walls.door_center_z + DOOR_SLIDE_M + DOOR_LEAF_HALF_Z
	if (z1 + margin > door_z0 and z0 - margin < door_z1
			and y1 + margin > _walls.door_y_min and y0 - margin < _walls.door_y_max):
		return false
	var wy0 := _walls.window_center_y - _walls.window_half_height - pad
	var wy1 := _walls.window_center_y + _walls.window_half_height + pad
	if y1 > wy0 and y0 < wy1:
		for cz: float in _walls.window_centers_z:
			var wz0 := cz - _walls.window_half_length - pad
			var wz1 := cz + _walls.window_half_length + pad
			if z1 > wz0 and z0 < wz1:
				return false
	return true


## Rolls the crooked-plate budget for this side and returns a tilt in degrees, 0.0 if not crooked.
func _plate_tilt(rng: RandomNumberGenerator) -> float:
	var roll := rng.randf()
	if _crooked_left > 0 and roll < 0.45:
		_crooked_left -= 1
		var tilt_sign := 1.0 if rng.randf() < 0.5 else -1.0
		return tilt_sign * rng.randf_range(3.0, 8.0)
	return 0.0


## Places a plate, shrinking it 12% when crooked so a tilted plate still fits its slot box. A null
## rng means never crooked. Returns the plate's span (z0, z1, y0, y1, layer) for spikes, or an
## empty Dictionary if it touched an opening and was not built.
func _place_plate(pieces: RefCounted, side: float, z: float, y: float, w: float, h: float, layer: int,
		rng: RandomNumberGenerator) -> Dictionary:
	var tilt := 0.0
	if rng != null:
		tilt = _plate_tilt(rng)
	var pw := w
	var ph := h
	if tilt != 0.0:
		pw *= 0.88
		ph *= 0.88
	var t := deg_to_rad(tilt)
	var half_y := ph * 0.5 * cos(t) + pw * 0.5 * absf(sin(t))
	var half_z := pw * 0.5 * cos(t) + ph * 0.5 * absf(sin(t))
	if not _clear_of_openings(z - half_z, z + half_z, y - half_y, y + half_y):
		return {}
	var xs := _plate_x(y - ph * 0.5, y + ph * 0.5)
	pieces.add_plate(side, z, y, pw, ph, tilt, layer, xs.x, xs.y)
	return {"z0": z - pw * 0.5, "z1": z + pw * 0.5, "y0": y - ph * 0.5, "y1": y + ph * 0.5,
			"layer": layer}


## Places a spike on the outer face of `plate` (from `_place_plate`) at height y, its cone base
## embedded 1 cm.
func _place_spike(pieces: RefCounted, side: float, y: float, z: float, plate: Dictionary) -> void:
	if not _clear_of_openings(z, z, y, y):
		return
	var y0: float = plate["y0"]
	var y1: float = plate["y1"]
	var xs := _plate_x(y0, y1)
	var line := lerpf(xs.x, xs.y, (y - y0) / (y1 - y0))
	var x := line + 0.02 * float(plate["layer"]) + 0.04 - 0.01
	pieces.add_spike(side, Vector3(side * x, y, z), 0.22)


## Adds a rebar bar unless its box touches an opening.
func _place_bar(pieces: RefCounted, from: Vector3, to: Vector3, thickness: float) -> void:
	if not _clear_of_openings(minf(from.z, to.z), maxf(from.z, to.z), minf(from.y, to.y),
			maxf(from.y, to.y)):
		return
	pieces.add_bar(&"rebar", from, to, thickness)


func _add_merged(mesh_name: String, st: SurfaceTool, mat: Material) -> void:
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.material_override = mat
	add_child(mi)
