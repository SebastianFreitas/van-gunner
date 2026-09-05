class_name Pickup
extends Area3D

## Walk into a floor pickup to use it. Idle pickups bob, spin, and gently
## push/slide away from each other — Binding of Isaac style.

@export var item: ItemDefinition

@export var pickup_radius := 0.18
## Larger collision used only for projectile hits — walk pickup keeps pickup_radius.
@export var shot_hit_radius := 0.35
@export var bob_height := 0.12
@export var bob_speed := 2.4
@export var spin_speed := 1.4
## Safety net: street pickups vacuum into the hopper after this many seconds.
@export var lifetime := 45.0

@export_group("Personal Space")
@export var personal_space_radius := 0.30
@export var separation_speed := 2.5
## How hard overlapping pickups shove each other (adds slide velocity).
@export var separation_impulse := 1.5
## How quickly slide velocity bleeds off — lower = longer slides.
@export var slide_friction := 2.2

@export_group("Animation")
@export var spin_duration := 2.4
@export var face_duration := 1.6
@export var face_turn_speed := 7.0

enum _AnimState { SPIN, FACE }

var _stashed := false
var _used := false
var _collector: Node3D
var _bob_initialized := false
var _base_y := 0.0
var _time := 0.0
var _anim_state: int = _AnimState.SPIN
var _anim_timer := 0.0
var _slide_velocity := Vector3.ZERO
var _shot_hit_area: Area3D

@onready var sprite: Sprite3D = get_node_or_null("Sprite3D") as Sprite3D


func _ready() -> void:
	if item:
		if sprite:
			sprite.texture = item.icon
		if item.pickup_radius > 0.0:
			pickup_radius = item.pickup_radius
		if item.shot_hit_radius > 0.0:
			shot_hit_radius = item.shot_hit_radius

	add_to_group(&"pickup")
	_apply_pickup_radius()
	_apply_shot_hit_radius()
	body_entered.connect(_on_body_entered)
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_expired)


func _process(delta: float) -> void:
	if _used:
		return
	if not _bob_initialized:
		_base_y = position.y
		_bob_initialized = true
	_time += delta
	position.y = _base_y + sin(_time * bob_speed) * bob_height
	_apply_separation(delta)
	_apply_sliding(delta)
	_update_animation(delta)


func _apply_pickup_radius() -> void:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not shape_node:
		return
	var sphere := SphereShape3D.new()
	sphere.radius = pickup_radius
	shape_node.shape = sphere


func _apply_shot_hit_radius() -> void:
	if shot_hit_radius <= pickup_radius:
		if _shot_hit_area:
			_shot_hit_area.queue_free()
			_shot_hit_area = null
		return
	if not _shot_hit_area:
		_shot_hit_area = Area3D.new()
		_shot_hit_area.name = &"ShotHitArea"
		_shot_hit_area.collision_layer = collision_layer
		_shot_hit_area.collision_mask = 0
		_shot_hit_area.monitorable = true
		_shot_hit_area.monitoring = false
		add_child(_shot_hit_area)
		var shape_node := CollisionShape3D.new()
		_shot_hit_area.add_child(shape_node)
	var shape := _shot_hit_area.get_child(0) as CollisionShape3D
	var sphere := SphereShape3D.new()
	sphere.radius = shot_hit_radius
	shape.shape = sphere


func _set_shot_hit_active(active: bool) -> void:
	if _shot_hit_area:
		_shot_hit_area.set_deferred("monitorable", active)


func _apply_separation(delta: float) -> void:
	if personal_space_radius <= 0.0:
		return
	var push := Vector3.ZERO
	var here := global_position if not _stashed else _local_horizontal_position()
	for other in _nearby_pickups():
		if other == self or not (other is Pickup):
			continue
		var other_pickup: Pickup = other
		var other_pos := (
			other_pickup.global_position
			if not _stashed
			else other_pickup._local_horizontal_position()
		)
		var offset := here - other_pos
		offset.y = 0.0
		var min_distance := personal_space_radius + _personal_space_of(other_pickup)
		var distance := offset.length()
		if distance < 0.001:
			var angle := float(get_instance_id() % 360) * (TAU / 360.0)
			push += Vector3(cos(angle), 0.0, sin(angle)) * min_distance
		elif distance < min_distance:
			push += offset.normalized() * (min_distance - distance)
	if push == Vector3.ZERO:
		return
	if _stashed:
		_slide_velocity += push * separation_impulse
		_slide_velocity.y = 0.0
	else:
		global_position += push * separation_speed * delta


func _apply_sliding(delta: float) -> void:
	if _slide_velocity.length_squared() < 0.00001:
		_slide_velocity = Vector3.ZERO
		return
	position += _slide_velocity * delta
	_slide_velocity = _slide_velocity.lerp(Vector3.ZERO, slide_friction * delta)


func _nearby_pickups() -> Array:
	var results: Array = []
	if _stashed:
		var parent_node := get_parent()
		if not parent_node:
			return results
		for child in parent_node.get_children():
			if child is Pickup and child != self and child._stashed and not child._used:
				results.append(child)
	else:
		for other in get_tree().get_nodes_in_group(&"pickup"):
			if other is Pickup and other != self and not other._stashed and not other._used:
				results.append(other)
	return results


func _local_horizontal_position() -> Vector3:
	return Vector3(position.x, 0.0, position.z)


func _personal_space_of(other: Pickup) -> float:
	return other.personal_space_radius if other else personal_space_radius


func _update_animation(delta: float) -> void:
	if not sprite:
		return
	_anim_timer += delta
	match _anim_state:
		_AnimState.SPIN:
			rotate_y(spin_speed * delta)
			if _anim_timer >= spin_duration:
				_anim_state = _AnimState.FACE
				_anim_timer = 0.0
		_AnimState.FACE:
			_turn_toward_player(delta)
			if _anim_timer >= face_duration:
				_anim_state = _AnimState.SPIN
				_anim_timer = 0.0


func _turn_toward_player(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if not player:
		return
	var target_pos := player.global_position
	var head := player.get_node_or_null("Head") as Node3D
	if head:
		target_pos = head.global_position
	var forward := target_pos - global_position
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return
	var parent3d := get_parent_node_3d()
	if parent3d:
		forward = parent3d.global_transform.basis.orthonormalized().inverse() * forward
	# Yaw-only turning: reading `quaternion` would fail while the pop-in tween
	# still has the pickup scaled down to a near-degenerate basis.
	var target_yaw := atan2(-forward.x, -forward.z)
	var turn_amount := clampf(face_turn_speed * delta, 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, target_yaw, turn_amount)


func take_damage(_amount = null) -> void:
	## Shots no longer stash loot; walk over floor drops or use the hopper.
	pass


func force_collect() -> void:
	if _used or _stashed:
		return
	LootCollector.absorb_world_pickup(self)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	_use(body)


func _use(player: Node3D) -> void:
	if _used:
		return
	_used = true
	if not _collector:
		_collector = player
	set_deferred("monitoring", false)
	_set_shot_hit_active(false)
	LootCollector.unregister(self)
	_on_collected(_collector)
	_consume()


func _on_collected(player: Node3D) -> void:
	if item:
		item.collect(player)


## Called after an ejected pickup is placed; gold cashes immediately.
func _on_stashed(land_index: int = 0) -> void:
	_bob_initialized = false
	_base_y = position.y
	if item and item.kind == ItemDefinition.ItemKind.MONEY:
		_auto_collect_instant()
		return
	var angle := land_index * 2.3999632 + float(get_instance_id() % 97) * 0.04
	_slide_velocity = Vector3(cos(angle), 0.0, sin(angle)) * 0.7
	set_deferred("monitoring", true)


func _auto_collect_instant() -> void:
	if _used:
		return
	_used = true
	set_deferred("monitoring", false)
	_set_shot_hit_active(false)
	LootCollector.unregister(self)
	var player := _collector as Node3D
	if not player:
		player = get_tree().get_first_node_in_group(&"player") as Node3D
	if item:
		item.collect(player)
	_consume()


func _consume() -> void:
	if not is_inside_tree():
		return
	set_deferred("monitorable", false)
	var tween := create_tween()
	tween.set_parallel()
	# Never reaches exactly zero — a zero scale is a singular basis and Jolt rejects it.
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y + 0.25, 0.25)
	tween.chain().tween_callback(queue_free)


func _on_lifetime_expired() -> void:
	if _stashed or _used:
		return
	if LootCollector.is_world_pos_outside_van(global_position):
		force_collect()
