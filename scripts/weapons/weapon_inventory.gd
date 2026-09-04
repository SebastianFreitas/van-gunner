class_name WeaponInventory
extends Node

## Exactly 2 weapon slots. Active gun drives GunStatsController + GunController.

signal loadout_changed
signal active_weapon_changed(index: int, instance: WeaponInstance)
signal weapon_pickup_rejected(reason: String)

enum AddResult { STORED, REPLACED, REJECTED }

const SLOT_COUNT := 2
const SWAP_LOCK_MS := 120

@export var stats_controller_path: NodePath
@export var gun_controller_path: NodePath

var slots: Array = [null, null] ## Array[WeaponInstance] nullable
var active_index: int = 0

var _stats: GunStatsController
var _gun: GunController
var _swap_unlock_msec: int = 0


func _ready() -> void:
	_stats = null
	_gun = null
	if not stats_controller_path.is_empty():
		_stats = get_node_or_null(stats_controller_path) as GunStatsController
	if not gun_controller_path.is_empty():
		_gun = get_node_or_null(gun_controller_path) as GunController
	if _stats == null:
		_stats = get_parent().get_node_or_null("GunStats") as GunStatsController
	if _gun == null:
		_gun = get_parent().get_node_or_null("Head/Camera3D/Weapon") as GunController
	## Defer so GunController._ready has wired stats_changed.
	call_deferred("_boot_loadout")


func _boot_loadout() -> void:
	if GameSession.pending_weapons_save is Dictionary:
		load_from_save_dict(GameSession.pending_weapons_save)
		GameSession.pending_weapons_save = null
	elif slots[0] == null:
		seed_starter()
	else:
		_apply_active(true)


func seed_starter(level: int = 1) -> void:
	slots[0] = WeaponGenerator.create_starter(level)
	slots[1] = null
	active_index = 0
	_apply_active(true)
	loadout_changed.emit()


func get_active() -> WeaponInstance:
	if active_index < 0 or active_index >= SLOT_COUNT:
		return null
	return slots[active_index] as WeaponInstance


func get_slot(index: int) -> WeaponInstance:
	if index < 0 or index >= SLOT_COUNT:
		return null
	return slots[index] as WeaponInstance


func occupied_count() -> int:
	var n := 0
	for s in slots:
		if s != null:
			n += 1
	return n


func first_empty_slot() -> int:
	for i in SLOT_COUNT:
		if slots[i] == null:
			return i
	return -1


func try_add(instance: WeaponInstance) -> AddResult:
	if instance == null:
		return AddResult.REJECTED
	var empty := first_empty_slot()
	if empty >= 0:
		slots[empty] = instance
		if get_active() == null:
			active_index = empty
			_apply_active(true)
		loadout_changed.emit()
		active_weapon_changed.emit(active_index, get_active())
		return AddResult.STORED
	weapon_pickup_rejected.emit("full")
	return AddResult.REJECTED


func replace_slot(index: int, instance: WeaponInstance) -> WeaponInstance:
	if index < 0 or index >= SLOT_COUNT or instance == null:
		return null
	_persist_active_ammo()
	var old: WeaponInstance = slots[index] as WeaponInstance
	slots[index] = instance
	if active_index == index:
		_apply_active(true)
	loadout_changed.emit()
	active_weapon_changed.emit(active_index, get_active())
	return old


func swap_active() -> bool:
	var other := 1 - active_index
	if slots[other] == null:
		return false
	return set_active(other)


func cycle_active(dir: int) -> bool:
	if occupied_count() <= 1:
		return false
	var step := 1 if dir >= 0 else -1
	var idx := active_index
	for _i in SLOT_COUNT:
		idx = (idx + step + SLOT_COUNT) % SLOT_COUNT
		if slots[idx] != null:
			return set_active(idx)
	return false


func set_active(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT or slots[index] == null:
		return false
	if index == active_index:
		return true
	if Time.get_ticks_msec() < _swap_unlock_msec:
		return false
	_persist_active_ammo()
	active_index = index
	_swap_unlock_msec = Time.get_ticks_msec() + SWAP_LOCK_MS
	_apply_active(true)
	active_weapon_changed.emit(active_index, get_active())
	loadout_changed.emit()
	return true


func drop_active() -> WeaponInstance:
	if occupied_count() <= 1:
		return null
	_persist_active_ammo()
	var dropped: WeaponInstance = slots[active_index] as WeaponInstance
	slots[active_index] = null
	for i in SLOT_COUNT:
		if slots[i] != null:
			active_index = i
			break
	_apply_active(true)
	loadout_changed.emit()
	active_weapon_changed.emit(active_index, get_active())
	return dropped


func destroy_slot(index: int) -> bool:
	if occupied_count() <= 1:
		return false
	if index < 0 or index >= SLOT_COUNT or slots[index] == null:
		return false
	_persist_active_ammo()
	slots[index] = null
	if active_index == index:
		for i in SLOT_COUNT:
			if slots[i] != null:
				active_index = i
				break
	_apply_active(true)
	loadout_changed.emit()
	active_weapon_changed.emit(active_index, get_active())
	return true


func refresh_active_stats() -> void:
	_apply_active(false)


func to_save_dict() -> Dictionary:
	_persist_active_ammo()
	var saved_slots: Array = []
	for i in SLOT_COUNT:
		var inst := slots[i] as WeaponInstance
		var entry: Variant = null
		if inst != null:
			entry = inst.to_dict()
		saved_slots.append(entry)
	return {
		"active_index": active_index,
		"slots": saved_slots,
	}


func load_from_save_dict(data: Dictionary) -> void:
	var saved_slots: Array = data.get("slots", [])
	slots = [null, null]
	for i in mini(SLOT_COUNT, saved_slots.size()):
		var entry = saved_slots[i]
		if entry is Dictionary:
			slots[i] = WeaponInstance.from_dict(entry)
	active_index = clampi(int(data.get("active_index", 0)), 0, SLOT_COUNT - 1)
	if slots[active_index] == null:
		for i in SLOT_COUNT:
			if slots[i] != null:
				active_index = i
				break
	if get_active() == null:
		seed_starter()
	else:
		_apply_active(true)
		loadout_changed.emit()


func _persist_active_ammo() -> void:
	var active := get_active()
	if active and _gun:
		_gun.capture_ammo_to_instance(active)


func _apply_active(restore_ammo: bool) -> void:
	var active := get_active()
	if _stats:
		_stats.set_weapon_instance(active)
	if restore_ammo and _gun and active:
		_gun.apply_weapon_ammo_from_instance(active)
