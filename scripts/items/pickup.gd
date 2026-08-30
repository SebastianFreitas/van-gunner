class_name Pickup
extends Area3D

## Base class for anything the player can collect: shoot it, walk into it,
## or just leave it — it gets swept up automatically at the next rest stop.
##
## Collecting applies whatever the pickup grants immediately (subclasses
## override `_on_collected()`), then hands the pickup off to LootCollector,
## which teleports it onto the crafting bench so the player can see what
## they just got. It briefly settles there (so simultaneous pickups still
## get their little "make room" moment) and is then consumed — it doesn't
## sit there forever, since its effect already fired the instant it was
## collected.

@export var pickup_radius := 1.1
@export var bob_height := 0.12
@export var bob_speed := 2.4
@export var spin_speed := 1.4
## Safety net: if somehow never shot, walked over, or swept at a rest stop,
## collect it anyway after this many seconds. 0 disables the safety net.
@export var lifetime := 45.0
## Seconds it stays visible on the bench after landing before being consumed.
@export var display_duration := 1.1

var _collected := false
var _settled := false
var _bob_initialized := false
var _base_y := 0.0
var _time := 0.0


func _ready() -> void:
	add_to_group(&"pickup")
	_apply_pickup_radius()
	body_entered.connect(_on_body_entered)
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_expired)


func _process(delta: float) -> void:
	if _settled:
		return
	if not _bob_initialized:
		# Deferred until first frame so callers can place the pickup with
		# global_position right after instancing it without the bob fighting them.
		_base_y = position.y
		_bob_initialized = true
	_time += delta
	position.y = _base_y + sin(_time * bob_speed) * bob_height
	rotate_y(spin_speed * delta)


func _apply_pickup_radius() -> void:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not shape_node:
		return
	var sphere := SphereShape3D.new()
	sphere.radius = pickup_radius
	shape_node.shape = sphere


## Lets the player's weapon "collect" a pickup by shooting it, reusing the
## same take_damage() contract enemies use — no changes to the weapon needed.
func take_damage(_amount: float) -> void:
	_collect(get_tree().get_first_node_in_group(&"player"))


## Triggers collection without a specific player reference on hand (e.g. a
## rest-stop sweep by LootCollector). Safe to call even if already collected.
func force_collect() -> void:
	_collect(get_tree().get_first_node_in_group(&"player"))


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	_collect(body)


func _collect(player: Node3D) -> void:
	if _collected:
		return
	_collected = true
	set_deferred("monitoring", false)
	_on_collected(player)
	LootCollector.collect(self)


## Override in subclasses to apply whatever the pickup grants.
func _on_collected(_player: Node3D) -> void:
	pass


## Called by LootCollector once this pickup has landed on the bench.
func _on_settled() -> void:
	_settled = true
	if display_duration > 0.0:
		get_tree().create_timer(display_duration).timeout.connect(_consume)
	else:
		_consume()


func _consume() -> void:
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_IN
	)
	tween.tween_property(self, "position:y", position.y + 0.25, 0.25)
	tween.chain().tween_callback(queue_free)


func _on_lifetime_expired() -> void:
	if not _collected:
		_collect(null)
