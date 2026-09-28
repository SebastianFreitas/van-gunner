# Plan state: van-exterior-2

Plan: .claude/plans/van-exterior-2.md · Stage: running
Updated: 2026-09-28 · after phase 6 · commit c2bf8bf

## Architecture now
- `scripts/debug/debug_van_commands.gd`: `cmd_torch` and `cmd_floodlight` (cull mask 3, toggled with `visible`).
- `tools/smoke/smoke_shots.gd` `van_views_lit()`: `--shots` saves v08..v16 `idle-van-lit-*` (side-front, side-rear, outside, quarter-driver, quarter-passenger, front, rear, window, roof).
- `scripts/van/look/van_cab.gd` + `van_cab_shell.gd` / `van_cab_face.gd` / `van_cab_parts.gd`: cab-over from `CAB_BACK_Z` -4.72 to `NOSE_Z` -8.2, skin at `profile.outer_x_at(y)` (about 2.54 at the sill) down to `BASE_Y` -0.25; `VanCab._add_quad` / `_add_tri` / `_dark_material` are static and reused.
- `van_front_kit.gd`: front bumper, seeded rams and cages.
- `scripts/van/look/van_wheels.gd`: wheels (`WHEEL_X` 2.8, `FRONT_AXLE_Z` -7.25, radii 0.5/0.58, rear axles [3.0] or [2.3, 3.6]), 24 tread blocks, mud flaps; calls `van_chassis.gd`.
- `scripts/van/look/van_chassis.gd` (RefCounted, `SKIN_X` 2.56): `FlareL/R<n>` + `WellL/R<n>` per wheel, side steps (z -3.485) and cab steps (z -5.7), `FuelTank` on -exhaust side (z 0.1), `ToolBox` + `ExhaustPipe` (z -1.1..1.2) + `ExhaustTip` on the exhaust side, `SpareL/R` at z -1.55, `FrameRailL/R` (z 4.4) and `RearBumper` (z 4.92, y -0.19..-0.01).
- `scripts/van/look/van_hull.gd`: skin (`SKIN_OFFSET_M` 0.06), roof z -4.72..4.78, rear face at z 4.78, sill boxes (x wall_x_at(0)+0.09, y -0.25..0.03, z -4.72..4.78).
- The body sits at road level (floor y 0, road -0.2): there is no visible underside.

## Phase 6 · Underside and wheels · done
- Chassis kit per D6, D14 (bolt-on flares, wheels outboard), D15 (spares behind the side door), D16 (short exhaust); closes U1–U6 (U6 was the spare chains on the cab doors, U3 the 7.9 m exhaust). Commit c2bf8bf.
- Verified: check, smoke clean, scene dump identical (built at runtime), lit side-front and side-rear shots read by eye. Reviewer pass skipped (main context at its line).
- No `(auto)` decisions.

## Next phase: 3 · Holes and seams
- Start at: the audit's "Holes and seams" section (`.claude/plans/research/van-exterior-2-01-audit.md`), then `scripts/van/look/van_hull.gd` (`_build_rear`, `_build_sills`) and `van_hull_lines.gd`; read `.claude/rules/art-style.md` and `.claude/rules/van-shell-and-hud.md`.
- Requirements: D5 profile-sampled patches for S1, S3, S4, S5, S6 (C1/S2 closed by phase 5). S5 (the rear step plate, not located yet) sits just above the new `RearBumper`: make sure they don't overlap. Verify: check, smoke, scene dump, lit shots re-read against those IDs.
- Open questions: none known; list the phase's own decisions at its start.
