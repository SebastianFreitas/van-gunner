class_name WarehouseDummy
extends Node3D

## Standing shootable raider for warehouse hides. Not in `&"enemy"` — street
## waves despawn that group. No assault AI; indoor combat is a later pass.

const _SPRITE := preload("res://scenes/enemies/door_raider.png")

@export var max_health := 3.0

var health := 3.0
var _dead := false
var _base_modulate := Color.WHITE
var _sprite: Sprite3D


func _ready() -> void:
	health = max_health
	_build()


func drop_to(dest: Vector3, duration := 0.42) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position", dest, duration)


func take_damage(amount = null) -> void:
	if _dead:
		return
	var info: DamageInfo
	if amount is DamageInfo:
		info = amount
	else:
		info = DamageInfo.create(float(amount) if amount != null else 1.0, DamageType.Type.NORMAL)
	if info.amount <= 0.0:
		return
	var damage_amount := info.get_final_amount()
	health = maxf(0.0, health - damage_amount)
	var popup_pos := info.hit_position
	if popup_pos == Vector3.ZERO:
		popup_pos = global_position + Vector3(0.0, 1.35, 0.0)
	CombatFeedback.show_damage(popup_pos, damage_amount, info.is_headshot, info.damage_type)
	if is_zero_approx(health):
		_die()
		return
	_flash_hit()


func _build() -> void:
	_sprite = Sprite3D.new()
	_sprite.name = "Sprite3D"
	_sprite.texture = _SPRITE
	_sprite.pixel_size = 0.006
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.render_priority = 2
	_sprite.position = Vector3(0.0, 1.15, 0.0)
	add_child(_sprite)

	var hitbox := Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.monitorable = true
	hitbox.position = Vector3(0.0, 0.95, 0.0)
	add_child(hitbox)
	var body_shape := CapsuleShape3D.new()
	body_shape.radius = 0.42
	body_shape.height = 1.7
	var body_col := CollisionShape3D.new()
	body_col.shape = body_shape
	hitbox.add_child(body_col)

	var head := Area3D.new()
	head.name = "HeadHitbox"
	head.add_to_group(&"head_hitbox")
	head.collision_layer = 4
	head.collision_mask = 0
	head.monitoring = false
	head.monitorable = true
	head.position = Vector3(0.0, 1.72, 0.0)
	add_child(head)
	var head_shape := SphereShape3D.new()
	head_shape.radius = 0.28
	var head_col := CollisionShape3D.new()
	head_col.shape = head_shape
	head.add_child(head_col)


func _flash_hit() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(1.0, 0.32, 0.26, 1.0)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", _base_modulate, 0.12)


func _die() -> void:
	_dead = true
	AudioDirector.play_at(&"enemy_down", self)
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 2.0, 0.35)
	tween.tween_callback(queue_free)
