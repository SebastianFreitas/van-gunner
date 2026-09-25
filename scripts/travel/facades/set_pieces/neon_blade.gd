extends FacadeSetPiece
## A giant neon blade bolted flat across the widest eligible face: the same two-face box builder
## facade_signs.gd uses for an ordinary blade, just bigger, brighter and lit from the neon palette.


const _FacadeSigns := preload("res://scripts/travel/facades/facade_signs.gd")

## facade_signs.gd's own default energy is private; this is a fresh copy of that number.
const _ENERGY := 2.4
const _SIZE := Vector3(1.6, 7.0, 0.3)
const _BOTTOM_Y := 6.6


func can_apply(plans: Array[Dictionary]) -> bool:
	return _target_index(plans) != -1


func pick_plan(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> int:
	return _target_index(plans)


func apply_plans(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> void:
	var target := _target_index(plans)
	if target == -1:
		return
	plans[target][&"rare"] = id
	plans[target][&"suppress"] = [&"signs", &"fire_escape"]


func build(ctx: Dictionary) -> void:
	var host: Node3D = ctx[&"host"]
	var plan: Dictionary = ctx[&"plan"]
	var side_sign: float = ctx[&"side_sign"]
	var keep_out: RefCounted = ctx[&"keep_out"]
	var rng: RandomNumberGenerator = ctx[&"rng"]
	var district: FacadeDistrict = ctx[&"district"]
	if district.sign_words.is_empty():
		return
	var word: String = district.sign_words[rng.randi() % district.sign_words.size()]
	var colors := _FacadeSigns.NEON_COLORS
	var color: Color = colors[rng.randi_range(0, colors.size() - 1)]
	var seed_value := rng.randf() * 1000.0
	_FacadeSigns.build_blade(
		host, "RareBlade", plan, side_sign, keep_out, float(plan[&"width"]) * 0.5, word, _SIZE,
		_BOTTOM_Y, color, _ENERGY, seed_value, 0.15, 0.4
	)


## Widest plan at least 8 m wide: the blade needs road frontage to read from a distance.
func _target_index(plans: Array[Dictionary]) -> int:
	var best := -1
	var best_width := -1.0
	for i in plans.size():
		var width := float(plans[i].get(&"width", 0.0))
		if width >= 8.0 and width > best_width:
			best_width = width
			best = i
	return best
