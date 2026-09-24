class_name WaveCountMultEffect
extends ActCardEffect

## Bumps each wave's spawn count (danger roads). Multiplies then optionally adds.

@export var count_mult := 1.0
@export var count_add := 0


func modify_wave_plan(plan: Array[int], _ctx: ActCardEffectContext) -> Array[int]:
	if plan.is_empty():
		return plan
	if is_equal_approx(count_mult, 1.0) and count_add == 0:
		return plan
	var bumped: Array[int] = []
	for count in plan:
		bumped.append(maxi(1, ceili(float(count) * count_mult) + count_add))
	return bumped
