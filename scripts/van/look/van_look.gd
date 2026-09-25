class_name VanLook
extends Node3D

## Owns the van's look seed (derived from the run seed) and rebuilds its child look generators.

signal look_rebuilt(seed_value: int)

const _SaveSandbox := preload("res://scripts/core/save_sandbox.gd")

## Used when there is no run (scene dump, menu) or in the smoke sandbox, so baselines stay stable.
const DEFAULT_VAN_SEED := 1337
const GROUP := &"van_look"

## Current look seed; every part RNG derives from it.
var van_seed := DEFAULT_VAN_SEED
var _run_seed_seen := 0          # GameSession.run_seed the current seed was derived from
var _overridden := false         # true after a debug reroll, until the run seed changes


func _ready() -> void:
	add_to_group(GROUP)
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.session_loaded.connect(_on_session_loaded)
	_run_seed_seen = GameSession.run_seed
	rebuild(seed_for_run(GameSession.run_seed))


static func seed_for_run(run_seed: int) -> int:
	if run_seed == 0 or _SaveSandbox.enabled:
		return DEFAULT_VAN_SEED
	return hash([run_seed, "van"])


## One RandomNumberGenerator stream per part so adding a part never reshuffles others.
func rng_for(part_id: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([van_seed, part_id])
	return rng


func rebuild(seed_value: int) -> void:
	van_seed = seed_value
	for child in get_children():
		if child.has_method(&"rebuild_look"):
			child.rebuild_look(self)
	look_rebuilt.emit(van_seed)


func reroll(seed_value: int) -> void:
	_overridden = true
	rebuild(seed_value)


func is_overridden() -> bool:
	return _overridden


func _sync_to_run() -> void:
	if GameSession.run_seed == _run_seed_seen:
		return
	_run_seed_seen = GameSession.run_seed
	_overridden = false
	rebuild(seed_for_run(_run_seed_seen))


func _on_phase_changed(_phase: int) -> void:
	_sync_to_run()


func _on_session_loaded() -> void:
	_sync_to_run()
