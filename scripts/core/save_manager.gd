extends Node

const SLOT_COUNT := 3
const SAVE_VERSION := 4
const SAVE_PATH := "user://save_slot_%d.json"


func has_save(slot: int) -> bool:
	return _valid_slot(slot) and FileAccess.file_exists(SAVE_PATH % slot)


func get_slot_summary(slot: int) -> Dictionary:
	if not has_save(slot):
		return {"exists": false, "compatible": false, "slot": slot}
	var data := _read_slot_dict(slot)
	if data.is_empty():
		return {
			"exists": true,
			"compatible": false,
			"slot": slot,
			"file_version": -1,
		}
	var file_version := int(data.get("version", -1))
	if file_version != SAVE_VERSION:
		return {
			"exists": true,
			"compatible": false,
			"slot": slot,
			"file_version": file_version,
			"route_step": int(data.get("route_step", 0)),
			"van_health": float(data.get("van_health", 100.0)),
		}
	return {
		"exists": true,
		"compatible": true,
		"slot": slot,
		"file_version": file_version,
		"route_step": int(data.get("route_step", 0)),
		"van_health": float(data.get("van_health", 100.0)),
		"saved_at": str(data.get("saved_at", "Unknown")),
	}


func load_slot(slot: int) -> bool:
	var data := load_slot_data(slot)
	if data.is_empty():
		return false
	GameSession.load_from_data(slot, data)
	return true


func load_slot_data(slot: int) -> Dictionary:
	var data := _read_slot_dict(slot)
	if data.is_empty():
		return {}
	var file_version := int(data.get("version", -1))
	if file_version != SAVE_VERSION:
		push_warning(
			"Save slot %d uses version %d; this build expects %d."
			% [slot, file_version, SAVE_VERSION]
		)
		return {}
	return data


func save_active_session() -> bool:
	var slot: int = GameSession.selected_slot
	if not _valid_slot(slot):
		return false
	var file := FileAccess.open(SAVE_PATH % slot, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save slot %d." % slot)
		return false
	file.store_string(JSON.stringify(GameSession.to_save_data(), "\t"))
	return true


func delete_slot(slot: int) -> bool:
	if not _valid_slot(slot) or not has_save(slot):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH % slot)) == OK


func _read_slot_dict(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var file := FileAccess.open(SAVE_PATH % slot, FileAccess.READ)
	if file == null:
		push_warning("Could not open save slot %d." % slot)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Save slot %d is not valid JSON data." % slot)
		return {}
	return parsed


func _valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT
