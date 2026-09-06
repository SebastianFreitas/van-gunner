class_name VanSpeedLevelEffect
extends SkillNodeEffect

## Feeds the existing MetaProgression.van_speed_level curve. Do not invent a
## second speed — chase math still reads get_van_speed_for_level.

@export var levels := 1


func describe() -> String:
	var n := maxi(levels, 1)
	if n == 1:
		return "+1 van speed level"
	return "+%d van speed levels" % n


func van_speed_levels() -> int:
	return maxi(levels, 0)
