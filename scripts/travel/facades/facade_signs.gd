extends RefCounted
## Street signage for one building: a backlit box sign over a storefront, a neon strip, a
## perpendicular blade sign, a cloth banner, or a torn poster on a boarded front. One word per
## building from the district's list; every sign passes the keep-out gate.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeBody := preload("res://scripts/travel/facades/facade_body.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")

const MAX_SIGNS_PER_BUILDING := 1  # build() always returns after placing zero or one.
const FACE_GAP := 0.03
const BOX_DEPTH := 0.25
const BLADE_SIZE := Vector3(1.4, 6.0, 0.25)
## Tile y (add BASE_Y): a bottom of 6.2 sits below the lane keep-out's LANE_TOP_Y of 6.0 and
## still reaches its x range, so it's rejected outright; 6.6 clears the lane box by 0.2 m.
const BLADE_BOTTOM_Y := 6.6
const POSTER_SIZE := Vector2(0.9, 1.2)

const VISIBILITY_RANGE := 64.0
# facade_sign.gdshader's own uniform defaults, reused for kinds without their own colour.
const _DEFAULT_COLOR := Color(1.0, 0.85, 0.6)
const _DEFAULT_ENERGY := 2.4
## Public so the neon_blade set-piece can share the same palette.
const NEON_COLORS: Array[Color] = [
	Color(1.0, 0.3, 0.6), Color(0.4, 0.9, 1.0), Color(1.0, 0.7, 0.3), Color(0.5, 1.0, 0.5),
	Color(1.0, 0.35, 0.3),
]
## Rust, navy, bottle green: a muted cloth palette for the arcade banner.
const _BANNER_COLORS: Array[Color] = [
	Color(0.42, 0.18, 0.08), Color(0.12, 0.16, 0.32), Color(0.10, 0.22, 0.16),
]
## Box faces as corner-index quads into an 8-corner bit-encoded box, plus each face's normal.
const _BOX_FACES := [
	[4, 6, 7, 5, 1.0, 0.0, 0.0], [0, 2, 3, 1, -1.0, 0.0, 0.0],
	[2, 6, 7, 3, 0.0, 1.0, 0.0], [0, 4, 5, 1, 0.0, -1.0, 0.0],
	[1, 5, 7, 3, 0.0, 0.0, 1.0], [0, 4, 6, 2, 0.0, 0.0, -1.0],
]


## One building's sign, chosen by its ground kind; every sign face is a fresh ShaderMaterial.
static func build(
	host: Node3D, plan: Dictionary, side_sign: float, keep_out: RefCounted, rng: RandomNumberGenerator,
	district: FacadeDistrict
) -> void:
	# A rare piece that owns this building's face (a mural, a collapse) suppresses its own sign
	# before any RNG draw, since the piece already consumed this plan's identity.
	if plan.get(&"suppress", []).has(&"signs"):
		return
	# Roll first, always, so a mouth or wordless district still consumes the same RNG draw as
	# every other building, keeping the fixtures built after this side's loop aligned.
	if rng.randf() >= district.sign_chance:
		return
	if plan.get(&"mouth", false):
		return
	if district.sign_words.is_empty():
		return
	var word: String = district.sign_words[rng.randi() % district.sign_words.size()]
	var kind := &""
	match int(plan[&"ground_kind"]):
		_FacadePlan.GROUND_STOREFRONT:
			kind = &"box" if rng.randf() < 0.7 else &"neon"
		_FacadePlan.GROUND_BOARDED:
			kind = &"poster"
		_FacadePlan.GROUND_ARCADE:
			kind = &"banner"
		_:
			if float(plan[&"width"]) >= 8.0 and rng.randf() < 0.4:
				kind = &"blade"
			else:
				return
	if kind == &"box" and plan[&"district_id"] == &"commercial" and rng.randf() < 0.35:
		kind = &"blade"
	match kind:
		&"box":
			_build_box(host, plan, side_sign, keep_out, word)
		&"neon":
			_build_neon(host, plan, side_sign, keep_out, rng, district, word)
		&"blade":
			var u_center := float(plan[&"width"]) * 0.5 + (1.0 if rng.randf() < 0.5 else -1.0)
			var seed_value := rng.randf() * 1000.0
			build_blade(
				host, "SignBlade", plan, side_sign, keep_out, u_center, word, BLADE_SIZE,
				BLADE_BOTTOM_Y, _DEFAULT_COLOR, _DEFAULT_ENERGY, seed_value, 0.0, 0.0
			)
		&"banner":
			_build_banner(host, plan, side_sign, keep_out, rng, word)
		&"poster":
			_build_poster(host, plan, side_sign, keep_out, rng, word)


## u (metres from the building's road-view left end) to world z; facade_body._u's inverse.
static func _z_at(plan: Dictionary, side_sign: float, u: float) -> float:
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	return z0 + u if side_sign > 0.0 else z1 - u


## Every box face except those in skip_normals, in a plain 0..1 prop UV (dark backing faces).
static func emit_dark_faces(
	st: SurfaceTool, center: Vector3, size: Vector3, skip_normals: Array[Vector3]
) -> void:
	var h := size * 0.5
	var pts: Array[Vector3] = []
	for i in 8:
		pts.append(center + Vector3(
			h.x * (2.0 * float((i >> 2) & 1) - 1.0), h.y * (2.0 * float((i >> 1) & 1) - 1.0),
			h.z * (2.0 * float(i & 1) - 1.0)
		))
	var uv := [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
	for f: Array in _BOX_FACES:
		var n := Vector3(f[4], f[5], f[6])
		if not skip_normals.any(func(sn: Vector3) -> bool: return sn.is_equal_approx(n)):
			_FacadeBody.add_quad(st, pts[f[0]], pts[f[1]], pts[f[2]], pts[f[3]], uv[0], uv[1], uv[2], uv[3], n)


## A quad on the x = x plane; v runs top(0)-to-bottom(1), since an Image's row 0 is its top.
static func emit_face_x(
	st: SurfaceTool, x: float, y_top: float, y_bot: float, z_center: float, width: float, ss: float
) -> void:
	var z_lo := z_center - ss * width * 0.5
	var z_hi := z_center + ss * width * 0.5
	_FacadeBody.add_quad(
		st, Vector3(x, y_top, z_lo), Vector3(x, y_top, z_hi), Vector3(x, y_bot, z_hi), Vector3(x, y_bot, z_lo),
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector3(-ss, 0.0, 0.0)
	)


## A quad on the z = z plane (a blade's large face); same top-v-0 rule as emit_face_x.
static func emit_face_z(
	st: SurfaceTool, z: float, y_top: float, y_bot: float, x_center: float, depth: float, normal_z: float
) -> void:
	var x_lo := x_center - depth * 0.5
	var x_hi := x_center + depth * 0.5
	_FacadeBody.add_quad(
		st, Vector3(x_lo, y_top, z), Vector3(x_hi, y_top, z), Vector3(x_hi, y_bot, z), Vector3(x_lo, y_bot, z),
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector3(0.0, 0.0, normal_z)
	)


## Shared two-surface build (box, blade): dark faces but skip_normals, then text_cb's face(s).
static func build_boxed(
	host: Node3D, node_name: String, center: Vector3, size: Vector3, skip_normals: Array[Vector3],
	keep_out: RefCounted, text_cb: Callable, sign_mat: ShaderMaterial
) -> void:
	if not keep_out.allows(_FacadeKeepOut.box_aabb(center, size)):
		return
	var mesh := ArrayMesh.new()
	var st_dark := SurfaceTool.new()
	st_dark.begin(Mesh.PRIMITIVE_TRIANGLES)
	emit_dark_faces(st_dark, center, size, skip_normals)
	st_dark.commit(mesh)
	mesh.surface_set_material(0, _FacadeMaterials.prop_material(&"sign_box", Color(0.05, 0.05, 0.05), 0.7, 0.3))
	var st_text := SurfaceTool.new()
	st_text.begin(Mesh.PRIMITIVE_TRIANGLES)
	text_cb.call(st_text)
	st_text.commit(mesh)
	mesh.surface_set_material(1, sign_mat)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = VISIBILITY_RANGE
	host.add_child(mi)


## Shared single-surface build (neon, banner, poster), gated by a depth-thickened AABB.
static func _build_flat(
	host: Node3D, node_name: String, x: float, y_top: float, y_bot: float, z_center: float,
	width: float, side_sign: float, keep_out: RefCounted, material: ShaderMaterial
) -> void:
	var aabb_size := Vector3(0.02, y_top - y_bot, width)
	var aabb_center := Vector3(x, (y_top + y_bot) * 0.5, z_center)
	if not keep_out.allows(_FacadeKeepOut.box_aabb(aabb_center, aabb_size)):
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	emit_face_x(st, x, y_top, y_bot, z_center, width, side_sign)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = VISIBILITY_RANGE
	host.add_child(mi)


## A backlit box over the first storefront unit's doorway, inside the fascia band.
static func _build_box(
	host: Node3D, plan: Dictionary, side_sign: float, keep_out: RefCounted, word: String
) -> void:
	var unit_w := float(plan[&"width"]) / float(plan[&"ground_units"])
	var size := Vector3(BOX_DEPTH, 0.7, minf(unit_w - 1.2, 6.0))
	var center := Vector3(
		_FacadePlan.face_x(plan, side_sign) - side_sign * (FACE_GAP + BOX_DEPTH * 0.5),
		_FacadePlan.BASE_Y + 3.8, _z_at(plan, side_sign, unit_w * 0.5)
	)
	var sign_mat := _FacadeMaterials.sign_material(
		word, 4, false, _DEFAULT_COLOR, _DEFAULT_ENERGY, 0, 0.0, 0.0, 0.0, float(word.length())
	)
	build_boxed(
		host, "SignBox", center, size, [Vector3(-side_sign, 0.0, 0.0)], keep_out,
		func(st: SurfaceTool) -> void:
			emit_face_x(
				st, center.x - side_sign * size.x * 0.5, center.y + size.y * 0.5,
				center.y - size.y * 0.5, center.z, size.z, side_sign
			),
		sign_mat
	)


## A neon strip in the same storefront-unit slot a box would take instead.
static func _build_neon(
	host: Node3D, plan: Dictionary, side_sign: float, keep_out: RefCounted, rng: RandomNumberGenerator,
	district: FacadeDistrict, word: String
) -> void:
	var z_center := _z_at(plan, side_sign, float(plan[&"width"]) / float(plan[&"ground_units"]) * 0.5)
	var x := _FacadePlan.face_x(plan, side_sign) - side_sign * 0.05
	var color: Color = NEON_COLORS[rng.randi_range(0, NEON_COLORS.size() - 1)]
	var flicker_amount := 0.3 if district.id == &"derelict" else 0.1
	var sign_mat := _FacadeMaterials.sign_material(
		word, 4, false, color, _DEFAULT_ENERGY, 1, rng.randf() * 1000.0, district.dead_lamp_chance,
		flicker_amount, float(word.length())
	)
	_build_flat(host, "SignNeon", x, 5.7, 4.9, z_center, 3.6, side_sign, keep_out, sign_mat)


## A perpendicular blade sign readable while approaching the building; public so a set-piece
## (neon_blade) can place its own at a different size, height, colour and seed.
static func build_blade(
	host: Node3D, node_name: String, plan: Dictionary, side_sign: float, keep_out: RefCounted,
	u_center: float, word: String, size: Vector3, bottom_y: float, color: Color, energy: float,
	seed_value: float, dead_ratio: float, flicker_amount: float
) -> void:
	var center := Vector3(
		_FacadePlan.face_x(plan, side_sign) - side_sign * (FACE_GAP + size.x * 0.5),
		_FacadePlan.BASE_Y + bottom_y + size.y * 0.5, _z_at(plan, side_sign, u_center)
	)
	var sign_mat := _FacadeMaterials.sign_material(
		word, 4, true, color, energy, 1, seed_value, dead_ratio, flicker_amount, float(word.length())
	)
	var y_top := center.y + size.y * 0.5
	var y_bot := center.y - size.y * 0.5
	var half_thick := size.z * 0.5
	build_boxed(
		host, node_name, center, size, [Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0)], keep_out,
		func(st: SurfaceTool) -> void:
			# Both faces so it reads correctly (top to bottom) from either side of the corridor.
			emit_face_z(st, center.z + half_thick, y_top, y_bot, center.x, size.x, 1.0)
			emit_face_z(st, center.z - half_thick, y_top, y_bot, center.x, size.x, -1.0),
		sign_mat
	)


## A cloth banner strung across the first arcade bay; unlit, so it reads the same day or night.
static func _build_banner(
	host: Node3D, plan: Dictionary, side_sign: float, keep_out: RefCounted, rng: RandomNumberGenerator,
	word: String
) -> void:
	var z_center := _z_at(plan, side_sign, float(plan[&"width"]) / float(plan[&"ground_units"]) * 0.5)
	var x := _FacadePlan.face_x(plan, side_sign) - side_sign * 0.08
	var y := _FacadePlan.BASE_Y + _FacadePlan.GROUND_HEIGHT + 1.2
	var color: Color = _BANNER_COLORS[rng.randi_range(0, _BANNER_COLORS.size() - 1)]
	var sign_mat := _FacadeMaterials.sign_material(
		word, 3, false, color, _DEFAULT_ENERGY, 2, 0.0, 0.0, 0.0, float(word.length())
	)
	_build_flat(host, "SignBanner", x, y + 0.45, y - 0.45, z_center, 2.4, side_sign, keep_out, sign_mat)


## A torn poster taped to a boarded-up front, at a random spot with enough margin to fit.
static func _build_poster(
	host: Node3D, plan: Dictionary, side_sign: float, keep_out: RefCounted, rng: RandomNumberGenerator,
	word: String
) -> void:
	var z_center := _z_at(plan, side_sign, 1.0 + rng.randf() * (float(plan[&"width"]) - 2.0))
	var x := _FacadePlan.face_x(plan, side_sign) - side_sign * FACE_GAP
	var y0 := _FacadePlan.BASE_Y
	var sign_mat := _FacadeMaterials.sign_material(
		word, 3, false, Color(0.8, 0.72, 0.55), _DEFAULT_ENERGY, 2, 0.0, 0.0, 0.0, float(word.length())
	)
	_build_flat(
		host, "SignPoster", x, y0 + 2.8, y0 + 1.6, z_center, POSTER_SIZE.x, side_sign, keep_out, sign_mat
	)
