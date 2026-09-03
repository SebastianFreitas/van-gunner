class_name FpsPlayer
extends CharacterBody3D

signal interaction_prompt_changed(text: String)
signal shot_fired(hit: bool)

@export var move_speed := 4.5
@export var acceleration := 16.0
@export var mouse_sensitivity := 0.0022
@export var step_height := 0.35
@export var step_check_distance := 0.45
@export var movement_reference_path: NodePath

const _REAR_DOOR_INTERACT_SCRIPT := preload("res://scripts/run/rear_door_interact.gd")

@onready var head: Node3D = $Head
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var weapon: GunController = $Head/Camera3D/Weapon
@onready var gun_stats: GunStatsController = $GunStats
@onready var usables: UsablesController = $Usables

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _current_interactable: Interactable
var _movement_reference: Node3D
var _local_horizontal_velocity := Vector3.ZERO


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	floor_snap_length = 0.2
	add_to_group(&"player")
	_movement_reference = get_node_or_null(movement_reference_path) as Node3D
	if not _movement_reference:
		_movement_reference = get_parent_node_3d()
	weapon.fired.connect(func(hit: bool) -> void: shot_fired.emit(hit))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)
	elif event.is_action_pressed("interact") and _current_interactable:
		_current_interactable.interact(self)
	elif event.is_action_pressed("reload") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		weapon.try_reload()
	elif event.is_action_pressed("use_slot_1"):
		usables.try_use_slot(0)
	elif event.is_action_pressed("use_slot_2"):
		usables.try_use_slot(1)
	elif event.is_action_pressed("use_slot_3"):
		usables.try_use_slot(2)
	elif event.is_action_pressed("use_slot_4"):
		usables.try_use_slot(3)


func _physics_process(delta: float) -> void:
	var reference_basis := _movement_reference.global_basis.orthonormalized()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var view_basis_in_reference := reference_basis.inverse() * global_basis.orthonormalized()
	var local_direction := view_basis_in_reference * Vector3(input.x, 0.0, input.y)
	var wish_direction := Vector3.ZERO
	if local_direction.length_squared() > 0.001:
		wish_direction = (reference_basis * local_direction.normalized())
	var target := local_direction.normalized() * move_speed if local_direction.length_squared() > 0.001 else Vector3.ZERO
	_local_horizontal_velocity.x = move_toward(
		_local_horizontal_velocity.x,
		target.x,
		acceleration * delta
	)
	_local_horizontal_velocity.z = move_toward(
		_local_horizontal_velocity.z,
		target.z,
		acceleration * delta
	)
	var world_horizontal_velocity := reference_basis * _local_horizontal_velocity
	velocity.x = world_horizontal_velocity.x
	velocity.z = world_horizontal_velocity.z
	if is_on_floor() and wish_direction.length_squared() > 0.01:
		_try_step_up(wish_direction)
	move_and_slide()
	if is_on_floor() and wish_direction.length_squared() > 0.01:
		if _try_step_up(wish_direction):
			move_and_slide()
	var resulting_local_velocity := reference_basis.inverse() * velocity
	_local_horizontal_velocity.x = resulting_local_velocity.x
	_local_horizontal_velocity.z = resulting_local_velocity.z
	if Input.is_action_pressed("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		weapon.try_fire()
	_update_interaction()


func _try_step_up(wish_direction: Vector3) -> bool:
	if not is_on_floor():
		return false

	var direction := Vector3(wish_direction.x, 0.0, wish_direction.z)
	if direction.length_squared() < 0.01:
		return false
	direction = direction.normalized()

	var space := get_world_3d().direct_space_state
	var exclude := [get_rid()]

	var foot := global_position + Vector3.UP * 0.05
	var query := PhysicsRayQueryParameters3D.create(
		foot,
		foot + direction * step_check_distance
	)
	query.exclude = exclude
	query.collision_mask = collision_mask
	var low_hit := space.intersect_ray(query)
	if low_hit.is_empty():
		return false
	if low_hit.normal.y > 0.55:
		return false

	var head_pos := global_position + Vector3.UP * (step_height + 0.05)
	query = PhysicsRayQueryParameters3D.create(
		head_pos,
		head_pos + direction * step_check_distance
	)
	query.exclude = exclude
	query.collision_mask = collision_mask
	if not space.intersect_ray(query).is_empty():
		return false

	var probe := head_pos + direction * step_check_distance
	query = PhysicsRayQueryParameters3D.create(
		probe,
		probe + Vector3.DOWN * (step_height + 0.1)
	)
	query.exclude = exclude
	query.collision_mask = collision_mask
	var floor_hit := space.intersect_ray(query)
	if floor_hit.is_empty():
		return false

	var rise: float = floor_hit.position.y - global_position.y
	if rise <= 0.01 or rise > step_height:
		return false

	global_position.y += rise
	velocity.y = 0.0
	return true


func _update_interaction() -> void:
	var next: Interactable
	if interaction_ray.is_colliding():
		var collider := interaction_ray.get_collider()
		if collider is Interactable:
			next = collider
			if collider.get_script() == _REAR_DOOR_INTERACT_SCRIPT:
				var resolved := _resolve_rear_door_interact(interaction_ray.get_collision_point())
				if resolved:
					next = resolved
	if next == _current_interactable:
		if next:
			interaction_prompt_changed.emit(next.get_interaction_prompt())
		return
	_current_interactable = next
	interaction_prompt_changed.emit(
		_current_interactable.get_interaction_prompt() if _current_interactable else ""
	)


func _resolve_rear_door_interact(hit_point: Vector3) -> Interactable:
	var rear_doors := get_tree().get_first_node_in_group(&"rear_doors")
	if rear_doors == null:
		return null
	# Van is often yawed in the shop bay — pick the leaf in rear-door local space.
	var local_x: float = rear_doors.to_local(hit_point).x
	var hinge_name := "LeftHinge" if local_x < 0.0 else "RightHinge"
	return rear_doors.get_node_or_null("%s/Interact" % hinge_name) as Interactable
