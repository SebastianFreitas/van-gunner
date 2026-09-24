class_name EnemySpeedMultEffect
extends ActCardEffect

## Scales raider world chase speed on spawn (1.15 = 15% faster).

@export var speed_mult := 1.0


func configure_enemy(ctx: ActCardEffectContext) -> void:
	if ctx == null or ctx.enemy == null:
		return
	if is_equal_approx(speed_mult, 1.0):
		return
	if "mob_world_speed" in ctx.enemy:
		ctx.enemy.mob_world_speed *= speed_mult
	if "approach_speed" in ctx.enemy:
		ctx.enemy.approach_speed *= speed_mult
