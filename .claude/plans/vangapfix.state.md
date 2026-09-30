Status: phase-done

Phase 4 landed (f9465c8). Phase 5 runs next.

# Plan state: vangapfix
## Plan

`vangapfix`, `.claude/plans/vangapfix.md`. Branch `claude/plan-vangapfix`, worktree
`C:/Users/Traff/Documents/van-gunner/.claude/worktrees/plan-vangapfix`. Run unattended
with `tools/autoplan.py`; `Questions: auto`.

## Architecture now

- Phase 1's tools as before: `gaplight [on|out|off]` (`scripts/debug/debug_gap_light.gd`), the 37 `g` views
  (`tools/smoke/smoke_shots_closeups.gd` `gap_views`, files `g01`..`g37`), `tools/gap_check.py`.
- `scripts/van/van_ceiling_cove.gd` (phase 2): `CoveL` / `CoveR` under `Ceiling`, z -4.57 to 4.547.
- `scripts/van/rear_door_frame.gd` (phase 3, about 140 lines, all static): `build(doors, left_hinge)` makes
  `RearWall/Frame`, a 65-point plate ring, street face z 4.562, cabin face 4.547, outer outline 2 cm into
  liner/roof/floor, inner 7 cm inside the opening; called from `rear_doors.gd` `_ready` on the line after
  the `rear_door_leaf_build.gd` build line (phase 4 goes on the line after it).
- `rear_door_leaf_build.gd`: `ASTRAGAL_HALF_W` 0.05, `ASTRAGAL_LIFT` 0.036, `ASTRAGAL_END_GAP` 0.0
  (astragal x ±0.05, rig z 4.582..4.594). `van_floor.gd` `RearThreshold` z 4.56; `van_rear_dressing.gd`
  `LOCK_BAR_Z` -0.104 (D71).
- `scripts/van/rear_door_lips.gd` (phase 4, about 190 lines, all static): `build(doors, left, right)`
  makes `OuterLip` on each hinge (right one the left mesh at `scale.x = -1`; top strip 17 stations,
  bottom strip outer y -0.01, D74) and `AstragalOuter` on the right hinge (plate z 4.855..4.867, stem
  a closed box, D73); called from `rear_doors.gd` `_ready` on the line after the frame's.

## Completed phase

4 · Rear doors, street side, commit f9465c8. Check, smoke (strict audit clean, no rule, no
fingerprint move), plain scene dump clean. `gap_check`: rear-out whole / hinge-left / hinge-right 0;
header 408, sill 362, centre 3556, all identical to `before` and on the rear leaf windows' surrounds
(Carry forward lines written). Lips and outer astragal shown in `-whole`, `-header`, `-sill`,
`-centre`. The astragal plate covers the centre amber marker lamp (Carry forward). Pictures in
`C:/Users/Traff/AppData/Local/Temp/vgf4/` (`shots2/`, before|after pairs in `pairs/`). The closing
capture `.godot/shots/before/` is phase 4's result.

## Next phase

5 · Side door stops, both views. First action: read phase 5's section and the Ds it cites (D73 and
D75 included), then write the spec(s).

## Requirements / gotchas

- D75 (owner): an audit row the phase's piece raises is fixed by the session (missing face, a
  number moved, one number of a neighbouring piece, then one exact rule) and recorded as a D (auto);
  old magenta goes to Carry forward. Block only when none of that makes the strict audit clean.
- The flicker audit (`tools/van_audit/van_audit_flicker.gd`) reports two faces of different nodes
  that look the same way (normal dot over 0.985), lie within `PLANE_EPS` 1 cm of one plane and
  overlap by 0.005 m² or more. The right rear leaf is a `scale.x = -1` copy, and the audit sees its
  cabin face as looking the other way, so a face 1 cm or less inside the right leaf's cabin face
  (rig z 4.63) raises a row too (that is why `van_rear_dressing.gd` embeds its bars 1.5 cm).
- `Interior/Shell/Floor/RearThreshold` (`van_floor.gd` `_build_threshold_strips`): a visual box, no
  collision, x ±1.1, y 0..0.03, rig z 4.54..4.62. The frame's bottom rail (z 4.547..4.562) runs
  through it.
- The rear dressing's lock bar (`van_rear_dressing.gd` `_add_lock_bar`, an unnamed mesh under
  `LeftHinge`): 0.9 × 0.07 × 0.07 at handle height across the centre seam, rig x -0.46..0.44,
  y 1.515..1.585, z 4.575..4.645 (`LOCK_BAR_Z` -0.10); its two brackets share that z.
- The main session may make single-line source edits only (the file guard refuses more); a trial
  of numbers goes line by line, and `py -3 tools/van_audit.py --strict` (2 minutes) tests it.
- `gap-rear-in-whole` is mostly covered by a lattice standing in front of its camera; the frame
  shows only at the opening's edges behind it.
- Earlier notes still hold: `compare` calls street noise `changed` (D69) in most `v` views and a
  dozen `c` views per run; no SendUserFile in the autoplan session.

## Questions

none

## Blocker

none

Record of the answered block (phase 4, first build): `EDGE .../RightHinge/AstragalOuter open=1` (the
stem's open street end, now D73) and `FLICKER .../RightHinge/OuterLip` vs `VanLook/Wheels/RearBumper`
(the lip 5 mm behind the bumper's back face, now D74). No pictures were taken on it.
