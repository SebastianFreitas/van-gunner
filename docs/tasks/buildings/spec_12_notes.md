# Step 12: notes on the committed tree (read with spec_12_debug_stress.md)

These override the spec where they differ.

## Where to work

Same as `spec_08b_notes.md` "Where to work": the repo root is the worktree
`C:\Users\Traff\Documents\van-gunner\.claude\worktrees\continue-previous-work-605228`, never
edit or stage `resources/balance/game_balance.tres` or `export_presets.cfg`, read `GODOT` through
powershell, sanity scripts in the scratchpad, write files with the Write tool, never
`git stash` / `git worktree`. Lines of at most 100 columns (tab = 4).

## What exists now (after 8a, 8b, 10a, 10b)

- Twenty-two set-pieces in `resources/facades/set_pieces/` (list them from the registry, never
  hard-code the ids). Spans build under `Facades/Span`; industrial overhead dressing builds
  under `Facades/Overhead` (only on tiles with no rare); both are dropped when a side opens.
- `facade_keep_out.gd` has `static func lane_box() -> AABB`, `body_boxes_for(side_sign,
  opening)`, `prop_boxes_for(side_sign, opening)`.
- `DebugCommands` is an autoload (`scripts/debug/debug_commands.gd`, 219 lines); the smoke
  already calls `DebugCommands.run("...")`.
- The mouth audit today is `tools/smoke/smoke_route.gd::_assert_bay_mouth_clear` (lines ~75-120):
  it loads `facade_keep_out.gd` by path, walks every tile whose `opening_of(side) == 2`, and checks
  visible `VisualInstance3D`s under `facade_root(side)` (`Body*` names against body boxes, the
  rest against prop boxes). Its log line is
  `bay mouth clear: %d bay side(s), %d facade nodes checked`; keep that text exactly.

## Corrections to the spec

1. **Do not hide the stress host.** `is_visible_in_tree()` is false under a hidden parent, so a
   hidden host makes every audit skip every node and pass vacuously. Make the stress host a
   visible `Node3D` at `position = Vector3(0, -500, 0)` (it lives for one synchronous call and is
   freed before any frame renders). In `facade_audit`, treat a node as visible when
   `node.visible` holds for it and every ancestor up to (not including) the tile root. That
   helper takes the tile as an argument, so both the smoke and the stress use the same rule.
2. **Skip nodes that are being freed.** `rebuild_side` renames the old side root to
   `LeftOld`/`RightOld` and calls `queue_free()`, and `set_opening` queue-frees `Span`/`Overhead`.
   In a synchronous stress build those nodes are still in the tree when the audit runs, and the
   old pre-bay building would count as a mouth violation. The audit skips any node that is, or
   has an ancestor below the tile that is, `is_queued_for_deletion()`, and any subtree whose root
   name ends in `Old`.
3. **Lane audit scope.** Only the tile's own `Facades` child (`Left`, `Right`, `Span`,
   `Overhead`), not `SideStreets/*`, whose branch facades are built far outside the lane.
4. **No vacuous pass.** `mouth_violations` also reports a violation line when a bay side has zero
   checked nodes. The stress fails a build whose lane audit checked zero nodes.
5. `facade_audit.gd` API (RefCounted, static, no class_name; `##` summary):
   - `static func mouth_violations(corridor_root: Node) -> Array[String]` (every tile under the
     root with a BAY side) plus `static func tile_mouth_violations(tile: Node3D, counts: Dictionary) -> Array[String]`
     for one tile. `counts` gets `&"bays"` and `&"checked"` added, so the smoke can still log its
     exact line.
   - `static func tile_lane_violations(tile: Node3D, counts: Dictionary) -> Array[String]`.
   The smoke keeps its log and fail text: it fails with the first violation line, and with the
   existing messages when there are no bays or zero nodes were checked.
6. **forced_id and allow_rare.** The forced branch in `roll` returns the forced piece whenever
   `forced_id != &""`, regardless of `allow_rare`, the chance and the piece's `districts` (so the
   stress covers every piece on every district), but still respects span/side eligibility for
   `openings`. It makes no RNG draw.
7. **Stress flow per build** mirrors the game: instantiate, `add_child` to the host (in the
   tree), `configure(seed, district, hash([seed]), true)` (openings NONE/NONE at this point, as
   in `travel_world`), `apply_side_streets(false, false)`, then `open_bay(side)` for a bay case,
   then both audits, then `host.remove_child(tile); tile.free()`. Set
   `facade_set_pieces.forced_id` per piece and restore the previous value in every exit path
   (including an early error return). The "none" case uses `forced_id = &""` with
   `allow_rare = false` in `configure`, so it builds plain tiles (and overheads).
8. Before relying on it, read `corridor_segment.gd`'s `_ready` and `configure` and confirm that
   instantiating a tile outside the travel world has no global side effects (group
   registrations other than `facade_lights`, signals to autoloads). Report what you find. Lights
   count toward the world cap only while alive, and the tile is freed at once.
9. `pick_district`'s meta check goes first, before any `tc._rng` draw, exactly as the spec says.
   `travel_controller.gd` must not change.
10. Timing: print the wall time in the report. If `facade stress 1` takes more than 40 s headless,
    stop and report instead of trimming coverage yourself.

## Verification

As the spec says. In addition, the one-off sanity must:
- run `facade stress 1` and confirm the "none" case audits a non-zero node count;
- deliberately prove the audit can fail: add a `MeshInstance3D` with a 1 m `BoxMesh` at tile
  (x 9.0, y 1.0, z 0.0) under the bay side root of a stress tile in the sanity script only (never
  in the repo) and confirm `tile_mouth_violations` reports it;
- print the node count before and after the stress (`Performance.OBJECT_NODE_COUNT`, after one
  `await process_frame`); they must match.
