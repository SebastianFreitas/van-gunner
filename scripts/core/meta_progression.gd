extends Node

signal van_speed_changed(level: int, speed: float)
signal rare_parts_changed(total: int)
signal tree_changed

## Preload-as-type: this autoload cannot name SkillNodeDefinition / the tree
## registry by global class_name or the script fails to parse.
const _SkillNodeDefinition := preload("res://scripts/meta/skill_node_definition.gd")
const _SkillTreeRegistry := preload("res://scripts/core/skill_tree_registry.gd")

const SAVE_PATH := "user://meta_progression.json"
const SAVE_VERSION := 2
const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"

## FUTURE — persistent street-card back marks (meta, all runs):
## The full card mechanic should let the player scribble / stamp a mark on the
## *back* of a street card so they can recognize it in the face-down boss pick.
## Store those marks here (this JSON on disc), not on the run save, so they
## survive every new run. Key by ActCardDefinition.id. Unmarked cards stay blank.

## Derived from allocated speed nodes. Callers (travel, chase) still read this.
var van_speed_level := 0
var rare_parts := 0
var allocated_ids: Array[StringName] = []
var pending_ids: Array[StringName] = []
## Linear 0–1 mixer sliders. Master is the overall cap; Music / SFX sit under it.
var master_volume := 0.7
var music_volume := 1.0
var sfx_volume := 1.0


func _ready() -> void:
	load_profile()
	apply_audio_settings()


func get_van_speed() -> float:
	return GameBalance.get_van_speed_for_level(van_speed_level)


func add_rare_parts(amount: int) -> void:
	if amount <= 0:
		return
	rare_parts += amount
	save_profile()
	rare_parts_changed.emit(rare_parts)


func is_allocated(node_id: StringName) -> bool:
	return node_id in allocated_ids


func is_pending(node_id: StringName) -> bool:
	return node_id in pending_ids


func allocation_count() -> int:
	return allocated_ids.size() + pending_ids.size()


func can_allocate(node_id: StringName) -> Dictionary:
	var node: _SkillNodeDefinition = _SkillTreeRegistry.get_definition(node_id)
	if node == null:
		return {"ok": false, "reason": "unknown"}
	if is_allocated(node_id) or is_pending(node_id):
		return {"ok": false, "reason": "owned"}
	if not _parent_ready(node):
		return {"ok": false, "reason": "locked"}
	if allocation_count() >= _SkillTreeRegistry.MAX_ALLOCATED:
		return {"ok": false, "reason": "cap"}
	if node.cost > 0 and rare_parts < node.cost:
		return {"ok": false, "reason": "insufficient_parts", "cost": node.cost}
	return {"ok": true, "cost": node.cost, "immediate": _apply_immediately()}


func try_allocate(node_id: StringName) -> Dictionary:
	var check := can_allocate(node_id)
	if not check.get("ok", false):
		return check
	var node: _SkillNodeDefinition = _SkillTreeRegistry.get_definition(node_id)
	var cost := node.cost
	if cost > 0:
		rare_parts -= cost
		rare_parts_changed.emit(rare_parts)
	var immediate: bool = check.get("immediate", false)
	if immediate:
		allocated_ids.append(node_id)
		_rebuild_speed_from_allocated()
		save_profile()
		tree_changed.emit()
		_notify_vital_delta(node)
		return {"ok": true, "cost": cost, "pending": false, "id": node_id}
	pending_ids.append(node_id)
	save_profile()
	tree_changed.emit()
	return {"ok": true, "cost": cost, "pending": true, "id": node_id}


func try_refund_pending(node_id: StringName) -> Dictionary:
	if not is_pending(node_id):
		return {"ok": false, "reason": "not_pending"}
	if _has_pending_child(node_id):
		return {"ok": false, "reason": "has_child"}
	var node: _SkillNodeDefinition = _SkillTreeRegistry.get_definition(node_id)
	var cost := node.cost if node else 0
	pending_ids.erase(node_id)
	if cost > 0:
		rare_parts += cost
		rare_parts_changed.emit(rare_parts)
	save_profile()
	tree_changed.emit()
	return {"ok": true, "cost": cost, "id": node_id}


## Move queued requests into the live tree. Call from start_new before vitals boot.
func commit_pending() -> void:
	if pending_ids.is_empty():
		return
	for node_id in pending_ids:
		if node_id not in allocated_ids:
			allocated_ids.append(node_id)
	pending_ids.clear()
	_rebuild_speed_from_allocated()
	save_profile()
	tree_changed.emit()


func debug_reset_tree() -> void:
	allocated_ids = [_SkillTreeRegistry.ORIGIN_ID]
	pending_ids.clear()
	_rebuild_speed_from_allocated()
	save_profile()
	tree_changed.emit()
	van_speed_changed.emit(van_speed_level, get_van_speed())


func get_allocated_vital_max_bonus(vital_id: StringName) -> float:
	return _vital_bonus_from(allocated_ids, vital_id)


func get_pending_vital_max_bonus(vital_id: StringName) -> float:
	return _vital_bonus_from(pending_ids, vital_id)


func set_master_volume(linear: float) -> void:
	master_volume = clampf(linear, 0.0, 1.0)
	_apply_bus_volume(BUS_MASTER, master_volume)
	save_profile()


func set_music_volume(linear: float) -> void:
	music_volume = clampf(linear, 0.0, 1.0)
	_apply_bus_volume(BUS_MUSIC, music_volume)
	save_profile()


func set_sfx_volume(linear: float) -> void:
	sfx_volume = clampf(linear, 0.0, 1.0)
	_apply_bus_volume(BUS_SFX, sfx_volume)
	save_profile()


func apply_audio_settings() -> void:
	_apply_bus_volume(BUS_MASTER, master_volume)
	_apply_bus_volume(BUS_MUSIC, music_volume)
	_apply_bus_volume(BUS_SFX, sfx_volume)


func _apply_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("MetaProgression: missing audio bus %s" % bus_name)
		return
	var silent := linear <= 0.001
	AudioServer.set_bus_mute(idx, silent)
	if silent:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func load_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_ensure_origin()
		_rebuild_speed_from_allocated()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Meta progression save is not valid JSON.")
		_ensure_origin()
		_rebuild_speed_from_allocated()
		return
	var data: Dictionary = parsed
	var file_version := int(data.get("version", -1))
	master_volume = clampf(float(data.get("master_volume", 0.7)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 1.0)), 0.0, 1.0)
	if file_version == 1:
		var old_level := maxi(0, int(data.get("van_speed_level", 0)))
		_migrate_v1_speed(old_level)
		save_profile()
		return
	if file_version != SAVE_VERSION:
		push_warning(
			"Meta progression save uses version %d; this build expects %d."
			% [file_version, SAVE_VERSION]
		)
		_ensure_origin()
		_rebuild_speed_from_allocated()
		return
	rare_parts = maxi(0, int(data.get("rare_parts", 0)))
	allocated_ids = _ids_from_save(data.get("allocated_ids", []))
	pending_ids = _ids_from_save(data.get("pending_ids", []))
	_ensure_origin()
	_rebuild_speed_from_allocated()


func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write meta progression save.")
		return
	file.store_string(JSON.stringify(_profile_dict(), "\t"))


func to_save_data() -> Dictionary:
	return _profile_dict()


func _profile_dict() -> Dictionary:
	var allocated_strings: Array[String] = []
	for node_id in allocated_ids:
		allocated_strings.append(String(node_id))
	var pending_strings: Array[String] = []
	for node_id in pending_ids:
		pending_strings.append(String(node_id))
	return {
		"version": SAVE_VERSION,
		"van_speed_level": van_speed_level,
		"rare_parts": rare_parts,
		"allocated_ids": allocated_strings,
		"pending_ids": pending_strings,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
	}


func _migrate_v1_speed(old_level: int) -> void:
	allocated_ids = [_SkillTreeRegistry.ORIGIN_ID]
	pending_ids.clear()
	rare_parts = 0
	var capped := clampi(old_level, 0, GameBalance.VAN_SPEED_MAX_LEVEL)
	for i in range(1, capped + 1):
		allocated_ids.append(StringName("speed_%d" % i))
	_rebuild_speed_from_allocated()


func _ensure_origin() -> void:
	if _SkillTreeRegistry.ORIGIN_ID not in allocated_ids:
		allocated_ids.insert(0, _SkillTreeRegistry.ORIGIN_ID)


func _rebuild_speed_from_allocated() -> void:
	var levels := 0
	for node_id in allocated_ids:
		var node: _SkillNodeDefinition = _SkillTreeRegistry.get_definition(node_id)
		if node == null:
			continue
		for effect in node.effects:
			if effect:
				levels += effect.van_speed_levels()
	var next := clampi(levels, 0, GameBalance.VAN_SPEED_MAX_LEVEL)
	var changed := next != van_speed_level
	van_speed_level = next
	if changed:
		van_speed_changed.emit(van_speed_level, get_van_speed())


func _vital_bonus_from(ids: Array[StringName], vital_id: StringName) -> float:
	var total := 0.0
	for node_id in ids:
		var node: _SkillNodeDefinition = _SkillTreeRegistry.get_definition(node_id)
		if node == null:
			continue
		for effect in node.effects:
			if effect:
				total += effect.vital_max_bonus(vital_id)
	return total


func _parent_ready(node: _SkillNodeDefinition) -> bool:
	if node.is_origin() or node.parent_id == &"":
		return true
	return is_allocated(node.parent_id) or is_pending(node.parent_id)


func _has_pending_child(node_id: StringName) -> bool:
	for child in _SkillTreeRegistry.get_children_of(node_id):
		if is_pending(child.id):
			return true
	return false


func _apply_immediately() -> bool:
	return GameSession.phase == GameSession.RunPhase.IDLE


func _notify_vital_delta(node: _SkillNodeDefinition) -> void:
	if node == null:
		return
	if GameSession.has_method(&"apply_meta_vital_delta"):
		GameSession.apply_meta_vital_delta(node)


func _ids_from_save(raw) -> Array[StringName]:
	var ids: Array[StringName] = []
	if typeof(raw) != TYPE_ARRAY:
		return ids
	for entry in raw:
		var node_id := StringName(str(entry))
		if node_id != &"" and node_id not in ids:
			ids.append(node_id)
	return ids
