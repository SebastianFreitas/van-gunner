extends RefCounted

## Debug console commands: act. Registered in DebugCommands._register_commands.

var host: Node  # the DebugCommands autoload (tree access and shared finders)


func _init(owner: Node) -> void:
	host = owner


func cmd_card(args: Array) -> String:
	if args.is_empty():
		var cards := GameSession.get_active_modifier_cards()
		if cards.is_empty():
			return "No active street cards."
		var lines: PackedStringArray = PackedStringArray()
		for card in cards:
			lines.append("%s (%s) — %s" % [
				card.id,
				card.polarity_label(),
				card.description.strip_edges(),
			])
		return "active (%d):\n%s" % [cards.size(), "\n".join(lines)]
	var card_id := StringName(str(args[0]))
	var card := ActCardRegistry.load_by_id(card_id)
	if card == null:
		return "Unknown card: %s" % card_id
	ActCardCombat.clear()
	GameSession.boss_modifier_card_ids.clear()
	GameSession.active_street_card_id = card_id
	GameSession.pending_danger = card.is_danger()
	ActCardCombat.activate(card)
	return "Forced street card: %s (%s)" % [card.display_name, card.polarity_label()]


func cmd_stop(args: Array) -> String:
	if args.is_empty():
		return "Usage: stop <id> | stop <arrival> <content>  (see list stops)"
	var stop: SideStopDefinition
	if args.size() >= 2:
		var arrival := SideStopRegistry.arrival_from_label(str(args[0]))
		if arrival < 0:
			return "Unknown arrival '%s' — use rear_park or elevator." % str(args[0])
		var content_id := StringName(str(args[1]))
		stop = SideStopRegistry.compose(content_id, arrival as SideStopDefinition.Arrival)
		if stop == null:
			return "Unknown content stop: %s" % content_id
	else:
		var stop_id := StringName(str(args[0]))
		stop = SideStopRegistry.load_by_id(stop_id)
		if stop == null or stop.scene == null:
			return "Unknown stop: %s" % stop_id
	var travel: TravelController = host._find_travel_controller()
	if travel == null:
		return "TravelController not found — are you in the van scene?"
	if travel.has_method(&"force_stop_def"):
		if not travel.force_stop_def(stop):
			return "Could not queue stop: %s" % String(stop.id)
	elif travel.has_method(&"force_next_stop"):
		if not travel.force_next_stop(stop.id):
			return "Could not queue stop: %s" % String(stop.id)
	else:
		return "TravelController not found — are you in the van scene?"
	return "Next fork: %s [%s] on every road." % [stop.fork_label(), stop.arrival_label()]


func cmd_boss(_args: Array) -> String:
	var deck := host.get_tree().get_first_node_in_group(&"act_deck_controller")
	GameSession.debug_prepare_boss_pick()
	if deck and deck.has_method(&"begin_boss_pick_if_needed"):
		deck.begin_boss_pick_if_needed()
		return "Boss pick started — six streets, pick two."
	GameSession.commit_boss_picks([])
	GameSession.set_phase(GameSession.RunPhase.TRAVELLING)
	return "Boss pick skipped UI; stacked fallback cards and queued the fight."
