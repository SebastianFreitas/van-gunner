Status: phase-done

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

## Completed phase

1 · Gap light and seam views, commit `ca2beec`. Verified by the run's first session:
`py -3 tools/check.py` clean; `py -3 tools/smoke.py` clean (strict van audit clean, fingerprint not
moved, nothing blessed); `py -3 tools/smoke.py --shots %TEMP%/vgf1/shots`;
`py -3 tools/gap_check.py` → `gap_check: ok`, control 26.399 %, 34 of the 36 other views over 0;
`py -3 tools/shots.py compare before` → 12 non-`g` views `changed`, all street-only (D69). The
second session re-ran `gap_check.py` and `compare` on those shots, compared the two same-tree
captures (`%TEMP%/vgf1/shots`, `shots2`), and Read `gap-ceiling-left-front`, `gap-ceiling-left-rear`
and `12-rear-park-stop-outside` beside its `before` copy: the join is in sight across each ceiling
picture, and view 12 differs only in the facades across the street. The reviewer's two gaps (door
rows ordered per side, no early return on no rows) were fixed before the verify.

## Next phase

2 · Ceiling-to-wall cove (D2, D3, D4, D9, D17, D21, D22, D25, D26, D27, D30, D32, D33, D35, D37,
D41, D42, D46, D50, D53, D63, D64, D65).

Deliverable: one spec. New `scripts/van/van_ceiling_cove.gd` (`_init(ceiling)`, `add_coves()`,
static `join(walls, ceiling)`), preloaded as `_Cove` in `van_ceiling.gd` and called on the line
after `add_child(vault)` in `_build`; `CoveL` / `CoveR` under `Ceiling`, the six-point section
swept from `VanFrontWall.FACE_Z` - 0.02 to `RearWall/LeftHinge` z - 0.163, end caps fanned from C,
the wall's UVs. The numbers are in the plan's phase 2 section: build from them as written.

Verification (the plan's line is the full text; read it there): check, smoke, plain scene dump
(`SCENE DUMP CLEAN`), the shots, `gap_check.py`, `compare`. Own seam: the ceiling-to-wall join with
the cove along it, from the front wall to the cove's rear end cap. All four `gap-ceiling-*` views
show the strip, each Read beside its `before` copy; the two `-front` views read 0; the `-rear`
views read 0 at the own seam, and magenta in the join's last 8 cm or at the rear leaves' slits does
not block while `scripts/van/rear_door_frame.gd` does not exist (it gets the Carry forward line).
Street views by D64, every other view by D42 and D69. One audit rule may be added (Constraints).

First action: `.godot/shots/before/` holds the `g*.png` of phase 1's closing capture, so no capture
is needed; read `.claude/rules/van-shell-and-hud.md` and `.claude/rules/art-style.md`, then design
against `scripts/van/van_ceiling.gd` `_build` (where the `Vault` child is added).

## Requirements / gotchas

- The `before` table is at the end of the plan's Carry forward. All eight clearances are `ok`.
- The ceiling join's magenta today is only at two places per side: where the join meets the rear
  end of the side door bay's header (`-front` views, 278 and 491 px) and where it meets the rear
  wall (`-rear` views, 546 px each). The `-front` views must read 0 after phase 2, so look at
  whether the magenta there is the join's or the side door header slit's (D63) before judging.
- `compare` calls street-only noise `changed` (D69): Read such a view beside its `before` copy.
  The file guard refuses `.godot/`, so copy the `before` PNG to the scratchpad first.
- The autoplan session has no SendUserFile tool: name the owner's views by path in the report.
- The first session's Bash permission check failed eight times in a row after its commit (no
  verdict, not a denial), which is why this handoff came from a second session. If it happens
  again, make the edits with Write and Edit and retry the commit once.

## Questions

none

## Blocker

none
