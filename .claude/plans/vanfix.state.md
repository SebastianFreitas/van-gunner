Status: phase-done
# Plan state: vanfix

## Plan
`vanfix`, `.claude/plans/vanfix.md`; branch `claude/plan-vanfix`, worktree
`.claude/worktrees/plan-vanfix`.

## Architecture now
- `tools/van_audit.py`: launcher (`--out`, `--strict`, `--timeout`), report-only (exit 0)
  until phase 5; report at `.godot/van_audit/report.txt`.
- `tools/van_audit/van_audit.tscn` + `van_audit.gd`: runner, boots the van at IDLE like the
  probe, `collect()`, HEIGHT/REAR_ROOF, then flicker/clip per pose, openings, gaps, report.
- `van_audit_mesh.gd` (triangles in VanRig space, grid; skips `GunPort` and `player`),
  `van_audit_states.gd` (door leaves + window hinges posed closed/half/open, no tweens),
  `van_audit_overlap.gd` (static FLICKER/CLIP/OPENING), `van_audit_gaps.gd` (EDGE,
  LEAK_IN/LEAK_OUT on temporary layer-20 proxies; 327 lines).
- `tools/smoke/smoke_shots_closeups.gd` + `smoke_shots.gd` `van_views_closeups()` (called from
  `smoke_driver.gd` at IDLE): `c01`..`c32`; shot numbering is now per prefix.
- `.claude/rules/tooling.md` documents the audit.

## Completed phase
Phase 1 (Geometry audit tool and close-up shots), commits 8afebc8, c2ed626, then specs 1-3/1-4,
research 60e1a32. Verified: `py -3 tools/check.py` CHECK CLEAN, `py -3 tools/smoke.py` SMOKE
CLEAN, `py -3 tools/smoke.py --shots` (c01..c32 written), `py -3 tools/van_audit.py`:
`CLIP=229 EDGE=23 FLICKER=1888 HEIGHT=43 LEAK_IN=1 LEAK_OUT=109 OPENING=136 REAR_ROOF=8`.
It names the side-door hole (LEAK_OUT on `SideDoors/*/CurvedOuter`), the window sawtooth
(FLICKER `SideWindows/*/Hinge/CurvedFrame` vs `VanLook/Hull/SideWindowCasing*`/`SideSkin*`)
and the rear roof line (REAR_ROOF `Antenna0`, `JunkCrate19`, rack). Shots read: c01, c02, c10,
c31. Findings: `.claude/plans/research/vanfix-01-audit.md`.

## Next phase
Phase 2 · Side doors and windows from inside (D7, D8, D10).
Deliverables: side door leaves solid from both sides (inner face built, trim lifted by the D7
gap, duplicates removed), port untouched; the window frame, reveal, glass and iron cut clean
along the opening with no stepped edges and no part crossing another at closed, half or open.
Verification: check, smoke, scene dump (bless if the tree changes, say so), audit clear for
doors and windows, close-up shots re-read against pictures 1–3.
First action: read `.claude/plans/research/vanfix-01-audit.md` (door and window rows) and
`.claude/rules/` files for `scripts/van/`, then Explore `scripts/van/side_doors*.gd` (leaf
builder: CurvedBody/CurvedOuter/RecessedPanel) and `scripts/van/side_windows*.gd` (CurvedFrame,
IronCross, WindowGlass/ExteriorPane).

## Requirements / gotchas
- Audit runs ~4 min (600000 ms timeout); grep the report with `cut -c1-200`, never read it whole.
- "Audit clear for doors and windows" = no FLICKER/CLIP/OPENING/LEAK row naming
  `SideDoors` or `SideWindows` except rows that are audit noise, argued in the research file.
- The door leaf `CurvedBody` reaches forward into the cab back wall (CLIP z to -4.74); the
  door OPENING rows on PcRig/CabRelay props likely follow from the oversized closed box.
- Same-node duplicates (`a=b` FLICKER on WindowGlass, ExteriorPane, RecessedPanel) are D7
  "duplicates removed".
- Implementers overflowed 60k on every spec this phase: name files and line ranges tightly.
- A fresh worktree's first smoke can fail on `VanLook` not found: run check first.

## Blocker
none
