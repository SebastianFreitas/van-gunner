extends Node

signal van_speed_changed(level: int, speed: float)

const SAVE_PATH := "user://meta_progression.json"
const SAVE_VERSION := 1
const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"

## FUTURE — persistent street-card back marks (meta, all runs):
## The full card mechanic should let the player scribble / stamp a mark on the
## *back* of a street card so they can recognize it in the face-down boss pick.
## Store those marks here (this JSON on disc), not on the run save, so they
## survive every new run. Key by ActCardDefinition.id. Unmarked cards stay blank.

var van_speed_level := 0
## Linear 0–1 mixer sliders. Master is the overall cap; Music / SFX sit under it.
var master_volume := 0.7
var music_volume := 1.0
var sfx_volume := 1.0


func _ready() -> void:
	load_profile()
	apply_audio_settings()


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
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Meta progression save is not valid JSON.")
		return
	var data: Dictionary = parsed
	var file_version := int(data.get("version", -1))
	if file_version != SAVE_VERSION:
		push_warning(
			"Meta progression save uses version %d; this build expects %d."
			% [file_version, SAVE_VERSION]
		)
		return
	van_speed_level = maxi(0, int(data.get("van_speed_level", 0)))
	master_volume = clampf(float(data.get("master_volume", 0.7)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 1.0)), 0.0, 1.0)


func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write meta progression save.")
		return
	file.store_string(JSON.stringify(_profile_dict(), "\t"))


func to_save_data() -> Dictionary:
	return _profile_dict()


func _profile_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"van_speed_level": van_speed_level,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
	}
