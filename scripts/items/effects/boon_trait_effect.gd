class_name BoonTraitEffect
extends ItemEffect

## Registers a passive boon trait on the player's BoonTraits node.

@export var trait_key: StringName = &""
@export var add_value := 0.0
@export var multiply_value := 1.0
@export var set_flag := false


func apply(player: Node3D) -> void:
	var traits := BoonTraits.find_on(player)
	if not traits:
		push_warning("BoonTraitEffect: player has no BoonTraits node")
		return
	if trait_key == &"":
		return
	if set_flag:
		traits.set_flag(trait_key)
	if not is_zero_approx(add_value):
		traits.add_value(trait_key, add_value)
	if not is_equal_approx(multiply_value, 1.0):
		traits.multiply_value(trait_key, multiply_value)
