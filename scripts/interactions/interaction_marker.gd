class_name InteractionMarker
extends Sprite3D
## Flat pixel-art stencil at the centre of an Interactable: faint when idle, gold and pulsing when focused.

const GRID := 8
const IDLE_SIZE_M := 0.06
const FOCUS_SCALE := 1.4
const SNAP_SECONDS := 0.08
const PULSE_SECONDS := 1.0
const IDLE_COLOR := Color(0.93, 0.91, 0.85, 0.25)
## HUD gold #e7c45b, kept under the 1.1 glow threshold.
const FOCUS_COLOR := Color(0.906, 0.769, 0.357, 1.0)
const LAYER_VAN := 2

## One hollow diamond shared by every marker.
static var _texture: ImageTexture

var _t := 0.0
var _focused := false


func _init() -> void:
	if _texture == null:
		_texture = ImageTexture.create_from_image(_build_image())
	texture = _texture
	pixel_size = IDLE_SIZE_M / float(GRID)
	shaded = false
	double_sided = true
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	transparent = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layers = LAYER_VAN
	modulate = IDLE_COLOR


func _ready() -> void:
	# Godot switches _process on at ready for any script that defines it, which undoes an
	# _init set_process(false) and made every fresh marker pulse gold until its first unfocus.
	set_process(_focused)


static func _build_image() -> Image:
	var img := Image.create(GRID, GRID, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in range(4):
		for p: Vector2i in [
			Vector2i(3 - i, i), Vector2i(4 + i, i),
			Vector2i(3 - i, GRID - 1 - i), Vector2i(4 + i, GRID - 1 - i),
		]:
			img.set_pixelv(p, Color.WHITE)
	return img


func set_focused(on: bool) -> void:
	_focused = on
	_t = 0.0
	set_process(on)
	if not on:
		scale = Vector3.ONE
		modulate = IDLE_COLOR
		return
	_apply_focus()


func _process(delta: float) -> void:
	_t += delta
	_apply_focus()


func _apply_focus() -> void:
	var snap := minf(_t / SNAP_SECONDS, 1.0)
	scale = Vector3.ONE * lerpf(1.0, FOCUS_SCALE, snap)
	var pulse := 0.5 + 0.5 * sin(_t * TAU / PULSE_SECONDS)
	var c := FOCUS_COLOR
	c.a = lerpf(0.85, 1.0, pulse)
	modulate = c
