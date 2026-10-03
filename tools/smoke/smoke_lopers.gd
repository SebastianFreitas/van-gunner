extends RefCounted
## Smoke checks for the loper's wall work, run one after another from the driver.

const _LoperClimb := preload("res://tools/smoke/smoke_loper_climb.gd")
const _LoperKnock := preload("res://tools/smoke/smoke_loper_knock.gd")
const _LoperWallDeath := preload("res://tools/smoke/smoke_loper_wall_death.gd")


func run(driver: Node) -> void:
	await _LoperClimb.new().run(driver)
	await _LoperKnock.new().run(driver)
	await _LoperWallDeath.new().run(driver)
