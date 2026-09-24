class_name EnemyHealthMultEffect
extends ActCardEffect

## Scales raider max/current health on spawn (dangers that make fights longer).

@export var health_mult := 1.0


func configure_enemy(ctx: ActCardEffectContext) -> void:
	if ctx == null or ctx.enemy == null:
		return
	if is_equal_approx(health_mult, 1.0):
		return
	if "max_health" in ctx.enemy:
		ctx.enemy.max_health *= health_mult
	if "health" in ctx.enemy:
		ctx.enemy.health = ctx.enemy.max_health if "max_health" in ctx.enemy else ctx.enemy.health * health_mult
	if "health_bar" in ctx.enemy and ctx.enemy.health_bar and ctx.enemy.health_bar.has_method("update_ratio"):
		ctx.enemy.health_bar.update_ratio(1.0)
