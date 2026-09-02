class_name DebugConsole
extends Control

## In-game debug terminal. H to open, Esc to close.

signal opened
signal closed

const MAX_LINES := 200
const PROMPT := "> "

@onready var output: RichTextLabel = %Output
@onready var input_line: LineEdit = %InputLine
@onready var suggestion: Label = %Suggestion

var _lines: PackedStringArray = PackedStringArray()
var _history: PackedStringArray = PackedStringArray()
var _history_index := -1
var _completion_index := -1
var _completion_key := ""


func _ready() -> void:
	if not DebugConfig.ENABLED:
		queue_free()
		return
	_apply_closed_state()
	set_process(true)
	input_line.text_changed.connect(_on_input_text_changed)
	_log("Debug console ready. H to open, Esc to close. Try: help, list boons, give <tab>")


func _process(_delta: float) -> void:
	if not visible and Input.is_action_just_pressed(&"debug_console"):
		open()


func _unhandled_input(_event: InputEvent) -> void:
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
		if event.keycode == KEY_TAB:
			_apply_tab_completion(event.shift_pressed)
			get_viewport().set_input_as_handled()
			return
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
	_update_suggestion()
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
	_update_suggestion()


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
	_update_suggestion()


func _on_input_text_changed(_new_text: String) -> void:
	_completion_index = -1
	_completion_key = ""
	_update_suggestion()


func _apply_tab_completion(reverse: bool) -> void:
	var text := input_line.text
	var caret := input_line.caret_column
	var ctx: Dictionary = DebugCommands.get_completion_context(text, caret)
	var matches: Array = ctx.get("matches", [])
	if matches.is_empty():
		_update_suggestion()
		return

	var token_start: int = ctx.token_start
	var partial: String = ctx.partial
	var key := "%d|%s" % [token_start, partial]
	if key != _completion_key:
		_completion_key = key
		_completion_index = -1

	var completion := _next_completion(matches, partial, reverse)
	var new_text := text.substr(0, token_start) + completion
	var suffix := text.substr(caret)
	if ctx.get("add_space", false):
		new_text += " "
	input_line.text = new_text + suffix
	input_line.caret_column = new_text.length()
	_update_suggestion()


func _next_completion(matches: Array, partial: String, reverse: bool) -> String:
	if matches.size() == 1:
		return String(matches[0])

	if _completion_index < 0:
		var shared := _common_prefix(matches)
		if shared.length() > partial.length():
			return shared
		_completion_index = 0 if not reverse else matches.size() - 1
		return String(matches[_completion_index])

	if reverse:
		_completion_index = (_completion_index - 1 + matches.size()) % matches.size()
	else:
		_completion_index = (_completion_index + 1) % matches.size()
	return String(matches[_completion_index])


func _common_prefix(options: Array) -> String:
	if options.is_empty():
		return ""
	var prefix := String(options[0])
	for i in range(1, options.size()):
		var option := String(options[i])
		while not option.to_lower().begins_with(prefix.to_lower()) and prefix.length() > 0:
			prefix = prefix.substr(0, prefix.length() - 1)
	return prefix


func _update_suggestion() -> void:
	if not suggestion:
		return
	var ctx: Dictionary = DebugCommands.get_completion_context(
		input_line.text,
		input_line.caret_column
	)
	var matches: Array = ctx.get("matches", [])
	if matches.is_empty():
		suggestion.text = "Tab completes commands and item ids  ·  list boons"
		return
	var preview: PackedStringArray = PackedStringArray()
	var limit := mini(matches.size(), 6)
	for i in limit:
		preview.append(String(matches[i]))
	var extra := matches.size() - limit
	var hint := "Tab: %s" % ", ".join(preview)
	if extra > 0:
		hint += "  (+%d)" % extra
	suggestion.text = hint
