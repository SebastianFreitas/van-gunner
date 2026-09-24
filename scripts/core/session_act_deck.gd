extends RefCounted

## Act deck logic for GameSession. Static helpers; every function takes the
## GameSession autoload as `session`.


## Builds a fresh 3-blessing / 3-danger deck, shuffles play order, returns display-order
## cards (also shuffled, independent of play order) for the reveal UI.
static func begin_new_act_deck(session: Node) -> Array[ActCardDefinition]:
	session.run_act += 1
	session.pending_danger = false
	session.pending_narrow_fork = false
	ActCardCombat.clear()
	session.active_street_card_id = &""
	session.pending_boon_card_id = &""
	session.boss_modifier_card_ids.clear()
	session.boss_cleared_for_act = false
	var deck_ids := build_act_deck_ids(session)
	var play_rng := _act_rng(session, 0)
	_shuffle_card_ids(deck_ids, play_rng)
	session.act_cards = deck_ids
	session.act_cards_total = session.act_cards.size()
	var display_ids: Array[StringName] = session.act_cards.duplicate()
	var display_rng := _act_rng(session, 1)
	_shuffle_card_ids(display_ids, display_rng)
	session.act_source_cards = display_ids.duplicate()
	return resolve_card_ids(session, display_ids)


static func peek_route_cards(session: Node) -> Array[ActCardDefinition]:
	## Face-up offers for the live fork. Pick one; the rest stay in the deck.
	## With one card left, both T buttons show it.
	var offers: Array[ActCardDefinition] = []
	if session.act_cards.is_empty():
		return offers
	var count: int = session.get_fork_offer_count()
	for i in count:
		var idx := mini(i, session.act_cards.size() - 1)
		var card := ActCardRegistry.load_by_id(session.act_cards[idx])
		if card:
			offers.append(card)
	return offers


## Street modifiers currently in force. Boss fights stack every picked card;
## normal streets still resolve as a single-entry list.
static func get_active_modifier_cards(session: Node) -> Array[ActCardDefinition]:
	if not session.boss_modifier_card_ids.is_empty():
		return session.get_boss_modifier_cards()
	var street: ActCardDefinition = session.get_active_street_card()
	var cards: Array[ActCardDefinition] = []
	if street:
		cards.append(street)
	return cards


static func commit_boss_picks(session: Node, card_ids: Array[StringName]) -> void:
	var picked: Array[StringName] = []
	for card_id in card_ids:
		if card_id == &"":
			continue
		picked.append(card_id)
		if picked.size() >= session.BOSS_CARD_PICK_COUNT:
			break
	if picked.is_empty():
		picked = _debug_fallback_boss_picks(session)
	ActCardCombat.clear()
	session.active_street_card_id = &""
	session.pending_boon_card_id = &""
	session.pending_danger = false
	session.boss_modifier_card_ids = picked
	session.boss_cleared_for_act = false
	ActCardCombat.activate_active_cards()
	SaveManager.save_active_session()


static func complete_boss_encounter(session: Node) -> void:
	ActCardCombat.clear()
	session.boss_modifier_card_ids.clear()
	session.boss_cleared_for_act = true
	session.active_street_card_id = &""
	session.pending_danger = false
	if session.boss_parts_granted_this_run < 3:
		session.boss_parts_granted_this_run += 1
		MetaProgression.add_rare_parts(1)
	SaveManager.save_active_session()


## Debug: dump remaining streets and treat the current act as ready for the boss pick.
static func debug_prepare_boss_pick(session: Node) -> void:
	if session.act_source_cards.is_empty():
		session.begin_new_act_deck()
	session.act_cards.clear()
	session.pending_boon_card_id = &""
	session.pending_danger = false
	session.pending_narrow_fork = false
	session.boss_modifier_card_ids.clear()
	session.boss_cleared_for_act = false
	ActCardCombat.clear()
	session.active_street_card_id = &""


static func _debug_fallback_boss_picks(session: Node) -> Array[StringName]:
	var picked: Array[StringName] = []
	for card_id in session.act_source_cards:
		if card_id == &"":
			continue
		picked.append(card_id)
		if picked.size() >= session.BOSS_CARD_PICK_COUNT:
			break
	return picked


static func commit_route_card(session: Node, direction: StringName, offer_count: int) -> void:
	if session.act_cards.is_empty():
		ActCardCombat.clear()
		session.active_street_card_id = &""
		session.pending_boon_card_id = &""
		session.pending_danger = false
		return
	var offer_index := 0
	match direction:
		&"straight":
			if offer_count >= 3:
				offer_index = 1
		&"right":
			offer_index = 1 if offer_count < 3 else 2
	offer_index = mini(offer_index, session.act_cards.size() - 1)
	var card_id: StringName = session.act_cards[offer_index]
	session.act_cards.remove_at(offer_index)
	ActCardCombat.clear()
	session.active_street_card_id = card_id
	session.pending_boon_card_id = card_id
	var card := ActCardRegistry.load_by_id(card_id)
	session.pending_danger = card != null and card.is_danger()
	ActCardCombat.activate(card)


static func build_act_deck_ids(session: Node) -> Array[StringName]:
	var deck: Array[StringName] = []
	var blessings := ActCardRegistry.list_by_polarity(ActCardDefinition.Polarity.BLESSING)
	var dangers := ActCardRegistry.list_by_polarity(ActCardDefinition.Polarity.DANGER)
	var pick_rng := _act_rng(session, 2)
	for _i in session.ACT_BLESSING_COUNT:
		deck.append(_pick_card_id(blessings, pick_rng, &"brass_road"))
	for _i in session.ACT_DANGER_COUNT:
		deck.append(_pick_card_id(dangers, pick_rng, &"hasty_pack"))
	return deck


static func _pick_card_id(
	pool: Array[ActCardDefinition],
	rng: RandomNumberGenerator,
	fallback_id: StringName
) -> StringName:
	if pool.is_empty():
		return fallback_id
	## Without replacement so a six-card act does not roll the same street twice
	## while the pool still has unused ids.
	var idx := rng.randi_range(0, pool.size() - 1)
	var card: ActCardDefinition = pool[idx]
	pool.remove_at(idx)
	if card and card.id != &"":
		return card.id
	return fallback_id


static func resolve_card_ids(_session: Node, ids: Array[StringName]) -> Array[ActCardDefinition]:
	var cards: Array[ActCardDefinition] = []
	for card_id in ids:
		var card := ActCardRegistry.load_by_id(card_id)
		if card:
			cards.append(card)
	return cards


static func reset_act_deck(session: Node) -> void:
	session.run_act = 0
	session.act_cards.clear()
	session.act_cards_total = 0
	session.act_source_cards.clear()
	session.boss_modifier_card_ids.clear()
	session.boss_cleared_for_act = false
	ActCardCombat.clear()
	session.active_street_card_id = &""
	session.pending_boon_card_id = &""
	session.pending_danger = false
	session.pending_narrow_fork = false


static func _act_rng(session: Node, channel: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([session.run_seed, session.run_act, channel])
	return rng


static func _shuffle_card_ids(cards: Array[StringName], rng: RandomNumberGenerator) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
