class_name ExplosionFx
extends Sprite3D

## Billboard disc that matches the 3D blast radius, then fades.

const TEX_SIZE := 128
const FADE_SECONDS := 0.32

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
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	transparent = true
	shaded = false
	double_sided = true
	no_depth_test = false
	render_priority = 4
	texture = _ensure_texture()
	pixel_size = (2.0 * radius) / float(TEX_SIZE)
	modulate = Color(1.0, 0.72, 0.28, 0.95)
	scale = Vector3(0.28, 0.28, 0.28)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE, FADE_SECONDS).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS).set_delay(0.06)
	tween.chain().tween_callback(queue_free)


static func _ensure_texture() -> Texture2D:
	if _texture:
		return _texture
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.22, 0.62, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.95, 0.7, 1.0),
		Color(1.0, 0.55, 0.18, 0.9),
		Color(0.95, 0.22, 0.05, 0.4),
		Color(0.4, 0.05, 0.0, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = TEX_SIZE
	tex.height = TEX_SIZE
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_texture = tex
	return _texture
