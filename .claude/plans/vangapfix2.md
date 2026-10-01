# vangapfix2

Stage: ready
Started: 2026-09-30
Procedure: `.claude/skills/plan/interview.md` (the interview), then `run.md` (state in `.claude/plans/vangapfix2.state.md` while running).
Path: light (D1, from Brief: four named seams in the van shell, no new design)
Size: aims at 10 KB (light path), at most 20 KB, each phase at most 2.5 KB (interview.md "Plan size")
Interview: A, C done · 7 asked · review: build 2 rounds, art style 1 · Initial idea skipped (light path)
Questions: ask

## Brief (owner's words, verbatim)

> close the gaps vangapfix left open (side window and rear door window surrounds, the roof edge above each side door, the side door slits seen from outside), as listed in vangapfix's D77

## Scope

- In, by phase: 1 new `scripts/van/side_door_header_seal.gd`, one call in `scripts/van/van_side_wall.gd`; 2 `scripts/van/side_door_stops.gd` (and the reveals in `van_side_wall_panel.gd` only if the path runs there); 3 new `scripts/van/rear_window_lip.gd`, one call in `scripts/van/rear_door_leaf_build.gd`; 4 `scripts/van/side_windows.gd`; 5 the seal files the leftover pink points at; 6 `scripts/van/look/van_marker_lights.gd`, `tools/van_audit/van_audit_exempt.gd` (reason text), `.claude/rules/van-shell-and-hud.md` (seams paragraph). Every phase: `tools/smoke/fingerprint.baseline.txt` when blessed, `docs/PROJECT_MAP.md`.
- Out (stays exactly as is): the cab front; the roof skin, the cove, the door leaves' outer shape and the door motion; vangapfix's seals unless a phase names one; `art-style.md` values.

## Current state (explored 2026-09-30; anchors drift, grep the names)

- **Views.** vangapfix's 43 gap-light views (`g01`..`g43`, `tools/smoke/smoke_shots_closeups.gd`, judged by `tools/gap_check.py`) fail strict on 29 (list in vangapfix D77). Last set: `%TEMP%/vgf6/shots/`.
- **Roof edge above the side doors.** Pink band under the roof skin along the whole door top, from the street (`g30`, `g31`). Near it: `RoofSkin` and its down-turned lip (`look/van_hull.gd` `_build_roof`, rim y 3.14 at x 2.22, lip down to the wall top 3.08), the door header at y 3.05 (`van_side_wall_panel.gd` `add_door_opening_reveals`), `DoorSlideTrack_*` (`van_side_wall.gd` `_add_door_slide_tracks`, y 2.97..3.05, cabin layer), `CoveL/R` (`van_ceiling_cove.gd`, y 3.056..3.126). No face closes the path between the wall's outer top and the roof lip above the door bay.
- **Rear door windows.** Pink down the outer vertical edge of each rear leaf window and at its outer corners (`g03`, `g23`..`g25`). The leaf is a vaulted slab (`van_hull_mesh.gd` `build_vaulted_xy_slab`, from `rear_door_leaf_build.gd`, `WINDOW_HOLE`); its skin stops at the hole edge and does not meet the cabin-side `rear_door_frame.gd` where the leaf curves away. No street-side frame.
- **Side windows.** A thin pink line at the surround's rear edge (`g38`..`g41`, and in `g12`..`g17`). `side_windows.gd` frame and stop rings, cut in `van_side_wall.gd` (`WINDOW_CUT_POLY`); the frame's outer edge butts the cut.
- **Side door slits.** Pink at the closed leaf's rear edge and bottom from the street (`g29`, `g32`, `g33`, `g35`..`g37`), hairlines at the stop's rear edge from inside (`g19`, `g21`). The leaf (`side_door_leaf.gd`, 2.21 m) leaves about 13 cm at each end of the 2.47 m opening; the `side_door_stops.gd` plate sits 7.5..9 cm inboard of the liner; the reveals close the wall cavity all round.

## Open items

- none

## Decisions (while asking; folded into the phases in Part C; `(auto)` = taken while running)

- none left (D2..D6 folded into Constraints and phases)

## Constraints (every phase)

- Geometry only; always night. Read `.claude/rules/van-shell-and-hud.md` and `.claude/rules/art-style.md` first. Axes: x across (left negative), y up, z along (cab -z, rear +z).
- **Seal rule** (from rules): overlap about 5 cm, never over 7 cm into an opening, 2 cm clear of a moving leaf, an edge on a fixed surface sunk 2 cm; no parallel face within 1 cm (audit FLICKER). Both door kinds move away from the cabin (from code: side leaf `recess_distance -0.30`, rear leaves swing out), so a seal over a leaf's edge stands on the cabin side; a street-side piece rides on the leaf it covers (D5).
- **Visible trim is fine (D2, owner):** every seal seen from the street uses the rear lips' material (the steel `rear_door_lips.gd` `_material` picks, re-read from the same node it reads; flat, never `from_prop`), no wider than the seal rule needs; street pieces take layer 1 via `VanLighting.GROUP_EXTERIOR_LAYER` as `rear_door_lips.gd` does, cabin pieces `LAYER_VAN_INTERIOR`, set before `add_child`.
- **Done bar (D3, owner):** zero pink. Each phase gets its own views to 0; phase 6 passes `gap_check.py --strict` on all 43.
- **Own views only (D6, from vangapfix D75):** a phase fixes its own audit rows and its own views; pink elsewhere goes to Carry forward (view, px, where) for phase 5, never a block.
- New helpers: `RefCounted`, no `class_name`, no `await`, under 300 lines, typed, tabs, `&"..."` StringNames, a one-line `##` summary after `extends`.
- **Order, every phase:** when `.godot/shots/before/` has no `g*.png`, `py -3 tools/shots.py capture before` first (fresh worktree: `py -3 tools/check.py` before it, so `.godot/` is seeded). Then the specs; `py -3 tools/check.py`; `py -3 tools/smoke.py` (strict audit; `--bless` only when it says the fingerprint moved, named in the report); `py -3 tools/scene_dump.py` must end `SCENE DUMP CLEAN`, never blessed; `py -3 tools/smoke.py --shots <scratchpad>/shots`, `py -3 tools/gap_check.py <scratchpad>/shots`, `py -3 tools/shots.py compare before <scratchpad>/shots` (non-`g` views change only at the phase's seam); `py -3 tools/gen_context.py`; commit by path.
- Code that does not follow the phase text is fixed and the Order reruns; a phase blocks only when the code follows the text and still fails.

## Progress

| # | Phase | Kind | Needs | Rests on | Status |
|---|---|---|---|---|---|
| 1 | Roof edge above the side doors | code | - | Brief, D2 | todo |
| 2 | Side door slits | code | - | Brief | todo |
| 3 | Rear window surrounds | code | - | Brief, D2 | todo |
| 4 | Side window surrounds | code | - | Brief | todo |
| 5 | Leftover pink sweep | code | 1, 2, 3, 4 | D3, D7 | todo |
| 6 | Amber lamps, rules text, final check | code, doc | 5 | D3, D4 | todo |

## Phases

A phase session reads its own section, the Brief, Constraints and Carry forward.

### 1 · Roof edge above the side doors
Own views: `g30`, `g31`; the door-top part of `g08`, `g10`, `g14`, `g15`.
Deliverable: one spec. New `scripts/van/side_door_header_seal.gd` (`## Side door header seal: dark steel strip closing the band between the side wall's outer top and the roof lip above each side door.`), `static func build(walls: VanSideWall, parent: Node3D) -> void`, called once from `van_side_wall.gd` beside `_add_door_slide_tracks`; nodes `DoorHeaderSeal_L` / `_R` over the door's z span plus 5 cm each end, street layer, the rear lips' material (Constraints). → phase decides: measure the open band's y and x along the door bay (from `_build_roof` and `add_door_opening_reveals`, checked in `g31`), then apply the seal rule: 5 cm onto the roof lip's underside and the wall's outer skin, edges sunk 2 cm, 2 cm clear of the leaf closed and stepped out. Reads: `look/van_hull.gd`, `van_side_wall_panel.gd`.
Verification: Order; own views 0; the door still opens (smoke).
Reviewed: Right (owner, 2026-10-01)
Notes:

### 2 · Side door slits
Own views: `g19`, `g21`, `g29`, `g32`..`g37`; the slit part of `g12`, `g13`, `g16`, `g17`.
Deliverable: one spec in `side_door_stops.gd` (the reveals only if the path runs through them). → phase decides: trace the street-to-cabin path through the leaf's rear, bottom and front slits, then close it cabin side by the seal rule: the stop (or a return from the reveal) overlaps the leaf's edge by 5 cm and stays 2 cm clear of the leaf closed, stepped out and sliding. Reads: `side_door_stops.gd`, `side_door_leaf.gd`.
Verification: Order; own views 0; the door opens and closes with no clip (smoke).
Reviewed: Right (owner, 2026-10-01)
Notes:

### 3 · Rear window surrounds
Own views: `g03`, `g23`, `g24`, `g25`.
Deliverable: one spec. New `scripts/van/rear_window_lip.gd` (`## Rear window lip: dark lip riding on each rear leaf, closing the slot between the vaulted skin and the window's cabin frame.`), called once per leaf from `rear_door_leaf_build.gd`; node `WindowLip` under each leaf, the rear lips' material, street layer, rounded like `WINDOW_HOLE`. → phase decides: measure the slot between the vaulted skin and the cabin frame around the hole (widest at the outer vertical edge), then apply the seal rule: 5 cm onto the skin, at most 7 cm into the glass, sunk 2 cm; never past the leaf's inner edge. Reads: `van_hull_mesh.gd` `build_vaulted_xy_slab`, `rear_door_frame.gd`.
Verification: Order; own views 0; the leaves swing 110° with no clip (smoke).
Reviewed: Right (owner, 2026-10-01)
Notes:

### 4 · Side window surrounds
Own views: `g38`..`g41`; the window part of `g12`..`g17`.
Deliverable: one spec in `side_windows.gd`. The frame ring sits 2 cm inside the cut and the static `WindowStop` ring already covers that slot 4 cm past the cut, cabin side (from code), so the line is a gap in or beside one of those two rings. → phase decides: trace the line (rear edge, `g39`, a cabin view) to the ring it passes, then close it by the seal rule in that ring; the glass opening and the sash's size unchanged. A gap at the frame ring (the moving sash) is closed by widening `WindowStop` (its inner poly reaching further over the frame), never by growing the frame. Reads: `side_windows.gd`, `van_side_wall_shell.gd` `build_curved_frame_ring_mesh`.
Verification: Order; own views 0; the window reads the same size from inside (compare).
Reviewed: Right (owner, 2026-10-01)
Notes:

### 5 · Leftover pink sweep
Own views: every `g` view still over 0 (Carry forward and a fresh check; known: hinge pinholes in `g06`, `g07`, ceiling-front specks in `g08`, `g10`).
Deliverable: one spec at a time, as many as it takes (D7, owner: keep fixing, no stop). Each pink cluster: find the seam it shows through and close it by the seal rule in the file that builds that seam; after each spec run the shots and `gap_check.py` again. A hinge pinhole is a seam like any other. It stops only when a fix would break the seal rule or a door's motion; then it blocks with the views left and where they show.
Verification: Order; `gap_check.py --strict` passes on all 43 views.
Reviewed: Right (owner, 2026-10-01)
Notes:

### 6 · Amber lamps, rules text, final check
Deliverable: two specs. (a) `look/van_marker_lights.gd`: the row of three amber ID lamps moves up onto the roof's rear rim above the doors, like a box van's ID lamps (D4, owner), spacing unchanged, the row together (one `id_y`, from code). → phase decides: measure the roof's rear rim (`look/van_hull.gd` `_build_roof`) and the top of `AstragalOuter` (`rear_door_lips.gd`, about y 3.44), then stand each housing on the rim's top, proud of the roof edge like box-van ID lamps (only about 4.5 cm of rear face is free above the lips, less than the 7 cm housing), its base sunk 2 cm into the rim, housing and lens sizes unchanged, clear of `OuterLip` and `AstragalOuter`; derive the heights from the profile and ceiling in code, not a hard-coded number. Reads: `van_marker_lights.gd`, `look/van_hull.gd`. (b) `van_audit_exempt.gd`: the five reasons ending `the gap-light views still show pink (vangapfix D77)` end `not see-through (vangapfix2)` instead. Then in the rules' seams paragraph drop the "Still open after vangapfix" sentence and name the new seals by node and file.
Verification: Order; `gap_check.py --strict` still passes on all 43 views; `v14` and `c31` show the lamps on the rim, clear of the strip and not floating.
Reviewed: Right (owner, 2026-10-01)
Notes:

## Carry forward

- vangapfix D77 (in `.claude/plans/vangapfix.md`) lists the 29 views still pink after its phase 6.
- Phase 2 (side door slits): the `cabrebuild` branch added a temporary LEAK_OUT rule for `Interior/Shell/SideWalls/DoorStop_R` (box `RIGHT_DOOR_REAR_SLIT`, d D77) in `tools/van_audit/van_audit_exempt.gd`, because the truck cab moved the leak sampler's rays onto the right leaf's rear slit. Delete that rule and its constant once the slit is closed; the strict audit must stay clean without it.
- A fresh worktree's `.godot/` must be seeded (`py -3 tools/check.py`) before any tool creates it, or the smoke import times out.
