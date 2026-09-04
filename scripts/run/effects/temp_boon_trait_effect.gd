class_name TempBoonTraitEffect
extends ActCardEffect

## While this street is active, grants a boon trait via BoonTraits street overlay.
## Reuses the entire BoonCombat / behavior pipeline — easiest way to ship weird cards
## that already exist as boons (freeze chance, phys bonus, fire death, etc.).

@export var trait_key: StringName = &""
@export var add_value := 0.0
@export var multiply_value := 1.0
@export var set_flag := false


func on_activate(ctx: ActCardEffectContext) -> void:
	if ctx == null or trait_key == &"":
		return
	ctx.add_street_trait(trait_key, add_value, multiply_value, set_flag)
