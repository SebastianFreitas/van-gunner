Status: phase-done
# Plan state: vanfix

## Plan
`vanfix`, `.claude/plans/vanfix.md`; branch `claude/plan-vanfix`, worktree
`.claude/worktrees/plan-vanfix`.

## Architecture now
- `tools/van_audit.py`: launcher (`--out`, `--strict`, `--timeout`), report-only (exit 0)
  until phase 5; report at `.godot/van_audit/report.txt` (~4 min, use `--timeout 600`).
  FLICKER counts parallel faces within `PLANE_EPS` 0.01 m as coplanar (D12: edge-to-edge gaps
  2 cm, stacked lifts 1 cm). EDGE is per mesh: an edge of one triangle, over 5 cm, with no
  physics body within 1.5 cm (`van_audit_gaps.gd` ~107–159), so seams between meshes report.
- `tools/van_audit/van_audit.tscn` + `van_audit.gd`; helpers `van_audit_mesh.gd`,
  `van_audit_states.gd` (every door and window at the same fraction), `van_audit_overlap.gd`
  (FLICKER/CLIP/OPENING), `van_audit_gaps.gd` (EDGE, LEAK_IN, LEAK_OUT cast from outside).
- `tools/smoke/smoke_shots_closeups.gd`: close-ups `c01`..`c32`.
- Side door leaf (`scripts/van/side_door_leaf.gd`): opening half length 1.235 at z -3.42,
  recess 0.24 (D13), leaf `DOOR_HALF_Z` 1.105; outer parts on layers 1+2 (D15); port untouched.
- Side windows (`scripts/van/side_windows.gd`): `Hinge` pivot `HINGE_OUT_M` 0.32 outboard of
  the liner (D16), past the skin's outer face 0.22. Iron cross `scripts/van/iron_cross.gd`.
- Side walls: `VanSideWall._add_side` builds `<Left|Right>Wall` (faces, layer 2) and
  `<Left|Right>WallReveals` (returns + reveals, liner to 0.16, layers 1+2; D18) from
  `van_side_wall_panel.gd` (398 lines) / `van_side_wall_shell.gd` (at cap 400). Jambs:
  `scripts/van/van_side_wall_jambs.gd`. Side door and window casings deleted.
- Outer body (`scripts/van/look/van_hull.gd`, 334 lines): `SideSkin<S>` = wall grid and cuts
  0.16 → `SIDE_SKIN_OUTER_M` 0.22, no inner face (D17); `RoofSkin` to z -4.70; `FrontSkin` at
  z -4.70 (-Z facing) closes the step from the cab outline (`VanBodyProfile` outer, 0.12) up to
  the roof skin and down the corners to the side returns' top; `RearSkin` a ring at z 4.78 around
  the rear leaves 2 cm out, with a reveal back to the liner end z 4.70; sills (`SILL_TOP_Y`
  0.04) and `BellySkin` (two strips from the deck edge x ±2.4 to the sills) to z 4.80 (D20).
  Helpers `van_hull_patches.gd` (sills, belly, rear corners), `van_hull_lines.gd` (hull lines at
  inner + 0.22 + `TRIM_LIFT` 0.01, breaking over the door slide, D19; corner posts, rails end
  `POST_GAP` 2 cm short).
- Rear doors: `scripts/van/rear_doors.gd` (400, cap) + `scripts/van/rear_door_lighting.gd`
  (leaf parts on layers 1+2).
- Cab (real cab kept, D21): `scripts/van/look/van_cab_shell.gd` swept on
  `VanBodyProfile.section_points(steps, true)` from z -4.68 forward (`CabLiner`, `CabBackLip`,
  `CabFace`; back wall double-sided). Trim in `van_cab_face.gd` sits ≥ 2 cm off the face plane;
  front kit `van_front_kit.gd`. Front wheels `VanWheels.FRONT_WHEEL_OUT` 0.04 out, cab steps
  `SKIN_X + 0.17`, A-pillars 3 cm inside the outline (D22).

## Completed phase
Phase 4 · Sealed simple cab, done 815948b (sessions 10–11; fda7fad spec 4-1, 23f70b1 spec 4-2,
815948b steps/wheels/pillars). Verified: check, smoke, scene dump clean (identical, not blessed);
`py -3 tools/van_audit.py --timeout 600`: CLIP 102, EDGE 24, FLICKER 1683, HEIGHT 43, LEAK_IN 1,
LEAK_OUT 44, OPENING 99, REAR_ROOF 8; `VanLook/Cab/` FLICKER 41 → 0, 3 cab EDGE rows left are tube
ends and a CabFace windshield-corner seam (no holes). Shots v11, v13, c23 read: cab closed, front
unchanged to the eye.

## Next phase
Phase 5 · Add-ons snapped and height-capped (D6). Start: read the plan's phase 5 and Carry
forward (audit speed-up before `--strict` goes into smoke; door-adjacent window poses; wheel
Hub/Bolt FLICKER). Grep the audit report for REAR_ROOF, HEIGHT and the `VanLook/` add-on roots
(Armour, Rebar, Spikes, Signs, RoofRack, Junk, Antennas, Spares) to size the work; expect to save
specs (unattended.md) rather than fit it all in one session.

## Requirements / gotchas
- The cab's back edge meets `FrontSkin` at z -4.70 (cab outline 0.12 off the liner): keep the
  cab's outer outline on `VanBodyProfile.section_points(steps, true)` or FrontSkin's inner edge
  (sampled at 16 steps across the cab top) must move with it.
- A fresh worktree's first smoke fails on `VanLook` not found; run `py -3 tools/check.py` first.
- `rear_doors.gd`, `van_side_wall_shell.gd` are at 400 lines; split before adding.

## Blocker
none
