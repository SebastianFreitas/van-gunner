extends RefCounted
## Upper-facade props for one building: trim (parapet cap, cornice, string-course ledges,
## downspout), AC units, a fire escape, balconies, roof clutter and wall pipes. Each family is
## one ArrayMesh so a tile stays under its node budget; every box passes the keep-out gate.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _BASE_Y := _FacadePlan.BASE_Y
const _GROUND_H := _FacadePlan.GROUND_HEIGHT
const _FLOOR_H := _FacadePlan.FLOOR_HEIGHT

## Props start this far off the face so they never z-fight the body wall.
const FACE_GAP := 0.02
const MAX_AC_UNITS := 8
const MAX_LEDGES := 4
## Fog swallows higher roofs.
const ROOF_CLUTTER_MAX_HEIGHT := 34.0


static func build(
	host: Node3D, plan: Dictionary, side_sign: float, keep_out: RefCounted,
	rng: RandomNumberGenerator, district: FacadeDistrict
) -> void:
	# A rare piece that owns this plan (laundry_balconies, a mural, a collapse...) suppresses the
	# ordinary families it would otherwise double up on, before that family's own chance roll.
	var suppress: Array = plan.get(&"suppress", [])
	if not suppress.has(&"trim"):
		_build_trim(host, plan, side_sign, keep_out, rng, district)
	if not suppress.has(&"ac_units"):
		_build_ac_units(host, plan, side_sign, keep_out, rng, district)
	if not suppress.has(&"fire_escape"):
		_build_fire_escape(host, plan, side_sign, keep_out, rng, district)
	if not suppress.has(&"balconies"):
		_build_balconies(host, plan, side_sign, keep_out, rng, district)
	if not suppress.has(&"roof_clutter"):
		_build_roof_clutter(host, plan, side_sign, keep_out, rng, district)
	if not suppress.has(&"wall_pipes"):
		_build_wall_pipes(host, plan, side_sign, keep_out, rng, district)


## A box centred `depth` out from the face, toward the road; doubling `depth` gives the outer
## edge of a box already centred with that depth (used for rail posts beyond a platform/slab).
static func _out_x(xf: float, ss: float, depth: float) -> float:
	return xf - ss * (FACE_GAP + depth * 0.5)


## A box set back behind the face (roof clutter), clamped to the 1.2 m roof plate.
static func _roof_x(xf: float, ss: float, size_x: float) -> float:
	var behind := 0.5 + size_x * 0.5
	var far := behind + size_x * 0.5
	if far > 1.15:
		behind -= far - 1.15
	return xf + ss * behind


## u (metres along the building) to world z; mirrors facade_body._u's inverse.
static func _z_at(plan: Dictionary, ss: float, u: float) -> float:
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	return z0 + u if ss > 0.0 else z1 - u


## Floor line k (k = 0 is the ground-floor top).
static func _floor_y(k: int) -> float:
	return _BASE_Y + _GROUND_H + float(k) * _FLOOR_H


static func _param_f(plan: Dictionary, key: StringName, default: float) -> float:
	return float(plan[&"params"].get(key, default))


static func _cols(width: float, pitch: float) -> int:
	return maxi(0, floori((width - 0.3) / pitch))


static func _col_u(col: int, pitch: float) -> float:
	return (float(col) + 0.5) * pitch


## Builds one family's [center, size] box list into a single ArrayMesh; skips the node if the
## keep-out rejected every box.
static func _emit(
	host: Node3D, node_name: String, material: Material, shadows: bool, boxes: Array,
	ko: RefCounted
) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added := false
	for b: Array in boxes:
		added = _FacadeMeshKit.add_box(st, b[0], b[1], ko) or added
	if added:
		_FacadeMeshKit.commit(host, st, node_name, material, shadows)


static func _build_trim(
	host: Node3D, plan: Dictionary, ss: float, ko: RefCounted, rng: RandomNumberGenerator,
	dist: FacadeDistrict
) -> void:
	var xf := _FacadePlan.face_x(plan, ss)
	var width: float = plan[&"width"]
	var height: float = plan[&"height"]
	var y_top := _BASE_Y + height
	var zc := _z_at(plan, ss, width * 0.5)
	# Parapet cap, always present, straddling the face top.
	var boxes := [[Vector3(xf - ss * 0.15, y_top + 0.06, zc), Vector3(0.7, 0.12, width)]]
	if rng.randf() < dist.cornice_chance:
		boxes.append([Vector3(_out_x(xf, ss, 0.5), y_top - 0.5, zc), Vector3(0.5, 0.35, width)])
	var band: float = float(plan[&"params"][&"band_every"])
	if rng.randf() < dist.ledge_chance and band > 0.0:
		var floors: int = int(plan[&"floors"])
		var ks: Array[int] = []
		for k in range(1, floors + 1):
			if k % int(band) == 0:
				ks.append(k)
		if ks.size() > MAX_LEDGES:
			var step := ceili(float(ks.size()) / float(MAX_LEDGES))
			var spread: Array[int] = []
			var idx := 0
			while idx < ks.size():
				spread.append(ks[idx])
				idx += step
			ks = spread
		for k: int in ks:
			boxes.append([Vector3(_out_x(xf, ss, 0.25), _floor_y(k) + 0.12, zc), Vector3(0.25, 0.12, width)])
	if rng.randf() < dist.downspout_chance:
		var u := clampf(0.35 if rng.randf() < 0.5 else width - 0.35, 0.15, width - 0.15)
		var dh := height - 0.6
		boxes.append([
			Vector3(_out_x(xf, ss, 0.12), _BASE_Y + 0.3 + dh * 0.5, _z_at(plan, ss, u)),
			Vector3(0.12, dh, 0.12),
		])
	_emit(host, "Trim", _FacadeMaterials.trim_material(plan[&"preset"]), true, boxes, ko)


## A window-mounted AC unit per cell, rolled independently so density scales with building size.
static func _build_ac_units(
	host: Node3D, plan: Dictionary, ss: float, ko: RefCounted, rng: RandomNumberGenerator,
	dist: FacadeDistrict
) -> void:
	var params: Dictionary = plan[&"params"]
	var style: int = int(params[&"style"])
	if float(params.get(&"windows_on", 1.0)) < 0.5 or style == 3 or style == 6:
		return
	var width: float = plan[&"width"]
	var height: float = plan[&"height"]
	var floors: int = int(plan[&"floors"])
	var pitch := _param_f(plan, &"window_pitch", 2.6)
	var sill := _param_f(plan, &"window_sill", 0.9)
	var wh := _param_f(plan, &"window_h", 1.7)
	var cols := _cols(width, pitch)
	var xf := _FacadePlan.face_x(plan, ss)
	var boxes := []
	for col in cols:
		if boxes.size() >= MAX_AC_UNITS:
			break
		for k in range(1, floors + 1):
			if boxes.size() >= MAX_AC_UNITS:
				break
			var sr := _GROUND_H + float(k - 1) * _FLOOR_H + sill
			if sr + wh > height - _FacadePlan.PARAPET or rng.randf() >= dist.ac_unit_chance:
				continue
			boxes.append([
				Vector3(_out_x(xf, ss, 0.35), _BASE_Y + sr + 0.21, _z_at(plan, ss, _col_u(col, pitch))),
				Vector3(0.5, 0.42, 0.62),
			])
	_emit(host, "AcUnits", _FacadeMaterials.metal_grey_material(), false, boxes, ko)


## One fire escape column: landings, rails, inter-floor ladders and a hanging drop ladder.
static func _build_fire_escape(
	host: Node3D, plan: Dictionary, ss: float, ko: RefCounted, rng: RandomNumberGenerator,
	dist: FacadeDistrict
) -> void:
	var roll := rng.randf() < dist.fire_escape_chance
	var params: Dictionary = plan[&"params"]
	var style: int = int(params[&"style"])
	var width: float = plan[&"width"]
	var floors: int = int(plan[&"floors"])
	var pitch := _param_f(plan, &"window_pitch", 2.6)
	var sill := _param_f(plan, &"window_sill", 0.9)
	var cols := _cols(width, pitch)
	if (
		not roll or float(params.get(&"windows_on", 1.0)) <= 0.5 or style == 3 or style == 6
		or width < 8.0 or floors < 3 or cols < 3
	):
		return
	var xf := _FacadePlan.face_x(plan, ss)
	# Needs a neighbour column on each side.
	var zc := _z_at(plan, ss, _col_u(rng.randi_range(1, cols - 2), pitch))
	var ox := _out_x(xf, ss, 1.9)  # outer edge of the 0.95 m platform
	var lx := _out_x(xf, ss, 0.6)
	var boxes := []
	for k in range(1, floors):
		if boxes.size() >= 90:
			break
		var y := _floor_y(k) + sill - 0.05
		# Posts and rail only make sense with their landing; skip the trio together when it
		# doesn't (a bay side rejects the landing itself, since it dips below the approach box).
		var platform_c := Vector3(_out_x(xf, ss, 0.95), y, zc)
		var platform_s := Vector3(0.95, 0.06, 2.6)
		if ko.allows(_FacadeKeepOut.box_aabb(platform_c, platform_s)):
			boxes.append([platform_c, platform_s])
			for dz: float in [-1.3, 0.0, 1.3]:
				boxes.append([Vector3(ox, y + 0.53, zc + dz), Vector3(0.05, 1.0, 0.05)])
			boxes.append([Vector3(ox, y + 1.03, zc), Vector3(0.05, 0.05, 2.6)])
		if k == 1:
			# No landing below the first one: a hanging drop ladder to the sidewalk instead.
			var drop_y := _floor_y(1) + sill - 1.2
			for dz: float in [-0.25, 0.25]:
				boxes.append([Vector3(lx, drop_y, zc + dz), Vector3(0.05, 2.2, 0.05)])
		else:
			var yb := y - _FLOOR_H
			# Same rule: the rungs only belong once a stringer actually clears the gate.
			var stringer_c := Vector3(lx, (yb + y) * 0.5, zc - 0.25)
			var stringer_s := Vector3(0.05, _FLOOR_H, 0.05)
			if ko.allows(_FacadeKeepOut.box_aabb(stringer_c, stringer_s)):
				for dz: float in [-0.25, 0.25]:
					boxes.append([Vector3(lx, (yb + y) * 0.5, zc + dz), Vector3(0.05, _FLOOR_H, 0.05)])
				for i in 6:
					boxes.append([Vector3(lx, lerpf(yb, y, (i + 1.0) / 7.0), zc), Vector3(0.05, 0.04, 0.5)])
	_emit(host, "FireEscape", _FacadeMaterials.iron_material(), false, boxes, ko)


## Balcony slabs (concrete) and their rails (iron), rolled independently per floor/column.
static func _build_balconies(
	host: Node3D, plan: Dictionary, ss: float, ko: RefCounted, rng: RandomNumberGenerator,
	dist: FacadeDistrict
) -> void:
	var roll := rng.randf() < dist.balcony_chance
	var params: Dictionary = plan[&"params"]
	var style: int = int(params[&"style"])
	if not roll or float(params.get(&"windows_on", 1.0)) <= 0.5 or style == 6:
		return
	var width: float = plan[&"width"]
	var floors: int = int(plan[&"floors"])
	var pitch := _param_f(plan, &"window_pitch", 2.6)
	var sill := _param_f(plan, &"window_sill", 0.9)
	var cols := _cols(width, pitch)
	var xf := _FacadePlan.face_x(plan, ss)
	var ox := _out_x(xf, ss, 1.8)  # outer edge of the 0.9 m slab
	var slabs := []
	var rails := []
	var count := 0
	for k in range(1, floors + 1):
		if count >= 10:
			break
		for col in cols:
			if count >= 10:
				break
			if rng.randf() >= 0.5:
				continue
			count += 1
			var z := _z_at(plan, ss, _col_u(col, pitch))
			var y := _floor_y(k) + sill - 0.07
			var top := y + 0.07
			var slab_c := Vector3(_out_x(xf, ss, 0.9), y, z)
			var slab_s := Vector3(0.9, 0.14, 2.2)
			# The rail is meaningless without its slab; skip both together when the slab itself
			# doesn't clear the gate.
			if not ko.allows(_FacadeKeepOut.box_aabb(slab_c, slab_s)):
				continue
			slabs.append([slab_c, slab_s])
			for dz: float in [-1.1, 1.1]:
				rails.append([Vector3(ox, top + 0.5, z + dz), Vector3(0.04, 1.0, 0.04)])
			rails.append([Vector3(ox, top + 1.0, z), Vector3(0.04, 0.05, 2.2)])
			rails.append([Vector3(ox, top + 0.225, z), Vector3(0.03, 0.45, 2.2)])
	_emit(host, "Balconies", _FacadeMaterials.concrete_material(), true, slabs, ko)
	_emit(host, "BalconyRails", _FacadeMaterials.iron_material(), false, rails, ko)


## A stair bulkhead, 1-3 vents and maybe a tank, sitting on the roof plate behind the face.
static func _build_roof_clutter(
	host: Node3D, plan: Dictionary, ss: float, ko: RefCounted, rng: RandomNumberGenerator,
	dist: FacadeDistrict
) -> void:
	var roll := rng.randf() < dist.roof_clutter_chance
	var height: float = plan[&"height"]
	var width: float = plan[&"width"]
	if not roll or height > ROOF_CLUTTER_MAX_HEIGHT or width <= 2.0:
		return
	var xf := _FacadePlan.face_x(plan, ss)
	var y_top := _BASE_Y + height
	var bulk := []
	if rng.randf() < 0.6:
		bulk.append(_roof_piece(plan, xf, ss, y_top, width, rng, Vector3(0.6, 2.4, 2.4)))
	var vents := []
	for i in rng.randi_range(1, 3):
		vents.append(_roof_piece(plan, xf, ss, y_top, width, rng, Vector3(0.5, 0.7, 0.5)))
	if rng.randf() < 0.35:
		vents.append(_roof_piece(plan, xf, ss, y_top, width, rng, Vector3(0.6, 1.6, 1.2)))
	_emit(host, "RoofBulkhead", _FacadeMaterials.concrete_material(), false, bulk, ko)
	_emit(host, "RoofVents", _FacadeMaterials.metal_grey_material(), false, vents, ko)


static func _roof_piece(
	plan: Dictionary, xf: float, ss: float, y_top: float, width: float, rng: RandomNumberGenerator,
	size: Vector3
) -> Array:
	var u := clampf(rng.randf_range(1.0, width - 1.0), 0.15, width - 0.15)
	return [Vector3(_roof_x(xf, ss, size.x), y_top + size.y * 0.5, _z_at(plan, ss, u)), size]


## 1-3 rusty vertical pipes, an optional horizontal run joining them, and mounting brackets.
static func _build_wall_pipes(
	host: Node3D, plan: Dictionary, ss: float, ko: RefCounted, rng: RandomNumberGenerator,
	dist: FacadeDistrict
) -> void:
	if rng.randf() >= dist.wall_pipe_chance:
		return
	var width: float = plan[&"width"]
	var height: float = plan[&"height"]
	var params: Dictionary = plan[&"params"]
	var windows_on := float(params.get(&"windows_on", 1.0)) > 0.5
	var pitch := _param_f(plan, &"window_pitch", 2.6)
	var window_w := _param_f(plan, &"window_w", 1.3)
	var cols := _cols(width, pitch) if windows_on else 0
	var xf := _FacadePlan.face_x(plan, ss)
	var pipe_h := height - 1.0
	var pipe_y := _BASE_Y + 0.5 + pipe_h * 0.5
	var bot := _BASE_Y + 0.5
	var top := _BASE_Y + height - 0.5
	var boxes := []
	for i in rng.randi_range(1, 3):
		var u: float
		if cols > 0:
			# Sit just past a window's edge rather than the pitch-cell boundary.
			var edge := _col_u(rng.randi_range(0, cols - 1), pitch)
			u = edge + (1.0 if rng.randf() < 0.5 else -1.0) * (window_w * 0.5 + 0.1)
		else:
			u = rng.randf_range(0.15, width - 0.15)
		u = clampf(u, 0.15, width - 0.15)
		var z := _z_at(plan, ss, u)
		var bracket_n := rng.randi_range(2, 4)
		var pipe_center := Vector3(_out_x(xf, ss, 0.22), pipe_y, z)
		var pipe_size := Vector3(0.2, pipe_h, 0.2)
		# A bracket without its pipe is nonsensical; only mount them once the pipe itself clears
		# the gate (on a bay side it never does, since it always dips below the approach box).
		if not ko.allows(_FacadeKeepOut.box_aabb(pipe_center, pipe_size)):
			continue
		boxes.append([pipe_center, pipe_size])
		var bx := _out_x(xf, ss, 0.11)
		for j in range(bracket_n):
			var t := (float(j) + 1.0) / (float(bracket_n) + 1.0)
			boxes.append([Vector3(bx, lerpf(bot, top, t), z), Vector3(0.1, 0.06, 0.3)])
	if rng.randf() < 0.5:
		var run_y := _BASE_Y + height * (2.0 / 3.0)
		boxes.append([
			Vector3(_out_x(xf, ss, 0.22), run_y, _z_at(plan, ss, width * 0.5)), Vector3(0.2, 0.2, width - 1.0),
		])
	_emit(host, "WallPipes", _FacadeMaterials.rust_pipe_material(), false, boxes, ko)
