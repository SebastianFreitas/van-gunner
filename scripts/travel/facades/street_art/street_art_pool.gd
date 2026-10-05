extends RefCounted
## Per-run pool of generated graffiti and posters packed into one atlas texture and one shared material, rebuilt when the run seed changes.

const _Graffiti := preload("res://scripts/travel/facades/street_art/street_art_graffiti.gd")
const _Posters := preload("res://scripts/travel/facades/street_art/street_art_posters.gd")

const GRAFFITI_COUNT := 40
## Posters generated for each of WANTED, FESTIVAL and NOTICE.
const POSTERS_PER_KIND := 8
const ATLAS_W := 512
## Pixels between atlas entries, so mipmaps and filtering don't bleed one into the next.
const PAD := 2

enum Family { GRAFFITI, POSTER }

static var _seed := -1
static var _entries: Array[Dictionary] = []
static var _material: StandardMaterial3D
static var _atlas: Image
static var _build_ms := 0.0


## Builds the pool for this run seed; does nothing when it is already built for it.
static func ensure(run_seed: int) -> void:
	if _material != null and run_seed == _seed:
		return
	var perf_t := PerfStats.begin()
	var t0 := Time.get_ticks_usec()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, &"street_art"])
	var van_name := van_name_for(run_seed)

	# Parallel arrays: image, family, kind, pixel size in metres.
	var images: Array[Image] = []
	var families: Array[int] = []
	var kinds: Array[int] = []
	var pixel_m: Array[float] = []
	for i in GRAFFITI_COUNT:
		images.append(_Graffiti.make(rng))
		families.append(Family.GRAFFITI)
		kinds.append(-1)
		pixel_m.append(_Graffiti.PIXEL_M)
	for kind: int in [_Posters.Kind.WANTED, _Posters.Kind.FESTIVAL, _Posters.Kind.NOTICE]:
		for i in POSTERS_PER_KIND:
			images.append(_Posters.make(rng, kind as _Posters.Kind, van_name))
			families.append(Family.POSTER)
			kinds.append(kind)
			pixel_m.append(_Posters.PIXEL_M)

	# Shelf-pack: tallest first, left to right, a new shelf when the row is full.
	var order: Array[int] = []
	for i in images.size():
		var size := images[i].get_size()
		if size.x > ATLAS_W - 2 * PAD:
			push_warning("street art: image %d is %dx%d, too wide for the atlas" % [
				i, size.x, size.y])
			continue
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ha := images[a].get_height()
		var hb := images[b].get_height()
		return a < b if ha == hb else ha > hb)
	var spots: Dictionary = {}
	var x := PAD
	var y := PAD
	var shelf_h := 0
	for i in order:
		var size := images[i].get_size()
		if x + size.x > ATLAS_W - PAD and shelf_h > 0:
			y += shelf_h + PAD
			x = PAD
			shelf_h = 0
		spots[i] = Vector2i(x, y)
		x += size.x + PAD
		shelf_h = maxi(shelf_h, size.y)
	var atlas_h := ceili(float(y + shelf_h + PAD) / 4.0) * 4

	_atlas = Image.create(ATLAS_W, atlas_h, false, Image.FORMAT_RGBA8)
	_atlas.fill(Color(0.0, 0.0, 0.0, 0.0))
	var atlas_size := Vector2(ATLAS_W, atlas_h)
	_entries.clear()
	for i in order:
		var img := images[i]
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		var pos: Vector2i = spots[i]
		_atlas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), pos)
		_entries.append({
			&"family": families[i],
			&"kind": kinds[i],
			&"uv": Rect2(Vector2(pos) / atlas_size, Vector2(img.get_size()) / atlas_size),
			&"size_m": Vector2(img.get_size()) * pixel_m[i],
		})
	_atlas.generate_mipmaps()

	# Lit, not unshaded: posters and paint are surfaces in the dark world and only
	# show under lamps.
	_material = StandardMaterial3D.new()
	_material.albedo_texture = ImageTexture.create_from_image(_atlas)
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_material.alpha_scissor_threshold = 0.5
	_material.roughness = 0.9
	_material.metallic = 0.0
	_material.metallic_specular = 0.3
	_material.cull_mode = BaseMaterial3D.CULL_BACK
	_material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_seed = run_seed
	_build_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	PerfStats.end(&"street_art", perf_t)


## Entries of one family; call ensure() first.
static func entries(family: Family) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _entries:
		if e[&"family"] == family:
			out.append(e)
	return out


static func material() -> StandardMaterial3D:
	return _material


## The packed atlas image, for the debug sheet.
static func atlas() -> Image:
	return _atlas


static func stats() -> String:
	var size := _atlas.get_size() if _atlas != null else Vector2i.ZERO
	return "street art: seed %d, %d graffiti, %d posters, atlas %dx%d, built in %.1f ms" % [
		_seed, entries(Family.GRAFFITI).size(), entries(Family.POSTER).size(),
		size.x, size.y, _build_ms]


## The van's painted name for this run; mirrors VanMarkings.rebuild_look's first draw.
static func van_name_for(run_seed: int) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash([VanLook.seed_for_run(run_seed), &"markings"])
	return VanMarkings.NAMES[r.randi_range(0, VanMarkings.NAMES.size() - 1)]
