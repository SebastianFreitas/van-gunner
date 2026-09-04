extends Node

signal van_speed_changed(level: int, speed: float)

const SAVE_PATH := "user://meta_progression.json"
const SAVE_VERSION := 1

## FUTURE — persistent street-card back marks (meta, all runs):
## The full card mechanic should let the player scribble / stamp a mark on the
## *back* of a street card so they can recognize it in the face-down boss pick.
## Store those marks here (this JSON on disc), not on the run save, so they
## survive every new run. Key by ActCardDefinition.id. Unmarked cards stay blank.

var van_speed_level := 0


func _ready() -> void:
	load_profile()


func get_van_speed() -> float:
	return GameBalance.get_van_speed_for_level(van_speed_level)


func can_upgrade_van_speed() -> bool:
	return van_speed_level < GameBalance.VAN_SPEED_MAX_LEVEL


func get_van_speed_upgrade_cost() -> int:
	return GameBalance.get_van_speed_upgrade_cost(van_speed_level)


func try_upgrade_van_speed(coin_source: int) -> Dictionary:
	if not can_upgrade_van_speed():
		return {"ok": false, "reason": "max_level"}
	var cost := get_van_speed_upgrade_cost()
	if coin_source < cost:
		return {"ok": false, "reason": "insufficient_coins", "cost": cost}
	van_speed_level += 1
	save_profile()
	van_speed_changed.emit(van_speed_level, get_van_speed())
	return {"ok": true, "cost": cost, "level": van_speed_level, "speed": get_van_speed()}


func load_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Meta progression save is not valid JSON.")
		return
	var data: Dictionary = parsed
	if int(data.get("version", -1)) != SAVE_VERSION:
		push_warning("Meta progression save uses an unsupported version.")
		return
	van_speed_level = maxi(0, int(data.get("van_speed_level", 0)))


func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write meta progression save.")
		return
	file.store_string(
		JSON.stringify({"version": SAVE_VERSION, "van_speed_level": van_speed_level}, "\t")
	)


func to_save_data() -> Dictionary:
	return {"version": SAVE_VERSION, "van_speed_level": van_speed_level}
