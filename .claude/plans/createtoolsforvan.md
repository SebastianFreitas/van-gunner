# createtoolsforvan

Stage: done
Started: 2026-10-12
Procedure: `.claude/skills/plan/interview.md` (the interview), then `run.md` (state in `.claude/plans/<name>.state.md` while running).
Path: light (tooling, one area: shot tools; from Brief)
Size: at most 20 KB (10 KB on the light path), each phase at most 2.5 KB (interview.md "Plan size")
Interview: A done · 4 asked; C done, D9 + build reviews 1 and 2 applied   <- A/B/C open or done, running total; missed: lines while running
Questions: auto

## Brief (owner's words, verbatim)

createtoolsforvan we just made stuf fto take pcitures of the windows, but what about one for all the interior in the van?

## Pass test (what "done" means; judged by the `look-judge` or a named command)

- none (no look or number to judge): tooling (D4).
- Judged on: `py -3 tools/smoke.py --shots <dir> --views icam` prints `SMOKE VIEWS DONE` and saves one `icam_*.png` per `describe()` name (21 today); `py -3 tools/check.py` clean.

## Scope

- In: new `scripts/van/van_interior_cams.gd`, one line in `scripts/van/van.gd` (beside :93), new `tools/smoke/smoke_shots_icam.gd`, `tools/smoke/smoke_driver.gd` (views flag), `tools/smoke.py` (`--views` choices, :112 skip), `.claude/rules/tooling-shots.md`, map regen.
- Out (stays exactly as is): the default `--shots` set, every baseline and fingerprint, `VanWindowCams`, `smoke_shots.gd`, `smoke_shots_closeups.gd`, lighting.

## Current state (explored 2026-10-12; anchors drift, grep the names)

- `scripts/van/van_window_cams.gd` (123 lines, `VanWindowCams`): one Camera3D per window, rig-local, built in `refresh()` (:34), `names()` :67, `camera()` :74, `aim(name, outward)` :80 moves to the outside view, `describe()` :95, `_place()` :101 fits the window in the FOV (`_MARGIN` 1.25, `_WALL_GAP` 0.1, `_NEAR` 0.05). Names `side_<l|r>_<rear|front>`, `rear_<l|r>`, `cab_<l|r>`; right = x<0.
- `tools/smoke/smoke_shots_wcam.gd` (59 lines): finds the live `VanWindowCams`, saves `wcam_<name>.png` and `_out.png` (`run` :13, `_save` :50).
- `tools/smoke/smoke_driver.gd:19,33,40,82`: `--smoke-views=wcam` flag, pins the van (`pin_van`/`unpin_van`), shoots, quits.
- `tools/smoke.py:36,195-197,223,255,281,338`: `--views` choices `["wcam"]`, needs `--shots`, skips stress shards, fingerprint (:112 hard-codes `--smoke-views=wcam`) and verify stamp, prints `SMOKE VIEWS DONE`.
- Existing interior views: default `--shots` front/back/above per checkpoint; `c01..` door/window/seam/rear-roof close-ups (`smoke_shots_closeups.gd` `views` :24), `g01..` gap-light views (`gap_views` :135, judged by `tools/gap_check.py`), `f01..f05` floor close-ups (`floor_views` :283). smoke_shots_closeups.gd is 356 lines, smoke_shots.gd 400 (at cap): new code goes in new files.
- `tools/shots.py`: compare per view; unknown views fall back to a default tolerance (:43-48).
- `VanInteriorSize`: x ±3.39 bottom / ±2.96 top, wall 4.00, z -4.70 (front) to 6.58 (rear), length 11.28, rear door half 2.7, top 3.6, bulkhead half 3.30. Floors: mid y `VanFloorHeight.RAISE` 0.45, rear y 0, stairs end `STAIR_END_Z` 1.96 (`VanFloorHeight.at`). Bulkhead (`van_bulkhead.gd`, frame + mesh, kick panel 0.55) at `VanOpenings.BULKHEAD_Z` 1.0 splits mid (FRONT_Z..1.0) from rear (1.0..REAR_Z); doorway x -3.30..-1.92. Player eye `FpsPlayer.EYE_HEIGHT` 2.0 (fps_player.gd:25). Window 1440x720; Godot `fov` is vertical by default.
- Rules: `.claude/rules/tooling-shots.md:31` documents wcam; art-shots.md holds the luminance targets (`tools/shot_stats.py`).

## Open items

- none

## Decisions (while asking; folded into the phases in Part C; `(auto)` = taken while running)

- (D9, owner 2026-10-13: "if its not depent on a wall, but like interactable like the computers ... it should change where the shot is taken depending on its location and front"; folded into phase 1 and Constraints.) (D1-D8 folded: D1, D3, D7 into Constraints; D2, D5, D6, D8 into phases 1-2; D4 into Pass test.)
- (D10, writer 2026-10-13 from build review: `cab_partition` became two views, `bulkhead` (from rear) and `cab_end` (from mid), since one cam cannot see the cab wall through the bulkhead; (from code) van_openings.gd:39.)
- (D11, writer 2026-10-13 from build review 2, reviewer's picks: prop front by thin axis, vertical fits, wy aims, bulkhead cut accepted; in phases 1-2.)
- (D12 (auto), phase 2: prop AABB merges MeshInstance3D only, not every VisualInstance3D: the CraftingTable's light and particles pushed its cam to about 6 m.)
- (D13 (auto), phase 2: a prop counts as vital when a direct child is in group `van_vitals` (the child is named `VanVital`), not a child named `van_vitals`.)

## Initial idea

Initial idea skipped (light path).

## Constraints (every phase)

- Light path, tooling only, no player-facing change (D1).
- Every wall/surface cam position derives from `VanInteriorSize`, `VanOpenings`, `VanFloorHeight`, `FpsPlayer.EYE_HEIGHT` constants, never a literal coordinate (D3, invariant 16); prop cams derive from the prop's live transform (D9).
- Every cam and its look target stay in one compartment (mid FRONT_Z..BULKHEAD_Z, rear BULKHEAD_Z..REAR_Z), at least 0.3 m from BULKHEAD_Z (from code: van_openings.gd:39).
- Every icam Camera3D sets `keep_aspect = KEEP_WIDTH`, FOV 70, so FOV is horizontal (at 2:1, about 39° tall); fits below use tan35° = 0.70 wide, 0.35 tall (from code: project.godot 1440x720).
- `refresh()` `push_error`s any cam outside its compartment box (|x| < BOTTOM_HALF, F < y < WALL_HEIGHT) or equal to its target, so the phase 3 smoke catches it.
- Runs only with `--views icam`; plain `--shots`, baselines, fingerprint and the verify stamp untouched, same skips as `wcam` (D7).
- Game light: no added lights or exposure changes (D6).

## Progress

| # | Phase | Kind | Needs | Rests on | Status |
|---|---|---|---|---|---|
| 1 | Interior camera node | code | - | D2 D5 D8 | done 2fe1be3 |
| 2 | Prop cams | code | 1 | D9 | done 107c3fd |
| 3 | `--views icam` shooter | code | 1 2 | D2 D7 | done 2fba16b |

Needs: earlier phases whose output it builds on. Rests on: decisions still in the list, or Brief. Status: todo, done <sha>, deferred Q<k>.

## Phases

### 1 · Interior camera node
Deliverable: `VanInteriorCams` (`class_name`, Node3D, rig-local like `VanWindowCams`, added in `van.gd` beside :93): `refresh()`, `names()`, `camera(name)`, `describe()`, one Camera3D per view, near 0.05. S = VanInteriorSize, O = VanOpenings, H = VanFloorHeight, F(x,z) = `H.at`, eye = F + EYE_HEIGHT, M = (S.FRONT_Z+O.BULKHEAD_Z)/2 = -1.85, R = (O.BULKHEAD_Z+S.REAR_Z)/2 = 3.79, wy = (F+S.WALL_HEIGHT)/2. Fifteen views:
- `floor_mid`: (0, F+2.6, S.FRONT_Z+1.0) -> (0, F, M). `floor_rear`: (0, F+2.6, H.STAIR_END_Z) -> (0, F, (H.STAIR_END_Z+S.REAR_Z)/2).
- `ceiling_mid` / `ceiling_rear`: (0, F+0.6, M or R) -> (0, S.WALL_HEIGHT, same z+0.01).
- `wall_left_mid`, `wall_left_rear`, `wall_right_mid`, `wall_right_rear`: (∓(S.BOTTOM_HALF-0.5), eye, M or R) -> (±S.BOTTOM_HALF, wy, same z) (left = +x). Fit: 2.85/0.70 = 4.07 m wide, 2.0/0.35 = 5.7 m tall; distance 6.28 fits.
- `rear_doors`: (0, eye, O.BULKHEAD_Z+0.3) -> (0, S.REAR_DOOR_TOP/2, S.REAR_Z); d 5.28: 2.7/0.70 = 3.86, 1.8/0.35 = 5.14 <= 5.28.
- `side_door_left/right`: (∓1.0, eye, O.SIDE_DOOR_Z) -> (±S.BOTTOM_HALF, O.SIDE_DOOR_Y_MIN+O.SIDE_DOOR_HEIGHT/2, O.SIDE_DOOR_Z); eye 2.45 < door top 3.07; fits.
- `bulkhead` (D10): (0, eye, S.REAR_Z-0.3) -> (0, wy, O.BULKHEAD_Z); d 5.28: 3.30/0.70 = 4.71 fits wide; 2.0/0.35 = 5.71 > 5.28, so about 0.15 m top and bottom fall outside: accepted, do not chase it (D11). `cab_end` (D10): (0, eye, O.BULKHEAD_Z-0.5) -> (0, wy, S.FRONT_Z), wy 2.225; d 5.2: 3.39/0.70 = 4.84, 1.775/0.35 = 5.07 <= 5.2.
- `corner_front_left`: (S.TOP_HALF-0.3, S.WALL_HEIGHT-0.3, S.FRONT_Z+0.3) -> (0, F, M); `corner_rear_right`: (-(S.TOP_HALF-0.3), S.WALL_HEIGHT-0.3, S.REAR_Z-0.3) -> (0, F, R).
Check: `py -3 tools/probe.py --eval` printing the live `VanInteriorCams.describe()`: 15 names, no `push_error`.
Files: `scripts/van/van_interior_cams.gd`, `scripts/van/van.gd`. Reads `van_window_cams.gd`.
Verification: `py -3 tools/check.py`, `py -3 tools/smoke.py` (default shots, no fingerprint change).
Reviewed: owner 2026-10-12 (phases question; prop-following cams added as D9)
Notes: done 2fe1be3; look_at up is FORWARD only when |dir.y| > 0.9, else UP; node named InteriorCams in `_init`.

### 2 · Prop cams
Deliverable: `refresh()` adds `prop_<node snake_case>` per direct child of `Interior/Props` that is an `Interactable` or has a `van_vitals` child (today CraftingTable, LootMachine, FuseBox, CabRelay, RequestBoard, ClassBoard), from the live transform (D9).
Front (D11; from code: class_board.tscn faces local +x, CabRelay rolled): the prop's thinnest horizontal axis of its merged local AABB (VisualInstance3Ds), signed toward its compartment centre; if thinnest/next is over 1/1.5 (no clear face, e.g. CraftingTable), the ±basis axis flattened to horizontal with the largest dot with (centre - prop). C = merged AABB centre, rh = largest horizontal half extent, ry = half height, d = max(1.2, 1.25·max(rh/0.70, ry/0.35)); cam = C + front·d at C.y, looking at C. Clamp into the prop's compartment (0.3 m off BULKHEAD_Z, 0.2 m off walls, F+0.3 < y < WALL_HEIGHT-0.2); if d < 0.6 after, cam at y WALL_HEIGHT-0.3 above the clamped spot looking down.
Check: `py -3 tools/probe.py --eval` that prints describe(), rotates ClassBoard 90° about y, calls `refresh()`, prints again: 21 names, `prop_class_board` moved by over 0.5 m and still on the board's thin axis.
Files: `scripts/van/van_interior_cams.gd` (`RefCounted` helper past 300 lines).
Verification: `py -3 tools/check.py`, `py -3 tools/smoke.py`.
Reviewed: owner 2026-10-12 (phases question; prop-following cams added as D9)
Notes:

### 3 · `--views icam` shooter
Deliverable: `tools/smoke/smoke_shots_icam.gd` copying `smoke_shots_wcam.gd`: save `icam_<name>.png` per name (no `_out`). `smoke_driver.gd` takes `--smoke-views=icam` beside `wcam` (:19,:40), same pin. `smoke.py`: choices `["wcam", "icam"]`, the :112 fingerprint skip on any `--smoke-views=` arg, docstring :36. One line in `tooling-shots.md` beside :31; regen the map.
Files: the three tools files, the rules file.
Verification: `py -3 tools/check.py`, `py -3 tools/smoke.py`, `py -3 tools/smoke.py --shots <scratch>/shots --views icam` (21 files, `SMOKE VIEWS DONE`); read a shot once only if `tools/shot_stats.py` says black or uniform.
Reviewed: owner 2026-10-12 (phases question; prop-following cams added as D9)
Notes: done 2fba16b; check, smoke clean; 21 icam shots, SMOKE VIEWS DONE; shot_stats: none black or uniform (ceiling_mid/rear very dark, mean ~0.0013; request_board mean 0.048, crafting_table 0.0185). smoke_driver.gd hit 400 lines, so `_wcam_only` became one `_views_only` string.

## Carry forward

- Views: floor_mid, floor_rear, ceiling_mid, ceiling_rear, wall_left_mid, wall_left_rear, wall_right_mid, wall_right_rear, rear_doors, side_door_left, side_door_right, bulkhead, cab_end, corner_front_left, corner_rear_right, plus prop_<node> (D9).
- (phase 1) The node is the rig child `InteriorCams`; `scripts/van/van.gd` is at 399 lines, so phase 2 adds nothing there.
- (phase 2) Prop cams live in `van_interior_cams.gd` (225 lines); RequestBoard (161 meshes, PcRig) and CraftingTable get about 5 m distances and hit the compartment clamps: judge their icam shots in phase 3.
