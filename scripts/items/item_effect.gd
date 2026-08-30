class_name ItemEffect
extends Resource

## Base class for anything an item/boon does when it is collected.
##
## Every concrete effect (heal, grant coins, buff damage, unlock a perk, ...)
## is its own small Resource subclass that overrides `apply()`. Items just
## hold an `Array[ItemEffect]`, so new behavior never requires touching the
## pickup, loot pool, or drop code — only a new effect script and a resource
## referencing it.


func apply(_player: Node3D) -> void:
	push_warning("ItemEffect.apply() not implemented for %s" % get_script())
