class_name WindowRaider
extends Node3D

signal attack_landed(amount: float)
signal defeated
signal assault_finished

enum AssaultPhase { IDLE, APPROACH, BREACHING, ENTERING, ATTACKING_BENCH }

@export var attack_damage := 8.0
@export var attack_interval := 1.25
@export var max_health := 3.0
## Agile raiders can climb window bars; door mobs only smash doors.
@export var is_agile := false
## Elite flag for rare weapon drops (agile counts as elite by default).
@export var is_elite := false

## Derived world chase speed for this act. Closing = mob_world_speed - live van speed.
var mob_world_speed := 0.0
## Last computed van-local closing rate (debug / legacy reads).
var approach_speed := 0.0

var _active := false
var health := max_health
var is_defeated := false
var assault_phase: AssaultPhase = AssaultPhase.IDLE
var assigned_breach: BreachPoint
var _last_damage_type: DamageType.Type = DamageType.Type.NORMAL
var _attack_loop_running := false
## Rest color after hit flash (agile window dudes are green-tinted).
var _base_modulate := Color.WHITE

## Lock to this marker each physics tick while standing (van keeps moving).
var _attach_marker: Node3D
## Chase this marker in parent-local space; refreshed every physics tick.
var _move_marker: Node3D
## Fixed speed for non-approach moves (interior). Approach uses live van-relative closing.
var _move_speed := 0.0
var _move_use_van_relative := false
var _move_arrived := true

@onready var sprite: Sprite3D = $Sprite3D
@onready var hitbox: Area3D = $Hitbox
@onready var health_bar: EnemyHealthBar = $EnemyHealthBar
@onready var loot_drop: LootDropComponent = get_node_or_null("LootDrop")
@onready var status_effects: StatusEffectController = $StatusEffects


func _ready() -> void:
	add_to_group(&"enemy")
	if is_agile:
		add_to_group(&"agile")
		if not is_elite:
			is_elite = true
		_base_modulate = Color(0.35, 0.95, 0.45)
		sprite.modulate = _base_modulate
	health = max_health
	# After TravelController (-100) so we see the van's updated PathFollow transform.
	process_physics_priority = -50
	call_deferred("_configure_status_from_traits")


func _physics_process(delta: float) -> void:
	if not _active or is_defeated:
		return
	if _move_marker and is_instance_valid(_move_marker) and not _move_arrived:
		_physics_chase_marker(delta)
	elif _attach_marker and is_instance_valid(_attach_marker):
		_snap_to_marker(_attach_marker)


func _configure_status_from_traits() -> void:
	BoonCombat.configure_enemy_status_effects(self, get_tree())


func begin_assault(breach: BreachPoint, world_speed: float) -> void:
	if _active or is_defeated or breach == null:
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
	assault_phase = AssaultPhase.ATTACKING_BENCH
	var controller := _breach_controller()
	if controller:
		_attach_marker = controller.bench_marker
	_start_attack_loop()


func retreat() -> void:
	if is_defeated:
		return
	_active = false
	_clear_motion()
	_release_breach()
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
		info = DamageInfo.create(float(amount), DamageType.Type.NORMAL)
	if info.amount <= 0.0:
		return
	_last_damage_type = info.damage_type
	var damage_amount := info.get_final_amount()
	if info.damage_type in [DamageType.Type.POISON, DamageType.Type.FIRE]:
		damage_amount = info.amount
	if status_effects:
		damage_amount *= status_effects.get_outgoing_damage_multiplier()
	health = maxf(0.0, health - damage_amount)
	health_bar.update_ratio(health / max_health)
	var popup_pos := info.hit_position
	if popup_pos == Vector3.ZERO:
		popup_pos = global_position + Vector3(0, 1.35, 0)
	CombatFeedback.show_damage(popup_pos, damage_amount, info.is_headshot, info.damage_type)
	if is_zero_approx(health):
		_die()
		return
	_flash_hit(info.damage_type)


func _flash_hit(damage_type: DamageType.Type) -> void:
	var flash_color := Color(1.0, 0.32, 0.26, 1.0)
	match damage_type:
		DamageType.Type.POISON:
			flash_color = Color(0.45, 0.95, 0.35, 1.0)
		DamageType.Type.FIRE:
			flash_color = Color(1.0, 0.45, 0.12, 1.0)
		DamageType.Type.COLD:
			flash_color = Color(0.55, 0.82, 1.0, 1.0)
		DamageType.Type.LIGHTNING:
			flash_color = Color(0.85, 0.75, 1.0, 1.0)
		DamageType.Type.EXPLOSIVE:
			flash_color = Color(1.0, 0.55, 0.2, 1.0)
	sprite.modulate = flash_color
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", _base_modulate, 0.12)


func _die() -> void:
	is_defeated = true
	_active = false
	_clear_motion()
	_release_breach()
	assault_phase = AssaultPhase.IDLE
	health_bar.visible = false
	hitbox.collision_layer = 0
	if has_node("HeadHitbox"):
		$HeadHitbox.collision_layer = 0
	BoonCombat.apply_on_enemy_death(self, _last_damage_type)
	if loot_drop:
		loot_drop.spawn_drops(global_position, get_parent())
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
	if not assigned_breach.is_passable():
		assigned_breach.claim(self)

	await _move_to_marker(assigned_breach.outside_marker, 0.0, true)
	if not _active or is_defeated:
		return
	_attach_marker = assigned_breach.outside_marker

	if not assigned_breach.is_passable():
		assault_phase = AssaultPhase.BREACHING
		await _breach_until_open()
		if not _active or is_defeated:
			return

	_release_breach()
	_attach_marker = null
	assault_phase = AssaultPhase.ENTERING
	var interior_speed := GameBalance.MOB_INTERIOR_SPEED
	await _move_to_marker(assigned_breach.entry_marker, interior_speed, false)
	if not _active or is_defeated:
		return

	var controller := _breach_controller()
	var bench_marker: Node3D = (
		controller.bench_marker
		if controller
		else assigned_breach.entry_marker
	)
	await _move_to_marker(bench_marker, interior_speed, false)
	if not _active or is_defeated:
		return
	_attach_marker = bench_marker

	assault_phase = AssaultPhase.ATTACKING_BENCH
	_start_attack_loop()


func _breach_until_open() -> void:
	while _active and is_inside_tree() and not is_defeated:
		if assigned_breach == null or assigned_breach.is_passable():
			return
		if not assigned_breach.claim(self):
			var controller := _breach_controller()
			if controller:
				var next_point := controller.assign_breach_point(self)
				if next_point and next_point != assigned_breach:
					assigned_breach = next_point
					assault_phase = AssaultPhase.APPROACH
					_attach_marker = null
					if not assigned_breach.is_passable():
						assigned_breach.claim(self)
					await _move_to_marker(assigned_breach.outside_marker, 0.0, true)
					if not _active or is_defeated:
						return
					_attach_marker = assigned_breach.outside_marker
					assault_phase = AssaultPhase.BREACHING
					continue
		var wait_time := _next_attack_wait()
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
		var wait_time := _next_attack_wait()
		await get_tree().create_timer(wait_time).timeout
		if not _active or is_defeated:
			break
		if assault_phase != AssaultPhase.ATTACKING_BENCH:
			continue
		var outgoing := _outgoing_damage()
		attack_landed.emit(outgoing)
		GameSession.damage_van(outgoing)
	_attack_loop_running = false


func _move_to_marker(marker: Node3D, speed: float, van_relative: bool = false) -> void:
	_attach_marker = null
	_move_marker = marker
	_move_speed = speed
	_move_use_van_relative = van_relative
	_move_arrived = false
	while _active and is_inside_tree() and not is_defeated and not _move_arrived:
		await get_tree().physics_frame
	_move_marker = null
	_move_use_van_relative = false


func _current_van_speed() -> float:
	var travel := get_tree().get_first_node_in_group(&"travel_controller") as TravelController
	if travel:
		return travel.travel_speed
	return MetaProgression.get_van_speed()


func _physics_chase_marker(delta: float) -> void:
	var parent_3d := get_parent() as Node3D
	if parent_3d == null or not is_instance_valid(_move_marker):
		_move_arrived = true
		return
	# Marker lives on the moving van — always re-read global, convert to our
	# parent-local space so PathFollow motion is already baked in.
	var target_local := parent_3d.to_local(_move_marker.global_position)
	var to_target := target_local - position
	var remaining := to_target.length()
	var speed := _move_speed
	if _move_use_van_relative:
		# World chase vs live van speed. Boost → lower/negative closing → gain distance.
		speed = mob_world_speed - _current_van_speed()
		approach_speed = speed
	if remaining <= 0.05:
		if speed < 0.0:
			# Van still pulling away — don't latch onto the marker yet.
			return
		position = target_local
		global_transform.basis = _move_marker.global_transform.basis
		_move_arrived = true
		return
	if is_zero_approx(remaining):
		return
	var direction := to_target / remaining
	if speed > 0.0:
		position += direction * minf(speed * delta, remaining)
	elif speed < 0.0:
		# Fall behind along the approach axis (ready for van-boost distance gains).
		position -= direction * (-speed) * delta


func _snap_to_marker(marker: Node3D) -> void:
	var parent_3d := get_parent() as Node3D
	if parent_3d == null or not is_instance_valid(marker):
		return
	position = parent_3d.to_local(marker.global_position)
	global_transform.basis = marker.global_transform.basis


func _clear_motion() -> void:
	_attach_marker = null
	_move_marker = null
	_move_use_van_relative = false
	_move_arrived = true


func _next_attack_wait() -> float:
	var speed_multiplier := status_effects.get_attack_speed_multiplier() if status_effects else 1.0
	return attack_interval / maxf(speed_multiplier, 0.2)


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
