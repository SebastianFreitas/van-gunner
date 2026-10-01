extends RefCounted
## Builds the wrecked paving's granite curb: 1 m blocks, knocked, missing or toppled in gone stretches.

const _PavingMesh := preload("res://scripts/travel/road_floor_paving_mesh.gd")

const CURB_LEN := 1.0
const JOINT := 0.03
const CHAMFER := 0.025
const MIN_PIECE := 0.12
const MISSING: Array[float] = [0.0, 0.02, 0.06, 0.12]
const KNOCKED: Array[float] = [0.02, 0.06, 0.12, 0.18]


## `wreck` is the RoadFloorWreck (untyped: it preloads this file); its fields are read as is.
func build(wreck, side_idx: int, side_sign: float, rng: RandomNumberGenerator, curb: Object,
		rubble: Object) -> void:
	var curb_depth: float = wreck._curb_depth
	if curb_depth <= 0.0:
		return
	var z_start: float = wreck._z_start
	var z_end: float = wreck._z_end
	var top: float = wreck._top
	var inner: float = wreck._inner
	var gutter_top_y: float = wreck._gutter_top_y
	var y_bot := gutter_top_y - 0.04
	var height := top + 0.02 - y_bot
	var cx := inner - curb_depth * 0.5
	var k := floori(z_start / CURB_LEN)
	while k * CURB_LEN < z_end:
		var z0 := maxf(k * CURB_LEN, z_start)
		var z1 := minf((k + 1) * CURB_LEN, z_end)
		k += 1
		if z1 - z0 < MIN_PIECE:
			continue
		var z := (z0 + z1) * 0.5
		var r_miss := rng.randf()
		var r_knock := rng.randf()
		var tone := rng.randf()
		var tier: int = wreck.tier_at(side_idx, z)
		var gone: float = wreck._gone_at(z)
		var edge: float = wreck._edge_near(z)
		var tint := 1.0 if gone > 0.0 else tier / 3.0
		var chance := MISSING[tier] + 0.2 * edge
		if gone > 0.0:
			chance = lerpf(MISSING[tier], 0.6, gone)
		if r_miss < chance:
			_add_chunks(wreck, side_sign, rng, rubble, z0, z1)
			continue
		var size := Vector3(curb_depth, height, z1 - z0 - JOINT)
		var centre := Vector3(side_sign * cx, y_bot + height * 0.5, z)
		if gone <= 0.0 and r_knock >= KNOCKED[tier] + 0.3 * edge:
			var sides := _PavingMesh.SIDE_NEG_X | _PavingMesh.SIDE_POS_X \
					| _PavingMesh.SIDE_NEG_Z | _PavingMesh.SIDE_POS_Z
			curb.add_block(size, Transform3D(Basis(), centre), tint, tone, CHAMFER, sides, false)
			continue
		var yaw_deg := rng.randf_range(2.0, 6.0)
		var shift := rng.randf_range(0.01, 0.04)
		var drop := rng.randf_range(0.01, 0.03)
		if gone > 0.0:
			yaw_deg = rng.randf_range(4.0, 12.0)
			shift = rng.randf_range(0.03, 0.10)
			drop = rng.randf_range(0.03, 0.10)
		if rng.randf() < 0.5:
			yaw_deg = -yaw_deg
		var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
		if gone > 0.0:
			# The top leans toward the road, pivoting on the bottom edge.
			basis = basis * Basis(Vector3.BACK, side_sign * deg_to_rad(rng.randf_range(4.0, 14.0)))
		var pivot := Vector3(centre.x, y_bot, z)
		var origin := pivot + basis * Vector3(0.0, height * 0.5, 0.0)
		origin += Vector3(-side_sign * shift, -drop, 0.0)
		# Keep the walk-side top corner from rising above the walk.
		var corner := origin + basis * Vector3(side_sign * curb_depth * 0.5, height * 0.5, 0.0)
		if corner.y > top + 0.06:
			origin.y -= corner.y - (top + 0.06)
		curb.add_block(size, Transform3D(basis, origin), tint, tone, CHAMFER,
				_PavingMesh.SIDE_ALL, true)


## One or two lumps of granite in the gutter where a block is gone.
func _add_chunks(wreck, side_sign: float, rng: RandomNumberGenerator, rubble: Object, z0: float,
		z1: float) -> void:
	var curb_depth: float = wreck._curb_depth
	var inner: float = wreck._inner
	var gutter_top_y: float = wreck._gutter_top_y
	var count := 2 if rng.randf() < 0.5 else 1
	for i in count:
		var size := Vector3(rng.randf_range(0.10, 0.28), rng.randf_range(0.06, 0.14),
				rng.randf_range(0.10, 0.28))
		var pos := Vector3(side_sign * (inner - curb_depth - rng.randf_range(0.05, 0.30)),
				gutter_top_y + size.y * 0.3, rng.randf_range(z0, z1))
		var t := rng.randf() * TAU
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) \
				* Basis(Vector3(cos(t), 0.0, sin(t)), deg_to_rad(rng.randf_range(0.0, 20.0)))
		rubble.add_block(size, Transform3D(basis, pos), 1.0, rng.randf(), 0.015,
				_PavingMesh.SIDE_ALL, true)
