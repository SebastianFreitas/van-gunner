class_name HitscanWeapon
extends Node3D

signal fired(hit: bool)

@export var damage := 1.0
@export var range := 80.0
@export var shots_per_second := 1.0

@onready var camera: Camera3D = get_parent()
@onready var muzzle_flash: OmniLight3D = $MuzzleFlash

var _next_shot_time := 0


func _ready() -> void:
	# Keep legacy hitscan path on the same balance sheet as GunController.
	damage = GameBalance.BASE_DAMAGE_PER_SHOT
	shots_per_second = GameBalance.BASE_FIRE_RATE


func try_fire() -> void:
	var now := Time.get_ticks_msec()
	if now < _next_shot_time:
		return
	_next_shot_time = now + roundi(1000.0 / maxf(shots_per_second, 0.1))

	var origin := camera.global_position
	var end := origin - camera.global_basis.z * range
	var query := PhysicsRayQueryParameters3D.create(origin, end, 4)
	query.collide_with_areas = true
	var player := camera.get_parent().get_parent()
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var did_hit := false
	if not result.is_empty():
		var target := result.collider as Node
		while target and not target.has_method("take_damage"):
			target = target.get_parent()
		if target and target.has_method("take_damage"):
			target.take_damage(damage)
			did_hit = true
	_play_feedback()
	fired.emit(did_hit)


func _play_feedback() -> void:
	muzzle_flash.show()
	var rest_position := position
	position.z += 0.08
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "position", rest_position, 0.09)
	tween.tween_property(muzzle_flash, "light_energy", 0.0, 0.06)
	tween.chain().tween_callback(_reset_flash)


func _reset_flash() -> void:
	muzzle_flash.hide()
	muzzle_flash.light_energy = 2.5
