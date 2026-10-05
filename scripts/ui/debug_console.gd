class_name DebugConsole
extends Control

## In-game debug terminal. H to open, Esc to close.

signal opened
signal closed

const MAX_LINES := 200
const MAX_HISTORY := 50
const PROMPT := "> "
const Frame := preload("res://scripts/ui/debug_console_frame.gd")

## Panel offsets (left, top, width, height) kept across scene reloads; empty = tscn default.
static var _saved_rect := Rect2()

@onready var output: RichTextLabel = %Output
@onready var input_line: LineEdit = %InputLine
@onready var suggestion: Label = %Suggestion

var _lines: PackedStringArray = PackedStringArray()
var _history: PackedStringArray = PackedStringArray()
var _history_index := -1
var _completion_index := -1
var _completion_key := ""
var _keep_input_focus := false
var _frame: RefCounted


func _ready() -> void:
	if not DebugConfig.ENABLED:
		queue_free()
		return
	add_to_group(&"debug_console")
	_frame = Frame.new(self, _saved_rect)
	_apply_closed_state()
	set_process(true)
	input_line.keep_editing_on_text_submit = true
	input_line.select_all_on_focus = false
	input_line.focus_mode = Control.FOCUS_ALL
	input_line.text_changed.connect(_on_input_text_changed)
	input_line.focus_exited.connect(_on_input_focus_exited)
	output.focus_mode = Control.FOCUS_NONE
	_log("Debug console ready. H to open, Esc to close. Try: help, list boons, give <tab>")


## Game code polls this to ignore movement and action keys while the player types.
func is_typing() -> bool:
	return is_visible_in_tree()


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
	if event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_PAGEUP or event.keycode == KEY_PAGEDOWN:
			var bar := output.get_v_scroll_bar()
			var direction := -1.0 if event.keycode == KEY_PAGEUP else 1.0
			bar.value += direction * bar.page
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_L and event.ctrl_pressed and not event.echo:
			_lines = PackedStringArray()
			output.text = ""
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if not input_line.has_focus():
			_steal_key_into_input(event as InputEventKey)
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
		_focus_input()
		return
	show()
	_frame.clamp_to_viewport()
	mouse_filter = MOUSE_FILTER_STOP
	input_line.text = ""
	_keep_input_focus = true
	_update_suggestion()
	## Mouse must be free before LineEdit will actually edit.
	opened.emit()
	_focus_input()
	_focus_input.call_deferred()


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


func _save_rect(rect: Rect2) -> void:
	_saved_rect = rect


func _apply_closed_state() -> void:
	_keep_input_focus = false
	hide()
	mouse_filter = MOUSE_FILTER_IGNORE
	if input_line:
		input_line.release_focus()


func _on_input_submitted(text: String) -> void:
	var line := text.strip_edges()
	input_line.clear()
	if not line.is_empty():
		_log(PROMPT + line)
		_push_history(line)
		var result := DebugCommands.run(line)
		if not result.is_empty():
			_log(result)
	_update_suggestion()
	_focus_input()
	_focus_input.call_deferred()


func _on_input_focus_exited() -> void:
	if not _keep_input_focus or not visible:
		return
	await get_tree().process_frame
	if _keep_input_focus and visible and not input_line.has_focus():
		_focus_input()


func _focus_input() -> void:
	if not _keep_input_focus or not visible or input_line == null:
		return
	if not input_line.is_inside_tree():
		return
	input_line.grab_focus()
	input_line.edit()
	input_line.caret_column = input_line.text.length()


func _steal_key_into_input(event: InputEventKey) -> void:
	_focus_input()
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_TAB, KEY_UP, KEY_DOWN]:
		return
	if event.unicode < 32:
		return
	input_line.insert_text_at_caret(String.chr(event.unicode))
	get_viewport().set_input_as_handled()


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
		if _history.size() > MAX_HISTORY:
			_history.remove_at(0)
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
		var fill: String = ctx.get("fill", "")
		if not fill.is_empty():
			input_line.text = text.substr(0, caret) + fill + text.substr(caret)
			input_line.caret_column = caret + fill.length()
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
		var usage: String = ctx.get("hint", "")
		if not usage.is_empty():
			suggestion.text = usage
			return
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
