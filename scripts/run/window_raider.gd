class_name WindowRaider
extends Node3D

signal attack_landed(amount: float)
signal defeated

@export var attack_damage := 8.0
@export var attack_interval := 1.25
@export var max_health := 3.0

var _active := false
var health := max_health
var is_defeated := false

@onready var sprite: Sprite3D = $Sprite3D
@onready var hitbox: Area3D = $Hitbox
@onready var loot_drop: LootDropComponent = get_node_or_null("LootDrop")
@onready var status_effects: StatusEffectController = $StatusEffects


func _ready() -> void:
	add_to_group(&"enemy")


func activate() -> void:
	if _active:
		return
	_active = true
	_attack_loop()


func retreat() -> void:
	if is_defeated:
		return
	_active = false
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
	var damage_amount := info.get_final_amount()
	if info.damage_type in [DamageType.Type.POISON, DamageType.Type.FIRE]:
		damage_amount = info.amount
	health = maxf(0.0, health - damage_amount)
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
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)


func _die() -> void:
	is_defeated = true
	_active = false
	hitbox.collision_layer = 0
	if has_node("HeadHitbox"):
		$HeadHitbox.collision_layer = 0
	if loot_drop:
		loot_drop.spawn_drops(global_position, get_parent())
	GameSession.notify_enemy_defeated(self)
	defeated.emit()
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "position:y", position.y - 1.5, 0.3)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)


func _attack_loop() -> void:
	while _active and is_inside_tree():
		var speed_multiplier := status_effects.get_attack_speed_multiplier() if status_effects else 1.0
		var wait_time := attack_interval / maxf(speed_multiplier, 0.2)
		await get_tree().create_timer(wait_time).timeout
		if _active:
			attack_landed.emit(attack_damage)
