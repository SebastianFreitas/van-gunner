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
Phase 5 in progress. Session 4 (autoplan) landed 06ed1ec: D38 recess 0.30, D39/D41 OPENING
exemptions, D40 trunk/feed/hopper hop over the door bays, battery jumper moved ahead of the window
bay; scene dump blessed (only recess_distance -0.24 -> -0.3). Earlier: D35-D37 (258d238..a937e13).
Audit now: CLIP 0, EDGE 23, FLICKER 562, LEAK_IN 1, LEAK_OUT 40, OPENING 0 (was 6/23/572/1/40/46).
Triage for what is left:
- FLICKER (562): Welder props (bottle bands, scorch decals, gauge, spokes), Hopper chain links,
  KickPlate vs Generator (34, re-check with the audit at=), wall posts, TopRail, cable strands
  (bundle strands coplanar: @Node3D@375 Strand7 at the front ceiling z -4.32, 0.53 m2 = the hopped
  feed/trunk; MachineParts.cable_bundle strand spacing), Plate vs WallRib; half/open rows ungrouped.
- LEAK_OUT 40, LEAK_IN 1 (through=nothing at (2.706, 1.158, -1.382)), EDGE 23: not triaged yet.

## Blocker
none.

## Next phase
Phase 5 continued: (d) rear dressing; (e) the FLICKER groups above (start with cable strands and
the Welder/Hopper props: one Explore per group, one spec each); (f) LEAK_OUT/LEAK_IN triage and
EDGE exemptions; (g) wire --strict into smoke once every count is 0; rear and roof shots, several
van seeds (smoke.py --shots DIR --van-seeds 3). Nothing visible was shot this session: D40 moves
cables onto the ceiling over the door bays, look at them in the next shots.

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
