Status: partial
# Plan state: vanfix

## Plan
`vanfix`, `.claude/plans/vanfix.md`; branch `claude/go-cc7a37`, worktree
`.claude/worktrees/go-cc7a37`.

## Architecture now
- `tools/van_audit.py`: launcher (`--out`, `--strict`, `--timeout`), report-only (exit 0)
  until wired into smoke; report at `.godot/van_audit/report.txt` (~50 s, D23). States `closed`,
  `half`/`open` (side doors + rear windows), `win_half`/`win_open` (front windows alone).
  FLICKER: parallel faces within `PLANE_EPS` 0.01 m (D12: gaps 2 cm, lifts 1 cm). EDGE: per-mesh
  open edge (`van_audit_gaps.gd`). Files `tools/van_audit/`; close-ups `smoke_shots_closeups.gd`.
- Side door: opening z -3.42 ± 1.235, leaf `DOOR_HALF_Z` 1.105, recess 0.24 (D13), slides
  `slide_distance` 2.45 (`side_doors.gd`): the open leaf's rear edge is at z ≈ 0.135.
- Side windows y 1.775 ± 0.707 (bottom 1.07), centres z 2.835 / -0.375, hinge 0.32 out (D16).
- Outer body `van_hull.gd` (334): `SideSkin<S>` 0.22 off the liner (D17), sills in
  `van_hull_patches.gd` (`_build_sill`, section x `wall_x_at(0)+0.22` -0.04..+0.06, y -0.25..0.04,
  z -4.72..4.80), lines `van_hull_lines.gd` (D19).
- Chassis `scripts/van/look/van_chassis.gd` (RefCounted under `VanWheels`): flares with
  `z_lo/z_hi` trims and vertex-only caps, wells z-clamped, `SILL_OUT_X`, `TANDEM_GAP`; spare
  chains `SpareChain<S>0..3`. `VanWheels.SIX_WHEEL_CHANCE`, `rear_axles_for(look)`,
  `rear_arch_spans(look)` (merged rear arch z spans, for the sill).
- Cab (D21, D22): `van_cab_shell.gd` on `VanBodyProfile.section_points(steps, true)`.
- Caps: `rear_doors.gd`, `van_side_wall_shell.gd` at 400 lines; split before adding.

## Completed phase
Phase 5 (partial). This session: 0deab2b sill breaks over the rear arches (spec-5-1, `build(walls,
arch_spans)` in `van_hull_patches.gd`); 28cbe77 split phase 5 into 5/5b/5c/5d (D31) and saved
spec-5-2. check, smoke clean. Audit: CLIP 70, EDGE 23, FLICKER 1612, OPENING 83, LEAK_OUT 47,
LEAK_IN 1 (Tread vs Sill rows gone).

## Blocker
none (Q1 answered as D30: pack toolbox/tank first, then spare, behind the open door).

## Next phase
Phase 5 finish: send `.claude/plans/vanfix.spec-5-2.md` (D30 packing in `van_chassis.gd`) to the
implementer, verify (check, audit rows for Spare/Tank/ToolBox, smoke, scene dump; bless the dump
only if the tree changes and say so), commit, mark row 5 done. Then 5b (side add-ons + the new
`SillR` vs `ExhaustHanger0/1` FLICKER rows at x 2.70: the hangers sit at `SILL_OUT_X + 0.02` with
0.10 depth, so they reach into the sill: shift them so their inner face stays 2 cm off it), 5c
interior FLICKER, 5d exemptions + `--strict` in smoke, each its own session.

## Requirements / gotchas
- The audit's `Interior/Props/FuseBox/Generator` and `CraftingTable/Welder` fan/flywheel/spoke
  rows are animated or run-to-run: freeze or skip animated parts before `--strict`. A
  PerimeterFrame vs SideSkin row in `half` flips 30/31 pairs on a MIN_AREA-borderline triangle.
- Remaining EDGE rows (CabLiner/BackLip/Face, 6 Wells (single plates, by design: exemption),
  RearSkin, CornerPostF L/R, BellySkin, RearWall hinge CurvedBody, 4 ExteriorPane, SideSkin L/R,
  RearCorner L/R) each need a look; by-design single-sided ones go on an audit exemption list.
- Front flares use `WHEEL_X` without `FRONT_WHEEL_OUT`: only 2 cm beyond the front tyre.
- The cab's back edge meets `FrontSkin` at z -4.70: keep the cab outline on
  `VanBodyProfile.section_points(steps, true)`.
- A fresh worktree's first smoke fails on `VanLook` not found; run `py -3 tools/check.py` first.
