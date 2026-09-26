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
	_cab._add_mesh("Bumper", _cab._box(Vector3(5.0, 0.35, 0.3)), mat,
			Vector3(0.0, 0.1, VanCab.NOSE_Z - 0.2))


func _ram(kind: StringName, mat: Material, rng: RandomNumberGenerator) -> void:
	var jitter := rng.randf_range(0.9, 1.05)
	var nose_z := VanCab.NOSE_Z
	var i := 0
	match kind:
		&"plow":
			for y: float in [0.0, 0.7]:
				for s: float in [-1.0, 1.0]:
					_bar("RamBar%d" % i, Vector3(s * 2.4 * jitter, y, nose_z - 0.35),
							Vector3(0.0, y, -9.2), 0.12, mat)
					i += 1
			_bar("RamBar%d" % i, Vector3(0.0, 0.0, -9.2), Vector3(0.0, 0.7, -9.2), 0.12, mat)
			i += 1
			for s: float in [-1.2, 1.2]:
				_bar("RamBar%d" % i, Vector3(s * jitter, 0.0, -8.775),
						Vector3(s * jitter, 0.7, -8.775), 0.12, mat)
				i += 1
		&"bar_ram":
			for y: float in [0.25, 0.75]:
				_bar("RamBar%d" % i, Vector3(-1.8 * jitter, y, -9.0), Vector3(1.8 * jitter, y, -9.0),
						0.18, mat)
				i += 1
			for x: float in [-1.2, 1.2]:
				for y: float in [0.25, 0.75]:
					_bar("RamBar%d" % i, Vector3(x * jitter, y, -9.0),
							Vector3(x * jitter, y, nose_z - 0.35), 0.18, mat)
					i += 1
		&"cow_catcher":
			var top_rail_from := Vector3(-2.2 * jitter, 0.9, nose_z - 0.35)
			var top_rail_to := Vector3(2.2 * jitter, 0.9, nose_z - 0.35)
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
						Vector3(s * 0.3 * jitter, 0.15, nose_z - 0.35), 0.12, mat)
				i += 1


func _cage(kind: StringName, mat: Material) -> void:
	var top_l := Vector3(-2.3, 2.65, -5.5)
	var top_r := Vector3(2.3, 2.65, -5.5)
	var bot_l := Vector3(-2.3, 1.6, -6.3)
	var bot_r := Vector3(2.3, 1.6, -6.3)
	var normal := Vector3(0.0, 0.8, -1.05).normalized() * 0.06
	var i := 0
	match kind:
		&"bars":
			for n: int in range(6):
				var t := float(n) / 5.0
				var l := top_l.lerp(bot_l, t) + normal
				var r := top_r.lerp(bot_r, t) + normal
				_bar("CageBar%d" % i, l, r, 0.05, mat)
				i += 1
		&"grid":
			for n: int in range(5):
				var t := float(n) / 4.0
				var l := top_l.lerp(bot_l, t) + normal
				var r := top_r.lerp(bot_r, t) + normal
				_bar("CageBar%d" % i, l, r, 0.035, mat)
				i += 1
			for n: int in range(7):
				var s := float(n) / 6.0
				var top := top_l.lerp(top_r, s) + normal
				var bot := bot_l.lerp(bot_r, s) + normal
				_bar("CageBar%d" % i, top, bot, 0.035, mat)
				i += 1
		&"slit_plate":
			var lower_top := top_l.lerp(bot_l, 0.6)
			var lower_top_r := top_r.lerp(bot_r, 0.6)
			var lower_size := Vector3(4.6, 0.04, (lower_top - bot_l).length())
			var lower_pos := ((lower_top + lower_top_r) * 0.5 + (bot_l + bot_r) * 0.5) * 0.5 + normal
			var plate_l := _cab._add_mesh("CagePlate%d" % i, _cab._box(lower_size), mat, lower_pos)
			plate_l.basis = Basis.looking_at((bot_l - lower_top).normalized(), Vector3.UP)
			i += 1
			var top_bot := top_l.lerp(bot_l, 0.25)
			var top_bot_r := top_r.lerp(bot_r, 0.25)
			var upper_size := Vector3(4.6, 0.04, (top_l - top_bot).length())
			var upper_pos := ((top_l + top_r) * 0.5 + (top_bot + top_bot_r) * 0.5) * 0.5 + normal
			var plate_u := _cab._add_mesh("CagePlate%d" % i, _cab._box(upper_size), mat, upper_pos)
			plate_u.basis = Basis.looking_at((top_bot - top_l).normalized(), Vector3.UP)


func _lamp_cages(mat: Material) -> void:
	var nose_z := VanCab.NOSE_Z
	for s: float in [-1.0, 1.0]:
		var lamp_x := s * 1.75
		var i := 0
		for dx: float in [-0.1, 0.0, 0.1]:
			var suffix := "L" if s < 0.0 else "R"
			_bar("LampCage%s%d" % [suffix, i], Vector3(lamp_x + dx, 0.77, nose_z - 0.2),
					Vector3(lamp_x + dx, 1.13, nose_z - 0.2), 0.025, mat)
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
