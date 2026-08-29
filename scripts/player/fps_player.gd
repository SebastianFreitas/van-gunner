class_name FpsPlayer
extends CharacterBody3D

signal interaction_prompt_changed(text: String)
signal shot_fired(hit: bool)

@export var move_speed := 4.5
@export var acceleration := 16.0
@export var mouse_sensitivity := 0.0022

@onready var head: Node3D = $Head
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var weapon: HitscanWeapon = $Head/Camera3D/Weapon

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _current_interactable: Interactable


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	elif event.is_action_pressed("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		weapon.try_fire()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var target := direction * move_speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	move_and_slide()
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
