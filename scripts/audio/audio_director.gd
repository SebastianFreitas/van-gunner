extends Node

## Central sound playback. Gameplay code says *what happened* (`&"gun_fire"`),
## never which file or how loud. Register as an autoload named AudioDirector.
##
## No class_name: same autoload parse-cycle rule as GameSession and GameBalance.
##
## Two playback paths, on purpose:
##
## - Non-positional cues go through one AudioStreamPolyphonic player per bus.
##   That gives N simultaneous voices from a single node with no pool, no
##   `finished` bookkeeping, and oldest-first voice stealing for free.
## - Positional cues use a pool of AudioStreamPlayer3D, mirroring ProjectilePool.
##
## Two things that will bite you if you skip them:
##
## 1. Sounds are never parented to the emitter. Enemies queue_free on death and
##    projectiles go back to ProjectilePool, either of which cuts the tail off
##    mid-play. The pooled player outlives the thing that made the noise.
## 2. Positional players are reparented into the emitter's own space, not left
##    at a global position. Enemies live in EnemyContainer under VanRig, so
##    their coordinates are van-local while the rig slides along the travel
##    path. A sound pinned to a world position falls behind the van in about a
##    second and pans off to the rear.

const BANK_PATH := "res://resources/audio/sound_bank.tres"
## Preload-as-type: same autoload parse-cycle rule as GameBalance / GameBalanceData.
const _SoundBank := preload("res://scripts/audio/sound_bank.gd")
const _SoundCue := preload("res://scripts/audio/sound_cue.gd")

## Voices per bus. 24 is generous; the per-cue min_interval does the real work.
const POLYPHONY_PER_BUS := 24
const POSITIONAL_POOL_SIZE := 16
const MUSIC_FADE_SECONDS := 1.2

var bank: _SoundBank

var _bus_players := {}
var _bus_playbacks := {}

var _holder: Node3D
var _pool: Array[AudioStreamPlayer3D] = []
var _active_voices := {}
var _last_played_ms := {}

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: AudioStreamPlayer
var _music_stream: AudioStream
var _music_tween: Tween

## Scene-local connections (gun, doors, breach points) are live while a van run
## is loaded. GameSession signals stay connected for the process lifetime.
var _run_bound := false
var _last_coins := 0


func _ready() -> void:
	# UI clicks and pause stingers must still fire while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_bank()

	_holder = Node3D.new()
	_holder.name = "PositionalSfx"
	add_child(_holder)
	for _i in POSITIONAL_POOL_SIZE:
		_pool.append(_create_positional_player())

	_music_a = _create_music_player(&"MusicA")
	_music_b = _create_music_player(&"MusicB")
	_music_current = _music_a

	_last_coins = GameSession.coins
	GameSession.phase_changed.connect(_on_phase_changed)
	GameSession.coins_changed.connect(_on_coins_changed)
	GameSession.enemy_defeated.connect(_on_enemy_defeated)
	GameSession.session_loaded.connect(_on_session_loaded)


func _load_bank() -> void:
	# CACHE_MODE_REPLACE so an Inspector save wins over a stale cache, same as
	# GameBalance does with game_balance.tres.
	var loaded := ResourceLoader.load(
		BANK_PATH, "", ResourceLoader.CACHE_MODE_REPLACE
	) as _SoundBank
	if loaded == null:
		push_error("AudioDirector: failed to load %s" % BANK_PATH)
		bank = _SoundBank.new()
	else:
		bank = loaded
	bank.build_index()


# --- Public API ---------------------------------------------------------------


## Non-positional: UI, the player's own gun, phase stingers.
func play(id: StringName, volume_offset_db: float = 0.0) -> void:
	var cue := _claim(id)
	if cue == null:
		return
	var playback := _playback_for_bus(cue.bus)
	if playback == null:
		return
	playback.play_stream(cue.stream, 0.0, cue.volume_db + volume_offset_db, 1.0)


## Positional, in the emitter's own coordinate space. Pass the node that made
## the noise — an enemy, a breach point, a shattering window. Safe to call in
## the same frame the emitter is freed.
func play_at(id: StringName, emitter: Node3D, volume_offset_db: float = 0.0) -> void:
	if not is_instance_valid(emitter):
		return
	var cue := _claim(id)
	if cue == null:
		return
	var space := emitter.get_parent() as Node3D
	if space == null:
		space = _holder
	_play_positional(cue, space, emitter.position, volume_offset_db)


## Positional at an explicit point inside a known space (spawn markers,
## EnemyContainer-local impact points).
func play_in_space(
	id: StringName, space: Node3D, local_position: Vector3, volume_offset_db: float = 0.0
) -> void:
	var cue := _claim(id)
	if cue == null or not is_instance_valid(space):
		return
	_play_positional(cue, space, local_position, volume_offset_db)


## Crossfades. Call from a phase_changed handler; passing the stream already
## playing is a no-op, so TRAVELLING -> COMBAT -> TRAVELLING does not restart it.
func play_music(stream: AudioStream, fade_seconds: float = MUSIC_FADE_SECONDS) -> void:
	if stream == _music_stream:
		return
	_music_stream = stream

	var incoming := _music_b if _music_current == _music_a else _music_a
	var outgoing := _music_current
	_music_current = incoming

	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_parallel(true)

	if stream != null:
		incoming.stream = stream
		incoming.volume_db = -60.0
		incoming.play()
		_music_tween.tween_property(incoming, "volume_db", 0.0, fade_seconds)

	if outgoing.playing:
		_music_tween.tween_property(outgoing, "volume_db", -60.0, fade_seconds)
		_music_tween.chain().tween_callback(outgoing.stop)


func stop_music(fade_seconds: float = MUSIC_FADE_SECONDS) -> void:
	play_music(null, fade_seconds)


## Hook scene-local signals on the van run. Gameplay still never calls play();
## this is the autoload listening. Call once per van instance from van._ready.
func bind_run() -> void:
	_run_bound = true
	_last_coins = GameSession.coins

	var gun := get_tree().get_first_node_in_group(&"gun_controller")
	## `fired` is hit/miss for the HUD. Muzzle audio listens to `shot`, which
	## goes off when the round leaves the gun, not when the pellet resolves.
	_connect_once(gun, &"shot", _on_gun_shot)
	_connect_once(gun, &"reloading_changed", _on_reloading_changed)

	var player := get_tree().get_first_node_in_group(&"player")
	if player:
		var usables: Variant = player.get("usables")
		if usables is Node:
			_connect_once(usables, &"usable_activated", _on_usable_activated)

	var rear_doors := get_tree().get_first_node_in_group(&"rear_doors")
	_connect_once(rear_doors, &"glass_shattered", _on_glass_shattered.bind(rear_doors))

	var side_windows := get_tree().get_first_node_in_group(&"side_windows")
	_connect_once(side_windows, &"window_changed", _on_window_changed.bind(side_windows))

	for point in get_tree().get_nodes_in_group(&"breach_points"):
		_connect_once(point, &"breached", _on_breached.bind(point))


func unbind_run() -> void:
	_run_bound = false


# --- Internals ----------------------------------------------------------------


## Resolves the cue and applies the rate gate. Returns null when the cue should
## not sound — callers treat that as "nothing to do", not an error.
func _claim(id: StringName) -> _SoundCue:
	if bank == null:
		return null
	var cue := bank.get_cue(id)
	if cue == null:
		push_warning("AudioDirector: unknown cue %s" % id)
		return null
	# Empty stream = authored id, take not dropped in yet. Skip quietly so the
	# wiring can land before the WAVs do.
	if cue.stream == null:
		return null

	if cue.min_interval > 0.0:
		var now := Time.get_ticks_msec()
		var last: int = _last_played_ms.get(id, -1_000_000)
		if now - last < int(cue.min_interval * 1000.0):
			return null
		_last_played_ms[id] = now

	if cue.positional and _active_voices.get(id, 0) >= cue.max_voices:
		return null
	return cue


func _play_positional(
	cue: _SoundCue, space: Node3D, local_position: Vector3, volume_offset_db: float
) -> void:
	var player := _acquire_positional_player()
	if player == null:
		return

	if player.get_parent() != space:
		player.reparent(space, false)
	player.position = local_position
	player.stream = cue.stream
	player.bus = cue.bus
	player.volume_db = cue.volume_db + volume_offset_db
	player.max_distance = cue.max_distance
	player.unit_size = cue.unit_size
	player.set_meta(&"cue_id", cue.id)

	_active_voices[cue.id] = _active_voices.get(cue.id, 0) + 1
	player.play()


func _acquire_positional_player() -> AudioStreamPlayer3D:
	while not _pool.is_empty():
		var candidate: AudioStreamPlayer3D = _pool.pop_back()
		if is_instance_valid(candidate):
			return candidate
	return _create_positional_player()


func _create_positional_player() -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.finished.connect(_on_positional_finished.bind(player))
	_holder.add_child(player)
	return player


func _on_positional_finished(player: AudioStreamPlayer3D) -> void:
	if not is_instance_valid(player):
		return
	var id: StringName = player.get_meta(&"cue_id", &"")
	if id != &"":
		_active_voices[id] = maxi(_active_voices.get(id, 1) - 1, 0)
	player.stream = null
	# Back under the holder so a freed EnemyContainer never takes the pool with it.
	if is_instance_valid(_holder) and player.get_parent() != _holder:
		player.reparent(_holder, false)
	_pool.append(player)


func _playback_for_bus(bus: StringName) -> AudioStreamPlaybackPolyphonic:
	var cached := _bus_playbacks.get(bus, null) as AudioStreamPlaybackPolyphonic
	if cached != null:
		return cached

	var player := AudioStreamPlayer.new()
	player.name = "Polyphonic_%s" % bus
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = POLYPHONY_PER_BUS
	player.stream = poly
	player.bus = bus
	add_child(player)
	# The polyphonic playback only exists once the host player is running.
	player.play()

	var playback := player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	if playback == null:
		push_error("AudioDirector: no polyphonic playback for bus %s" % bus)
		player.queue_free()
		return null
	_bus_players[bus] = player
	_bus_playbacks[bus] = playback
	return playback


func _create_music_player(player_name: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = &"Music"
	player.volume_db = -60.0
	add_child(player)
	return player


func _connect_once(source: Object, sig: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(sig):
		return
	if source.is_connected(sig, callable):
		return
	source.connect(sig, callable)


# --- Event mapping: *what happened* → cue id ---------------------------------


func _on_gun_shot() -> void:
	play(&"gun_fire")


func _on_reloading_changed(is_reloading: bool) -> void:
	if is_reloading:
		play(&"gun_reload")


func _on_usable_activated(_item, success: bool) -> void:
	if success:
		play(&"usable")


func _on_glass_shattered(_side: StringName, emitter: Object) -> void:
	if emitter is Node3D:
		play_at(&"glass_shatter", emitter as Node3D)


func _on_window_changed(_window_id: StringName, is_open: bool, emitter: Object) -> void:
	if emitter is Node3D:
		var cue: StringName = &"window_open" if is_open else &"window_close"
		play_at(cue, emitter as Node3D)


func _on_breached(point: Object) -> void:
	if point is Node3D:
		play_at(&"breach", point as Node3D)


func _on_phase_changed(phase) -> void:
	match phase:
		GameSession.RunPhase.COMBAT:
			play(&"stinger_combat")
		GameSession.RunPhase.REST:
			play(&"stinger_rest")
		GameSession.RunPhase.ACT_REVEAL:
			play(&"stinger_reveal")
		GameSession.RunPhase.GAME_OVER:
			play(&"stinger_game_over")
			stop_music()


func _on_coins_changed(total: int) -> void:
	var gained := total > _last_coins
	_last_coins = total
	# Skip until a van run is bound so a CONTINUE load does not ding the menu.
	if gained and _run_bound:
		play(&"coin")


func _on_enemy_defeated(enemy: Node) -> void:
	if enemy is Node3D:
		play_at(&"enemy_down", enemy as Node3D)


func _on_session_loaded() -> void:
	_last_coins = GameSession.coins
