# Plan state: van-exterior-2

Plan: .claude/plans/van-exterior-2.md · Stage: running
Updated: 2026-09-28 · after phase 2 · commit c4711c6

## Architecture now
- `scripts/debug/debug_van_commands.gd`: `cmd_torch` (spot on the player camera) and `cmd_floodlight` (four omnis on VanRig), cull mask 3, toggled with `visible`.
- `tools/smoke/smoke_shots.gd` `van_views_lit()`: `--shots` saves v08..v16 `idle-van-lit-*` (side-front, side-rear, outside, quarter-driver, quarter-passenger, front, rear, window, roof).
- `scripts/van/look/van_cab.gd` `rebuild_look()`: hood, windshield, header, two headlight discs; `CAB_BACK_Z` -4.72, `NOSE_Z` -8.2; no sides or back. Headlight SpotLight3Ds at (±1.75, 0.95, `NOSE_Z`-0.2), energy 3.0, range 26, 30°: they already light the road.
- `scripts/van/look/van_front_kit.gd` `build()`: bumper (width 5.0 at `NOSE_Z`-0.2), seeded ram (plow / bar_ram / cow_catcher, to z -9.2), cage, lamp cages.
- `scripts/van/look/van_wheels.gd`: `WHEEL_X` 2.8, `FRONT_AXLE_Z` -7.25, radii 0.5 / 0.58, rear axles by count, `_build_exhaust()`.
- `scripts/van/look/van_hull.gd`: skin (`SKIN_OFFSET_M` 0.06), roof z -4.72..4.78, rear, sill boxes. `van_front_wall.gd` is interior only (`FACE_Z` -4.55).

## Phase 2 · Audit with pictures · done
- `.claude/plans/research/van-exterior-2-01-audit.md`: 27 entries (C1–C5 cab, S1–S6 seams, W1–W5 windows, U1–U6 underside, N1–N5 night), each with shots, builder and severity. Annotated PNGs sent to the owner. Commit c4711c6.
- Run order set in Progress: **5 → 6 → 3 → 4 → 7**. No `(auto)` decisions.

## Next phase: 5 · A real cab and what the windshield shows
- Start at: the audit's "Cab and front" section, then `scripts/van/look/van_cab.gd` `rebuild_look()` and `van_front_kit.gd` `build()`; read `.claude/rules/art-style.md` and `.claude/rules/van-shell-and-hud.md` (Van shell geometry, Van look).
- Requirements: D3 cab-over face on `VanBodyProfile` (A-pillars, cab doors with windows, framed windshield reveal, grille, bumper refit from the front kit so no beams lie loose ahead, headlight housings), D9 dark cab behind the windshield (dashboard, seat backs, driver silhouette, faint dash glow). Close C1–C5; the cab must have sides so the front wheels (U1) sit under it; keep the headlight spots (N2); close the body's front end (S2) where the cab meets it. Helper split past 300 lines. Verify: check, smoke, scene dump (`--bless` expected: the tree changes), front/quarter lit shots, unlit front inside the budget.
- Open questions: ask at phase start how long the cab-over is (keep `NOSE_Z` -8.2 or shorten), and whether the seeded ram variants stay.
