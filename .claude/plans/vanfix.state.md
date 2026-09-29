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
- Side door: opening z -3.42 ± 1.235, leaf `DOOR_HALF_Z` 1.105, recess 0.24 (D13), slides
  `slide_distance` 2.45 (`side_doors.gd`): the open leaf's rear edge is at z ≈ 0.135; the open
  leaf spans x ≈ 2.64..2.9, so nothing low on the side fits under it.
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
- `SKIN_X` 2.56 in `van_chassis.gd` and `VanArmour.FACE_X` / `_Pieces.FACE_X` 2.6 and
  `VanArmour._skin_x` (`wall_x_at(y) + VanHull.SKIN_OFFSET_M` 0.06) all predate D17's 0.22 skin:
  side add-ons sit partly inside the skin. Snapping them is part of (d).
- Cab (D21, D22): `van_cab_shell.gd` on `VanBodyProfile.section_points(steps, true)`.
- Caps: `rear_doors.gd`, `van_side_wall_shell.gd` at 400 lines; split before adding.

## Completed phase
Phase 5 in progress. This session: 732f874 sills break over the rear arches (spec-5-1, Tread vs
Sill rows gone); fdfe328 D30 layout (no door CLIP vs ToolBox/Tank/Spare left) and exhaust hangers
on the real sill face. check, smoke, scene dump clean (scene dump unchanged, nothing blessed).
Audit: CLIP 57, EDGE 23, FLICKER 1603, OPENING 83, LEAK_OUT 47, LEAK_IN 1.

## Blocker
none (Q2 answered as D32: drop `low_front` and `low_mid`; the side keeps pillar,
top and tail armour snapped to the real skin).

## Next phase
Phase 5 continued: (a) send spec-5-2 (side-step hangers, roof rack, antenna FLICKER,
`.claude/plans/vanfix.spec-5-2.md`) to the implementer; (b) D32 in `van_armour.gd`
(remove the `low_front` and `low_mid` slots) and snap every remaining armour piece to the real skin (`VanHull.SIDE_SKIN_OUTER_M`,
not `SKIN_OFFSET_M`/`FACE_X`; flat plates on the bowed skin: inner face at the max skin x over the
plate's y span + `TRIM_LIFT`), also `SKIN_X` in `van_chassis.gd` (toolbox, tank, spare mount,
steps) → the real skin, with a D6 placement check (touches, clear of openings, under the roof cap);
(c) exterior `VanLook/Cables` vs side door CurvedBody CLIP (closed state, ~30 rows, y 2.81..2.92,
z -2.6..-4.35) and vs side walls / bulkhead posts FLICKER; MarkerLights ClearanceL0/R0 OPENING;
(d) rear dressing; (e) interior FLICKER (Bulkhead ~875 pairs, Props ~301 incl. CabRelay/Rack,
InnerShell ~163, Shell ~49); (f) wire `--strict` into smoke once every count is 0.

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
