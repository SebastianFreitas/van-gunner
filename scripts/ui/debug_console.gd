class_name DebugConsole
extends Control

## In-game debug terminal. H to open, Esc to close.

signal opened
signal closed

const MAX_LINES := 200
const PROMPT := "> "

@onready var output: RichTextLabel = %Output
@onready var input_line: LineEdit = %InputLine

var _lines: PackedStringArray = PackedStringArray()
var _history: PackedStringArray = PackedStringArray()
var _history_index := -1


func _ready() -> void:
	if not DebugConfig.ENABLED:
		queue_free()
		return
	_apply_closed_state()
	set_process(true)
	_log("Debug console ready. H to open, Esc to close. Try: help, chill")


func _process(_delta: float) -> void:
	if not visible and Input.is_action_just_pressed(&"debug_console"):
		open()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not input_line.has_focus() and event is InputEventKey and event.pressed and not event.echo:
		input_line.grab_focus()
	if event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP:
			_recall_history(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			_recall_history(1)
			get_viewport().set_input_as_handled()


func open() -> void:
	if visible:
		return
	show()
	mouse_filter = MOUSE_FILTER_STOP
	input_line.text = ""
	input_line.grab_focus()
	opened.emit()


func close() -> void:
	if not visible:
		return
	_apply_closed_state()
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _apply_closed_state() -> void:
	hide()
	mouse_filter = MOUSE_FILTER_IGNORE
	input_line.release_focus()


func _on_input_submitted(text: String) -> void:
	var line := text.strip_edges()
	input_line.clear()
	if line.is_empty():
		input_line.grab_focus()
		return
	_log(PROMPT + line)
	_push_history(line)
	var result := DebugCommands.run(line)
	if not result.is_empty():
		_log(result)
	input_line.grab_focus()


func _log(text: String) -> void:
	_lines.append(text)
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	output.text = "\n".join(_lines)
	if output.get_line_count() > 0:
		output.scroll_to_line(output.get_line_count() - 1)


func _push_history(line: String) -> void:
	if _history.is_empty() or _history[_history.size() - 1] != line:
		_history.append(line)
	_history_index = _history.size()


func _recall_history(direction: int) -> void:
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + direction, 0, _history.size())
	if _history_index == _history.size():
		input_line.text = ""
	else:
		input_line.text = _history[_history_index]
		input_line.caret_column = input_line.text.length()
