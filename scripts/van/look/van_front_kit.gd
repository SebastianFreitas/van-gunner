extends RefCounted
## Builds the van's seeded front kit (bumper, ram, windshield cage, lamp cages) onto a VanCab.

const RAMS: Array[StringName] = [&"plow", &"bar_ram", &"cow_catcher", &"tyre_ram"]
const CAGES: Array[StringName] = [&"bars", &"grid", &"slit_plate"]

var _cab: VanCab


func _init(cab: VanCab) -> void:
	_cab = cab


func build(mat: Material, rng: RandomNumberGenerator) -> void:
	var ram: StringName = RAMS[rng.randi_range(0, RAMS.size() - 1)]
	var cage: StringName = CAGES[rng.randi_range(0, CAGES.size() - 1)]
	var lamp_caged := rng.randf() < 0.5
	_bumper(mat)
	_ram(ram, mat, rng)
	_cage(cage, mat)
	if lamp_caged:
		_lamp_cages(mat)


func _bumper(mat: Material) -> void:
	var nose_z := VanCab.NOSE_Z
	_cab._add_mesh("Bumper", _cab._box(Vector3(VanCab.BUMPER_W, VanCab.BUMPER_H, VanCab.BUMPER_D)),
			mat, Vector3(0.0, VanCab.BUMPER_Y, nose_z - 0.02 - VanCab.BUMPER_D * 0.5))
	for s: float in [-1.0, 1.0]:
		_cab._add_mesh("BumperBracket%s" % ("L" if s < 0.0 else "R"),
				_cab._box(Vector3(0.18, 0.2, 0.2)), mat,
				Vector3(s * 1.6, VanCab.BUMPER_Y - VanCab.BUMPER_H * 0.5 - 0.1, nose_z - 0.12))


func _mount_z(y: float) -> float:
	if y <= VanCab.BUMPER_TOP_Y + 0.01:
		return VanCab.BUMPER_FRONT_Z
	return VanCab.NOSE_Z - 0.02


func _ram(kind: StringName, mat: Material, rng: RandomNumberGenerator) -> void:
	var jitter := rng.randf_range(0.9, 1.05)
	var i := 0
	match kind:
		&"plow":
			for y: float in [0.0, 0.7]:
				for s: float in [-1.0, 1.0]:
					_bar("RamBar%d" % i, Vector3(s * 2.4 * jitter, y, _mount_z(y)),
							Vector3(0.0, y, -9.2), 0.12, mat)
					i += 1
			var tip_bot := Vector3(0.0, 0.0, -9.2)
			var tip_top := Vector3(0.0, 0.7, -9.2)
			_bar("RamBar%d" % i, tip_bot, tip_top, 0.12, mat)
			i += 1
			for s: float in [-1.0, 1.0]:
				var bot_from := Vector3(s * 2.4 * jitter, 0.0, _mount_z(0.0))
				var top_from := Vector3(s * 2.4 * jitter, 0.7, _mount_z(0.7))
				_bar("RamBar%d" % i, bot_from.lerp(tip_bot, 0.5), top_from.lerp(tip_top, 0.5),
						0.12, mat)
				i += 1
		&"bar_ram":
			for y: float in [0.25, 0.75]:
				_bar("RamBar%d" % i, Vector3(-1.8 * jitter, y, -9.0), Vector3(1.8 * jitter, y, -9.0),
						0.18, mat)
				i += 1
			for x: float in [-1.2, 1.2]:
				for y: float in [0.25, 0.75]:
					_bar("RamBar%d" % i, Vector3(x * jitter, y, -9.0),
							Vector3(x * jitter, y, _mount_z(y)), 0.18, mat)
					i += 1
		&"cow_catcher":
			var top_rail_from := Vector3(-2.2 * jitter, 0.6, _mount_z(0.6))
			var top_rail_to := Vector3(2.2 * jitter, 0.6, _mount_z(0.6))
			var bot_rail_from := Vector3(-1.6 * jitter, -0.15, -9.1)
			var bot_rail_to := Vector3(1.6 * jitter, -0.15, -9.1)
			_bar("RamBar%d" % i, top_rail_from, top_rail_to, 0.07, mat)
			i += 1
			_bar("RamBar%d" % i, bot_rail_from, bot_rail_to, 0.07, mat)
			i += 1
			for n: int in range(7):
				var t := float(n) / 6.0
				var top := top_rail_from.lerp(top_rail_to, t)
				var bot := bot_rail_from.lerp(bot_rail_to, t)
				_bar("RamBar%d" % i, top, bot, 0.07, mat)
				i += 1
		&"tyre_ram":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.28
			torus.outer_radius = 0.52
			_cab._add_mesh("RamTyre", torus, mat, Vector3(0.0, 0.5, -9.0),
					Vector3(deg_to_rad(90.0), 0.0, 0.0))
			for s: float in [-1.0, 1.0]:
				_bar("RamBar%d" % i, Vector3(s * 0.3 * jitter, 0.5, -9.0),
						Vector3(s * 0.3 * jitter, 0.15, _mount_z(0.15)), 0.12, mat)
				i += 1


func _cage(kind: StringName, mat: Material) -> void:
	var face_z := VanCab.NOSE_Z
	var half_w := VanCab.WS_HALF_W + 0.05
	var top_l := Vector3(-half_w, VanCab.WS_TOP_Y, face_z - 0.10)
	var top_r := Vector3(half_w, VanCab.WS_TOP_Y, face_z - 0.10)
	var bot_l := Vector3(-half_w, VanCab.WS_BOT_Y, face_z - 0.10)
	var bot_r := Vector3(half_w, VanCab.WS_BOT_Y, face_z - 0.10)
	var i := 0
	match kind:
		&"bars":
			for n: int in range(6):
				var t := float(n) / 5.0
				var l := top_l.lerp(bot_l, t)
				var r := top_r.lerp(bot_r, t)
				_bar("CageBar%d" % i, l, r, 0.05, mat)
				i += 1
		&"grid":
			for n: int in range(5):
				var t := float(n) / 4.0
				var l := top_l.lerp(bot_l, t)
				var r := top_r.lerp(bot_r, t)
				_bar("CageBar%d" % i, l, r, 0.035, mat)
				i += 1
			for n: int in range(7):
				var s := float(n) / 6.0
				var top := top_l.lerp(top_r, s)
				var bot := bot_l.lerp(bot_r, s)
				_bar("CageBar%d" % i, top, bot, 0.035, mat)
				i += 1
		&"slit_plate":
			var ws_h := VanCab.WS_TOP_Y - VanCab.WS_BOT_Y
			var lower_size := Vector3(2.0 * VanCab.WS_HALF_W + 0.2, 0.6 * ws_h, 0.04)
			var lower_pos := Vector3(0.0, VanCab.WS_BOT_Y + 0.3 * ws_h, face_z - 0.10)
			_cab._add_mesh("CagePlate%d" % i, _cab._box(lower_size), mat, lower_pos)
			i += 1
			var upper_size := Vector3(2.0 * VanCab.WS_HALF_W + 0.2, 0.25 * ws_h, 0.04)
			var upper_pos := Vector3(0.0, VanCab.WS_TOP_Y - 0.125 * ws_h, face_z - 0.10)
			_cab._add_mesh("CagePlate%d" % i, _cab._box(upper_size), mat, upper_pos)

	## Weld the cage to the windshield frame at all four corners.
	var corners: Array[Vector3] = [top_l, top_r, bot_l, bot_r]
	for c: int in range(4):
		var corner: Vector3 = corners[c]
		_cab._add_mesh("CageTab%d" % c, _cab._box(Vector3(0.06, 0.06, 0.10)), mat,
				Vector3(corner.x, corner.y, face_z - 0.05))


func _lamp_cages(mat: Material) -> void:
	var face_z := VanCab.NOSE_Z
	for s: float in [-1.0, 1.0]:
		var lamp_x := VanCab.HEADLIGHT_X * s
		var i := 0
		for dx: float in [-0.1, 0.0, 0.1]:
			var suffix := "L" if s < 0.0 else "R"
			_bar("LampCage%s%d" % [suffix, i],
					Vector3(lamp_x + dx, VanCab.HEADLIGHT_Y - 0.22, face_z - 0.23),
					Vector3(lamp_x + dx, VanCab.HEADLIGHT_Y + 0.22, face_z - 0.23), 0.025, mat)
			i += 1


func _bar(mesh_name: String, from: Vector3, to: Vector3, thickness: float, mat: Material) -> void:
	var diff := to - from
	var length := diff.length()
	if length < 0.0001:
		return
	var mid := (from + to) * 0.5
	var up := Vector3.UP
	if absf(diff.normalized().dot(Vector3.UP)) > 0.95:
		up = Vector3.FORWARD
	var box := _cab._box(Vector3(thickness, thickness, length))
	var mi := _cab._add_mesh(mesh_name, box, mat, mid)
	mi.basis = Basis.looking_at(diff, up)
