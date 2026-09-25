extends FacadeSetPiece
## No geometry: kills every window's lights on the tile. corridor_facades special-cases this
## piece to apply it (and force_dead the fixtures) on both sides, since a side piece would
## otherwise only own one.


func apply_plans(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> void:
	for plan: Dictionary in plans:
		var params: Dictionary = plan[&"params"]
		params[&"lit_ratio"] = 0.0
		(plan[&"tags"] as Array[StringName]).append(&"dark")
		plan[&"rare"] = id
