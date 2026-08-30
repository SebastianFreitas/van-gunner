class_name GrantCoinEffect
extends ItemEffect

## Grants a random amount of coins to the session.

@export var amount := 1

func apply(_player: Node3D) -> void:
	GameSession.add_coins(amount)
