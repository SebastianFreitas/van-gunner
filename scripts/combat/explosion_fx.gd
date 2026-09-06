class_name ExplosionFx
extends Node3D

## Pixel-art billboard blast. The ring's outer edge is the same sphere
## DamageResolver overlaps: pixel_size * CIRCLE_R_PX = radius.

const SYSTEM_NAME := &"ExplosionFxSystem"
const POOL_SIZE := 16
const TEX_SIZE := 48
## Pixels from texture center to the range ring's outer edge.
const CIRCLE_R_PX := 23.0
const FRAME_COUNT := 6
const FRAME_FPS := 16.0

const C_WHITE := Color(1.0, 0.97, 0.82, 1.0)
const C_YELLOW := Color(1.0, 0.86, 0.22, 1.0)
const C_GOLD := Color(1.0, 0.62, 0.08, 1.0)
const C_ORANGE := Color(1.0, 0.38, 0.05, 1.0)
const C_RED := Color(0.86, 0.14, 0.04, 1.0)
const C_DARK := Color(0.22, 0.05, 0.03, 1.0)
const C_SMOKE := Color(0.14, 0.07, 0.05, 1.0)
const C_RING := Color(1.0, 0.93, 0.38, 1.0)

static var _fire_frames: SpriteFrames
static var _range_frames: SpriteFrames

var _bursts: Array[Node3D] = []
var _next := 0


static func spawn(center: Vector3, radius: float, host: Node = null) -> void:
	if radius <= 0.05:
		return
	var parent := _resolve_parent(host)
	if parent == null:
		return
	var sys := parent.get_node_or_null(NodePath(String(SYSTEM_NAME))) as ExplosionFx
	if sys == null:
		sys = ExplosionFx.new()
		sys.name = String(SYSTEM_NAME)
		parent.add_child(sys)
		sys._build_pool()
	sys._burst(center, radius)


static func _resolve_parent(host: Node) -> Node:
	if host:
		return host
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var travel := tree.get_first_node_in_group(&"travel_controller") as TravelController
	if travel and travel.van_rig:
		return travel.van_rig
	if tree.current_scene:
		return tree.current_scene
	return tree.root


func _build_pool() -> void:
	_ensure_frames()
	for i in POOL_SIZE:
		var burst := Node3D.new()
		burst.name = "Burst%d" % i
		burst.visible = false
		var range_spr := _make_sprite(&"Range", _range_frames, &"ring", 3)
		var fire_spr := _make_sprite(&"Fire", _fire_frames, &"blast", 4)
		burst.add_child(range_spr)
		burst.add_child(fire_spr)
		fire_spr.animation_finished.connect(_on_burst_finished.bind(burst))
		add_child(burst)
		_bursts.append(burst)


func _make_sprite(
	node_name: StringName, frames: SpriteFrames, anim: StringName, prio: int
) -> AnimatedSprite3D:
	var spr := AnimatedSprite3D.new()
	spr.name = String(node_name)
	spr.sprite_frames = frames
	spr.animation = anim
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.transparent = true
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.shaded = false
	spr.double_sided = true
	spr.centered = true
	spr.render_priority = prio
	return spr


func _burst(center: Vector3, radius: float) -> void:
	var burst := _bursts[_next]
	_next = (_next + 1) % _bursts.size()
	var px := radius / CIRCLE_R_PX
	var range_spr := burst.get_node("Range") as AnimatedSprite3D
	var fire_spr := burst.get_node("Fire") as AnimatedSprite3D
	range_spr.pixel_size = px
	fire_spr.pixel_size = px
	burst.global_position = center
	burst.visible = true
	range_spr.stop()
	fire_spr.stop()
	range_spr.frame = 0
	fire_spr.frame = 0
	range_spr.play(&"ring")
	fire_spr.play(&"blast")


func _on_burst_finished(burst: Node3D) -> void:
	burst.visible = false


static func _ensure_frames() -> void:
	if _fire_frames and _range_frames:
		return
	_fire_frames = SpriteFrames.new()
	_fire_frames.add_animation(&"blast")
	_fire_frames.set_animation_speed(&"blast", FRAME_FPS)
	_fire_frames.set_animation_loop(&"blast", false)
	_range_frames = SpriteFrames.new()
	_range_frames.add_animation(&"ring")
	_range_frames.set_animation_speed(&"ring", FRAME_FPS)
	_range_frames.set_animation_loop(&"ring", false)
	for i in FRAME_COUNT:
		_fire_frames.add_frame(&"blast", _make_fire_texture(i))
		_range_frames.add_frame(&"ring", _make_range_texture(i))


static func _make_range_texture(frame: int) -> ImageTexture:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var inner := 0.0
	var fill_col := C_WHITE
	match frame:
		0:
			inner = 0.0
			fill_col = C_WHITE
		1:
			inner = 0.0
			fill_col = C_YELLOW
		2:
			inner = CIRCLE_R_PX * 0.42
			fill_col = C_GOLD
		3:
			inner = CIRCLE_R_PX * 0.68
			fill_col = C_ORANGE
		4:
			inner = CIRCLE_R_PX * 0.82
			fill_col = C_RED
		_:
			inner = CIRCLE_R_PX * 0.88
			fill_col = C_DARK
	var dither := 1.0 if frame < 5 else 0.45
	_stamp_ring(img, inner, CIRCLE_R_PX, fill_col, dither)
	## Bright lip on the exact damage radius so the circle stays readable.
	if frame >= 1:
		_stamp_ring(img, CIRCLE_R_PX - 1.35, CIRCLE_R_PX, C_RING, dither)
	return ImageTexture.create_from_image(img)


static func _make_fire_texture(frame: int) -> ImageTexture:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := (TEX_SIZE - 1) * 0.5
	var cy := cx
	var core_r := 5.0 + float(frame) * 2.4
	if frame >= 4:
		core_r = 16.0 - float(frame - 4) * 2.0
	_paint_blob(img, cx, cy, core_r, 3 + frame)
	var sats := mini(frame + 1, 4)
	for i in sats:
		var ang := TAU * (0.12 + float(i) / float(maxi(sats, 1))) + float(frame) * 0.35
		var dist := 3.0 + float(frame) * 2.15
		var br := 3.2 + float(frame) * 1.15
		if frame >= 4:
			br *= 0.78
		_paint_blob(img, cx + cos(ang) * dist, cy + sin(ang) * dist, br, 11 + i * 7 + frame)
	_outline(img)
	if frame >= 4:
		_dither(img, 0.7 if frame == 4 else 0.38)
	if frame == 5:
		_recolor_remaining(img, C_SMOKE)
	return ImageTexture.create_from_image(img)


static func _stamp_ring(
	img: Image, r_inner: float, r_outer: float, color: Color, density: float
) -> void:
	var cx := (TEX_SIZE - 1) * 0.5
	var cy := cx
	var inner2 := r_inner * r_inner
	var outer2 := r_outer * r_outer
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			if density < 1.0 and not _bayer_keep(x, y, density):
				continue
			var dx := (float(x) + 0.5) - cx
			var dy := (float(y) + 0.5) - cy
			var d2 := dx * dx + dy * dy
			if d2 <= outer2 and d2 >= inner2:
				img.set_pixel(x, y, color)


static func _paint_blob(img: Image, cx: float, cy: float, radius: float, seed: int) -> void:
	if radius < 1.0:
		return
	var x0 := maxi(0, int(cx - radius - 2.0))
	var y0 := maxi(0, int(cy - radius - 2.0))
	var x1 := mini(TEX_SIZE, int(cx + radius + 3.0))
	var y1 := mini(TEX_SIZE, int(cy + radius + 3.0))
	var seed_f := float(seed)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dx := (float(x) + 0.5) - cx
			var dy := (float(y) + 0.5) - cy
			var ang := atan2(dy, dx)
			var jag := (
				1.0
				+ 0.13 * sin(ang * 5.0 + seed_f)
				+ 0.07 * sin(ang * 9.0 - seed_f * 0.6)
			)
			var d := sqrt(dx * dx + dy * dy) / (radius * jag)
			if d > 1.0:
				continue
			## Keep the fire inside the range circle.
			var ox := (float(x) + 0.5) - (TEX_SIZE - 1) * 0.5
			var oy := (float(y) + 0.5) - (TEX_SIZE - 1) * 0.5
			if ox * ox + oy * oy > (CIRCLE_R_PX - 1.0) * (CIRCLE_R_PX - 1.0):
				continue
			var col: Color
			if d < 0.2:
				col = C_WHITE
			elif d < 0.42:
				col = C_YELLOW
			elif d < 0.62:
				col = C_GOLD
			elif d < 0.82:
				col = C_ORANGE
			else:
				col = C_RED
			var existing := img.get_pixel(x, y)
			if existing.a > 0.0 and _heat(existing) >= _heat(col):
				continue
			img.set_pixel(x, y, col)


static func _outline(img: Image) -> void:
	var marks: Array[Vector2i] = []
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			if img.get_pixel(x, y).a > 0.0:
				continue
			if _opaque_neighbor(img, x, y):
				marks.append(Vector2i(x, y))
	for p in marks:
		img.set_pixel(p.x, p.y, C_DARK)


static func _opaque_neighbor(img: Image, x: int, y: int) -> bool:
	if x > 0 and img.get_pixel(x - 1, y).a > 0.0:
		return true
	if x + 1 < TEX_SIZE and img.get_pixel(x + 1, y).a > 0.0:
		return true
	if y > 0 and img.get_pixel(x, y - 1).a > 0.0:
		return true
	if y + 1 < TEX_SIZE and img.get_pixel(x, y + 1).a > 0.0:
		return true
	return false


static func _dither(img: Image, density: float) -> void:
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			if img.get_pixel(x, y).a <= 0.0:
				continue
			if not _bayer_keep(x, y, density):
				img.set_pixel(x, y, Color(0, 0, 0, 0))


static func _recolor_remaining(img: Image, color: Color) -> void:
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			if img.get_pixel(x, y).a > 0.0:
				img.set_pixel(x, y, color)


static func _bayer_keep(x: int, y: int, density: float) -> bool:
	var bayer := (x & 1) * 2 + (y & 1) + ((x >> 1) & 1) * 8 + ((y >> 1) & 1) * 4
	return float(bayer) / 16.0 < density


static func _heat(c: Color) -> int:
	if c.g > 0.9:
		return 4
	if c.g > 0.7:
		return 3
	if c.g > 0.5:
		return 2
	if c.r > 0.7:
		return 1
	return 0
