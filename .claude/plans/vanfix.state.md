Status: phase-done
# Plan state: vanfix

## Plan
`vanfix`, `.claude/plans/vanfix.md`; branch `claude/plan-vanfix`, worktree
`.claude/worktrees/plan-vanfix`.

## Architecture now
- `tools/van_audit.py`: launcher (`--out`, `--strict`, `--timeout`), report-only (exit 0)
  until wired into smoke; report at `.godot/van_audit/report.txt` (~50 s, D23). States `closed`,
  `half`/`open` (side doors + rear windows), `win_half`/`win_open` (front windows alone).
  FLICKER: parallel faces within `PLANE_EPS` 0.01 m (D12: gaps 2 cm, lifts 1 cm). EDGE: per-mesh
  open edge (`van_audit_gaps.gd`). Files `tools/van_audit/`; close-ups `smoke_shots_closeups.gd`.
- Side door: opening z -3.42 ± 1.235, leaf `DOOR_HALF_Z` 1.105, recess 0.30 (D38), slides
  `slide_distance` 2.45 (`side_doors.gd`): the open leaf's rear edge is at z ≈ 0.135; the open
  leaf spans x ≈ 2.70..2.96, so nothing low on the side fits under it.
- Cables (D40): `Router.hop_bays(pts, inset)` / `lift(p, inset)` in `van_cable_router.gd` lift any
  upper-wall run (y > 2.2) inside the door bay band (`VanInnerShell.DOOR_Z_*` ± 0.05) to x ±1.5,
  0.14 under the liner, with 0.3 m ramps; trunks (inset 0), feed and hopper (0.12) use it;
  `_trunk_at(pts, z)` gives anchors. Battery jumper rises at z -1.75 (window bay is -1.60..0.85).
- Audit `OPENING_EXEMPT` (`van_audit_overlap.gd`): PcRig in `door_left` (D39), wall/reveals/skin
  for the four windows (D41).
- Side windows y 1.775 ± 0.707 (bottom 1.07), centres z 2.835 / -0.375, hinge 0.32 out (D16).
- Outer body `van_hull.gd` (334): `SideSkin<S>` 0.22 off the liner (D17), real skin x at y 0 is
  `wall_x_at(0)` 2.42 + 0.22 = 2.64. Sills in `van_hull_patches.gd` (`_build_sill(walls, s,
  arch_spans)`, x 2.60..2.70, y -0.25..0.04, z -4.72..4.80, broken over
  `VanWheels.rear_arch_spans(look)`, `SILL_MIN_SEGMENT`), lines `van_hull_lines.gd` (D19).
- Chassis `scripts/van/look/van_chassis.gd` (RefCounted under `VanWheels`): flares/wells as D29;
  `SILL_OUT_X` 2.70 (the real sill face; was a stale 2.62); exhaust pipe and hangers off it.
  D30 slot: `SLOT_Z0` 0.16 .. `rear_axles[0] - (REAR_RADIUS + FLARE_GAP + FLARE_T) - 0.02`
  (4-wheel 2.30, 6-wheel 1.60), packed with `ADDON_GAP` 0.02: exhaust side toolbox
  (`TOOLBOX_LEN` 0.92) then spare (`SPARE_LEN` 0.84), other side tank (`TANK_LEN` 1.2) then spare;
  a misfit is not built. Builders take a centre z.
- Side armour (`van_armour.gd`, `van_armour_pieces.gd`, D32/D33): slots pillar, top, tail only;
  `_skin_x` = `wall_x_at(y) + SIDE_SKIN_OUTER_M`; `_plate_x(y0, y1)` leans plates on the skin chord;
  `_clear_of_openings` (door path, windows +0.03, `BELT_BAND_Y`, `DRIP_BAND_Y`, roof cap) drops
  misfits; no signs or car door. `van_chassis.gd` `SKIN_X` 2.56 stays (D34: embedded, no rows).
- Roof (spec-5-2): slats at `RACK_Y + 0.03` on the rails, legs to `RACK_LEG_TOP_Y`, antenna bases on
  the rail top, whips 8 segments × 1 ring; junk at `van_roof_junk.gd` `BASE_Y` (`RACK_Y + 0.035`).
- Cab (D21, D22): `van_cab_shell.gd` on `VanBodyProfile.section_points(steps, true)`.
- Caps: `rear_doors.gd`, `van_side_wall_shell.gd` at 400 lines; split before adding.

## Completed phase
7 (done; Q1 answered as D45: joints left and exempted in phase 10). Commits:
- c00ca93: inner shell plates/patches clear of the rib z bands, patch 2 cm proud of its ring.
- 1881dd6: new helper `van_inner_shell_fit.gd` (RefCounted, `clear_of_ribs` now also clears the
  bulkhead plane `BULKHEAD_Z` 1.0 ± 0.08, `clear_of_plates`, `GENERATOR_ZONE` Rect2(0.845, 0,
  0.74, 1.3)); the shell keeps `_placed_plates` per side; wall patches skip plates, right plates
  skip the generator.
- e6f7e91: `van_bulkhead_mesh.gd` MidPost runs rail centre to rail centre (ends buried);
  `RAIL_DEPTH_INSET` 0.07 (not 0.04: MidPost faces are ±0.068): TopRail even ±0.045, odd ±0.025.
- e86ccb4: `van_chassis.gd` BumperHanger (0.06, 0.14, 0.18) at (±1.02, -0.10, 4.79); flare
  `x_in` = `SKIN_X + 0.06` (2.62; 2.59 hit `Cab/CabLiner`); `van_floor.gd` RearEntryRamp visual
  width 2.16 (collision still `RAMP_WIDTH` 2.2).
- ac2db2c: `HEADER_DEPTH` 0.20 (DoorHeader, BottomRail, both inner ends 4 cm inside the opening
  post), `KICK_DEPTH` 0.08 (visual only, collision keeps `panel_thickness`).
- Wheel Hub vs Bolt: already 2 cm proud (bolt outer face hub_x+0.05, hub face +0.03), no change.
Shots checked (01 interior, 03 outside): bulkhead and rear read as before.
Audit now: EDGE 23, FLICKER 418, LEAK_IN 1, LEAK_OUT 45 (was 492 FLICKER).
Left in phase 7 scope: Bulkhead `LeftWallPost_n/RightWallPost_n vs n+1` (0.0028 / 0.0009 each,
all joints) and `KickPlate_n vs n+1` (~0.013 each: KickPlate joints may be new with `KICK_DEPTH`,
unconfirmed); `Ceiling/Vault vs InnerShell/PatchCeil0_Ring` (0.0118 at x -1.5, ring 5 mm under
the vault, Explore thinks borderline); TopRail vs MeshBack netting (out of scope).

## Blocker
none

## Next phase
Phase 8 (Generator and welder visible flicker; the plan was re-cut 2026-09-29 into phases 8–13,
D46 questions auto, D47 visible floor 0.005 m²). Filter the report to FLICKER rows with area ≥
0.005 (plan, above phase 8) and fix only the FuseBox/Generator and CraftingTable/Welder ones,
plus freeze/skip animated fan/flywheel/spoke parts in the audit. First, optionally clear
`Ceiling/Vault vs InnerShell/PatchCeil0_Ring` by keeping the ceiling patch ring 2 cm under
`_ceiling_y` in `van_inner_shell.gd` `_build_ceiling_patch`. The bulkhead wall-post and kick-plate
joint rows stay (D45) and are exempted in phase 11. No phase question stops: take Recommended.

## Requirements / gotchas
- The audit's `Interior/Props/FuseBox/Generator` and `CraftingTable/Welder` fan/flywheel/spoke
  rows are animated or run-to-run: freeze or skip animated parts before `--strict`. A
  PerimeterFrame vs SideSkin row in `half` flips 30/31 pairs on a MIN_AREA-borderline triangle.
- Remaining EDGE rows (CabLiner/BackLip/Face, 6 Wells (single plates, by design: exemption),
  RearSkin, CornerPostF L/R, BellySkin, RearWall hinge CurvedBody, 4 ExteriorPane, SideSkin L/R,
  RearCorner L/R) each need a look; by-design single-sided ones go on an audit exemption list.
- The audit's `at=` is a padded-AABB cell corner, not the faces' position: find the faces from the
  meshes' own numbers (the hanger rows were "at z -2.6" for a hanger at z -0.6).
- Front flares use `WHEEL_X` without `FRONT_WHEEL_OUT`: only 2 cm beyond the front tyre.
- The cab's back edge meets `FrontSkin` at z -4.70: keep the cab outline on
  `VanBodyProfile.section_points(steps, true)`.
- A fresh worktree's first smoke fails on `VanLook` not found; run `py -3 tools/check.py` first.
