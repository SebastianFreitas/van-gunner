You are implementing step 9 of a procedural street-building system in a Godot 4.7 GDScript project at C:\Users\Traff\Documents\van-gunner (Windows; `py -3`): the junction scenes (T and crossroads) and the side-street branch scene lose their flat wall slabs and get procedural facades built by the same body builder the corridor tiles use. Existing: `scripts/travel/facades/facade_plan.gd` (`plan_side(rng, district: FacadeDistrict, opening, neighborhood_seed)`, `SPLITS`, `SPLIT_WEIGHTS`, `_pick_height`, `_params_for`), `facade_body.gd` (`build(host, plan, side_sign, index)`; the face sits at local x = side_sign * (8.8 - setback), z from plan.z0 to plan.z1), `facade_registry.gd` (`district(index)`), `facade_materials.gd` (`concrete_material()`, `trim_material(preset)`), `facade_mesh_kit.gd`. Read those, plus `scenes/corridor/corridor_t_junction.gd` (63 lines), `corridor_t_junction.tscn` (172 lines), `corridor_crossroads.tscn` (197 lines), `side_street_branch.gd` (19), `side_street_branch.tscn` (81), `scripts/travel/travel_world.gd` `spawn_special_ahead` (grep -n), and `scenes/corridor/corridor_segment.gd` `_set_side_street`.

# Project rules
- GDScript: tabs, LF, ~100 columns, two blank lines between functions, everything typed, `&"..."` StringNames, `##` docs; comments explain why. Helpers `RefCounted`, no `class_name`, no `await`, never preload/name an autoload (`travel_world.gd` may reference `GameSession` as it already does; nothing new may). Scripts <= 300 target, 400 cap.
- Editing `.tscn` as text: never renumber existing ids / `uid://`; removing a node removes its children and every `[connection]` naming it and any ext/sub resource nothing else references; keep `load_steps` consistent with the remaining resource count (ext + sub + 1).
- Never launch Godot with a window; never open `.png`/`.import`/`.godot/`. Deliver `.gd.uid` for new scripts.

# 1. `scripts/travel/facades/facade_plan.gd` (EDIT)
Generalise the split: add `static func plan_length(rng: RandomNumberGenerator, district: FacadeDistrict, length: float, neighborhood_seed: int) -> Array[Dictionary]` that does what the `OPENING_NONE` branch of `plan_side` does, but for a span of `length` metres: widths = each `SPLITS` row scaled by `length / 20.0`, z from `-length / 2`; `ground_units = clampi(roundi(width / 5.0), 1, 4)`. Make `plan_side`'s NONE branch call `plan_length(rng, district, 20.0, neighborhood_seed)` so tile output is bit-identical to today (same RNG calls in the same order — verify by reading).

# 2. `scripts/travel/facades/facade_spans.gd` (CREATE, RefCounted, static, <= 150 lines)
```
extends RefCounted
## Facade spans for walls that are not corridor tile sides (junction stems, branches, the T far
## wall, side-street flanks): a host node maps the tile body builder's frame onto any wall plane.
```
Preloads `_FacadePlan`, `_FacadeBody`, `_FacadeMaterials`, `_FacadeMeshKit`.
- `static func build_span(parent: Node3D, span_name: String, face_mid: Vector3, normal: Vector3, length: float, rng: RandomNumberGenerator, district: FacadeDistrict, neighborhood_seed: int) -> Node3D`:
  1. `var into := -normal.normalized()` (from the road into the wall), `var along := into.cross(Vector3.UP)` (a right-handed frame, so nothing is mirrored), host `Node3D` named `span_name` with `transform = Transform3D(Basis(into, Vector3.UP, along), face_mid - into * _FacadePlan.FACE_X)`; add to `parent`. In that frame the body builder's right side (`side_sign` 1.0) puts the face exactly on the plane through `face_mid` with normal `normal`.
  2. `var plans := _FacadePlan.plan_length(rng, district, length, neighborhood_seed)`; for each `_FacadeBody.build(host, plans[i], 1.0, i)`.
  3. Post-pass: every `GeometryInstance3D` under host gets `visibility_range_end = 64.0`. Return host.
- `static func build_corner_tower(parent: Node3D, tower_name: String, position: Vector3, height: float) -> MeshInstance3D` — a `BoxMesh` `(0.8, height, 0.8)` centred at `position + Vector3(0, height * 0.5 - 0.4, 0)`, `concrete_material()`, shadows ON, `visibility_range_end` 64 (hides the seam where two spans meet at a junction corner).

# 3. Junctions
`scenes/corridor/corridor_t_junction.gd` (EDIT; shared by both junction scenes):
- `const _FacadeSpans := preload(...)`, `const _FacadeRegistry := preload(...)`, `var _facades_built := false`.
- `func configure(seed_value: int, district: int, neighborhood_seed: int) -> void` — if built return; `var facades := Node3D.new(); facades.name = "Facades"; add_child(facades)`; `var rng := RandomNumberGenerator.new(); rng.seed = hash([seed_value, &"junction"])`; `var district_res: FacadeDistrict = _FacadeRegistry.district(district)`; build spans (junction-local coordinates; wall face planes are where the old wall meshes were, 0.2 m in from their 0.4 m boxes: use the box centre planes given below, the body's own face offset handles the rest):
  - stem left: `face_mid (-9, 0, 14.47)`, normal `+X`, length 11.184; stem right: `(9, 0, 14.52)`, normal `-X`, 11.184.
  - branch left north: `(-14.5, 0, -9)`, normal `+Z`, 11.172; branch left south: `(-14.5, 0, 9)`, normal `-Z`, 11.172; branch right north `(14.5, 0, -9)` `+Z`; branch right south `(14.5, 0, 9)` `-Z`.
  - if `_outgoing` (crossroads): outgoing left `(-9, 0, -14.47)` `+X` 11.184; outgoing right `(9, 0, -14.52)` `-X` 11.184. Else (T): far wall `(0, 0, -9)`, normal `+Z`, length 18.0.
  - corner towers at `(-9, 0, 9)`, `(9, 0, 9)`, `(-9, 0, -9)`, `(9, 0, -9)`, height 40.
  `_facades_built = true`.
- `_ready()`: keep today's two calls, then `call_deferred(&"_ensure_facades")` where `_ensure_facades` calls `configure(0, 0, 0)` if not built (a fallback for any instantiation that never configures; travel_world always does).
`scenes/corridor/corridor_t_junction.tscn` and `corridor_crossroads.tscn` (EDIT as text): delete the wall `MeshInstance3D`s (`Stem/LeftWall`, `Stem/RightWall`, `BranchLeft/NorthWall`, `BranchLeft/SouthWall`, `BranchRight/NorthWall`, `BranchRight/SouthWall`, the T's `NorthWall2`, `NorthWall3`, the crossroads' `Outgoing/LeftWall`, `Outgoing/RightWall`), all `Lamp*` nodes, and then every sub_resource nothing references (`WallMaterial`, `WallMesh`, `BranchWallMesh`, `LampMaterial`, `LampMesh`) and the shader ext_resource `id="1"`; keep `Surfaces` and every collision shape, the roads, `Beam*` nodes with `RibMaterial`/`CrossBeamMesh`, and the `Stem`/`Outgoing` Node3Ds that still hold beams; delete `BranchLeft`/`BranchRight` Node3Ds if they end up empty. Fix `load_steps`. Report each scene's remaining `[node` count.
`scripts/travel/travel_world.gd` (EDIT `spawn_special_ahead`): after `tc._active_junction.global_transform = ...`, add `if tc._active_junction.has_method(&"configure"): tc._active_junction.configure(hash([GameSession.run_seed, &"junction", tc._segment_index]), tc._neighborhood_variant, hash([GameSession.run_seed, tc._neighborhood_start]))`. No `tc._rng` draws.

# 4. Side-street branch
`scenes/corridor/side_street_branch.gd` (EDIT): keep `mirror_x` and the `_ready` mirror loop as they are. Add `var _configured := false`, `func is_configured() -> bool`, and `func configure(seed_value: int, district: int, neighborhood_seed: int) -> void`: if configured return; create a `Facades` Node3D child NOW (after `_ready`, so the mirror loop never touches it: the `##` comment must say why); `var rng := RandomNumberGenerator.new(); rng.seed = hash([seed_value, &"branch"])`; `var m := -1.0 if mirror_x else 1.0`; spans in branch-local coordinates with x mirrored by `m`: north flank `face_mid (m * -24, 0, -10)`, normal `+Z`, length 48; south flank `(m * -24, 0, 10)`, normal `-Z`, 48; far end `(m * -48, 0, 0)`, normal `Vector3(m, 0, 0)` (facing back toward the corridor), length 20. `_configured = true`.
`scenes/corridor/side_street_branch.tscn` (EDIT as text): delete `FlankWallNorth`, `FlankWallSouth`, `FarVoid`, `Lamp0`..`Lamp4`, then the unreferenced sub_resources (`WallMaterial`, `VoidMaterial`, `LampMaterial`, `FlankWallMesh`, `VoidMesh`, `LampMesh`) and the shader ext_resource; keep the script and `RoadFloor`; fix `load_steps`. Report the remaining node count (expect 2).
`scenes/corridor/corridor_segment.gd` (EDIT `_set_side_street`): when `enabled` and the side street node `has_method(&"configure")` and `not side_street.is_configured()`: `side_street.configure(hash([_facades.seed, &"branch", idx]), _facades.district, _facades.neighborhood_seed)` (guard with `_ensure_facades()` first; `_facades.seed` is 0 before `configure`, which is acceptable).

# Edge cases
- `open_bay` hides the branch after `_set_side_street(side, true, BAY)`; the branch may get configured and immediately hidden on a stop tile: acceptable (one-off cost) — but avoid it cheaply: in `_set_side_street`, only configure the branch when `opening != Opening.BAY`.
- Both junction scenes share the script; the T has no `OutgoingRoad`, so the far wall is built only when `_outgoing == null`.
- The old T far-wall collision shapes are hand-dragged (one overshoots to x 13.27); leave collisions alone.

# Do not touch
Shaders, `facade_body.gd`, `facade_keep_out.gd`, `corridor_segment.tscn`, `travel_controller.gd`, `travel_stops.gd`, `van.tscn`, balance/export files, baselines.

# Verification
`py -3 tools/check.py` clean (rerun once for stale `uid_cache`); `py -3 tools/smoke.py` passes with the fingerprint unchanged (the smoke drives through two junctions and past side streets). One-off headless sanity script outside the repo: instantiate `corridor_t_junction.tscn` and `corridor_crossroads.tscn` in the tree, call `configure(5, d, 9)` for d in 0..4, print the span host names and the `MeshInstance3D` count under `Facades`; instantiate `side_street_branch.tscn` with `mirror_x` true and false, `configure(3, 1, 9)`, print the global AABB (x range) of the far-end span's first body for both, and assert the mirrored one has x > 0. Report check tail, smoke tail (30 lines), sanity output, node counts, `wc -l` of every script created or edited, `git status --short`. Do not commit.
