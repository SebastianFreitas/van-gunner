extends RefCounted
## Console Tab completion for DebugCommands: candidates, usage hint and current-value fill.

const _DebugCatalog := preload("res://scripts/debug/debug_catalog.gd")
## What `cmd_list` in debug_catalog.gd handles.
const LIST_KINDS: Array[String] = [
	"boons", "items", "commands", "classes", "cards", "stops", "sounds", "tree",
]
const _TOGGLES: Array[String] = ["open", "close", "toggle"]

var host: Node  # the DebugCommands autoload (command table, groups, usage text)


func _init(owner: Node) -> void:
	host = owner


## Keys: token_start, partial, matches, add_space, hint (usage line), fill (Tab text).
func context(text: String, caret_col: int) -> Dictionary:
	var safe_caret := clampi(caret_col, 0, text.length())
	var before := text.substr(0, safe_caret)
	var token_start := before.rfind(" ") + 1
	var partial := before.substr(token_start)
	var parts: PackedStringArray = PackedStringArray()
	for p in before.strip_edges(false).split(" ", false):
		parts.append(p.to_lower())
	var after_space := before.ends_with(" ")
	var arg_index := parts.size() if after_space else parts.size() - 1
	var matches: Array[String] = []
	if arg_index <= 0:
		matches = _filter_prefix(host._command_names(), partial)
	else:
		matches = _filter_prefix(_arg_candidates(parts[0], arg_index, parts), partial)
	return {
		"token_start": token_start,
		"partial": partial,
		"matches": matches,
		"add_space": _should_add_space_after(parts, after_space),
		"hint": _hint(parts, arg_index),
		"fill": _fill(parts, after_space, safe_caret == text.length()),
	}


## Candidates for token `arg_index` (1 = first argument) of `cmd`; `prev_args` are the lowercase
## tokens before the one being completed, command first.
func _arg_candidates(
		cmd: String, arg_index: int, prev_args: PackedStringArray) -> PackedStringArray:
	match cmd:
		"give", "spawn":
			return PackedStringArray(ItemRegistry.list_ids())
		"stop":
			if arg_index >= 2 and prev_args.size() >= 2 \
					and SideStopRegistry.arrival_from_label(prev_args[1]) >= 0:
				return PackedStringArray(_DebugCatalog.stop_id_strings())
			return PackedStringArray(_DebugCatalog.stop_force_tokens())
		"arms":
			if arg_index == 1:
				return host._arms.sub_commands()
			if arg_index == 2 and prev_args.size() >= 2 and prev_args[1] == "curl":
				return host._arms.curl_fingers()
			if arg_index == 2 and prev_args.size() >= 2 and prev_args[1] == "ridx":
				return PackedStringArray(["1", "2", "3", "shift", "reset"])
	if arg_index != 1:
		return PackedStringArray()
	match cmd:
		"summon":
			return PackedStringArray(["enemy", "loper"])
		"reardoor", "sidedoor":
			return PackedStringArray(_TOGGLES)
		"van":
			return PackedStringArray(["seed", "reroll"])
		"list":
			return PackedStringArray(LIST_KINDS)
		"sound":
			return PackedStringArray(_DebugCatalog.sound_id_strings())
		"card":
			return PackedStringArray(_DebugCatalog.card_id_strings())
		"class":
			return PackedStringArray(_DebugCatalog.class_id_strings())
		"facade":
			return host._facade.sub_commands()
	return PackedStringArray()


## The usage line to show for a known command with arguments, or "".
func _hint(parts: PackedStringArray, arg_index: int) -> String:
	if parts.is_empty() or arg_index < 1 or not host._commands.has(parts[0]):
		return ""
	if parts[0] != "arms":
		return host.usage_line(parts[0])
	if parts.size() < 2 or not host._arms.sub_commands().has(parts[1]):
		return ""
	if parts[1] == "curl" and parts.size() >= 3 and host._arms.curl_fingers().has(parts[2]):
		return "arms curl %s %s" % [parts[2], host._arms.current_args_for("curl", parts[2])]
	return host._arms.hint(parts[1])


## The current values to append on Tab: `arms <sub> ` or `arms curl <finger> ` with nothing after.
func _fill(parts: PackedStringArray, after_space: bool, at_end: bool) -> String:
	if not at_end or not after_space or parts.is_empty() or parts[0] != "arms":
		return ""
	if parts.size() == 3 and parts[1] == "ridx":
		return host._arms.current_args_for("ridx", parts[2])
	if parts.size() == 2 and parts[1] != "curl":
		return host._arms.current_args_for(parts[1], "")
	if parts.size() == 3 and parts[1] == "curl":
		return host._arms.current_args_for("curl", parts[2])
	return ""


func _filter_prefix(options: Array, partial: String) -> Array[String]:
	var needle := partial.to_lower()
	var matches: Array[String] = []
	for option in options:
		var value := String(option)
		if needle.is_empty() or value.to_lower().begins_with(needle):
			matches.append(value)
	return matches


func _should_add_space_after(parts: PackedStringArray, after_space: bool) -> bool:
	if parts.size() <= 1:
		return true
	if parts[0] == "list" and parts.size() == 2:
		return true
	if parts[0] == "arms":
		# A finished sub gets its space so the hint shows at once; so does a curl finger.
		if parts.size() == 2:
			return not after_space or parts[1] == "curl"
		return parts.size() == 3 and parts[1] == "curl" and not after_space
	return false
