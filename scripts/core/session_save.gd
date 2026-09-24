extends RefCounted

## Save serialization for GameSession. Static helpers; every function takes the
## GameSession autoload as `session`.
const _SessionVitals := preload("res://scripts/core/session_vitals.gd")


static func load_from_data(session: Node, slot: int, data: Dictionary) -> void:
	session.selected_slot = slot
	session.run_seed = int(data.get("run_seed", randi()))
	session.route_step = int(data.get("route_step", 0))
	session.wave_count = int(data.get("wave_count", 0))
	session.last_direction = StringName(data.get("last_direction", "straight"))
	session.van_max_health = clampf(
		float(data.get("van_max_health", session.BASE_MAX_VAN_HEALTH)),
		session.BASE_MAX_VAN_HEALTH,
		9999.0
	)
	session.van_health = clampf(
		float(data.get("van_health", session.van_max_health)), 0.0, session.van_max_health
	)
	session.player_max_health = clampf(
		float(data.get("player_max_health", session.BASE_MAX_PLAYER_HEALTH)),
		session.BASE_MAX_PLAYER_HEALTH,
		9999.0
	)
	session.player_health = clampf(
		float(data.get("player_health", session.player_max_health)), 0.0, session.player_max_health
	)
	session.coins = maxi(0, int(data.get("coins", 0)))
	session.class_id = ClassCatalog.resolve_id(StringName(str(data.get("class_id", "basic"))))
	session.run_act = maxi(0, int(data.get("run_act", 0)))
	session.act_cards_total = maxi(0, int(data.get("act_cards_total", 0)))
	session.pending_danger = bool(data.get("pending_danger", false))
	session.pending_narrow_fork = bool(data.get("pending_narrow_fork", false))
	session.active_street_card_id = StringName(str(data.get("active_street_card_id", "")))
	session.pending_boon_card_id = StringName(str(data.get("pending_boon_card_id", "")))
	session.act_cards = cards_from_save(data.get("act_cards", []))
	session.act_source_cards = cards_from_save(data.get("act_source_cards", []))
	session.boss_modifier_card_ids = cards_from_save(data.get("boss_modifier_card_ids", []))
	session.boss_cleared_for_act = bool(data.get("boss_cleared_for_act", false))
	if session.act_source_cards.is_empty() and not session.act_cards.is_empty():
		session.act_source_cards = session.act_cards.duplicate()
	if session.act_cards_total <= 0 and not session.act_cards.is_empty():
		session.act_cards_total = session.ACT_CARD_COUNT
	session.set_chill_mode(false)
	var stored_phase := int(data.get("phase", session.RunPhase.IDLE))
	session.phase = (
		stored_phase if stored_phase in session.RunPhase.values() else session.RunPhase.IDLE
	)
	if session.phase in [
		session.RunPhase.COMBAT,
		session.RunPhase.ROUTE_CHOICE,
		session.RunPhase.REST,
		session.RunPhase.TURNING,
		session.RunPhase.PARKING,
		session.RunPhase.STOP,
		session.RunPhase.ACT_REVEAL,
		session.RunPhase.BOSS_PICK,
	]:
		session.phase = session.RunPhase.TRAVELLING
	parse_vital_health(session, data)
	session.boss_parts_granted_this_run = maxi(0, int(data.get("boss_parts_granted_this_run", 0)))
	_SessionVitals.apply_pending_to_tree(session)
	session.van_health_changed.emit(session.van_health, session.van_max_health)
	session.player_health_changed.emit(session.player_health, session.player_max_health)
	session.wave_changed.emit(session.wave_count)
	session.coins_changed.emit(session.coins)
	session.phase_changed.emit(session.phase)
	session.session_loaded.emit()


static func to_save_data(session: Node) -> Dictionary:
	var card_strings: Array[String] = []
	for card_id in session.act_cards:
		card_strings.append(String(card_id))
	var source_strings: Array[String] = []
	for card_id in session.act_source_cards:
		source_strings.append(String(card_id))
	var boss_strings: Array[String] = []
	for card_id in session.boss_modifier_card_ids:
		boss_strings.append(String(card_id))
	return {
		"version": SaveManager.SAVE_VERSION,
		"run_seed": session.run_seed,
		"route_step": session.route_step,
		"wave_count": session.wave_count,
		"last_direction": String(session.last_direction),
		"van_health": session.van_health,
		"van_max_health": session.van_max_health,
		"vital_health": vital_health_dict(session),
		"vital_max": vital_max_dict(session),
		"player_health": session.player_health,
		"player_max_health": session.player_max_health,
		"coins": session.coins,
		"boss_parts_granted_this_run": session.boss_parts_granted_this_run,
		"phase": session.phase,
		"run_act": session.run_act,
		"act_cards_total": session.act_cards_total,
		"act_cards": card_strings,
		"act_source_cards": source_strings,
		"boss_modifier_card_ids": boss_strings,
		"boss_cleared_for_act": session.boss_cleared_for_act,
		"active_street_card_id": String(session.active_street_card_id),
		"pending_boon_card_id": String(session.pending_boon_card_id),
		"pending_danger": session.pending_danger,
		"pending_narrow_fork": session.pending_narrow_fork,
		"class_id": String(session.class_id),
		"saved_at": Time.get_datetime_string_from_system(),
	}


static func cards_from_save(raw) -> Array[StringName]:
	var cards: Array[StringName] = []
	if typeof(raw) != TYPE_ARRAY:
		return cards
	for entry in raw:
		var card_id := StringName(str(entry))
		## Migrate legacy type-only decks to placeholder resources.
		if card_id == &"boon":
			card_id = &"brass_road"
		elif card_id == &"danger":
			card_id = &"hasty_pack"
		if card_id != &"":
			cards.append(card_id)
	return cards


static func parse_vital_health(session: Node, data: Dictionary) -> void:
	session.pending_vital_health = {}
	session.pending_vital_max = {}
	var raw = data.get("vital_health", {})
	if typeof(raw) == TYPE_DICTIONARY and not (raw as Dictionary).is_empty():
		for key in raw:
			session.pending_vital_health[str(key)] = float(raw[key])
	else:
		## Old slots stored a single hull number — split evenly across the four machines.
		var share := float(data.get("van_health", session.van_health)) / float(session.VITAL_COUNT)
		for vital_id in [&"bench", &"hopper", &"fuse_box", &"cab_relay"]:
			session.pending_vital_health[String(vital_id)] = share
	var raw_max = data.get("vital_max", {})
	if typeof(raw_max) == TYPE_DICTIONARY:
		for key in raw_max:
			session.pending_vital_max[str(key)] = float(raw_max[key])


static func vital_health_dict(session: Node) -> Dictionary:
	var stored := {}
	for vital in _SessionVitals.vital_nodes(session):
		stored[String(vital.vital_id)] = float(vital.health)
	if stored.is_empty():
		return session.pending_vital_health.duplicate()
	return stored


static func vital_max_dict(session: Node) -> Dictionary:
	var stored := {}
	for vital in _SessionVitals.vital_nodes(session):
		stored[String(vital.vital_id)] = float(vital.max_health)
	if stored.is_empty():
		return session.pending_vital_max.duplicate()
	return stored
