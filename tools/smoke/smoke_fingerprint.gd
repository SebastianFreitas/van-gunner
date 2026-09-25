extends RefCounted

## Static helpers that build the smoke driver's fingerprint lines (class stats,
## pools, act deck, waves, rest offer) and write them to user://. Split out of
## smoke_driver.gd; every seed(...) call stays exactly where it was so the RNG
## sequence, and therefore the fingerprint output, is unchanged.


## Wave bounds the fingerprint plans with. game_balance.tres often carries an
## uncommitted owner edit of segment_wave_min/max; pinning them here keeps the
## baseline reproducible on a clean clone (cloud sessions) and tracks the planning
## code, not the tuning. These are the values the baseline was blessed with.
const WAVE_MIN_PIN := 2
const WAVE_MAX_PIN := 4


static func stats_line(label: String, s: GunStats) -> String:
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


static func fingerprint_class_stats(lines: PackedStringArray) -> void:
	lines.append("[class_stats]")
	var ids := ClassCatalog.list_ids()
	var sorted_ids: Array[String] = []
	for id in ids:
		sorted_ids.append(String(id))
	sorted_ids.sort()
	for id_str in sorted_ids:
		var id := StringName(id_str)
		var stats := GunStatsController.build_class_stats(ClassCatalog.load_by_id(id))
		lines.append(stats_line(id_str, stats))


static func fingerprint_pools(lines: PackedStringArray) -> void:
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


static func fingerprint_act_deck(lines: PackedStringArray) -> void:
	lines.append("[act_deck]")
	GameSession.run_seed = 12345
	GameSession.run_act = 1
	var deck_ids := GameSession._build_act_deck_ids()
	var id_strings := PackedStringArray()
	for id in deck_ids:
		id_strings.append(String(id))
	lines.append(" ".join(id_strings))


static func fingerprint_waves(lines: PackedStringArray) -> void:
	lines.append("[waves]")
	var saved_min: int = GameBalance.data.segment_wave_min
	var saved_max: int = GameBalance.data.segment_wave_max
	GameBalance.data.segment_wave_min = WAVE_MIN_PIN
	GameBalance.data.segment_wave_max = WAVE_MAX_PIN
	for route_step in range(1, 7):
		var plan := GameBalance.build_segment_wave_plan(route_step)
		var plan_strings := PackedStringArray()
		for value in plan:
			plan_strings.append(str(value))
		lines.append("step %d: %s" % [route_step, " ".join(plan_strings)])
	GameBalance.data.segment_wave_min = saved_min
	GameBalance.data.segment_wave_max = saved_max


static func fingerprint_rest_offer(lines: PackedStringArray) -> void:
	lines.append("[rest_offer]")
	seed(12345)
	var choices := ItemPoolRegistry.pick_rest_choices(
		3, [&"chew_tobacco", &"explosive_rounds"]
	)
	var id_strings := PackedStringArray()
	for item in choices:
		id_strings.append(String(item.id))
	lines.append(" ".join(id_strings))


static func write_fingerprint(lines: PackedStringArray) -> void:
	var path := ProjectSettings.globalize_path("res://tools/smoke/fingerprint.txt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
