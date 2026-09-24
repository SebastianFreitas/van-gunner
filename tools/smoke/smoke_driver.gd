extends Node

## Drives a full headless playthrough of one van run to prove the game boots,
## the class/boon/rest UI flows work end to end, and the balance numbers stay
## deterministic. Writes a fingerprint of stats, pools and deck/wave plans to
## user://, which tools/smoke.py diffs against a committed baseline. Runs only
## when SaveSandbox.enabled, so it never touches a real save on disk.

const _WATCHDOG_SECONDS := 270.0
const _Fingerprint := preload("res://tools/smoke/smoke_fingerprint.gd")
const _Route := preload("res://tools/smoke/smoke_route.gd")

var _watchdog: SceneTreeTimer
## Direction chosen at the previous forced fork, so the next one picks differently.
var _last_route_direction: StringName = &""
## Route helper for the fork/side-stop pass; held so it lives through the awaits.
var _route: RefCounted


func _ready() -> void:
	_watchdog = get_tree().create_timer(_WATCHDOG_SECONDS)
	_watchdog.timeout.connect(func() -> void: _fail("watchdog timeout"))
	_run()


func _run() -> void:
	if not SaveSandbox.enabled:
		_fail("save sandbox is off; run with -- --smoke-sandbox")
		return
	if not DebugConfig.ENABLED:
		_fail("DebugConfig.ENABLED is false")
		return

	var mtimes := _record_user_mtimes()

	var lines := PackedStringArray()
	seed(12345)
	_Fingerprint.fingerprint_class_stats(lines)
	_Fingerprint.fingerprint_pools(lines)
	_Fingerprint.fingerprint_act_deck(lines)
	_Fingerprint.fingerprint_waves(lines)
	_Fingerprint.fingerprint_rest_offer(lines)

	# Save slots are 1-based; slot 0 would be an out-of-range no-op.
	GameSession.start_new(1)
	SceneRouter.go_to_van()
	if not await _wait_for_van_ready():
		return
	await _frames(10)
	if GameSession.phase != GameSession.RunPhase.IDLE:
		_fail("expected IDLE phase after entering the van, got %d" % GameSession.phase)
		return

	await _seconds(2.0)

	var van := get_tree().get_first_node_in_group(&"van_run")
	var gun_stats: GunStatsController = get_tree().get_first_node_in_group(&"gun_stats")

	if not await _class_panel_pass(van, gun_stats, lines):
		return
	if not await _boons_pass(van, gun_stats, lines):
		return
	if not await _bench_pass(van):
		return
	if not await _run_pass(van):
		return
	if not await _rest_offer_pass(van):
		return
	_route = _Route.new(self)
	if not await _route.fork_pass():
		return

	await _save_round_trip_pass()

	_check_user_mtimes_unchanged(mtimes)
	_Fingerprint.write_fingerprint(lines)
	_log("done")
	get_tree().quit(0)


## --- Setup helpers -----------------------------------------------------------


func _record_user_mtimes() -> Dictionary:
	var mtimes := {}
	mtimes["user://meta_progression.json"] = FileAccess.get_modified_time(
		"user://meta_progression.json"
	)
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var path := SaveManager.SAVE_PATH % slot
		mtimes[path] = FileAccess.get_modified_time(path)
	return mtimes


func _check_user_mtimes_unchanged(before: Dictionary) -> void:
	for path in before:
		var now := FileAccess.get_modified_time(path)
		if now != before[path]:
			_fail("user:// file modified: %s" % path)


func _wait_for_van_ready() -> bool:
	var elapsed := 0.0
	while elapsed < 30.0:
		if (
			get_tree().get_first_node_in_group(&"van_run")
			and get_tree().get_first_node_in_group(&"gun_stats")
			and get_tree().get_first_node_in_group(&"player")
		):
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_fail("timed out waiting for the van scene to be ready")
	return false


## --- Playthrough passes --------------------------------------------------------


func _class_panel_pass(van: Node, gun_stats: GunStatsController, lines: PackedStringArray) -> bool:
	var panel: Control = van.get("_class_panel")
	if panel == null:
		_fail("van._class_panel is null")
		return false
	panel.open()
	await _frames(2)
	for id in ClassCatalog.list_ids():
		panel._on_card_pressed(id)
		await _frames(3)
		if GameSession.class_id != id:
			_fail("expected class_id %s after pressing its card, got %s" % [id, GameSession.class_id])
			return false
		lines.append(_Fingerprint.stats_line("ingame " + String(id), gun_stats.get_stats()))
	panel.close()
	await _frames(2)
	return true


func _boons_pass(van: Node, gun_stats: GunStatsController, lines: PackedStringArray) -> bool:
	var panel: Control = van.get("_class_panel")
	for command in ["give double_damage", "give chew_tobacco", "give max_hp_phys"]:
		var result := DebugCommands.run(command)
		_log(result)
		if result.begins_with("Unknown") or result.begins_with("Player not found"):
			_fail("debug command failed: %s -> %s" % [command, result])
			return false
	await _frames(3)

	lines.append("[with_boons]")
	var ids := ClassCatalog.list_ids()
	for id in ids:
		panel._on_card_pressed(id)
		await _frames(3)
		lines.append(_Fingerprint.stats_line("boons " + String(id), gun_stats.get_stats()))
	lines.append(
		"player_max_health=%.4f van_max_health=%.4f" % [
			GameSession.get_max_player_health(), GameSession.get_max_van_health()
		]
	)
	if not ids.is_empty():
		panel._on_card_pressed(ids[0])
	return true


func _bench_pass(van: Node) -> bool:
	var bench: Control = van.get("bench_screen")
	if bench == null:
		_fail("van.bench_screen is null")
		return false
	bench.open()
	await _frames(5)
	bench.close()
	await _frames(2)

	var panel: Control = van.get("_class_panel")
	panel.open()
	await _frames(5)
	panel.close()
	return true


func _run_pass(van: Node) -> bool:
	GameSession.begin_run()
	await _frames(5)
	if GameSession.phase != GameSession.RunPhase.TRAVELLING:
		_fail("expected TRAVELLING phase after begin_run, got %d" % GameSession.phase)
		return false
	await _seconds(3.0)

	for _i in range(2):
		_log(DebugCommands.run("summon enemy"))

	var gun_controller := get_tree().get_first_node_in_group(&"gun_controller")
	if gun_controller == null:
		_fail("no gun_controller node found")
		return false
	for _i in range(60):
		gun_controller.try_fire()
		await get_tree().process_frame
	await _seconds(2.0)

	_log(DebugCommands.run("chill"))
	await _frames(5)
	return true


func _rest_offer_pass(van: Node) -> bool:
	GameSession.wave_count = maxi(GameSession.wave_count, 1)
	var card_ids := ActCardRegistry.list_ids()
	if card_ids.is_empty():
		_fail("ActCardRegistry.list_ids() is empty")
		return false
	GameSession.pending_boon_card_id = card_ids[0]

	var rewards := get_tree().get_first_node_in_group(&"boon_reward_controller")
	if rewards == null:
		_fail("no boon_reward_controller node found")
		return false

	GameSession.set_phase(GameSession.RunPhase.REST)
	await _frames(5)
	if not rewards.is_awaiting_resolution():
		_fail("boon_reward_controller did not start awaiting resolution")
		return false

	var boon_choice: Control = van.get("_boon_choice")
	var button := _first_button(boon_choice)
	if button == null:
		_fail("no visible button found in the boon choice panel")
		return false
	button.pressed.emit()

	var elapsed := 0.0
	while elapsed < 5.0 and rewards.is_awaiting_resolution():
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if rewards.is_awaiting_resolution():
		_fail("boon_reward_controller still awaiting resolution after the click")
		return false
	if GameSession.pending_boon_card_id != &"":
		_fail("pending_boon_card_id was not cleared after resolving the rest offer")
		return false
	return true


## Exercises GameSession.to_save_data/load_from_data headless: saves the live
## session, loads it straight back into the same session and checks nothing
## drifted, the way CONTINUE would minus the actual file read.
func _save_round_trip_pass() -> void:
	var before: Dictionary = GameSession.to_save_data()
	GameSession.load_from_data(GameSession.selected_slot, before)
	await _frames(5)
	var after: Dictionary = GameSession.to_save_data()

	# load_from_data maps mid-street phases to TRAVELLING, so a phase that was
	# mid-street at save time legitimately differs after the load.
	var mid_street_phases := [
		GameSession.RunPhase.COMBAT,
		GameSession.RunPhase.ROUTE_CHOICE,
		GameSession.RunPhase.REST,
		GameSession.RunPhase.TURNING,
		GameSession.RunPhase.PARKING,
		GameSession.RunPhase.STOP,
		GameSession.RunPhase.ACT_REVEAL,
		GameSession.RunPhase.BOSS_PICK,
	]
	if before.get("phase") in mid_street_phases:
		_log("save round-trip: dropping phase key, %d was mid-street" % before["phase"])
		before = before.duplicate()
		after = after.duplicate()
		before.erase("phase")
		after.erase("phase")

	var before_json := JSON.stringify(before, "", true)
	var after_json := JSON.stringify(after, "", true)
	if before_json != after_json:
		_log(before_json)
		_log(after_json)
		_fail("save round-trip mismatch")
		return
	_log("save round-trip ok")


func _phase_name() -> String:
	return GameSession.RunPhase.keys()[GameSession.phase]


func _first_button(n: Node) -> Button:
	if n == null:
		return null
	if n is Button and (n as Control).visible:
		return n as Button
	for child in n.get_children():
		var found := _first_button(child)
		if found:
			return found
	return null


## --- Small awaitables and logging ---------------------------------------------


func _wait_phase(target: GameSession.RunPhase, timeout_s: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_s:
		if GameSession.phase == target:
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return false


func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_s:
		if cond.call():
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return false


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _fail(msg: String) -> void:
	push_error("SMOKE: " + msg)
	get_tree().quit(1)


func _log(msg) -> void:
	print("SMOKE: " + str(msg))
