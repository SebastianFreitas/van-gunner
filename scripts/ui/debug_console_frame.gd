extends RefCounted

## Drag (header) and resize (corner grip) of the debug console panel, clamped to the viewport.

const MIN_SIZE := Vector2(320.0, 160.0)
const GRIP_SIZE := 14.0

var _console: DebugConsole
var _panel: PanelContainer
var _grip: ColorRect
## Offsets (left, top, right, bottom) the scene was authored with, for the double-click reset.
var _default_offsets := Vector4.ZERO
var _dragging := false
var _resizing := false


func _init(console: DebugConsole, saved: Rect2) -> void:
	_console = console
	_panel = console.get_node("Panel") as PanelContainer
	_grip = console.get_node("ResizeGrip") as ColorRect
	_default_offsets = _offsets()
	var header := console.get_node("Panel/Layout/Header") as Label
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_header_input)
	_grip.mouse_filter = Control.MOUSE_FILTER_STOP
	_grip.mouse_default_cursor_shape = Control.CURSOR_BDIAGSIZE
	_grip.gui_input.connect(_on_grip_input)
	console.resized.connect(clamp_to_viewport)
	if saved.has_area():
		_set_offsets(Vector4(saved.position.x, saved.position.y, saved.end.x, saved.end.y))
	clamp_to_viewport()


## Keeps the panel fully inside the viewport and parks the grip on its top-right corner.
func clamp_to_viewport() -> void:
	var vp := _console.get_viewport_rect().size
	var o := _offsets()
	var w := clampf(o.z - o.x, MIN_SIZE.x, maxf(MIN_SIZE.x, vp.x))
	var h := clampf(o.w - o.y, MIN_SIZE.y, maxf(MIN_SIZE.y, vp.y))
	var left := clampf(o.x, 0.0, maxf(0.0, vp.x - w))
	var top_abs := clampf(vp.y + o.y, 0.0, maxf(0.0, vp.y - h))
	var top := top_abs - vp.y
	_set_offsets(Vector4(left, top, left + w, top + h))
	_grip.position = Vector2(left + w - GRIP_SIZE, top_abs)


func _offsets() -> Vector4:
	return Vector4(_panel.offset_left, _panel.offset_top, _panel.offset_right, _panel.offset_bottom)


func _set_offsets(o: Vector4) -> void:
	_panel.offset_left = o.x
	_panel.offset_top = o.y
	_panel.offset_right = o.z
	_panel.offset_bottom = o.w


func _finish() -> void:
	_dragging = false
	_resizing = false
	clamp_to_viewport()
	var o := _offsets()
	_console.call(&"_save_rect", Rect2(o.x, o.y, o.z - o.x, o.w - o.y))
	_console.call(&"_focus_input")


func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.double_click:
			_dragging = false
			_set_offsets(_default_offsets)
			clamp_to_viewport()
			_console.call(&"_save_rect", Rect2())
			_console.call(&"_focus_input")
		elif event.pressed:
			_dragging = true
		elif _dragging:
			_finish()
		_panel.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var o := _offsets()
		var d: Vector2 = event.relative
		_set_offsets(Vector4(o.x + d.x, o.y + d.y, o.z + d.x, o.w + d.y))
		clamp_to_viewport()
		_panel.accept_event()


func _on_grip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_resizing = true
		elif _resizing:
			_finish()
		_grip.accept_event()
	elif event is InputEventMouseMotion and _resizing:
		var vp := _console.get_viewport_rect().size
		var o := _offsets()
		var d: Vector2 = event.relative
		o.y = clampf(o.y + d.y, -vp.y, o.w - MIN_SIZE.y)
		o.z = clampf(o.z + d.x, o.x + MIN_SIZE.x, vp.x)
		_set_offsets(o)
		clamp_to_viewport()
		_grip.accept_event()
