class_name CoinPickup
extends Pickup

## Simple currency pickup. Coins are deliberately kept separate from the
## item/effect system: they're not a "boon" with behavior, just a number
## that feeds GameSession's currency total.

@export var amount := 1


func _on_collected(_player: Node3D) -> void:
	GameSession.add_coins(amount)
