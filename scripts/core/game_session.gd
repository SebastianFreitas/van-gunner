extends Node

signal phase_changed(phase: RunPhase)
signal van_health_changed(current: float, maximum: float)
signal player_health_changed(current: float, maximum: float)
signal route_chosen(direction: StringName, step: int)
signal wave_changed(wave: int)
signal room_changed(room: StringName)
signal coins_changed(total: int)
signal enemy_defeated(enemy: Node)
signal session_loaded
signal chill_mode_changed(enabled: bool)
signal class_changed(class_id: StringName)

enum RunPhase {
	IDLE,
	TRAVELLING,
	COMBAT,
	ROUTE_CHOICE,
	TURNING,
	GAME_OVER,
	REST,
	PARKING,
	STOP,
	ACT_REVEAL,
	BOSS_PICK,
}

const BASE_MAX_VAN_HEALTH := 100.0
const BASE_MAX_PLAYER_HEALTH := 50.0
## Interior machines that sum to van death HP. Equal share of van_max_health.
const VITAL_COUNT := 4
const ACT_CARD_COUNT := 6
const ACT_BLESSING_COUNT := 3
const ACT_DANGER_COUNT := 3
## How many face-down streets the player commits to the act boss. Array-backed
## so later acts can stack more than two without a new data model.
const BOSS_CARD_PICK_COUNT := 2
## Preload-as-type avoids autoload parse order issues with global class_name.
const _SkillNodeDefinition := preload("res://scripts/meta/skill_node_definition.gd")
const _SessionSave := preload("res://scripts/core/session_save.gd")
const _SessionActDeck := preload("res://scripts/core/session_act_deck.gd")
const _SessionVitals := preload("res://scripts/core/session_vitals.gd")

var selected_slot := 0
var run_seed := 0
var route_step := 0
var wave_count := 0
var last_direction: StringName = &"straight"
var current_room: StringName = &"center"
var van_max_health := BASE_MAX_VAN_HEALTH
var van_health := BASE_MAX_VAN_HEALTH
var player_max_health := BASE_MAX_PLAYER_HEALTH
var player_health := BASE_MAX_PLAYER_HEALTH
var phase := RunPhase.IDLE
var coins := 0
var chill_mode := false
## Class for this run. Copied from the profile on NEW, restored on CONTINUE.
var class_id: StringName = &"basic"
## Per-vital current HP (string id → float). Applied when VanVital nodes bind.
var pending_vital_health: Dictionary = {}
## Per-vital max HP from CONTINUE. Missing on new runs so meta bonuses apply.
var pending_vital_max: Dictionary = {}
## Rare Parts already granted this run (cap 3). Run save, not meta.
var boss_parts_granted_this_run := 0

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
## Set by No Through Road; next fork is a T (2 cards) instead of a 4-way (3).
var pending_narrow_fork := false
## The six streets drawn for this act, in the order they were shown at reveal.
## Survives as cards are committed so the boss pick can show the same set again.
var act_source_cards: Array[StringName] = []
## Stacked street-card ids for the act boss. Empty during normal streets.
## Sized for 2 now; combat already iterates the whole list.
var boss_modifier_card_ids: Array[StringName] = []
## True after this act's boss is beaten (or skipped); blocks a second pick.
var boss_cleared_for_act := false


func start_new(slot: int) -> void:
	selected_slot = slot
	run_seed = randi()
	route_step = 0
	wave_count = 0
	last_direction = &"straight"
	current_room = &"center"
	van_max_health = BASE_MAX_VAN_HEALTH
	van_health = BASE_MAX_VAN_HEALTH
	player_max_health = BASE_MAX_PLAYER_HEALTH
	player_health = BASE_MAX_PLAYER_HEALTH
	LootCollector.clear()
	coins = 0
	class_id = ClassCatalog.resolve_id(MetaProgression.equipped_class_id)
	pending_vital_health = {}
	pending_vital_max = {}
	boss_parts_granted_this_run = 0
	MetaProgression.commit_pending()
	_SessionVitals.reset_vitals_in_tree(self)
	_SessionActDeck.reset_act_deck(self)
	set_chill_mode(false)
	set_phase(RunPhase.IDLE)
	SaveManager.save_active_session()


func load_from_data(slot: int, data: Dictionary) -> void:
	_SessionSave.load_from_data(self, slot, data)


## Equips a class for this run and remembers it for the next one. The class board
## only offers this in IDLE; the debug console calls it from any phase.
func equip_class(next_class_id: StringName) -> void:
	class_id = ClassCatalog.resolve_id(next_class_id)
	MetaProgression.set_equipped_class(class_id)
	class_changed.emit(class_id)
	SaveManager.save_active_session()


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


func bind_vital(vital: Node) -> void:
	_SessionVitals.bind_vital(self, vital)


func sync_van_health_from_vitals() -> void:
	_SessionVitals.sync_van_health_from_vitals(self)


func apply_meta_vital_delta(node: _SkillNodeDefinition) -> void:
	_SessionVitals.apply_meta_vital_delta(self, node)


func add_max_van_health(amount: float) -> void:
	_SessionVitals.add_max_van_health(self, amount)


func damage_van(amount: float) -> void:
	_SessionVitals.damage_van(self, amount)


func is_van_at_full_health() -> bool:
	return van_health >= van_max_health - 0.001


func is_van_fully_repaired() -> bool:
	return _SessionVitals.is_van_fully_repaired(self)


func repair_van_full() -> bool:
	return _SessionVitals.repair_van_full(self)


func get_max_player_health() -> float:
	return player_max_health


func is_player_at_full_health() -> bool:
	return player_health >= player_max_health - 0.001


func damage_player(amount: float) -> void:
	if amount <= 0.0 or phase == RunPhase.GAME_OVER:
		return
	player_health = maxf(0.0, player_health - amount)
	player_health_changed.emit(player_health, player_max_health)
	if is_zero_approx(player_health):
		set_phase(RunPhase.GAME_OVER)


func heal_player(amount: float) -> void:
	if amount <= 0.0 or phase == RunPhase.GAME_OVER:
		return
	player_health = minf(player_max_health, player_health + amount)
	player_health_changed.emit(player_health, player_max_health)


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
	var offer_count := get_fork_offer_count()
	if phase != RunPhase.ROUTE_CHOICE or direction not in get_route_directions():
		return
	last_direction = direction
	route_step += 1
	# Consume before commit so a freshly picked No Through Road still taxes the *next* fork.
	pending_narrow_fork = false
	_SessionActDeck.commit_route_card(self, direction, offer_count)
	route_chosen.emit(direction, route_step)
	set_phase(RunPhase.TURNING)
	SaveManager.save_active_session()


## 4-way shows three face-up streets; a T (narrow card, or fewer than three left) shows two.
func get_fork_offer_count() -> int:
	if act_cards.is_empty():
		return 2
	if pending_narrow_fork or act_cards.size() < 3:
		return 2
	return 3


func uses_t_junction() -> bool:
	return get_fork_offer_count() < 3


func get_route_directions() -> Array[StringName]:
	var dirs: Array[StringName] = [&"left", &"right"]
	if not uses_t_junction():
		dirs.insert(1, &"straight")
	return dirs


func needs_act_reveal() -> bool:
	return (
		act_cards.is_empty()
		and pending_boon_card_id == &""
		and not needs_boss_pick()
		and not is_boss_combat_queued()
	)


func needs_boss_pick() -> bool:
	return (
		act_cards.is_empty()
		and pending_boon_card_id == &""
		and not act_source_cards.is_empty()
		and boss_modifier_card_ids.is_empty()
		and not boss_cleared_for_act
	)


func is_boss_combat_queued() -> bool:
	return not boss_modifier_card_ids.is_empty() and not boss_cleared_for_act


func get_act_source_cards() -> Array[ActCardDefinition]:
	return _SessionActDeck.resolve_card_ids(self, act_source_cards)


func get_boss_modifier_cards() -> Array[ActCardDefinition]:
	return _SessionActDeck.resolve_card_ids(self, boss_modifier_card_ids)


## Street modifiers currently in force. Boss fights stack every picked card;
## normal streets still resolve as a single-entry list.
func get_active_modifier_cards() -> Array[ActCardDefinition]:
	return _SessionActDeck.get_active_modifier_cards(self)


func commit_boss_picks(card_ids: Array[StringName]) -> void:
	_SessionActDeck.commit_boss_picks(self, card_ids)


func complete_boss_encounter() -> void:
	_SessionActDeck.complete_boss_encounter(self)


## Debug: dump remaining streets and treat the current act as ready for the boss pick.
func debug_prepare_boss_pick() -> void:
	_SessionActDeck.debug_prepare_boss_pick(self)


## Builds a fresh 3-blessing / 3-danger deck, shuffles play order, returns display-order
## cards (also shuffled, independent of play order) for the reveal UI.
func begin_new_act_deck() -> Array[ActCardDefinition]:
	return _SessionActDeck.begin_new_act_deck(self)


func peek_route_cards() -> Array[ActCardDefinition]:
	return _SessionActDeck.peek_route_cards(self)


func get_active_street_card() -> ActCardDefinition:
	return ActCardRegistry.load_by_id(active_street_card_id)


func clear_pending_boon_card() -> void:
	pending_boon_card_id = &""


func act_cards_resolved_count() -> int:
	return clampi(act_cards_total - act_cards.size(), 0, act_cards_total)


func consume_pending_danger() -> bool:
	if not pending_danger:
		return false
	pending_danger = false
	return true


func _build_act_deck_ids() -> Array[StringName]:
	return _SessionActDeck.build_act_deck_ids(self)


func to_save_data() -> Dictionary:
	return _SessionSave.to_save_data(self)
