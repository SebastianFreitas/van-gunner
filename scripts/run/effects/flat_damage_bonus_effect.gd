class_name FlatDamageBonusEffect
extends ActCardEffect

## Adds flat damage to outgoing hits of a given damage type while the card is active.

@export var damage_type: DamageType.Type = DamageType.Type.COLD
@export var amount := 0.0


func modify_outgoing_damage(ctx: ActCardEffectContext) -> void:
	if amount == 0.0 or ctx == null or ctx.damage_info == null:
		return
	if ctx.damage_info.damage_type != damage_type:
		return
	ctx.damage_info.amount += amount
