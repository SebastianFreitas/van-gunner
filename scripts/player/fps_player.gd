class_name FpsPlayer
extends CharacterBody3D

signal interaction_prompt_changed(text: String)
signal shot_fired(hit: bool)

@export var move_speed := 4.5
@export var acceleration := 16.0
@export var mouse_sensitivity := 0.0022
@export var movement_reference_path: NodePath

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
	elif event.is_action_pressed("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		weapon.try_fire()


func _physics_process(delta: float) -> void:
	var reference_basis := _movement_reference.global_basis.orthonormalized()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var view_basis_in_reference := reference_basis.inverse() * global_basis.orthonormalized()
	var direction := (view_basis_in_reference * Vector3(input.x, 0.0, input.y)).normalized()
	var target := direction * move_speed
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
	move_and_slide()
	var resulting_local_velocity := reference_basis.inverse() * velocity
	_local_horizontal_velocity.x = resulting_local_velocity.x
	_local_horizontal_velocity.z = resulting_local_velocity.z
	_update_interaction()


func _update_interaction() -> void:
	var next: Interactable
	if interaction_ray.is_colliding():
		var collider := interaction_ray.get_collider()
		if collider is Interactable:
			next = collider
	if next == _current_interactable:
		if next:
			interaction_prompt_changed.emit(next.get_interaction_prompt())
		return
	_current_interactable = next
	interaction_prompt_changed.emit(
		_current_interactable.get_interaction_prompt() if _current_interactable else ""
	)
