class_name FpsPlayer
extends CharacterBody3D
## The first-person player controller: movement, interaction and shooting input.

signal interaction_prompt_changed(text: String)
signal shot_fired(hit: bool)
## A climb began; the hook for a future climb animation.
@warning_ignore("unused_signal")
signal mantle_started(rise: float, landing: Vector3)
## The climb ended with the player on the ledge; the hook for a future climb animation.
@warning_ignore("unused_signal")
signal mantle_finished

@export var move_speed := 4.5
@export var acceleration := 16.0
@export var mouse_sensitivity := 0.0022
@export var step_height := 0.35
@export var step_check_distance := 0.45
@export var jump_velocity := 6.0
@export var movement_reference_path: NodePath

const _REAR_DOOR_INTERACT_SCRIPT := preload("res://scripts/van/rear_door_interact.gd")
const _MANTLE := preload("res://scripts/player/player_mantle.gd")

@onready var head: Node3D = $Head
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var weapon: GunController = $Head/Camera3D/Weapon
@onready var camera: Camera3D = $Head/Camera3D
@onready var gun_stats: GunStatsController = $GunStats
@onready var usables: UsablesController = $Usables

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _current_interactable: Interactable
var _interact_pending := false
var _movement_reference: Node3D
var _local_horizontal_velocity := Vector3.ZERO
var _jump_queued := false
## Seconds after a jump press the airborne player keeps trying to mantle a ledge.
const MANTLE_BUFFER_TIME := 0.6
var _mantle_buffer := 0.0
## The equipped class; applied on ready and again whenever GameSession changes it.
var current_class: ClassDefinition
## Debug fly mode: no gravity, no collision, moves along the camera's full look direction.
var ghost := false
var _ghost_saved_mask := 0
## The step and climb helper (player_mantle.gd), made at the end of _ready.
var _mantle: RefCounted


func _ready() -> void:
	if not SaveSandbox.enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	floor_snap_length = 0.2
	add_to_group(&"player")
	_movement_reference = get_node_or_null(movement_reference_path) as Node3D
	if not _movement_reference:
		_movement_reference = get_parent_node_3d()
	weapon.fired.connect(func(hit: bool) -> void: shot_fired.emit(hit))
	GameSession.class_changed.connect(_on_class_changed)
	apply_class(ClassCatalog.load_or_basic(GameSession.class_id))
	_mantle = _MANTLE.new(self)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if (
			not mb.pressed
			and mb.button_index == MOUSE_BUTTON_LEFT
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
			and not _ui_wants_free_cursor()
			and not SaveSandbox.enabled
		):
			## Click in the world after a HUD/UI click stole the cursor.
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
	elif event.is_action_pressed("interact"):
		if _current_interactable:
			_interact_with(_current_interactable)
		else:
			_close_open_dialogue()
	elif event.is_action_pressed("jump"):
		_jump_queued = true
		_mantle_buffer = MANTLE_BUFFER_TIME
	elif event.is_action_pressed("reload") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		weapon.try_reload()
	elif event.is_action_pressed("use_slot_1"):
		if _try_dialogue_choice(0):
			get_viewport().set_input_as_handled()
		else:
			usables.try_use_slot(0)
	elif event.is_action_pressed("use_slot_2"):
		if _try_dialogue_choice(1):
			get_viewport().set_input_as_handled()
		else:
			usables.try_use_slot(1)
	elif event.is_action_pressed("use_slot_3"):
		if _try_dialogue_choice(2):
			get_viewport().set_input_as_handled()
		else:
			usables.try_use_slot(2)
	elif event.is_action_pressed("use_slot_4"):
		if _try_dialogue_choice(3):
			get_viewport().set_input_as_handled()
		else:
			usables.try_use_slot(3)


func _interact_with(target: Interactable) -> void:
	if _interact_pending:
		return
	var kind := target.get_gesture()
	var delay := 0.0
	if kind != &"":
		var vm := get_tree().get_first_node_in_group(&"gun_viewmodel")
		if vm and vm.has_method(&"play_gesture"):
			delay = vm.play_gesture(kind)
	if SaveSandbox.enabled:
		delay = 0.0
	if delay > 0.0:
		_interact_pending = true
		await get_tree().create_timer(delay).timeout
		_interact_pending = false
		if not is_instance_valid(target):
			return
	# The door, window or board reacts when the hand touches it, not on the key press.
	target.interact(self)


func get_look_interactable() -> Interactable:
	return _current_interactable


func apply_class(def: ClassDefinition) -> void:
	current_class = def
	gun_stats.set_class_definition(def)
	weapon.apply_class(def)


func _on_class_changed(class_id: StringName) -> void:
	apply_class(ClassCatalog.load_or_basic(class_id))


## Climbs onto the ledge the player faces, when jumping is allowed here.
func try_mantle() -> bool:
	return _can_mantle() and _mantle.try_climb()


func is_mantling() -> bool:
	return _mantle.is_climbing()


## The van-side part of the jump rule: false only when standing inside the van interior.
func _can_mantle() -> bool:
	var van := get_tree().get_first_node_in_group(&"van_run")
	if van == null:
		return true
	var containment := van.get("player_containment") as VanPlayerContainment
	if containment == null:
		return true
	return not containment.is_inside_interior(global_position)


func _can_jump() -> bool:
	# The sandbox never captures the mouse, so the smoke's real-input jump needs this.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not SaveSandbox.enabled:
		return false
	if _ui_wants_free_cursor():
		return false
	return _can_mantle()


func _ui_wants_free_cursor() -> bool:
	var van := get_tree().get_first_node_in_group(&"van_run")
	if van and van.has_method(&"has_modal_free_cursor"):
		return bool(van.has_modal_free_cursor())
	return false


func _try_dialogue_choice(index: int) -> bool:
	var hud := _dialogue_hud()
	if hud == null or not hud.has_method(&"try_choose"):
		return false
	return bool(hud.try_choose(index))


func _close_open_dialogue() -> void:
	var hud := _dialogue_hud()
	if hud and hud.has_method(&"is_open") and hud.is_open() and hud.has_method(&"close"):
		hud.close()


func _dialogue_hud() -> Node:
	return get_tree().get_first_node_in_group(&"dialogue_hud")


## Toggles debug fly mode: no gravity, no collision, free camera-relative movement.
func set_ghost(on: bool) -> void:
	if on == ghost:
		return
	if on:
		_ghost_saved_mask = collision_mask
		collision_mask = 0
		ghost = true
	else:
		collision_mask = _ghost_saved_mask
		ghost = false
		velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if ghost:
		var ghost_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var forward := -camera.global_basis.z
		var right := camera.global_basis.x
		var dir := right * ghost_input.x - forward * ghost_input.y
		if dir.length_squared() > 0.001:
			dir = dir.normalized()
		velocity = dir * move_speed * 2.5
		if Input.is_action_pressed("jump"):
			velocity += Vector3.UP * move_speed * 2.5
		move_and_slide()
		return
	if _mantle.is_climbing():
		_mantle.step_climb(delta)
		_mantle.update_head(delta)
		_jump_queued = false
		_update_interaction()
		return
	var reference_basis := _movement_reference.global_basis.orthonormalized()
	_mantle_buffer = maxf(_mantle_buffer - delta, 0.0)
	if is_on_floor():
		_mantle.note_floor()
	if not is_on_floor():
		velocity.y -= _gravity * delta
		if (_mantle_buffer > 0.0 or Input.is_action_pressed("jump")) \
				and _can_jump() and try_mantle():
			_mantle_buffer = 0.0
			_jump_queued = false
			_update_interaction()
			return
	elif _jump_queued and _can_jump() and _mantle.try_climb():
		_mantle_buffer = 0.0
		_jump_queued = false
		_update_interaction()
		return
	elif _jump_queued and _can_jump():
		velocity.y = jump_velocity
	else:
		velocity.y = 0.0
		_mantle_buffer = 0.0
	_jump_queued = false

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
		_mantle.try_step(wish_direction)
	move_and_slide()
	if is_on_floor() and wish_direction.length_squared() > 0.01:
		if _mantle.try_step(wish_direction):
			move_and_slide()
	var resulting_local_velocity := reference_basis.inverse() * velocity
	_local_horizontal_velocity.x = resulting_local_velocity.x
	_local_horizontal_velocity.z = resulting_local_velocity.z
	_mantle.update_head(delta)
	if Input.is_action_pressed("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		weapon.try_fire()
	_update_interaction()


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
