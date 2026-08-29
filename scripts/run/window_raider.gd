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


func take_damage(amount: float) -> void:
	if amount <= 0.0 or is_defeated:
		return
	health = maxf(0.0, health - amount)
	if is_zero_approx(health):
		_die()
		return
	sprite.modulate = Color(1.0, 0.32, 0.26, 1.0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)


func _die() -> void:
	is_defeated = true
	_active = false
	hitbox.collision_layer = 0
	defeated.emit()
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "position:y", position.y - 1.5, 0.3)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)


func _attack_loop() -> void:
	while _active and is_inside_tree():
		await get_tree().create_timer(attack_interval).timeout
		if _active:
			attack_landed.emit(attack_damage)
