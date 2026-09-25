You are implementing the rare set-piece framework (step 8a) of a procedural street-building system in a Godot 4.7 GDScript project at C:\Users\Traff\Documents\van-gunner (Windows; `py -3`). Existing in `scripts/travel/facades/`: `facade_materials.gd` (incl. `sign_material`, `label_texture`, prop materials), `facade_keep_out.gd`, `facade_plan.gd`, `facade_body.gd` (`add_quad`), `facade_mesh_kit.gd` (`add_box`, `add_box_ungated`, `commit`, `add_box_node`), `facade_props_upper.gd`, `facade_props_ground.gd` (`build`, `build_fixtures`), `facade_signs.gd`, `facade_registry.gd` (districts), `facade_district.gd` (`class_name FacadeDistrict`), `corridor_facades.gd` (`configure` returns `false` today; `rebuild_side` runs plan -> bodies -> upper props -> ground props -> signs -> fixtures -> visibility pass). Read all of them first (each under 300 lines), plus `scripts/stops/side_stop_definition.gd` + `side_stop_registry.gd` + `resources/side_stops/garage.tres` for how this project writes Resource subclasses and `.tres` files, and `scripts/items/item_effect.gd` (or any `ItemEffect` subclass under `scripts/items/effects/`) for how a behaviour Resource with virtual methods is written here.

# Project rules
- GDScript: tabs, LF, ~100 columns, two blank lines between top-level functions, everything typed, `&"..."` StringNames, `##` docs; comments explain why. `class_name` only on the Resource base (`FacadeSetPiece`); subclasses `extends FacadeSetPiece` without `class_name`; helpers `RefCounted` without `class_name`, no `await`, never preload/name an autoload. Scripts <= 300 lines target, 400 cap; each set-piece script <= 120 lines.
- Data in `.tres`; behaviour in small Resource subclasses. `.tres` written as text with an `ext_resource` to the subclass script; no colliding ids; mint no `uid=` unless the side-stop files have one (copy their style).
- Every placed box passes the keep-out gate (`facade_mesh_kit.add_box` / `add_box_node` do it); every quad through `facade_body.add_quad`. Set-pieces never touch a BAY or SIDE_STREET side.
- Never launch Godot with a window; never open `.png`/`.import`/`.godot/`. Deliver new `.gd.uid` files.

# 1. `scripts/travel/facades/facade_set_piece.gd` (CREATE)
```
class_name FacadeSetPiece
extends Resource
## One rare street set-piece: eligibility data plus the hooks a subclass overrides. Registered
## by dropping a .tres into resources/facades/set_pieces/.
```
Exports: `@export var id := &""`, `@export var weight := 1.0`, `@export var districts: Array[StringName] = []` (## Empty = any district), `@export var span := false` (## Crosses the street: needs both sides open-free and builds under Facades/Span), `@export var lights := 0` (## Lights this piece adds, for the world cap).
Virtuals (default implementations do nothing / accept):
- `func can_apply(plans: Array[Dictionary]) -> bool` — return `not plans.is_empty()`.
- `func apply_plans(plans: Array[Dictionary], rng: RandomNumberGenerator) -> void` — mutate plan dictionaries (usually `plans[i][&"params"]`) before bodies are built; also set `plans[i][&"rare"] = id` on the plan(s) it takes.
- `func build(ctx: Dictionary) -> void` — add nodes. `ctx` keys: `&"host"` (Node3D: the side root, or the `Span` root), `&"plans"` (Array[Dictionary] of that side; both sides' plans as `&"plans_left"`/`&"plans_right"` for spans), `&"side_sign"` (float; 0.0 for spans), `&"keep_out"` (RefCounted; for spans the keep-out of side +1 — a span must still respect the lane box: bottom >= 6, and by convention >= 9.0), `&"rng"`, `&"district"` (FacadeDistrict), `&"plan"` (the target plan for side pieces: the one `pick_plan` chose), `&"tile_seed"` (int).
- `func pick_plan(plans: Array[Dictionary], rng: RandomNumberGenerator) -> int` — default: the widest plan's index (ties: first).

# 2. `scripts/travel/facades/facade_set_pieces.gd` (CREATE, RefCounted, static helper)
```
extends RefCounted
## Rolls which rare set-piece (if any) a tile gets and on which side, and drives the piece's
## hooks from corridor_facades. The roll is the only place RARE_CHANCE is read.
```
`const RARE_CHANCE := 0.07`. Preloads `_FacadeRegistry`.
- `static func roll(rng: RandomNumberGenerator, district: FacadeDistrict, allow_rare: bool, openings: Array[int]) -> Dictionary` — `{}` unless `allow_rare` and `rng.randf() < RARE_CHANCE` (roll the RNG only when allowed, so the tile RNG stream is otherwise untouched). Candidates: `_FacadeRegistry.set_pieces()` filtered by `districts.is_empty() or district.id in districts`, and by openings: span pieces need `openings[0] == 0 and openings[1] == 0`; side pieces need at least one side `== 0`. Weighted pick (roulette over `weight`). Side: span -> `-1`; else the open side, or a coin flip when both are open. Return `{&"piece": piece, &"side_idx": side_idx}`.
- `static func debug_force(id: StringName) -> FacadeSetPiece` — the piece with that id or null (for the console later).

# 3. `facade_registry.gd` (EDIT): add `const SET_PIECES_DIR := "res://resources/facades/set_pieces/"`, `static var _set_pieces: Array[FacadeSetPiece]`, `static func set_pieces() -> Array[FacadeSetPiece]` (scan + load, keep `FacadeSetPiece` instances, sort by `id`), `static func set_piece(id: StringName) -> FacadeSetPiece`; `reset()` clears it too.

# 4. `corridor_facades.gd` (EDIT)
- Fields: `var _rare: Dictionary = {}` (## The rolled set-piece for this tile: piece + side_idx, or empty), `var _tile_rng_seed := 0`.
- `configure(...)`: after storing, `var tile_rng := RandomNumberGenerator.new(); tile_rng.seed = hash([seed, &"rare"])`; `_rare = _FacadeSetPieces.roll(tile_rng, district_res, allow_rare, _openings)`; then rebuild both sides; if `_rare` is a span piece, `_build_span()`; return `not _rare.is_empty()`.
- `rebuild_side(side_idx)`: after `plan_side` and before bodies: `if _rare_targets(side_idx): var piece: FacadeSetPiece = _rare.piece; if piece.can_apply(plans_out): var target := piece.pick_plan(plans_out, rng); piece.apply_plans(plans_out, rng); _rare_plan_index = target else: _rare = {}`. After signs/fixtures (before the visibility pass): if the rare targets this side: `piece.build({host: root, plans: plans_out, side_sign: ..., keep_out: keep_out, rng: rng, district: district_res, plan: plans_out[target], tile_seed: seed})`. Helper `_rare_targets(side_idx) -> bool`: `not _rare.is_empty() and not _rare.piece.span and _rare.side_idx == side_idx and _openings[side_idx] == 0`.
- `set_opening(side_idx, opening)`: when the opening changes to non-NONE and the rare targets that side (or is a span): drop it: `_rare = {}` and free `Facades/Span` if present, before rebuilding. (A bay or side street always wins over a rare.)
- `_build_span()`: create `Facades/Span` (Node3D), call `piece.build({host: span_root, plans_left: _plans[0], plans_right: _plans[1], side_sign: 0.0, keep_out: _keep_outs[1], rng: (a new RNG seeded hash([seed, &"span"])), district: district_res, tile_seed: seed})`, then the visibility pass on it.
- `describe()` adds the rare id if any.
- `func rare_id() -> StringName`.
`corridor_segment.gd` (EDIT): add `func rare_id() -> StringName` delegating.

# 5. Pieces (each: `scripts/travel/facades/set_pieces/<id>.gd` extending `FacadeSetPiece`, and `resources/facades/set_pieces/<id>.tres` setting `id`, `weight`, `districts`, `span`, `lights`)
Geometry conventions as in the props helpers (`x_face = FacadePlan.face_x(plan, side_sign)`, out = `-side_sign`, u -> z, `y0 = BASE_Y`, roof `y_top = y0 + plan.height`, roof plate x from `x_face` to `x_face + side_sign * 1.2`). Use the mesh kit for boxes; add to the kit `static func add_cylinder_node(host: Node3D, node_name: String, top_radius: float, bottom_radius: float, height: float, center: Vector3, material: Material, shadows: bool, keep_out: RefCounted) -> MeshInstance3D` (CylinderMesh; AABB from `box_aabb(center, Vector3(2 * max_r, height, 2 * max_r))`).

a. `rooftop_billboard` (weight 4, districts [tenement, industrial, commercial]): `pick_plan` = the lowest plan with height <= 28 (can_apply false if none). build: two posts `(0.2, 2.5, 0.2)` on the roof plate at u = mid +- 3.5 (or +- 2.0 when width < 10), x = x_face + side_sign * 0.6, y `y_top + 1.25`; panel: a two-surface box via SurfaceTools like the signs' box (dark 5 faces + a text face toward the road): size `(0.15, 4.0, 9.0)` (or `(0.15, 3.0, 6.0)` when width < 10) centred at u mid, x = x_face + side_sign * 0.6, y `y_top + 2.5 + 2.0`; text face material `FacadeMaterials.sign_material(word, 5, false, color, 2.0, 0, seed, 0.0, 0.0, 8.0)` with `word` from `const WORDS := ["DRINK COLA", "MOTEL", "NEW HOMES", "GAS", "SMILE", "VOTE NOW", "BIG SALE", "LOTTO"]` and colour from a bright palette; two flood boxes `(0.15, 0.15, 0.5)` at the panel's bottom edge with `prop_material(&"flood", Color(0.9, 0.9, 0.8), 0.4, 0.2, Color(1, 1, 0.9), 2.5)`. Height check: billboard top <= 40.
b. `water_tower` (weight 4, districts [tenement, industrial]): `pick_plan` = lowest plan with height <= 30. build on the roof at u mid, base x = x_face + side_sign * 0.8: four legs `(0.15, 3.0, 0.15)` at (+-0.9 u, +-0.5 x), y `y_top + 1.5`; a ring `(2.2, 0.1, 2.2)`? no: tank cylinder r 1.6 h 3.0 centre y `y_top + 4.5`, material `prop_material(&"tank_wood", Color(0.3, 0.2, 0.14), 0.85, 0.1)`; lid cylinder top 0.1 bottom 1.75 h 0.8 at `y_top + 6.4`, `metal_grey_material`; a ladder: two rails `(0.05, 5.0, 0.05)` + 8 rungs on the road side.
c. `antenna_farm` (weight 4, districts []): `pick_plan` = lowest plan with height <= 32. build: 6-10 masts `(0.08, h, 0.08)` with h in 6..14 at random u in [1, width - 1] and x within the plate (x_face + side_sign * rng(0.3, 1.0)), iron; 2 dishes: cylinder r 0.6 h 0.08 via `add_box_node` with rotation x = 60 deg (a box (1.2, 0.08, 1.2) rotated), metal grey; a beacon box `(0.25, 0.25, 0.25)` on the tallest mast top with `prop_material(&"beacon_red", Color(0.6, 0.05, 0.05), 0.5, 0.0, Color(1.0, 0.1, 0.1), 3.0)`.
d. `power_outage` (weight 3, districts [], span false): `apply_plans`: for every plan set `params.lit_ratio = 0.0`; tag `&"dark"`. build: nothing. Additionally `corridor_facades` passes `force_dead = (rare id == &"power_outage")` to `facade_fixtures.build_fixtures` (that function already has a trailing `force_dead: bool = false` parameter; when true every fixture is dead and no light is added). Because a side piece only targets one side, make `power_outage` special-cased in `corridor_facades`: when the rolled piece has `id == &"power_outage"`, apply it to BOTH sides' plans and fixtures (document this in a comment: it is the one "atmosphere" piece that spans the tile without geometry).

# 6. `.tres` files: `resources/facades/set_pieces/rooftop_billboard.tres`, `water_tower.tres`, `antenna_farm.tres`, `power_outage.tres` with the values above (districts as `Array[StringName]([&"tenement", ...])` in the .tres syntax the engine writes: check how `garage.tres` writes typed arrays, or write `districts = Array[StringName]([&"tenement", &"industrial"])`).

# Edge cases
- No set-piece resources found -> `set_pieces()` returns an empty array and `roll` returns `{}` without consuming RNG beyond the chance roll.
- A span piece must never be built when either side is non-NONE; `set_opening` drops it.
- `apply_plans` runs before bodies, so the mutated params reach the ShaderMaterial.
- `configure` return value feeds `travel_world`'s cooldown; return true only when a piece actually applied (`_rare` still non-empty after rebuilds).

# Do not touch
Shaders, `facade_body.gd`, `facade_keep_out.gd`, `facade_plan.gd`, `corridor_segment.tscn`, `travel_*.gd`, `van.tscn`, balance/export files, baselines, `scripts/stops/*`.

# Verification
`py -3 tools/check.py` clean; `py -3 tools/smoke.py` passes (fingerprint unchanged; `bay mouth clear:` logged). One-off headless sanity script outside the repo: for each set-piece id, configure a `corridor_segment.tscn` instance (in the tree) with `allow_rare = true` and a seed found by looping seeds 1..400 until `rare_id()` equals that id (print the seed used and the node names added under the side root or `Facades/Span`), then `open_bay` on the rare's side (or `&"left"` for a span) and assert `rare_id()` is empty and `Facades/Span` is gone. Report check tail, smoke tail (30 lines), sanity output, `wc -l` of every script created or edited, `git status --short`. Do not commit.
