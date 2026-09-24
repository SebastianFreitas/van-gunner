extends RefCounted

## Debug console command catalog: the `list` command plus the formatting and id-listing
## helpers shared by other command groups and by DebugCommands.get_completion_context.

const _SoundCue := preload("res://scripts/audio/sound_cue.gd")
const _SkillTreeRegistry := preload("res://scripts/core/skill_tree_registry.gd")

var host: Node  # the DebugCommands autoload (tree access and shared finders)


func _init(owner: Node) -> void:
	host = owner


func cmd_list(args: Array) -> String:
	if args.is_empty():
		return "Usage: list boons|items|commands|classes|cards|stops|sounds|tree [filter]"
	var kind: String = str(args[0]).to_lower()
	var filter_text := " ".join(args.slice(1))
	match kind:
		"commands":
			var lines: PackedStringArray = PackedStringArray()
			lines.append(host._cmd_help([]))
			return "\n".join(lines)
		"boons":
			return format_item_list(
				ItemRegistry.list_entries(ItemDefinition.ItemKind.BOON, filter_text),
				"boons",
				filter_text
			)
		"items":
			return format_item_list(ItemRegistry.list_entries(-1, filter_text), "items", filter_text)
		"classes":
			return format_class_list(filter_text)
		"cards":
			return format_card_list(filter_text)
		"stops":
			return format_stop_list(filter_text)
		"sounds":
			return format_sound_list(filter_text)
		"tree":
			return format_tree_list(filter_text)
		_:
			return (
				"Unknown list target: %s  (try boons, items, commands, classes, cards, stops, sounds, tree)"
				% kind
			)


static func format_card_list(filter_text: String) -> String:
	var needle := filter_text.strip_edges().to_lower()
	var lines: PackedStringArray = PackedStringArray()
	var count := 0
	for card_id in ActCardRegistry.list_ids():
		var card := ActCardRegistry.load_by_id(card_id)
		if card == null:
			continue
		var hay := ("%s %s %s" % [card.id, card.display_name, card.description]).to_lower()
		if not needle.is_empty() and not hay.contains(needle):
			continue
		lines.append(
			"  %s  —  [%s] %s — %s"
			% [card.id, card.polarity_label(), card.display_name, card.description.strip_edges()]
		)
		count += 1
	if count == 0:
		if filter_text.is_empty():
			return "No street cards found."
		return "No street cards match '%s'." % filter_text
	var header := "%d street cards" % count
	if not filter_text.is_empty():
		header += " matching '%s'" % filter_text
	return header + ":\n" + "\n".join(lines)


static func format_stop_list(filter_text: String) -> String:
	var needle := filter_text.strip_edges().to_lower()
	var lines: PackedStringArray = PackedStringArray()
	var count := 0
	for stop_id in SideStopRegistry.list_ids():
		var stop := SideStopRegistry.load_by_id(stop_id)
		if stop == null:
			continue
		var hay := ("%s %s %s" % [stop.id, stop.display_name, stop.short_label]).to_lower()
		if not needle.is_empty() and not hay.contains(needle):
			continue
		lines.append(
			"  %s  —  %s [%s, w=%.2f]"
			% [stop.id, stop.fork_label(), stop.arrival_label(), stop.spawn_weight]
		)
		count += 1
	if count == 0:
		if filter_text.is_empty():
			return "No side stops found."
		return "No side stops match '%s'." % filter_text
	var header := "%d side stops" % count
	if not filter_text.is_empty():
		header += " matching '%s'" % filter_text
	return header + ":\n" + "\n".join(lines)


static func stop_id_strings() -> Array[String]:
	var out: Array[String] = []
	for stop_id in SideStopRegistry.list_ids():
		out.append(String(stop_id))
	return out


static func stop_force_tokens() -> Array[String]:
	var out: Array[String] = ["rear_park", "elevator"]
	out.append_array(stop_id_strings())
	return out


static func card_id_strings() -> Array[String]:
	var out: Array[String] = []
	for card_id in ActCardRegistry.list_ids():
		out.append(String(card_id))
	return out


static func format_class_list(filter_text: String) -> String:
	var needle := filter_text.strip_edges().to_lower()
	var lines: PackedStringArray = PackedStringArray()
	for def in ClassCatalog.list_all():
		var id := String(def.id)
		if not needle.is_empty() and not id.to_lower().contains(needle):
			continue
		var tag := "  (equipped)" if def.id == GameSession.class_id else ""
		lines.append("  %s  —  %s%s" % [id, def.display_name, tag])
	if lines.is_empty():
		if filter_text.is_empty():
			return "No classes found."
		return "No classes match '%s'." % filter_text
	var header := "%d classes" % lines.size()
	if not filter_text.is_empty():
		header += " matching '%s'" % filter_text
	return header + ":\n" + "\n".join(lines)


static func class_id_strings() -> Array[String]:
	var out: Array[String] = []
	for class_id in ClassCatalog.list_ids():
		out.append(String(class_id))
	return out


static func format_sound_list(filter_text: String) -> String:
	var needle := filter_text.strip_edges().to_lower()
	var lines: PackedStringArray = PackedStringArray()
	var count := 0
	for cue_id in sound_id_strings():
		if not needle.is_empty() and not cue_id.to_lower().contains(needle):
			continue
		var cue := AudioDirector.bank.get_cue(StringName(cue_id)) as _SoundCue
		var stream_note := "ready" if cue and cue.stream else "no stream"
		var where := "3D" if cue and cue.positional else "2D"
		var interval: float = cue.min_interval if cue else 0.0
		lines.append("  %s  —  %s %s  min=%.3f" % [cue_id, where, stream_note, interval])
		count += 1
	if count == 0:
		if filter_text.is_empty():
			return "No sounds found."
		return "No sounds match '%s'." % filter_text
	var header := "%d sounds" % count
	if not filter_text.is_empty():
		header += " matching '%s'" % filter_text
	return header + ":\n" + "\n".join(lines)


static func format_tree_list(filter_text: String) -> String:
	var needle := filter_text.strip_edges().to_lower()
	var lines: PackedStringArray = PackedStringArray()
	var count := 0
	for node in _SkillTreeRegistry.list_definitions():
		var hay := ("%s %s %s" % [node.id, node.display_name, node.description]).to_lower()
		if not needle.is_empty() and not hay.contains(needle):
			continue
		var mark := "locked"
		if MetaProgression.is_allocated(node.id):
			mark = "live"
		elif MetaProgression.is_pending(node.id):
			mark = "queued"
		elif node.is_stub():
			mark = "stub"
		lines.append("  %s  —  [%s] %s — %s" % [
			node.id,
			mark,
			node.display_name,
			node.description.strip_edges(),
		])
		count += 1
	if count == 0:
		if filter_text.is_empty():
			return "No skill-tree nodes found."
		return "No skill-tree nodes match '%s'." % filter_text
	var header := "%d tree nodes  ·  %d live+queued / %d cap  ·  %d parts" % [
		count,
		MetaProgression.allocation_count(),
		_SkillTreeRegistry.MAX_ALLOCATED,
		MetaProgression.rare_parts,
	]
	if not filter_text.is_empty():
		header += " matching '%s'" % filter_text
	return header + ":\n" + "\n".join(lines)


static func sound_id_strings() -> Array[String]:
	var out: Array[String] = []
	if AudioDirector.bank == null:
		return out
	for cue_id in AudioDirector.bank.list_ids():
		out.append(String(cue_id))
	return out


static func format_item_list(entries: Array[Dictionary], label: String, filter_text: String) -> String:
	if entries.is_empty():
		if filter_text.is_empty():
			return "No %s found." % label
		return "No %s match '%s'." % [label, filter_text]
	var lines: PackedStringArray = PackedStringArray()
	var header := "%d %s" % [entries.size(), label]
	if not filter_text.is_empty():
		header += " matching '%s'" % filter_text
	lines.append(header + ":")
	for entry in entries:
		lines.append("  %s  —  %s" % [entry.id, entry.name])
	return "\n".join(lines)
