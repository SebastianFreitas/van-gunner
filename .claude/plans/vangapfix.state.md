Status: phase-done

Phase 3 is done (commit 4e42932, landed by this session's `try.py --commit`). Phase 4 runs next.

# Plan state: vangapfix

## Plan

`vangapfix`, `.claude/plans/vangapfix.md`. Branch `claude/van-gap-repair-plan-eccee1`, worktree
`C:/Users/Traff/Documents/van-gunner/.claude/worktrees/van-gap-repair-plan-eccee1`. Run unattended
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

## Completed phase

3 · Rear frame, cabin side, commit 4e42932. Check, smoke (strict audit clean, no rule, no fingerprint
move), plain scene dump clean. `gap_check`: rear-in whole/sill/centre 0, header 48, hinge-left 8,
hinge-right 8 (D72, Carry forward lines written), ceiling-left-rear / -right-rear 0. Pictures in
`C:/Users/Traff/AppData/Local/Temp/vgf3b/` (`shots/`, before|after pairs in `pairs/`). The closing
capture `.godot/shots/before/` is phase 3's result.

## Next phase

4 · Rear doors, street side (Needs 1, 3: both done). First action: read phase 4's section and its D's
in the plan, then write the spec for `scripts/van/rear_door_lips.gd`.

## Requirements / gotchas

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

Record of the answered block (phase 3, first build): rows `RearThreshold` vs `RearWall/Frame` and
`LeftHinge/Astragal` vs the lock bar; with D71's numbers the audit and smoke ended clean and
`gap_check.py` read (before -> with the frame) header 3106 -> 48, sill 1734 -> 0, hinge-left 4135 -> 8,
hinge-right 3340 -> 8, ceiling-left-rear and -right-rear 546 -> 0; the 48 and 8s are D72's. Pictures
in `C:/Users/Traff/AppData/Local/Temp/vgf3/`.
