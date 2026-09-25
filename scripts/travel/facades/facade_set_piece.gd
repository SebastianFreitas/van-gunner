class_name FacadeSetPiece
extends Resource
## One rare street set-piece: eligibility data plus the hooks a subclass overrides. Registered
## by dropping a .tres into resources/facades/set_pieces/.


@export var id := &""
@export var weight := 1.0
## Empty = any district.
@export var districts: Array[StringName] = []
## Crosses the street: needs both sides open-free and builds under Facades/Span.
@export var span := false
## Lights this piece adds, for the world cap.
@export var lights := 0


## Whether this piece can take one of `plans` (that side's plan dictionaries).
func can_apply(plans: Array[Dictionary]) -> bool:
	return not plans.is_empty()


## Mutates plan dictionaries (usually `plans[i][&"params"]`) before bodies are built; also sets
## `plans[i][&"rare"] = id` on the plan(s) it takes.
func apply_plans(_plans: Array[Dictionary], _rng: RandomNumberGenerator) -> void:
	pass


## Adds nodes for this piece. `ctx` keys: `&"host"` (the side root, or the Span root for a span
## piece), `&"plans"` (that side's plans; both sides' as `&"plans_left"`/`&"plans_right"` for a
## span), `&"side_sign"` (0.0 for spans), `&"keep_out"`, `&"rng"`, `&"district"`, `&"plan"` (the
## target plan for a side piece: the one `pick_plan` chose), `&"tile_seed"`.
func build(_ctx: Dictionary) -> void:
	pass


## Which plan this piece takes; default picks the widest plan (ties: first).
func pick_plan(plans: Array[Dictionary], _rng: RandomNumberGenerator) -> int:
	var best := 0
	var best_width := -1.0
	for i in plans.size():
		var width := float(plans[i].get(&"width", 0.0))
		if width > best_width:
			best_width = width
			best = i
	return best
