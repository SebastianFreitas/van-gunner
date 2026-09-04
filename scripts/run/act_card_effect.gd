class_name ActCardEffect
extends Resource

## Base class for anything an active street card does while it is the road.
##
## Cards hold an `Array[ActCardEffect]` — same pattern as ItemEffect on items.
## New weird behavior = new effect script + a .tres referencing it. No deck,
## spawn, or loot code changes required unless you need a brand-new hook.
##
## Lifecycle:
##   on_activate(ctx)          — card becomes the active street (route commit / load)
##   on_deactivate(ctx)        — card clears (new act / empty deck)
## Query hooks (while active):
##   modify_outgoing_damage    — player hits (after boons)
##   configure_enemy           — each raider spawn
##   modify_item_drop_chance   — death loot roll
##   modify_wave_plan          — optional wave-size bump (danger polarity still works too)


func on_activate(_ctx: ActCardEffectContext) -> void:
	pass


func on_deactivate(_ctx: ActCardEffectContext) -> void:
	pass


func modify_outgoing_damage(_ctx: ActCardEffectContext) -> void:
	pass


func configure_enemy(_ctx: ActCardEffectContext) -> void:
	pass


func modify_item_drop_chance(chance: float, _ctx: ActCardEffectContext) -> float:
	return chance


func modify_wave_plan(plan: Array[int], _ctx: ActCardEffectContext) -> Array[int]:
	return plan
