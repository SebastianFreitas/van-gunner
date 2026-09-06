class_name ExplosionFx
extends Sprite3D

## Billboard pixel burst sized to the 3D blast radius, then fades.

const TEX_SIZE := 16
const FADE_SECONDS := 0.28

static var _texture: Texture2D


static func spawn(center: Vector3, radius: float, host: Node = null) -> void:
	if radius <= 0.05:
		return
	var tree := Engine.get_main_loop() as SceneTree
	var parent: Node = host
	if parent == null and tree:
		var travel := tree.get_first_node_in_group(&"travel_controller") as TravelController
		if travel and travel.van_rig:
			parent = travel.van_rig
		else:
			parent = tree.current_scene if tree.current_scene else tree.root
	if parent == null:
		return
	var fx := ExplosionFx.new()
	parent.add_child(fx)
	fx.global_position = center
	fx._play(radius)


func _play(radius: float) -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	transparent = true
	shaded = false
	double_sided = true
	no_depth_test = false
	render_priority = 4
	texture = _ensure_texture()
	pixel_size = (2.0 * radius) / float(TEX_SIZE)
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	scale = Vector3(0.35, 0.35, 0.35)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE, FADE_SECONDS).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS).set_delay(0.05)
	tween.chain().tween_callback(queue_free)


static func _ensure_texture() -> Texture2D:
	if _texture:
		return _texture
	var image := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var mid := (TEX_SIZE - 1) * 0.5
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var dx := absf(float(x) - mid)
			var dy := absf(float(y) - mid)
			var chebyshev := maxf(dx, dy)
			var color := Color(0, 0, 0, 0)
			if chebyshev <= 1.5:
				color = Color(1.0, 1.0, 0.85, 1.0)
			elif chebyshev <= 3.5:
				color = Color(1.0, 0.92, 0.18, 1.0)
			elif chebyshev <= 5.5:
				color = Color(1.0, 0.72, 0.08, 1.0)
			elif chebyshev <= 7.0:
				color = Color(0.95, 0.42, 0.08, 1.0)
			image.set_pixel(x, y, color)
	_texture = ImageTexture.create_from_image(image)
	return _texture
