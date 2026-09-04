extends Node

signal phase_changed(phase: RunPhase)
signal van_health_changed(current: float, maximum: float)
signal route_chosen(direction: StringName, step: int)
signal wave_changed(wave: int)
signal room_changed(room: StringName)
signal coins_changed(total: int)
signal enemy_defeated(enemy: Node)
signal session_loaded
signal chill_mode_changed(enabled: bool)
signal area_changed(area: ItemDefinition.BoonPool)

enum RunPhase {
	IDLE,
	TRAVELLING,
	COMBAT,
	ROUTE_CHOICE,
	TURNING,
	GAME_OVER,
	REST,
	PARKING,
	SHOP,
	ACT_REVEAL,
}

const BASE_MAX_VAN_HEALTH := 100.0
const ACT_CARD_COUNT := 6
const ACT_BLESSING_COUNT := 3
const ACT_DANGER_COUNT := 3

var selected_slot := 0
var run_seed := 0
var route_step := 0
var wave_count := 0
var last_direction: StringName = &"straight"
var current_room: StringName = &"center"
var van_max_health := BASE_MAX_VAN_HEALTH
var van_health := BASE_MAX_VAN_HEALTH
var phase := RunPhase.IDLE
var coins := 0
var chill_mode := false
var current_area: ItemDefinition.BoonPool = ItemDefinition.BoonPool.GENERAL
## Pending weapon inventory restore applied when the player boots after load.
var pending_weapons_save = null

## 1-based act index; 0 means no deck has been drawn yet.
var run_act := 0
## Remaining play-order deck of ActCardDefinition ids.
var act_cards: Array[StringName] = []
## How many cards this act started with (for HUD progress).
var act_cards_total := 0
## Street card committed at the last route choice; combat reads modifiers from this.
var active_street_card_id: StringName = &""
## Card that still owes a REST boon pick (usually same as active until resolved).
var pending_boon_card_id: StringName = &""
## Set when a DANGER street is chosen; consumed when the next combat segment starts.
var pending_danger := false

const _LEFT_AREA_CYCLE: Array[ItemDefinition.BoonPool] = [
	ItemDefinition.BoonPool.FIRE,
	ItemDefinition.BoonPool.COLD,
	ItemDefinition.BoonPool.POISON,
	ItemDefinition.BoonPool.PHYSICAL,
]
const _RIGHT_AREA_CYCLE: Array[ItemDefinition.BoonPool] = [
	ItemDefinition.BoonPool.PHYSICAL,
	ItemDefinition.BoonPool.POISON,
	ItemDefinition.BoonPool.COLD,
	ItemDefinition.BoonPool.FIRE,
]


func start_new(slot: int) -> void:
	selected_slot = slot
	run_seed = randi()
	route_step = 0
	wave_count = 0
	last_direction = &"straight"
	current_room = &"center"
	van_max_health = BASE_MAX_VAN_HEALTH
	van_health = BASE_MAX_VAN_HEALTH
	coins = 0
	current_area = ItemDefinition.BoonPool.GENERAL
	pending_weapons_save = null
	_reset_act_deck()
	set_chill_mode(false)
	set_phase(RunPhase.IDLE)
	SaveManager.save_active_session()


func load_from_data(slot: int, data: Dictionary) -> void:
	selected_slot = slot
	run_seed = int(data.get("run_seed", randi()))
	route_step = int(data.get("route_step", 0))
	wave_count = int(data.get("wave_count", 0))
	last_direction = StringName(data.get("last_direction", "straight"))
	van_max_health = clampf(
		float(data.get("van_max_health", BASE_MAX_VAN_HEALTH)),
		BASE_MAX_VAN_HEALTH,
		9999.0
	)
	van_health = clampf(float(data.get("van_health", van_max_health)), 0.0, van_max_health)
	coins = maxi(0, int(data.get("coins", 0)))
	current_area = _area_from_save(int(data.get("current_area", ItemDefinition.BoonPool.GENERAL)))
	run_act = maxi(0, int(data.get("run_act", 0)))
	act_cards_total = maxi(0, int(data.get("act_cards_total", 0)))
	pending_danger = bool(data.get("pending_danger", false))
	active_street_card_id = StringName(str(data.get("active_street_card_id", "")))
	pending_boon_card_id = StringName(str(data.get("pending_boon_card_id", "")))
	act_cards = _cards_from_save(data.get("act_cards", []))
	if act_cards_total <= 0 and not act_cards.is_empty():
		act_cards_total = ACT_CARD_COUNT
	set_chill_mode(false)
	var stored_phase := int(data.get("phase", RunPhase.IDLE))
	phase = (stored_phase as RunPhase) if stored_phase in RunPhase.values() else RunPhase.IDLE
	if phase in [
		RunPhase.COMBAT,
		RunPhase.ROUTE_CHOICE,
		RunPhase.REST,
		RunPhase.TURNING,
		RunPhase.PARKING,
		RunPhase.SHOP,
		RunPhase.ACT_REVEAL,
	]:
		phase = RunPhase.TRAVELLING
	van_health_changed.emit(van_health, van_max_health)
	wave_changed.emit(wave_count)
	coins_changed.emit(coins)
	phase_changed.emit(phase)
	pending_weapons_save = data.get("weapons", null)
	session_loaded.emit()


func begin_run() -> void:
	if phase != RunPhase.IDLE:
		return
	set_phase(RunPhase.TRAVELLING)
	SaveManager.save_active_session()


func set_room(room: StringName) -> void:
	if current_room == room:
		return
	current_room = room
	room_changed.emit(room)


func set_phase(next_phase: RunPhase) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_changed.emit(phase)


func set_chill_mode(enabled: bool) -> void:
	if chill_mode == enabled:
		return
	chill_mode = enabled
	chill_mode_changed.emit(enabled)


func get_max_van_health() -> float:
	return van_max_health


func add_max_van_health(amount: float) -> void:
	if is_zero_approx(amount):
		return
	van_max_health = maxf(BASE_MAX_VAN_HEALTH, van_max_health + amount)
	if amount > 0.0:
		van_health += amount
	else:
		van_health = minf(van_health, van_max_health)
	van_health_changed.emit(van_health, van_max_health)


func damage_van(amount: float) -> void:
	if amount <= 0.0 or phase == RunPhase.GAME_OVER:
		return
	van_health = maxf(0.0, van_health - amount)
	van_health_changed.emit(van_health, van_max_health)
	if is_zero_approx(van_health):
		set_phase(RunPhase.GAME_OVER)


func is_van_at_full_health() -> bool:
	return van_health >= van_max_health - 0.001


func heal_van(amount: float) -> void:
	if amount <= 0.0 or phase == RunPhase.GAME_OVER:
		return
	van_health = minf(van_max_health, van_health + amount)
	van_health_changed.emit(van_health, van_max_health)


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	coins_changed.emit(coins)


func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


func notify_enemy_defeated(enemy: Node) -> void:
	if enemy:
		enemy_defeated.emit(enemy)


func complete_wave() -> void:
	wave_count += 1
	wave_changed.emit(wave_count)


func choose_route(direction: StringName) -> void:
	if phase != RunPhase.ROUTE_CHOICE or direction not in [&"left", &"right"]:
		return
	last_direction = direction
	route_step += 1
	current_area = _resolve_area_for_fork(direction, route_step)
	area_changed.emit(current_area)
	_commit_route_card(direction)
	route_chosen.emit(direction, route_step)
	set_phase(RunPhase.TURNING)
	SaveManager.save_active_session()


func get_rest_area() -> ItemDefinition.BoonPool:
	if route_step <= 0:
		return ItemDefinition.BoonPool.GENERAL
	return current_area


func get_area_flavor_name(area: ItemDefinition.BoonPool = current_area) -> String:
	match area:
		ItemDefinition.BoonPool.FIRE:
			return "FIRE"
		ItemDefinition.BoonPool.COLD:
			return "COLD"
		ItemDefinition.BoonPool.POISON:
			return "POISON"
		ItemDefinition.BoonPool.PHYSICAL:
			return "PHYSICAL"
		_:
			return "OPEN ROAD"


func needs_act_reveal() -> bool:
	return act_cards.is_empty() and pending_boon_card_id == &""


## Builds a fresh 3-blessing / 3-danger deck, shuffles play order, returns display-order
## cards (also shuffled, independent of play order) for the reveal UI.
func begin_new_act_deck() -> Array[ActCardDefinition]:
	run_act += 1
	pending_danger = false
	active_street_card_id = &""
	pending_boon_card_id = &""
	var deck_ids := _build_act_deck_ids()
	var play_rng := _act_rng(0)
	_shuffle_card_ids(deck_ids, play_rng)
	act_cards = deck_ids
	act_cards_total = act_cards.size()
	var display_ids: Array[StringName] = act_cards.duplicate()
	var display_rng := _act_rng(1)
	_shuffle_card_ids(display_ids, display_rng)
	return _resolve_card_ids(display_ids)


func peek_route_cards() -> Array[ActCardDefinition]:
	## Two face-up offers for left / right. Pick one; the other stays in the deck.
	## With one card left, both sides show it.
	var offers: Array[ActCardDefinition] = []
	if act_cards.is_empty():
		return offers
	var left := ActCardRegistry.load_by_id(act_cards[0])
	if left:
		offers.append(left)
	if act_cards.size() >= 2:
		var right := ActCardRegistry.load_by_id(act_cards[1])
		if right:
			offers.append(right)
	elif left:
		offers.append(left)
	return offers


func get_active_street_card() -> ActCardDefinition:
	return ActCardRegistry.load_by_id(active_street_card_id)


func get_pending_boon_card() -> ActCardDefinition:
	return ActCardRegistry.load_by_id(pending_boon_card_id)


func clear_pending_boon_card() -> void:
	pending_boon_card_id = &""


func act_cards_resolved_count() -> int:
	return clampi(act_cards_total - act_cards.size(), 0, act_cards_total)


func consume_pending_danger() -> bool:
	if not pending_danger:
		return false
	pending_danger = false
	return true


func _commit_route_card(direction: StringName) -> void:
	if act_cards.is_empty():
		active_street_card_id = &""
		pending_boon_card_id = &""
		pending_danger = false
		return
	var offer_index := 0
	if act_cards.size() >= 2 and direction == &"right":
		offer_index = 1
	var card_id := act_cards[offer_index]
	act_cards.remove_at(offer_index)
	active_street_card_id = card_id
	pending_boon_card_id = card_id
	var card := ActCardRegistry.load_by_id(card_id)
	pending_danger = card != null and card.is_danger()


func _build_act_deck_ids() -> Array[StringName]:
	var deck: Array[StringName] = []
	var blessings := ActCardRegistry.list_by_polarity(ActCardDefinition.Polarity.BLESSING)
	var dangers := ActCardRegistry.list_by_polarity(ActCardDefinition.Polarity.DANGER)
	var pick_rng := _act_rng(2)
	for _i in ACT_BLESSING_COUNT:
		deck.append(_pick_card_id(blessings, pick_rng, &"cold_road"))
	for _i in ACT_DANGER_COUNT:
		deck.append(_pick_card_id(dangers, pick_rng, &"hasty_pack"))
	return deck


func _pick_card_id(
	pool: Array[ActCardDefinition],
	rng: RandomNumberGenerator,
	fallback_id: StringName
) -> StringName:
	if pool.is_empty():
		return fallback_id
	var card: ActCardDefinition = pool[rng.randi_range(0, pool.size() - 1)]
	if card and card.id != &"":
		return card.id
	return fallback_id


func _resolve_card_ids(ids: Array[StringName]) -> Array[ActCardDefinition]:
	var cards: Array[ActCardDefinition] = []
	for card_id in ids:
		var card := ActCardRegistry.load_by_id(card_id)
		if card:
			cards.append(card)
	return cards


func _reset_act_deck() -> void:
	run_act = 0
	act_cards.clear()
	act_cards_total = 0
	active_street_card_id = &""
	pending_boon_card_id = &""
	pending_danger = false


func _act_rng(channel: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, run_act, channel])
	return rng


func _shuffle_card_ids(cards: Array[StringName], rng: RandomNumberGenerator) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


func _resolve_area_for_fork(direction: StringName, step: int) -> ItemDefinition.BoonPool:
	var index := (step - 1) % 4
	if direction == &"left":
		return _LEFT_AREA_CYCLE[index]
	return _RIGHT_AREA_CYCLE[index]


func _area_from_save(value: int) -> ItemDefinition.BoonPool:
	if value in ItemDefinition.BoonPool.values():
		return value as ItemDefinition.BoonPool
	return ItemDefinition.BoonPool.GENERAL


func _cards_from_save(raw) -> Array[StringName]:
	var cards: Array[StringName] = []
	if typeof(raw) != TYPE_ARRAY:
		return cards
	for entry in raw:
		var card_id := StringName(str(entry))
		## Migrate legacy type-only decks to placeholder resources.
		if card_id == &"boon":
			card_id = &"cold_road"
		elif card_id == &"danger":
			card_id = &"hasty_pack"
		if card_id != &"":
			cards.append(card_id)
	return cards


func to_save_data() -> Dictionary:
	var weapons = null
	var tree := get_tree()
	if tree:
		var player := tree.get_first_node_in_group(&"player")
		if player:
			## Untyped to avoid class_name cycle with WeaponInventory.
			var inv = player.get_node_or_null("WeaponInventory")
			if inv != null and inv.has_method("to_save_dict"):
				weapons = inv.to_save_dict()
	var card_strings: Array[String] = []
	for card_id in act_cards:
		card_strings.append(String(card_id))
	return {
		"version": 4,
		"run_seed": run_seed,
		"route_step": route_step,
		"wave_count": wave_count,
		"last_direction": String(last_direction),
		"van_health": van_health,
		"van_max_health": van_max_health,
		"coins": coins,
		"phase": phase,
		"current_area": int(current_area),
		"run_act": run_act,
		"act_cards_total": act_cards_total,
		"act_cards": card_strings,
		"active_street_card_id": String(active_street_card_id),
		"pending_boon_card_id": String(pending_boon_card_id),
		"pending_danger": pending_danger,
		"weapons": weapons,
		"saved_at": Time.get_datetime_string_from_system(),
	}