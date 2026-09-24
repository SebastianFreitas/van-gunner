extends Node

## Drives a full headless playthrough of one van run to prove the game boots,
## the class/boon/rest UI flows work end to end, and the balance numbers stay
## deterministic. Writes a fingerprint of stats, pools and deck/wave plans to
## user://, which tools/smoke.py diffs against a committed baseline. Runs only
## when SaveSandbox.enabled, so it never touches a real save on disk.

const _WATCHDOG_SECONDS := 150.0

var _watchdog: SceneTreeTimer


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
	_fingerprint_class_stats(lines)
	_fingerprint_pools(lines)
	_fingerprint_act_deck(lines)
	_fingerprint_waves(lines)
	_fingerprint_rest_offer(lines)

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

	_check_user_mtimes_unchanged(mtimes)
	_write_fingerprint(lines)
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


## --- Fingerprint sections -----------------------------------------------------


func _stats_line(label: String, s: GunStats) -> String:
	var parts := PackedStringArray([label])
	parts.append("fire_rate=%.4f" % s.fire_rate)
	parts.append("damage_per_shot=%.4f" % s.damage_per_shot)
	parts.append("bullet_speed=%.4f" % s.bullet_speed)
	parts.append("bullet_weight=%.4f" % s.bullet_weight)
	parts.append("bullet_size=%.4f" % s.bullet_size)
	parts.append("reload_speed=%.4f" % s.reload_speed)
	parts.append("mag_size=%d" % s.mag_size)
	parts.append("aim_range=%.4f" % s.aim_range)
	parts.append("explosion_radius=%.4f" % s.explosion_radius)
	parts.append("max_bounces=%d" % s.max_bounces)
	parts.append("bounce_speed_retention=%.4f" % s.bounce_speed_retention)
	parts.append("bounce_damage_retention=%.4f" % s.bounce_damage_retention)
	parts.append("pellets_per_shot=%d" % s.pellets_per_shot)
	parts.append("pellet_spread_degrees=%.4f" % s.pellet_spread_degrees)
	return " ".join(parts)


func _fingerprint_class_stats(lines: PackedStringArray) -> void:
	lines.append("[class_stats]")
	var ids := ClassCatalog.list_ids()
	var sorted_ids: Array[String] = []
	for id in ids:
		sorted_ids.append(String(id))
	sorted_ids.sort()
	for id_str in sorted_ids:
		var id := StringName(id_str)
		var stats := GunStatsController.build_class_stats(ClassCatalog.load_by_id(id))
		lines.append(_stats_line(id_str, stats))


func _fingerprint_pools(lines: PackedStringArray) -> void:
	lines.append("[pools]")
	var keys := ItemPoolRegistry._POOL_PATHS.keys()
	keys.sort()
	for key in keys:
		var pool: LootPool = ItemPoolRegistry.get_pool(key)
		if pool == null:
			lines.append("%s <missing>" % key)
			continue
		for entry in pool.entries:
			lines.append("%s %s %.4f" % [key, entry.item.id, entry.weight])


func _fingerprint_act_deck(lines: PackedStringArray) -> void:
	lines.append("[act_deck]")
	GameSession.run_seed = 12345
	GameSession.run_act = 1
	var deck_ids := GameSession._build_act_deck_ids()
	var id_strings := PackedStringArray()
	for id in deck_ids:
		id_strings.append(String(id))
	lines.append(" ".join(id_strings))


func _fingerprint_waves(lines: PackedStringArray) -> void:
	lines.append("[waves]")
	for route_step in range(1, 7):
		var plan := GameBalance.build_segment_wave_plan(route_step)
		var plan_strings := PackedStringArray()
		for value in plan:
			plan_strings.append(str(value))
		lines.append("step %d: %s" % [route_step, " ".join(plan_strings)])


func _fingerprint_rest_offer(lines: PackedStringArray) -> void:
	lines.append("[rest_offer]")
	seed(12345)
	var choices := ItemPoolRegistry.pick_rest_choices(
		3, [&"chew_tobacco", &"explosive_rounds"]
	)
	var id_strings := PackedStringArray()
	for item in choices:
		id_strings.append(String(item.id))
	lines.append(" ".join(id_strings))


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
		lines.append(_stats_line("ingame " + String(id), gun_stats.get_stats()))
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
		lines.append(_stats_line("boons " + String(id), gun_stats.get_stats()))
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


func _write_fingerprint(lines: PackedStringArray) -> void:
	var path := ProjectSettings.globalize_path("res://tools/smoke/fingerprint.txt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()


## --- Small awaitables and logging ---------------------------------------------


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
