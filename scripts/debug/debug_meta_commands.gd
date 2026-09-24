extends RefCounted

## Debug console commands: meta. Registered in DebugCommands._register_commands.

const _SoundCue := preload("res://scripts/audio/sound_cue.gd")

var host: Node  # the DebugCommands autoload (tree access and shared finders)


func _init(owner: Node) -> void:
	host = owner


func cmd_class(args: Array) -> String:
	var current := ClassCatalog.load_or_basic(GameSession.class_id)
	var current_name := current.display_name if current else String(GameSession.class_id)
	if args.is_empty():
		return "Class: %s  (usage: class <id>, try list classes)" % current_name
	var class_id := StringName(str(args[0]).to_lower())
	var def := ClassCatalog.load_by_id(class_id)
	if def == null:
		return "Unknown class: %s  (try list classes)" % class_id
	GameSession.equip_class(class_id)
	return "Equipped %s." % def.display_name


func cmd_parts(args: Array) -> String:
	var amount: int = int(args[0]) if not args.is_empty() else 1
	if amount <= 0:
		return "Usage: parts [n]  (n > 0)"
	MetaProgression.add_rare_parts(amount)
	return "Added %d Rare Parts (total %d)." % [amount, MetaProgression.rare_parts]


func cmd_tree_reset(_args: Array) -> String:
	MetaProgression.debug_reset_tree()
	return "Schematic reset to origin. Speed level %d. Rare Parts %d." % [
		MetaProgression.van_speed_level,
		MetaProgression.rare_parts,
	]


func cmd_sound(args: Array) -> String:
	if args.is_empty():
		return "Usage: sound <cue_id>  (try list sounds)"
	var cue_id := StringName(str(args[0]))
	if AudioDirector.bank == null or not AudioDirector.bank.has_cue(cue_id):
		return "Unknown cue: %s  (try list sounds)" % cue_id
	var cue := AudioDirector.bank.get_cue(cue_id) as _SoundCue
	if cue == null or cue.stream == null:
		return "Cue %s has no stream yet — drop a .wav / .ogg on the SoundCue." % cue_id
	# Always the non-positional path so you can hear it from the console.
	AudioDirector.play(cue_id)
	return "Playing %s." % cue_id
