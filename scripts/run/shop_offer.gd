class_name ShopOffer
extends Interactable

## A single priced item sitting on the shop counter. Look + E to buy with gold.

@export var item: ItemDefinition
@export var price_override := -1
@export var bob_height := 0.06
@export var bob_speed := 2.0
@export var spin_speed := 1.1

var _sold := false
var _price := 0
var _base_y := 0.0
var _time := 0.0

@onready var _sprite: Sprite3D = $Sprite3D
@onready var _collision: CollisionShape3D = $Collision


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	_apply_item(item)
	_base_y = position.y
	if _collision and _collision.shape == null:
		var sphere := SphereShape3D.new()
		sphere.radius = 0.35
		_collision.shape = sphere


func setup(offer_item: ItemDefinition) -> void:
	item = offer_item
	_apply_item(item)


func _apply_item(offer_item: ItemDefinition) -> void:
	_sold = false
	visible = true
	if _collision:
		_collision.disabled = false
	if not offer_item:
		_price = 0
		prompt = "Sold out"
		if _sprite:
			_sprite.texture = null
		return
	_price = price_override if price_override >= 0 else maxi(offer_item.shop_price, 1)
	if _sprite:
		_sprite.texture = offer_item.icon
		_sprite.pixel_size = 0.005
		_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_sprite.render_priority = 2


func get_interaction_prompt() -> String:
	if _sold or not item:
		return ""
	var name_text := item.display_name
	if GameSession.coins < _price:
		return "E  %s — %d GOLD (need %d)" % [name_text, _price, _price - GameSession.coins]
	if not item.can_collect(get_tree().get_first_node_in_group(&"player") as Node3D):
		if item.is_heal_consumable():
			return "E  %s — %d GOLD (hull full)" % [name_text, _price]
		return "E  %s — %d GOLD (can't use)" % [name_text, _price]
	return "E  BUY %s — %d GOLD" % [name_text, _price]


func interact(actor: Node3D) -> void:
	if _sold or not item:
		return
	if not item.can_collect(actor):
		return
	if not GameSession.spend_coins(_price):
		return
	item.collect(actor)
	_mark_sold()


func _mark_sold() -> void:
	_sold = true
	item = null
	prompt = ""
	if _collision:
		_collision.disabled = true
	if _sprite:
		var tween := create_tween()
		tween.set_parallel()
		tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.2).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "position:y", position.y + 0.2, 0.2)
		tween.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	if _sold or not item:
		return
	_time += delta
	position.y = _base_y + sin(_time * bob_speed) * bob_height
	rotate_y(spin_speed * delta)
