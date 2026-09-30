Status: phase-done

Phase 2 (ceiling-to-wall cove) is built, verified and committed as `16b9357`. Phase 3 runs next.

# Plan state: vangapfix

## Plan

`vangapfix`, `.claude/plans/vangapfix.md`. Branch `claude/van-gap-repair-plan-eccee1`, worktree
`C:/Users/Traff/Documents/van-gunner/.claude/worktrees/van-gap-repair-plan-eccee1`. Run unattended
with `tools/autoplan.py`; `Questions: auto`.

## Architecture now

- `scripts/debug/debug_gap_light.gd`: `run(rig, args)` builds `DebugGapLight` under the rig once
  (`Outside` magenta box, `Inside` magenta cabin section, `FrontMask` black box) and paints the
  `WindowGlass` meshes black while shown.
- `scripts/debug/debug_van_commands.gd` `cmd_gaplight`, registered in `debug_commands.gd` as
  `gaplight [on|out|off]`.
- `tools/smoke/smoke_shots_closeups.gd` `gap_views(rig)` / `_gap_view`: the 37 rows.
- `tools/smoke/smoke_shots.gd` `van_views_gaps()`, called from `smoke_driver.gd` right after
  `van_views_closeups()`; files `g01`..`g37`.
- `tools/gap_check.py <shots dir> [--strict]`: magenta count per `g` view.
- `scripts/van/van_ceiling_cove.gd` (phase 2, RefCounted, 132 lines): `add_coves()` builds
  `Interior/Shell/Ceiling/CoveL` and `CoveR` (one `SurfaceTool` mesh each, wall material, layer 2),
  z -4.57 to the rear hinge z - 0.163 (4.547); `static join(walls, ceiling) -> Vector2` is D27's J.
- `scripts/van/van_ceiling.gd`: `const _Cove` preload and `_Cove.new(self).add_coves()` right after
  `add_child(vault)` in `_build`.

## Completed phase

2 · Ceiling-to-wall cove, commit `16b9357`. Verified: `py -3 tools/check.py` (CHECK CLEAN),
`py -3 tools/smoke.py` (SMOKE CLEAN, VAN AUDIT CLEAN, no rule added, no bless),
`py -3 tools/scene_dump.py` (SCENE DUMP CLEAN), `py -3 tools/smoke.py --shots`,
`py -3 tools/gap_check.py` (`gap_check: ok`), `py -3 tools/shots.py compare before`. Read beside
their `before` copies: `g08` to `g11` (the strip shows in all four; magenta away from the own
seam), and every changed non-`g` view (`01`, `11`, `c21`, `c22`, `v01`, `v04` to `v15`): the cove
or street slide only. Pictures: `C:/Users/Traff/AppData/Local/Temp/vgf2b/shots/`, the `before`
copies in `.../vgf2b/before/`, the side-by-side composites in `.../vgf2b/cmp/`.

## Next phase

3 · Rear frame, cabin side. Deliverable: one spec: in `rear_door_leaf_build.gd` the three
astragal consts (`ASTRAGAL_HALF_W` 0.05, `ASTRAGAL_LIFT` 0.036, `ASTRAGAL_END_GAP` 0.0) and their
two comment lines; new `scripts/van/rear_door_frame.gd` (`static func build(doors: Node3D,
left_hinge: Node3D) -> void`, node `Frame` under `RearWall`, a flat plate ring from two outlines
of 65 matched points, four face bands) and its one call in `rear_doors.gd` `_ready`; all exactly as
the phase section writes it. Verification: the phase's own line (check, smoke, plain scene dump,
the shots; the six `gap-rear-in-*` views read 0 and five show the frame; `van_ceiling_cove.gd`
exists, so `gap-ceiling-left-rear` and `-right-rear` read 0 too with the join's last 8 cm as own
seam; `-rear-park-stop-back` shows the frame; street views by D64; the one LEAK_OUT rule only
when smoke reports the row). Rests on D2, D4, D7, D9, D17, D18, D21, D22, D24, D25, D26, D27, D28,
D30, D32, D35, D37, D41, D42, D46, D50, D53, D63, D64, D65. First action: check
`.godot/shots/before/` holds `g*.png` (phase 2's closing capture), read the "before" table's four
`rear` rows (all `ok`), then read `scripts/van/rear_door_leaf_build.gd` whole (136 lines) and
write the spec.

## Requirements / gotchas

- `compare` calls street-only noise `changed` (D69), in about 17 non-`g` views per run: Read each
  beside its `before` copy. The file guard refuses `.godot/`, so copy the `before` PNGs to the
  scratchpad first. A scratch PIL script that pastes before | after | thresholded difference at
  half size into one PNG per view settles a view in one Read (`%TEMP%/vgf2b/cmp.py`, `crop.py`).
- `compare` also calls a few `g` views changed (`g22`, `g23`, `g27`, `g31`, `g33` this time, all
  street-side): `g` views are judged by `gap_check.py` only, never by `compare`.
- The autoplan session has no SendUserFile tool: name the owner's views by path in the report.
- In `gap-ceiling-*-rear` today: 546 px each, a line along the top of the rear leaf from about
  20 px behind the cove's rear end cap to the picture's edge. Phase 3 must bring both to 0.
- From the street, the slit under the roof skin's edge shows what stands behind it
  (`c22-seam-rear-corner-top-left`: the cove's back now fills it). The frame's top edge is 2 cm
  above the sheet at z 4.547..4.562, so look at `c22`, `c21` and the D64 roof views for it.
- `tools/van_audit.py --strict` runs the audit alone (about 2 minutes), cheaper than a whole
  smoke when only an audit row is in question.
- The implementer finished phase 2's spec in one call at 24k; the verify and the pictures cost
  the main session about 60k.

## Questions

none

## Blocker

none
