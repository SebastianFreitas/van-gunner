# Plan state: van-exterior-2

Plan: .claude/plans/van-exterior-2.md · Stage: running
Updated: 2026-09-28 · after planning (phase 1 done earlier) · commit c1a685f

## Architecture now
- `scripts/debug/debug_van_commands.gd`: `cmd_torch` (DebugTorch spot on the player camera) and `cmd_floodlight` (DebugFloodlights, four omnis on VanRig), cull mask 3, toggled with `visible`.
- `tools/smoke/smoke_shots.gd` `van_views_lit()`: `--shots` saves v08..v16 `idle-van-lit-*` (side-front, side-rear, outside, quarter-driver, quarter-passenger, front, rear, window, roof) with the floodlight on.
- Exterior builders: `scripts/van/look/` (`van_hull.gd`, `van_hull_lines.gd`, `van_cab.gd` stub, `van_front_kit.gd`, `van_wheels.gd`, `van_armour.gd`, `van_marker_lights.gd`), `scripts/van/side_windows.gd`, `scripts/van/van_front_wall.gd`; outline from `VanBodyProfile`.

## Phase 1 · Tooling · done
- Torch, floodlight and nine lit shots, verified by check, smoke, scene dump and shots; commit 74f8364.
- Planning rounds since: D3 to D9 recorded (cab-over front, exterior window panes, profile seam patches, chassis kit, real night sources, audit-first order, dark cab with a dash glow).

## Next phase: 2 · Audit with pictures
- Start at: `py -3 tools/smoke.py --shots <scratchpad>/shots`, then Read v08..v16 `idle-van-lit-*.png`.
- Requirements: `.claude/plans/research/van-exterior-2-01-audit.md`, one entry per issue (shot, builder or node, severity), grouped cab/front, holes and seams, windows, underside/wheels, night read; set the run order of phases 3 to 7 in Progress (D8); send annotated PNGs to the owner. Cover the Carry forward first-look issues.
- Open questions: none.
