extends RefCounted
## Street art family: scatters the run's pooled graffiti and posters over one building's wall as one merged, keep-out-gated quad mesh.

const _FacadeBody := preload("res://scripts/travel/facades/facade_body.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeRuin := preload("res://scripts/travel/facades/facade_ruin.gd")
const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _Pool := preload("res://scripts/travel/facades/street_art/street_art_pool.gd")

## First layer's distance off the wall, as signs use.
const FACE_GAP := 0.03
## Each later piece sits this much further out, so overlaps never z-fight.
const LAYER_STEP := 0.004
const MAX_LAYERS := 12
## Tile-local y; above the sidewalk.
const ART_MIN_Y := 0.35
const HIGH_CHANCE := 0.1
const POSTER_TILT_DEG := 3.0
## Margin kept between a piece and the building's ends.
const EDGE_MARGIN := 0.2
const TRIES := 8


static func build(
	root: Node3D, plan: Dictionary, prop_plan: Dictionary, side_sign: float, index: int,
	keep_out: RefCounted, district: FacadeDistrict
) -> void:
	if district == null or plan.get(&"mouth", false) or plan.get(&"rare", &"") != &"":
		return
	if (plan.get(&"suppress", []) as Array).has(&"street_art"):
		return
	var params: Dictionary = plan[&"params"]
	var style := int(params.get(&"style", 0))
	if style == 3 or style == 6:
		return
	var width := float(plan[&"width"])
	if width < 1.5:
		return
	_Pool.ensure(GameSession.run_seed)
	var graffiti := _Pool.entries(_Pool.Family.GRAFFITI)
	var posters := _Pool.entries(_Pool.Family.POSTER)
	if graffiti.is_empty() or posters.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([float(params.get(&"seed", 0.0)), &"street_art"])

	var base := _FacadePlan.BASE_Y
	var ground_h := float(params.get(&"ground_height", _FacadePlan.GROUND_HEIGHT))
	var top_limit := _FacadeRuin.min_top(plan) - 0.3
	var roof_y := base + float(prop_plan[&"height"])
	var ground_kind := int(plan.get(&"ground_kind", _FacadePlan.GROUND_BLANK))
	var has_band := (
		ground_kind != _FacadePlan.GROUND_DOCK and ground_kind != _FacadePlan.GROUND_ARCADE
	)
	var band_lo := ART_MIN_Y
	var band_hi := minf(base + ground_h - 0.25, top_limit)
	var shaped := _FacadeRuin.is_shaped(plan)
	var holes: Array[Rect2] = []
	if shaped:
		var pitch := float(params.get(&"window_pitch", 2.6))
		for h: Vector3 in plan.get(&"ruin_holes", []):
			holes.append(Rect2(h.x * pitch, h.y, pitch, h.z - h.y))
	var ruin_boost := 1.25 if int(plan.get(&"ruin", 0)) >= 1 else 1.0

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := _FacadePlan.face_x(plan, side_sign)
	var emitted := 0
	var layer := 0
	var placed: Array[Rect2] = []

	# Posters first, so paint can go over paper.
	if has_band and band_hi - band_lo > 0.2:
		var tries := 1 + (1 if width > 10.0 else 0)
		for _t in tries:
			if rng.randf() >= district.poster_amount * 0.8:
				continue
			var count := 1 if rng.randf() < 0.6 else rng.randi_range(2, 5)
			var prev := Rect2()
			for k in count:
				var e: Dictionary = posters[rng.randi() % posters.size()]
				var size: Vector2 = e[&"size_m"]
				var rect := _poster_spot(rng, size, k > 0, prev, width, band_lo, band_hi, holes, placed)
				if rect.size == Vector2.ZERO:
					continue
				prev = rect
				var tilt := rng.randf_range(-1.0, 1.0) * POSTER_TILT_DEG
				if _emit_piece(st, plan, side_sign, x0, rect, e, tilt, layer, keep_out):
					layer += 1
					emitted += 1

	var n_g := floori(district.graffiti_amount * width * 0.3 * ruin_boost + rng.randf())
	for _g in n_g:
		var e: Dictionary = graffiti[rng.randi() % graffiti.size()]
		var size: Vector2 = e[&"size_m"]
		var high := (
			rng.randf() < HIGH_CHANCE and size.y <= 0.9
			and int(plan.get(&"floors", 0)) >= 1 and not shaped
		)
		if not high and (not has_band or size.y > band_hi - band_lo):
			continue
		if size.x > width - 2.0 * EDGE_MARGIN:
			continue
		for _try in TRIES:
			var u := rng.randf_range(EDGE_MARGIN, width - EDGE_MARGIN - size.x)
			var y_bot: float
			if high:
				y_bot = minf(roof_y - 0.15, top_limit) - size.y
			else:
				y_bot = maxf(rng.randf_range(0.35, 0.9), band_lo)
				if y_bot + size.y > band_hi:
					continue
			var rect := Rect2(u, y_bot, size.x, size.y)
			if not _fits(rect, holes, placed):
				continue
			if _emit_piece(st, plan, side_sign, x0, rect, e, 0.0, layer, keep_out):
				layer += 1
				emitted += 1
				placed.append(rect)
			break

	if emitted == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "StreetArt%d" % index
	mi.mesh = st.commit()
	mi.material_override = _Pool.material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## u (metres from the building's road-view left end) to world z; facade_body._u's inverse.
static func _z_at(plan: Dictionary, side_sign: float, u: float) -> float:
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	return z0 + u if side_sign > 0.0 else z1 - u


## True when the rect misses every hole and overlaps no earlier graffiti by over 25% of the
## smaller area.
static func _fits(rect: Rect2, holes: Array[Rect2], placed: Array[Rect2]) -> bool:
	for h in holes:
		if rect.intersects(h):
			return false
	for p in placed:
		var overlap := rect.intersection(p).get_area()
		if overlap > 0.25 * minf(rect.get_area(), p.get_area()):
			return false
	return true


## A poster rect inside the ground band, or a zero rect when no try finds a spot. A cluster
## member is offset from the previous poster, and overlapping it is the point.
static func _poster_spot(
	rng: RandomNumberGenerator, size: Vector2, follow: bool, prev: Rect2, width: float,
	band_lo: float, band_hi: float, holes: Array[Rect2], placed: Array[Rect2]
) -> Rect2:
	if size.y > band_hi - band_lo or size.x > width - 2.0 * EDGE_MARGIN:
		return Rect2()
	for _try in TRIES:
		var cu: float
		var cy: float
		if follow and prev.size != Vector2.ZERO:
			var pc := prev.get_center()
			cu = pc.x + signf(rng.randf() - 0.5) * rng.randf_range(0.35, 0.8) * size.x
			cy = pc.y + signf(rng.randf() - 0.5) * rng.randf_range(0.1, 0.35)
		else:
			cu = rng.randf_range(EDGE_MARGIN + size.x * 0.5, width - EDGE_MARGIN - size.x * 0.5)
			cy = rng.randf_range(1.3, 2.1)
		cu = clampf(cu, EDGE_MARGIN + size.x * 0.5, width - EDGE_MARGIN - size.x * 0.5)
		cy = clampf(cy, band_lo + size.y * 0.5, band_hi - size.y * 0.5)
		var rect := Rect2(cu - size.x * 0.5, cy - size.y * 0.5, size.x, size.y)
		if _fits(rect, holes, placed):
			return rect
	return Rect2()


## Emits one tilted quad of the entry over rect (u, y metres), gated by the keep-out. Returns
## false, emitting nothing, when the gate refuses it.
static func _emit_piece(
	st: SurfaceTool, plan: Dictionary, side_sign: float, x0: float, rect: Rect2, entry: Dictionary,
	tilt_deg: float, layer: int, keep_out: RefCounted
) -> bool:
	var x := x0 - side_sign * (FACE_GAP + LAYER_STEP * mini(layer, MAX_LAYERS - 1))
	var c := rect.get_center()
	var hw := rect.size.x * 0.5
	var hh := rect.size.y * 0.5
	var ang := deg_to_rad(tilt_deg)
	var corners: Array[Vector2] = [
		Vector2(-hw, hh), Vector2(hw, hh), Vector2(hw, -hh), Vector2(-hw, -hh)
	]
	var pts: Array[Vector3] = []
	var u_lo := INF
	var u_hi := -INF
	var y_lo := INF
	var y_hi := -INF
	for corner in corners:
		var p := c + corner.rotated(ang)
		u_lo = minf(u_lo, p.x)
		u_hi = maxf(u_hi, p.x)
		y_lo = minf(y_lo, p.y)
		y_hi = maxf(y_hi, p.y)
		pts.append(Vector3(x, p.y, _z_at(plan, side_sign, p.x)))
	if keep_out != null:
		var z_mid := _z_at(plan, side_sign, (u_lo + u_hi) * 0.5)
		var box := _FacadeKeepOut.box_aabb(
			Vector3(x, (y_lo + y_hi) * 0.5, z_mid), Vector3(0.02, y_hi - y_lo, u_hi - u_lo)
		)
		if not keep_out.allows(box):
			return false
	var uv: Rect2 = entry[&"uv"]
	_FacadeBody.add_quad(
		st, pts[0], pts[1], pts[2], pts[3],
		uv.position, uv.position + Vector2(uv.size.x, 0.0), uv.end,
		uv.position + Vector2(0.0, uv.size.y), Vector3(-side_sign, 0.0, 0.0)
	)
	return true
