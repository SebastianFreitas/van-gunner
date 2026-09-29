Status: partial
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
6 (done 0dcc580). 74cfe3c: `MachineParts.cable_bundle` offsets strands across the run
(`_run_side`, `_strand_sides`, mitered), not along world X. 0dcc580: `van_side_wall_jambs.gd`
`JAMB_FRONT_OUT` 0.017 (front inner return buried in `FrontWall/Slab`), `_front_overlap` +
`_clip_front_strip` clip the jamb cabin face at the panel grid edge; `van_side_wall.gd`
`_add_floor_seal_strips` seal y -0.03..0.05 (3 cm under the deck), inner face 1.5 cm further in,
z ends 0.10 short of the van ends. Scene dump and fingerprint unchanged (no bless). Shots
01/02 checked: cables side by side, nothing floating.
Audit now: CLIP 0, EDGE 23, FLICKER 492, LEAK_IN 1, LEAK_OUT 45, OPENING 0.
Cable FLICKER left: 25 rows, all < 0.01 m² (strand vs clamp/tape `@MeshInstance3D`, strands of
different bundles e.g. `@355/Strand8_1` vs `@405/Strand1_2` 0.0011, `@366` vs `@386` 0.0098,
`Battery/Body` vs `InnerShell/WallRibL2_1` 0.003, `Bulkhead/MeshBack_321` vs `@386`, jerry can
`HandleR` vs `HandleTop`). One LEAK_OUT `@355/Strand4_0` (1 ray at (1.83, 2.78, 1.25)), maybe new.
`DoorJamb_L/R` LEAK_OUT unchanged (96 / 86 rays): phase 10 (leak triage).
FLICKER groups left for phases 7–9: Generator self 78, Welder self 72, PcRig self 56, Hopper
self 53, CabRelay Rack self 45, KickPlate_0..5 vs Generator 49, FrontWall/Slab vs Rack 11 /
PcRig 4, WallRib vs Plate 16, PatchWall/Ceil _Ring vs patch 10, Bulkhead TopRail vs
TopRail_7..9 / MidPost, RearEntryRamp and RightHinge/CurvedBody vs BumperHanger,
`CargoRail_R_0` vs `VanLook/Wheels/FlareR1/R2`.
Get the list: group `^FLICKER` rows by a=/b= prefix (awk over the report).
- LEAK_OUT 45 (1-3 ray rows through the rear-door centre seam at x ≈ 0 onto Bulkhead/CabDoor,
  likely noise), LEAK_IN 1 (through=nothing at (2.706, 1.158, -1.382)), EDGE 23: not triaged.

## Blocker
none.

## Next phase
Phase 7 continues (partial). Done c00ca93: `van_inner_shell.gd` plates/patches clear of rib z
bands (`_clear_of_ribs`), patch 2 cm proud of its ring (`RING_*`/`PATCH_*`), plates z -4.5..4.45.
WallRib vs Plate and patch-vs-ring rows are gone; audit FLICKER 464 (was 492).
1. Send `.claude/plans/vanfix.spec-7-2.md` (patches vs plates/bulkhead, plate vs generator).
2. Send `.claude/plans/vanfix.spec-7-3.md` (bulkhead MidPost ends, TopRail depth/joints).
3. Then explore and spec the rest (not designed yet): `Floor/RearEntryRamp` (van_floor.gd ~171)
   and `RearWall/RightHinge/CurvedBody` and `FrameRailL/R` vs `VanLook/Wheels/BumperHangerL/R`
   (van_chassis.gd ~316, size 0.12×0.16×0.2 at (±1.05, -0.06, 4.8)), `RearThreshold` vs
   `RearEntryRamp`; `SideWalls/CargoRail_R_0` (van_side_wall.gd ~292) vs `Wheels/FlareR1/R2`;
   wheel `Hub` vs `Bolt%d` (van_wheels.gd ~139-145: no audit row today, bolts < MIN_AREA; give
   the bolt a 2 cm lift off the hub face per the deliverable). Explore's earlier numbers for
   these were unreliable: read the ranges yourself (under 60 lines each).

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
