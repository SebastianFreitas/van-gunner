extends RefCounted
## Rolls which rare set-piece (if any) a tile gets and on which side, and drives the piece's
## hooks from corridor_facades. The roll is the only place RARE_CHANCE is read.


const _FacadeRegistry := preload("res://scripts/travel/facades/facade_registry.gd")

const RARE_CHANCE := 0.07


## `{}` unless `allow_rare` and the chance roll hits; the RNG is only drawn from when allowed, so
## the tile RNG stream is otherwise untouched. `openings` mirrors the tile's Opening enum per
## side (NONE = 0): a span piece needs both sides NONE, a side piece needs at least one.
static func roll(
	rng: RandomNumberGenerator, district: FacadeDistrict, allow_rare: bool, openings: Array[int]
) -> Dictionary:
	if not allow_rare or rng.randf() >= RARE_CHANCE:
		return {}
	var left_open := openings[0] == 0
	var right_open := openings[1] == 0
	var candidates: Array[FacadeSetPiece] = []
	for piece: FacadeSetPiece in _FacadeRegistry.set_pieces():
		if not (piece.districts.is_empty() or district.id in piece.districts):
			continue
		if piece.span:
			if left_open and right_open:
				candidates.append(piece)
		elif left_open or right_open:
			candidates.append(piece)
	if candidates.is_empty():
		return {}
	var piece := _weighted_pick(rng, candidates)
	var side_idx := -1
	if not piece.span:
		if left_open and right_open:
			side_idx = 0 if rng.randf() < 0.5 else 1
		else:
			side_idx = 0 if left_open else 1
	return {&"piece": piece, &"side_idx": side_idx}


## The piece with that id, or null; for the debug console later.
static func debug_force(id: StringName) -> FacadeSetPiece:
	return _FacadeRegistry.set_piece(id)


static func _weighted_pick(
	rng: RandomNumberGenerator, candidates: Array[FacadeSetPiece]
) -> FacadeSetPiece:
	var total := 0.0
	for piece: FacadeSetPiece in candidates:
		total += maxf(piece.weight, 0.0)
	if total <= 0.0:
		return candidates[rng.randi() % candidates.size()]
	var draw := rng.randf() * total
	var acc := 0.0
	for piece: FacadeSetPiece in candidates:
		acc += maxf(piece.weight, 0.0)
		if draw < acc:
			return piece
	return candidates[candidates.size() - 1]
