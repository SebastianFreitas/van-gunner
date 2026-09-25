extends FacadeSetPiece
## A blank wall (windows switched off) painted with a generated mural: solid shapes plus one
## giant glyph word from the district's sign list.


const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")

const _BASE_Y := _FacadePlan.BASE_Y
const _TEX_SIZE := 256
const _CACHE_CAP := 16
## warm / cool / mono; each is [base, shape a, shape b, glyph accent].
const _PALETTES := [
	[
		Color(0.81, 0.33, 0.19), Color(0.72, 0.56, 0.18), Color(0.2, 0.25, 0.35),
		Color(0.59, 0.59, 0.55),
	],
	[Color(0.2, 0.5, 0.7), Color(0.62, 0.58, 0.48), Color(0.1, 0.15, 0.25), Color(0.7, 0.2, 0.3)],
	[Color(0.1, 0.1, 0.1), Color(0.58, 0.58, 0.58), Color(0.45, 0.45, 0.45), Color(0.8, 0.2, 0.2)],
]

static var _cache: Dictionary = {}


func can_apply(plans: Array[Dictionary]) -> bool:
	return _target_index(plans) != -1


func pick_plan(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> int:
	return _target_index(plans)


func apply_plans(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> void:
	var target := _target_index(plans)
	if target == -1:
		return
	var params: Dictionary = plans[target][&"params"]
	params[&"windows_on"] = 0.0
	params[&"grime"] = 0.3
	plans[target][&"rare"] = id
	plans[target][&"suppress"] = [
		&"balconies", &"fire_escape", &"ac_units", &"wall_pipes", &"signs",
	]


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var ss: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var rng: RandomNumberGenerator = ctx[&"rng"]
	var district: FacadeDistrict = ctx[&"district"]
	var width := float(plan[&"width"])
	var height := minf(float(plan[&"height"]) - 6.0, 14.0)
	var xf := _FacadePlan.face_x(plan, ss)
	var center := Vector3(
		xf - ss * 0.03, _BASE_Y + 4.8 + height * 0.5, _z_at(plan, ss, width * 0.5)
	)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if not _FacadeMeshKit.add_box(st, center, Vector3(0.02, height, width - 2.0), keep_out):
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _texture_for(int(ctx[&"tile_seed"]), rng, district)
	mat.roughness = 0.95
	_FacadeMeshKit.commit(host, st, "Mural", mat, false)


static func _texture_for(
	tile_seed: int, rng: RandomNumberGenerator, district: FacadeDistrict
) -> ImageTexture:
	if _cache.has(tile_seed):
		return _cache[tile_seed]
	var pal: Array = _PALETTES[rng.randi_range(0, _PALETTES.size() - 1)]
	var img := Image.create(_TEX_SIZE, _TEX_SIZE, false, Image.FORMAT_RGB8)
	img.fill(pal[0])
	for i in rng.randi_range(3, 5):
		var w := rng.randi_range(40, 120)
		var h := rng.randi_range(40, 120)
		var x0 := rng.randi_range(0, _TEX_SIZE - w)
		var y0 := rng.randi_range(0, _TEX_SIZE - h)
		var color: Color = pal[rng.randi_range(1, 2)]
		for x in range(x0, x0 + w):
			for y in range(y0, y0 + h):
				img.set_pixel(x, y, color)
	for i in rng.randi_range(2, 3):
		var r := rng.randi_range(20, 60)
		var cx := rng.randi_range(r, _TEX_SIZE - r)
		var cy := rng.randi_range(r, _TEX_SIZE - r)
		var color: Color = pal[rng.randi_range(1, 2)]
		for x in range(cx - r, cx + r):
			for y in range(cy - r, cy + r):
				if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
					img.set_pixel(x, y, color)
	if not district.sign_words.is_empty():
		var word: String = district.sign_words[rng.randi_range(0, district.sign_words.size() - 1)]
		var glyph := word.substr(0, clampi(rng.randi_range(2, 4), 1, word.length()))
		var scale := rng.randi_range(10, 14)
		var origin := Vector2i(
			int((_TEX_SIZE - BlockGlyphs.text_width_px(glyph, scale)) / 2.0),
			int((_TEX_SIZE - BlockGlyphs.line_height(scale)) / 2.0)
		)
		BlockGlyphs.draw_text(img, glyph, origin, pal[3], scale)
	for x in _TEX_SIZE:
		for y in _TEX_SIZE:
			img.set_pixel(x, y, img.get_pixel(x, y) * rng.randf_range(0.6, 1.0))
	if _cache.size() > _CACHE_CAP: _cache.clear()  # cap so a long trip can't grow this forever
	_cache[tile_seed] = ImageTexture.create_from_image(img)
	return _cache[tile_seed]


func _target_index(plans: Array[Dictionary]) -> int:
	var best := -1
	var best_width := -1.0
	for i in plans.size():
		var style := int(plans[i][&"params"][&"style"])
		if style != 1 and style != 2:
			continue
		var width := float(plans[i][&"width"])
		if width > best_width:
			best_width = width
			best = i
	return best


## u (metres along the building) to world z; mirrors facade_body._u's inverse.
static func _z_at(plan: Dictionary, side_sign: float, u: float) -> float:
	var z0: float = plan[&"z0"]
	var z1: float = plan[&"z1"]
	return z0 + u if side_sign > 0.0 else z1 - u
