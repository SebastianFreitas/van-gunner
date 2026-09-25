class_name WindowRaider
extends Node3D
## A raider enemy: approaches, breaches a window or door, then attacks the bench or player.

signal attack_landed(amount: float)
signal defeated
signal assault_finished

enum AssaultPhase { IDLE, APPROACH, BREACHING, ENTERING, ATTACKING_BENCH, ATTACKING_PLAYER }

@export var attack_damage := 8.0
@export var attack_interval := 1.25
@export var max_health := 3.0
## Agile raiders can climb window bars; door mobs only smash doors.
@export var is_agile := false
## Elite flag for rare weapon drops. Set explicitly (boss spawn / inspector), never from agility.
@export var is_elite := false
## Act-1 boss portrait. Swapped in by `mark_as_boss`.
const _BOSS_SPRITE := preload("res://scenes/enemies/wanjna.png")
## Window climbers get their own sprite; the scene default is the door goon.
const _AGILE_SPRITE := preload("res://scenes/enemies/agile_raider.png")
const _MELEE_RANGE := 1.2
const _RETARGET_SECS := 0.5
const _WAIT_TIMEOUT := 1.0
const _BENCH_BIAS := 0.6
const _PLAYER_BIAS := 0.4
## Per-frame chase math and target-picking helpers. RefCounted, bound to this node.
const _RaiderMotion := preload("res://scripts/enemies/window_raider_motion.gd")
const _RaiderTargeting := preload("res://scripts/enemies/window_raider_targeting.gd")

## Derived world chase speed for this act. Closing = mob_world_speed - live van speed.
var mob_world_speed := 0.0
## Last computed van-local closing rate (debug / legacy reads).
var approach_speed := 0.0

var _active := false
var health := max_health
var is_defeated := false
var is_boss := false
var assault_phase: AssaultPhase = AssaultPhase.IDLE
var assigned_breach: BreachPoint
var _assigned_vital: Node
var _attack_loop_running := false
## Rest color after hit flash.
var _base_modulate := Color.WHITE

## Lock to this marker each physics tick while standing (van keeps moving).
var _attach_marker: Node3D
## Chase this marker in parent-local space; refreshed every physics tick.
var _move_marker: Node3D
## Parent-local chase target when no marker is set (graph waypoints).
var _move_target_local := Vector3.ZERO
var _move_has_local := false
## Fixed speed for non-approach moves (interior). Approach uses live van-relative closing.
var _move_speed := 0.0
var _move_use_van_relative := false
var _move_arrived := true
var _chase_player := false

var _motion: _RaiderMotion
var _targeting: _RaiderTargeting

@onready var sprite: Sprite3D = $Sprite3D
@onready var hitbox: Area3D = $Hitbox
@onready var health_bar: EnemyHealthBar = $EnemyHealthBar
@onready var loot_drop: LootDropComponent = get_node_or_null("LootDrop")
@onready var status_effects: StatusEffectController = $StatusEffects


func _init() -> void:
	# begin_assault may be called by EncounterDirector right after instancing/add_child,
	# before _ready runs — build the helpers as early as possible.
	_motion = _RaiderMotion.new(self)
	_targeting = _RaiderTargeting.new(self)


func _ready() -> void:
	add_to_group(&"enemy")
	if is_agile:
		add_to_group(&"agile")
		sprite.texture = _AGILE_SPRITE
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	health = max_health
	# After TravelController (-100) so we see the van's updated PathFollow transform.
	process_physics_priority = -50
	call_deferred("_configure_status_from_traits")


func _physics_process(delta: float) -> void:
	if not _active or is_defeated:
		return
	if _chase_player:
		_motion.physics_chase_player(delta)
	elif (
		(_move_has_local or (_move_marker and is_instance_valid(_move_marker)))
		and not _move_arrived
	):
		_motion.physics_chase_target(delta)
	elif _attach_marker and is_instance_valid(_attach_marker):
		_snap_to_marker(_attach_marker)


func _configure_status_from_traits() -> void:
	BoonCombat.configure_enemy_status_effects(self, get_tree())


func begin_assault(breach: BreachPoint, world_speed: float) -> void:
	if _active or is_defeated:
		return
	assigned_breach = breach
	mob_world_speed = world_speed
	approach_speed = world_speed - _current_van_speed()
	_active = true
	_run_assault()


## Legacy helper for debug spawns that already stand on a breach/bench.
func activate() -> void:
	if _active or is_defeated:
		return
	_active = true
	_run_interior_combat()


func is_inside_cabin() -> bool:
	return assault_phase in [
		AssaultPhase.ENTERING,
		AssaultPhase.ATTACKING_BENCH,
		AssaultPhase.ATTACKING_PLAYER,
	]


func mark_as_boss() -> void:
	is_boss = true
	is_elite = true
	add_to_group(&"boss")
	# Wanjna's sprite already carries the sodium-lamp gang color.
	_base_modulate = Color.WHITE
	if sprite:
		sprite.texture = _BOSS_SPRITE
		sprite.modulate = _base_modulate
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD


func retreat() -> void:
	if is_defeated or is_boss:
		return
	_active = false
	_clear_motion()
	_release_breach()
	_targeting.release_nav()
	assault_phase = AssaultPhase.IDLE
	assault_finished.emit()
	var tween := create_tween()
	tween.tween_property(self, "position:y", -2.0, 0.35)
	tween.tween_callback(queue_free)


func take_damage(amount) -> void:
	if is_defeated:
		return
	var info: DamageInfo
	if amount is DamageInfo:
		info = amount
	else:
		info = DamageInfo.create(float(amount))
	var damage_amount := info.get_final_amount()
	if damage_amount <= 0.0:
		return
	if status_effects:
		damage_amount *= status_effects.get_outgoing_damage_multiplier()
	health = maxf(0.0, health - damage_amount)
	health_bar.update_ratio(health / max_health)
	var popup_pos := info.hit_position
	if popup_pos == Vector3.ZERO:
		popup_pos = global_position + Vector3(0, 1.35, 0)
	CombatFeedback.show_damage(popup_pos, damage_amount, info.is_headshot)
	if is_zero_approx(health):
		_die()
		return
	_targeting.flash_hit()


func _die() -> void:
	is_defeated = true
	_active = false
	_clear_motion()
	_release_breach()
	_targeting.release_nav()
	health_bar.visible = false
	hitbox.collision_layer = 0
	if has_node("HeadHitbox"):
		$HeadHitbox.collision_layer = 0
	BoonCombat.apply_on_enemy_death(self)
	if loot_drop:
		loot_drop.spawn_drops(global_position, get_parent())
	assault_phase = AssaultPhase.IDLE
	GameSession.notify_enemy_defeated(self)
	defeated.emit()
	assault_finished.emit()
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "position:y", position.y - 1.5, 0.3)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)


func _run_assault() -> void:
	assault_phase = AssaultPhase.APPROACH
	_attach_marker = null
	while _active and is_inside_tree() and not is_defeated:
		if assigned_breach and is_instance_valid(assigned_breach) and assigned_breach.claim(self):
			break
		assigned_breach = _targeting.request_breach()
		if assigned_breach and assigned_breach.claim(self):
			break
		await _wait_outside_for_breach()
	if not _active or is_defeated or assigned_breach == null:
		return

	await _approach_breach(assigned_breach)
	if not _active or is_defeated:
		return
	_attach_marker = assigned_breach.outside_marker

	if not assigned_breach.is_passable():
		assault_phase = AssaultPhase.BREACHING
		await _breach_until_open()
		if not _active or is_defeated:
			return

	_attach_marker = null
	assault_phase = AssaultPhase.ENTERING
	var interior_speed := GameBalance.MOB_INTERIOR_SPEED
	if assigned_breach and assigned_breach.entry_marker:
		await _move_to_marker(assigned_breach.entry_marker, interior_speed, false)
	_release_breach()
	if not _active or is_defeated:
		return
	await _run_interior_combat()


func _breach_until_open() -> void:
	while _active and is_inside_tree() and not is_defeated:
		if assigned_breach == null or assigned_breach.is_passable():
			return
		if not assigned_breach.claim(self):
			var next_point := _targeting.request_breach()
			if next_point and next_point != assigned_breach:
				assigned_breach = next_point
				assault_phase = AssaultPhase.APPROACH
				_attach_marker = null
				await _approach_breach(assigned_breach)
				if not _active or is_defeated:
					return
				_attach_marker = assigned_breach.outside_marker
				assault_phase = AssaultPhase.BREACHING
				continue
		var wait_time := _targeting.next_attack_wait()
		# Poll so an opened window/door lets them hop in without waiting a full smash.
		var elapsed := 0.0
		while elapsed < wait_time:
			var step := minf(0.1, wait_time - elapsed)
			await get_tree().create_timer(step).timeout
			elapsed += step
			if not _active or is_defeated or assigned_breach == null:
				return
			if assigned_breach.is_passable():
				return
		if not _active or is_defeated or assigned_breach == null:
			return
		if assigned_breach.is_passable():
			return
		assigned_breach.take_damage(_outgoing_damage())


func _start_attack_loop() -> void:
	if _attack_loop_running:
		return
	_attack_loop_running = true
	_attack_loop()


func _attack_loop() -> void:
	while _active and is_inside_tree() and not is_defeated:
		var wait_time := _targeting.next_attack_wait()
		await get_tree().create_timer(wait_time).timeout
		if not _active or is_defeated:
			break
		var outgoing := _outgoing_damage()
		if assault_phase == AssaultPhase.ATTACKING_BENCH:
			var vital := _targeting.living_assigned_vital()
			if vital == null:
				vital = _targeting.pick_vital()
				_assigned_vital = vital
			attack_landed.emit(outgoing)
			if vital and vital.has_method("take_damage"):
				vital.take_damage(outgoing)
			else:
				GameSession.damage_van(outgoing)
		elif assault_phase == AssaultPhase.ATTACKING_PLAYER and _targeting.in_player_melee():
			attack_landed.emit(outgoing)
			GameSession.damage_player(outgoing)
	_attack_loop_running = false


func _move_to_marker(marker: Node3D, speed: float, van_relative: bool = false) -> void:
	if marker == null:
		return
	_attach_marker = null
	_move_marker = marker
	_move_has_local = false
	_move_speed = speed
	_move_use_van_relative = van_relative
	_move_arrived = false
	while _active and is_inside_tree() and not is_defeated and not _move_arrived:
		await get_tree().physics_frame
	_move_marker = null
	_move_use_van_relative = false


func _move_to_local(target_local: Vector3, speed: float, van_relative: bool = false) -> void:
	_attach_marker = null
	_move_marker = null
	_move_target_local = target_local
	_move_has_local = true
	_move_speed = speed
	_move_use_van_relative = van_relative
	_move_arrived = false
	while _active and is_inside_tree() and not is_defeated and not _move_arrived:
		await get_tree().physics_frame
	_move_has_local = false
	_move_use_van_relative = false


func _approach_breach(breach: BreachPoint, speed := 0.0, van_relative := true) -> void:
	if breach == null or breach.outside_marker == null:
		return
	var nav := _targeting.cabin_nav()
	var pts: Array[Vector3] = []
	if nav:
		pts = nav.approach_waypoints(position, breach)
	else:
		var parent_3d := get_parent() as Node3D
		if parent_3d:
			pts.append(parent_3d.to_local(breach.outside_marker.global_position))
	await _follow_path(pts, speed, van_relative)


func _follow_path(points: Array[Vector3], speed: float, van_relative: bool) -> void:
	var nav := _targeting.cabin_nav()
	for pt in points:
		if not _active or is_defeated:
			return
		if _RaiderTargeting.horizontal_xz(position, pt) <= 0.12:
			continue
		if nav and nav.is_passage_point(pt):
			var waited := 0.0
			while _active and not is_defeated and not nav.claim_passage(self):
				await get_tree().create_timer(0.1).timeout
				waited += 0.1
				if waited >= _WAIT_TIMEOUT:
					return
			await _move_to_local(pt, speed, van_relative)
			nav.release_passage(self)
		else:
			await _move_to_local(pt, speed, van_relative)


func _wait_outside_for_breach() -> void:
	var nav := _targeting.cabin_nav()
	if nav:
		var wait_at := nav.try_claim_outside_wait(self)
		if _RaiderTargeting.horizontal_xz(position, wait_at) > 0.4:
			var wait_path: Array[Vector3] = []
			wait_path.append(wait_at)
			await _follow_path(wait_path, 0.0, true)
	var elapsed := 0.0
	while elapsed < _WAIT_TIMEOUT and _active and not is_defeated:
		var got := _targeting.request_breach()
		if got:
			assigned_breach = got
			if nav:
				nav.release_outside_wait(self)
			return
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	if nav:
		nav.release_outside_wait(self)


func _current_van_speed() -> float:
	var travel := get_tree().get_first_node_in_group(&"travel_controller") as TravelController
	if travel:
		return travel.travel_speed
	return MetaProgression.get_van_speed()


func _snap_to_marker(marker: Node3D) -> void:
	var parent_3d := get_parent() as Node3D
	if parent_3d == null or not is_instance_valid(marker):
		return
	position = parent_3d.to_local(marker.global_position)
	global_transform.basis = marker.global_transform.basis


func _clear_motion() -> void:
	_attach_marker = null
	_move_marker = null
	_move_has_local = false
	_move_use_van_relative = false
	_move_arrived = true
	_chase_player = false


func _run_interior_combat() -> void:
	assault_phase = AssaultPhase.ATTACKING_BENCH
	_start_attack_loop()
	while _active and is_inside_tree() and not is_defeated:
		if _targeting.wants_player_target():
			await _pursue_player()
		else:
			await _pursue_vital()
		if not _active or is_defeated:
			return
		var elapsed := 0.0
		while elapsed < _RETARGET_SECS:
			await get_tree().create_timer(0.1).timeout
			elapsed += 0.1
			if not _active or is_defeated:
				return


func _pursue_player() -> void:
	var player := _targeting.player()
	var nav := _targeting.cabin_nav()
	if player == null:
		return
	assault_phase = AssaultPhase.ATTACKING_PLAYER
	_attach_marker = null
	_chase_player = false
	if nav:
		nav.release_vital(self)
		_assigned_vital = null
		var claim := nav.try_claim_melee(self, player)
		if not claim["ok"]:
			await _pursue_vital()
			return
		var dest: Vector3 = claim["local"]
		await _follow_path(_targeting.path_to_dest(dest), GameBalance.MOB_INTERIOR_SPEED, false)
		return
	_chase_player = true
	_move_arrived = false


func _pursue_vital() -> void:
	var nav := _targeting.cabin_nav()
	if nav:
		nav.release_melee(self)
	assault_phase = AssaultPhase.ATTACKING_BENCH
	_chase_player = false
	var vital := _targeting.living_assigned_vital()
	if vital == null or (nav and not nav.is_vital_free(vital, self)):
		vital = _targeting.pick_vital()
	if vital == null or (nav and not nav.claim_vital(vital, self)):
		_assigned_vital = null
		await _wait_at_staging()
		return
	_assigned_vital = vital
	var marker := _targeting.vital_marker(vital)
	if marker == null:
		return
	var dest := _targeting.parent_local(marker)
	if _RaiderTargeting.horizontal_xz(position, dest) > 0.4:
		await _follow_path(
			_targeting.path_to_dest(dest), GameBalance.MOB_INTERIOR_SPEED, false
		)
		if not _active or is_defeated:
			return
	if _RaiderTargeting.horizontal_xz(position, dest) > 0.45:
		return
	_attach_marker = marker


func _wait_at_staging() -> void:
	var nav := _targeting.cabin_nav()
	if nav:
		var dest := nav.staging_local(position)
		if _RaiderTargeting.horizontal_xz(position, dest) > 0.4:
			await _move_to_local(dest, GameBalance.MOB_INTERIOR_SPEED, false)
	var elapsed := 0.0
	while elapsed < _WAIT_TIMEOUT and _active and not is_defeated:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1


func _apply_status_move_speed(speed: float) -> float:
	if speed <= 0.0 or status_effects == null:
		return speed
	return speed * maxf(status_effects.get_move_speed_multiplier(), 0.0)


func _outgoing_damage() -> float:
	var outgoing := attack_damage
	if status_effects:
		outgoing *= status_effects.get_outgoing_damage_multiplier()
	return outgoing


func _release_breach() -> void:
	if assigned_breach and is_instance_valid(assigned_breach):
		assigned_breach.release(self)


func _breach_controller() -> BreachController:
	return get_tree().get_first_node_in_group(&"breach_controller") as BreachController


func _exit_tree() -> void:
	_clear_motion()
	_release_breach()
	_targeting.release_nav()
