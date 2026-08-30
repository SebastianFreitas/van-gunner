class_name UsablesController
extends Node

signal slots_changed
signal boons_changed
signal item_acquired(item: ItemDefinition, charges: int, slot_index: int)
signal usable_activated(item: ItemDefinition, success: bool)

const MAX_SLOTS := 4

var _slots: Array[UsableState] = []
var _active_index := 0
var _boons: Array[ItemDefinition] = []


func _ready() -> void:
	if GameSession.has_signal(&"enemy_defeated"):
		GameSession.enemy_defeated.connect(_on_enemy_defeated)


func _process(delta: float) -> void:
	var changed := false
	for state in _slots:
		if state.cooldown_remaining <= 0.0:
			continue
		var previous := state.cooldown_remaining
		state.cooldown_remaining = maxf(0.0, state.cooldown_remaining - delta)
		if previous > 0.0 and is_zero_approx(state.cooldown_remaining):
			var config := state.get_config()
			if config and config.recharge_mode == ItemUsableConfig.RechargeMode.COOLDOWN:
				state.charges = config.max_charges
			changed = true
	if changed:
		slots_changed.emit()


func get_slots() -> Array[UsableState]:
	return _slots


func get_active_index() -> int:
	return _active_index


func get_boons() -> Array[ItemDefinition]:
	return _boons


func has_boon(item: ItemDefinition) -> bool:
	if not item:
		return false
	for boon in _boons:
		if boon and boon.id == item.id:
			return true
	return false


func register_boon(item: ItemDefinition) -> void:
	if not item or has_boon(item):
		return
	_boons.append(item)
	boons_changed.emit()
	item_acquired.emit(item, 1, -1)


func add_usable(item: ItemDefinition) -> void:
	if not item or not item.is_usable():
		return
	var existing := _find_slot(item.id)
	if existing:
		var config := item.usable
		if config and config.is_consumed_on_use:
			existing.charges = mini(existing.charges + config.max_charges, config.max_charges * 2)
			slots_changed.emit()
			item_acquired.emit(item, existing.charges, _slot_index_of(existing))
			return
	var state := UsableState.new(item)
	if _slots.size() >= MAX_SLOTS:
		_slots.pop_front()
		if _active_index > 0:
			_active_index -= 1
	_slots.append(state)
	if _slots.size() == 1:
		_active_index = 0
	slots_changed.emit()
	item_acquired.emit(item, state.charges, _slots.size() - 1)


func select_slot(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	_active_index = index
	slots_changed.emit()


func try_use_active() -> bool:
	if _slots.is_empty():
		usable_activated.emit(null, false)
		return false
	_active_index = clampi(_active_index, 0, _slots.size() - 1)
	return _try_use_state(_slots[_active_index])


func try_use_slot(index: int) -> bool:
	if index < 0 or index >= _slots.size():
		usable_activated.emit(null, false)
		return false
	_active_index = index
	return _try_use_state(_slots[index])


func _try_use_state(state: UsableState) -> bool:
	if not state or not state.is_ready():
		usable_activated.emit(state.definition if state else null, false)
		return false
	var player := get_parent() as Node3D
	if not player:
		usable_activated.emit(state.definition, false)
		return false
	state.definition.apply_effects(player)
	var config := state.get_config()
	if config:
		if config.is_consumed_on_use:
			state.charges -= 1
		if config.recharge_mode == ItemUsableConfig.RechargeMode.COOLDOWN:
			state.cooldown_remaining = config.recharge_cooldown_sec
			if not config.is_consumed_on_use:
				state.charges = 0
	_slots = _slots.filter(func(slot: UsableState) -> bool: return _should_keep_slot(slot))
	if _active_index >= _slots.size():
		_active_index = maxi(0, _slots.size() - 1)
	slots_changed.emit()
	usable_activated.emit(state.definition, true)
	return true


func _find_slot(item_id: StringName) -> UsableState:
	for state in _slots:
		if state.definition and state.definition.id == item_id:
			return state
	return null


func _slot_index_of(state: UsableState) -> int:
	return _slots.find(state)


func _should_keep_slot(state: UsableState) -> bool:
	if state.charges > 0:
		return true
	var config := state.get_config()
	return config != null and config.recharge_mode != ItemUsableConfig.RechargeMode.NONE


func _on_enemy_defeated(_enemy: Node) -> void:
	var changed := false
	for state in _slots:
		var config := state.get_config()
		if not config or config.recharge_mode != ItemUsableConfig.RechargeMode.ON_KILL:
			continue
		var before := state.charges
		state.charges = mini(state.charges + config.recharge_per_kill, config.max_charges)
		changed = changed or state.charges != before
	if changed:
		slots_changed.emit()
