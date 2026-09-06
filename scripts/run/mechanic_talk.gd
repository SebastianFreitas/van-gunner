class_name MechanicTalk
extends "res://scripts/dialogue/npc_talk.gd"

## Mechanic bay keeper. Three buys: full van patch, a van-pool boon, a weld kit.

const _DialogueChoice := preload("res://scripts/dialogue/dialogue_choice.gd")
const _WELD_KIT_ID := "window_bar_kit"
const _VAN_POOL_KEY := "van"


func _ready() -> void:
	speaker_name = "Mechanic"
	greeting = "What do you need?"
	prompt = "E  TALK"
	super._ready()


func build_choices(actor: Node3D) -> Array:
	var choices: Array = []
	choices.append(_repair_choice())
	choices.append(_boon_choice(actor))
	choices.append(_kit_choice())
	return choices


func execute_choice(actor: Node3D, choice: Variant) -> bool:
	last_error = ""
	if choice == null:
		return false
	match choice.id:
		&"repair":
			return _buy_repair()
		&"boon":
			return _buy_boon(actor)
		&"kit":
			return _buy_kit(actor)
	return false


func _repair_choice():
	var choice := _DialogueChoice.new()
	choice.id = &"repair"
	choice.label = "Full repair — hull, doors, windows"
	choice.price = GameBalance.MECHANIC_FULL_REPAIR_COST
	if GameSession.is_van_fully_repaired():
		choice.available = false
		choice.detail = "(already patched)"
	elif GameSession.coins < choice.price:
		choice.available = false
		choice.detail = "(need %d)" % (choice.price - GameSession.coins)
	return choice


func _boon_choice(actor: Node3D):
	var choice := _DialogueChoice.new()
	choice.id = &"boon"
	choice.label = "Random van boon"
	choice.price = GameBalance.MECHANIC_VAN_BOON_COST
	if _roll_van_boon(actor) == null:
		choice.available = false
		choice.detail = "(nothing left)"
	elif GameSession.coins < choice.price:
		choice.available = false
		choice.detail = "(need %d)" % (choice.price - GameSession.coins)
	return choice


func _kit_choice():
	var choice := _DialogueChoice.new()
	choice.id = &"kit"
	choice.label = "Weld kit"
	choice.price = _weld_kit_price()
	if GameSession.coins < choice.price:
		choice.available = false
		choice.detail = "(need %d)" % (choice.price - GameSession.coins)
	return choice


func _buy_repair() -> bool:
	if GameSession.is_van_fully_repaired():
		last_error = "ALREADY PATCHED"
		return false
	if not _try_pay(GameBalance.MECHANIC_FULL_REPAIR_COST):
		return false
	GameSession.repair_van_full()
	return true


func _buy_boon(actor: Node3D) -> bool:
	var item := _roll_van_boon(actor)
	if item == null:
		last_error = "NOTHING LEFT"
		return false
	if not item.can_collect(actor):
		last_error = "ALREADY GOT THAT"
		return false
	if not _try_pay(GameBalance.MECHANIC_VAN_BOON_COST):
		return false
	item.collect(actor)
	return true


func _buy_kit(actor: Node3D) -> bool:
	var item := ItemRegistry.load_by_id(_WELD_KIT_ID)
	if item == null or not item.can_collect(actor):
		last_error = "CAN'T TAKE THAT"
		return false
	if not _try_pay(_weld_kit_price()):
		return false
	item.collect(actor)
	return true


func _try_pay(cost: int) -> bool:
	if GameSession.coins < cost:
		last_error = "NEED %d GOLD" % (cost - GameSession.coins)
		return false
	return GameSession.spend_coins(cost)


func _roll_van_boon(actor: Node3D) -> ItemDefinition:
	var pool := ItemPoolRegistry.get_pool(_VAN_POOL_KEY)
	if pool == null:
		return null
	return pool.pick_item(_owned_boon_ids(actor))


func _owned_boon_ids(actor: Node3D) -> Array:
	var ids: Array = []
	if actor == null:
		return ids
	var controller := actor.get_node_or_null("Usables") as UsablesController
	if controller == null:
		return ids
	for boon in controller.get_boons():
		if boon:
			ids.append(boon.id)
	return ids


func _weld_kit_price() -> int:
	var item := ItemRegistry.load_by_id(_WELD_KIT_ID)
	if item == null:
		return 20
	return maxi(item.shop_price, 1)
