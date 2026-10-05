extends RefCounted
## Debug forces for street recesses: facade recess <m|off>, facade plaza <on|off>, and the stress run's per-build recess force.

const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")


static func run_recess(args: Array, rebuild: Callable) -> String:
	if args.is_empty():
		if _FacadePlan.forced_recess >= 0.0:
			return "Forced recess: %.2f m  (facade recess off to clear)" % _FacadePlan.forced_recess
		return "Forced recess: off  (usage: facade recess <0..6|off>)"
	var token := String(args[0])
	if token == "off":
		_FacadePlan.forced_recess = -1.0
	elif token.is_valid_float() and float(token) >= 0.0 and float(token) <= 6.0:
		_FacadePlan.forced_recess = snappedf(float(token), 0.25)
	else:
		return "Forced recess: usage: facade recess <0..6|off>"
	var done: String = rebuild.call()
	var shown := "off" if _FacadePlan.forced_recess < 0.0 else "%.2f m" % _FacadePlan.forced_recess
	return "Forced recess: " + shown + " — " + done


static func run_plaza(args: Array, rebuild: Callable) -> String:
	if args.is_empty():
		var state := "on" if _FacadePlan.forced_plaza else "off"
		return "Forced plaza: %s  (facade plaza <on|off>: every recessed tile-side lot a plaza)" % state
	var token := String(args[0])
	if token == "on":
		_FacadePlan.forced_plaza = true
	elif token == "off":
		_FacadePlan.forced_plaza = false
	else:
		return "Forced plaza: usage: facade plaza <on|off>"
	var done: String = rebuild.call()
	return "Forced plaza: " + token + " — " + done


## Sets the stress build's recess force; true when the build is forced.
static func stress_force(build_index: int) -> bool:
	match build_index % 3:
		1:
			_FacadePlan.forced_recess = 3.0
		2:
			_FacadePlan.forced_recess = 6.0
		_:
			_FacadePlan.forced_recess = -1.0
	return build_index % 3 != 0


static func stress_restore() -> void:
	_FacadePlan.forced_recess = -1.0
	_FacadePlan.forced_plaza = false
