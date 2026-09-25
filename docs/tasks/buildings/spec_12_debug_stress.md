You are implementing step 12 of a procedural street-building system in a Godot 4.7 GDScript project at C:\Users\Traff\Documents\van-gunner (Windows; `py -3`): debug console commands for the facade system and a `facade stress` audit the smoke test runs. Existing: `scripts/debug/debug_commands.gd` (219 lines; command table `_register_commands`, helper `_find_travel_controller`, `_cmd_help`), the helper command scripts it preloads (`debug_run_flow_commands.gd`, `debug_act_commands.gd`, ... — read one, e.g. `debug_act_commands.gd`, as the template: how a helper is constructed, how `cmd_*` functions take `args: Array` and return a String), `scripts/debug/debug_catalog.gd` (`cmd_list`), `scenes/corridor/corridor_segment.gd` (`configure`, `apply_side_streets`, `open_bay`, `opening_of`, `facade_root`, `district`, `rare_id`, `describe_facades`), `scripts/travel/facades/corridor_facades.gd`, `facade_registry.gd` (`districts()`, `set_pieces()`, `reset()`), `facade_set_pieces.gd` (`roll`, `debug_force`), `facade_keep_out.gd` (`body_boxes_for`, `prop_boxes_for`), `scripts/travel/travel_world.gd` (`spawn_world_segment`, `pick_district`), `scripts/travel/travel_controller.gd` (`corridor_root`, `_world_pieces`, `_segment_index`, `_neighborhood_variant`), `tools/smoke/smoke_route.gd` (`fork_pass`, `_assert_bay_mouth_clear`). Read them first (grep -n then ranges for files over 300 lines; `travel_controller.gd` is over the cap on purpose and must not change).

# Project rules
GDScript: tabs, LF, ~100 columns, two blank lines between functions, everything typed, `&"..."` StringNames, `##` docs; comments explain why. Helpers `RefCounted`, no `class_name`, no `await` in helpers, never preload/name an autoload from a helper (the debug helpers already receive what they need from `debug_commands.gd`; follow the existing pattern exactly — if the existing helpers reference autoloads, you may do the same). Scripts <= 300 target, 400 cap. `SaveSandbox` is the only test hook in game code: the stress audit is a debug command (owner-facing), not a test hook. Never launch Godot with a window; never open `.png`/`.import`/`.godot/`.

# 1. Forcing hooks (tiny, in game code)
- `scripts/travel/facades/facade_set_pieces.gd` (EDIT): `static var forced_id := &""` (## Debug: when set, roll() returns this piece on every eligible tile instead of rolling). In `roll`, when `forced_id != &""`: find the piece by id; if it exists and its side/span eligibility holds for `openings`, return it (side: first NONE side); else `{}`. No RNG draw in that branch.
- `scripts/travel/travel_world.gd` (EDIT `pick_district`): `if tc.has_meta(&"debug_district"): return int(tc.get_meta(&"debug_district"))` at the top — BEFORE any `tc._rng` draw (a forced district freezes the neighborhood draws; that is fine for a debug session). No new fields on `travel_controller.gd`.

# 2. `scripts/debug/debug_facade_commands.gd` (CREATE, <= 300 lines)
```
extends RefCounted
## Debug console commands for the street facades: force a district or set-piece, reseed the
## tiles in view, print stats and plans, and run the keep-out stress audit.
```
Constructed like the other helpers (owner = the DebugCommands node; use its `_find_travel_controller()` through a passed-in Callable or by duplicating the group lookup — follow the template). Register in `debug_commands.gd`'s table as `"facade": _facade.cmd_facade` (one entry; sub-commands parsed from `args[0]`), and add `facade` to whatever completion/help structures the other commands use (read `get_completion_context` and `_cmd_help`; keep `debug_commands.gd` under 300 lines — if adding pushes it over, put the sub-command names in the new helper and expose `sub_commands() -> Array[String]`).
Sub-commands (`cmd_facade(args: Array) -> String`):
- `facade` / `facade help` — usage lines.
- `facade list` — districts (index, id) and set-pieces (id, weight, districts, span).
- `facade district <index|id|off>` — sets/clears `travel.set_meta(&"debug_district", index)`; returns what it did. New tiles use it.
- `facade rare <id|off>` — sets `facade_set_pieces.forced_id`; returns confirmation (unknown id -> error text listing ids).
- `facade reseed [n]` — for every corridor tile alive (`travel.corridor_root` children with `has_method(&"configure")`), call `configure(<n or randi()> + child index, tile.district(), hash([n, &"nb"]), true)` then `apply_side_streets` with its current openings (read `opening_of` for both sides before, re-apply: NONE/NONE -> `apply_side_streets(false, false)`; keep BAY sides untouched: skip tiles with a BAY opening). Returns "reseeded N tiles".
- `facade stats` — tiles alive, total `MeshInstance3D` under all `Facades` nodes, `OmniLight3D` count in group `facade_lights`, ShaderMaterial count (unique `material_override` on bodies), and the `describe_facades()` of the tile nearest the van (the one whose `route_progress` meta is closest to `travel.van_follow.progress`).
- `facade dump [left|right]` — `describe_facades()` of the nearest tile plus, per building on that side: preset, height, floors, ground_kind, rare, and the list of prop node names.
- `facade check` — runs the same mouth audit as `smoke_route._assert_bay_mouth_clear` over all alive tiles (reuse its logic by moving it into a static function on a new tiny helper `scripts/travel/facades/facade_audit.gd`: `static func mouth_violations(corridor_root: Node) -> Array[String]` returning human-readable violation lines; `smoke_route.gd` then calls that and fails on a non-empty result, keeping its own log/fail lines). Returns "OK mouth clear (N nodes)" or the violation lines.
- `facade stress [seeds]` — the matrix audit: for every district index and every set-piece id (plus "none"), for openings in [(NONE, NONE), (BAY, NONE), (NONE, BAY)], for `seeds` seeds (default 2): instantiate `res://scenes/corridor/corridor_segment.tscn` under a hidden `Node3D` parented to the DebugCommands node (it must be in the tree for `@onready`), set `facade_set_pieces.forced_id`, `configure(seed, district, hash([seed]), true)`, `apply_side_streets(false, false)` then `open_bay(side)` when the case has a bay, then `facade_audit.mouth_violations` on that one tile AND a lane audit: every visible `VisualInstance3D` under `Facades` whose tile-local AABB intersects `facade_keep_out.lane_box()` is a violation ("lane"); free the tile (`free()`, not queue_free, so memory stays flat) and continue. Restore `forced_id` to its previous value at the end. Returns `"OK stress: %d builds, 0 violations"` or lines `"FAIL district=%d rare=%s openings=%s seed=%d: %s"` (cap at 20 lines then "... and N more"). It must finish in well under 60 s headless (about 5 districts x ~23 pieces x 3 openings x 2 seeds = ~700 builds; if a build takes > 10 ms, reduce the default seeds to 1 and say so).

# 3. `tools/smoke/smoke_route.gd` (EDIT)
In `fork_pass`, before the first `drive_side_stop`, add: `var stress := DebugCommands.run("facade stress 1")`; `driver._log(stress)`; if `not stress.begins_with("OK")`: `driver._fail("facade stress: " + stress)`; return false. (`DebugCommands` is already used there for the stop commands; keep the same access pattern.)
Switch `_assert_bay_mouth_clear` to `facade_audit.mouth_violations` as described in section 2 (same log/fail text).

# 4. Docs
None here (the docs step is separate).

# Edge cases
- `facade stress` on a machine where set-piece resources are missing still runs the "none" case.
- `debug_district` meta persists for the session; `facade district off` removes the meta.
- Freed stress tiles must not leak: use `free()` after removing from the tree and confirm with `Performance.get_monitor(Performance.OBJECT_NODE_COUNT)` before/after in your sanity run.

# Do not touch
Shaders, `facade_body.gd`, `facade_plan.gd`, `corridor_segment.tscn`, `travel_controller.gd`, `travel_stops.gd`, `van.tscn`, balance/export files, baselines.

# Verification
`py -3 tools/check.py` clean; `py -3 tools/smoke.py` passes with the new `OK stress:` line logged and `bay mouth clear:` still logged, fingerprint unchanged; paste the smoke tail (35 lines). Also run the stress once more in a one-off headless script outside the repo with `seeds` 3 and paste its output and wall time. Report `wc -l` of every script created or edited and `git status --short`. Do not commit.
