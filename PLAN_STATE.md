# Plan state: van-exterior-2

Plan: .claude/plans/van-exterior-2.md · Stage: running
Updated: 2026-09-28 · after phase 5 · commit b662a42

## Architecture now
- `scripts/debug/debug_van_commands.gd`: `cmd_torch` and `cmd_floodlight` (cull mask 3, toggled with `visible`).
- `tools/smoke/smoke_shots.gd` `van_views_lit()`: `--shots` saves v08..v16 `idle-van-lit-*` (side-front, side-rear, outside, quarter-driver, quarter-passenger, front, rear, window, roof).
- `scripts/van/look/van_cab.gd` (core): constants `CAB_BACK_Z` -4.72, `NOSE_Z` -8.2 (the face), `BASE_Y` -0.25, `CAB_FLOOR_Y` 0.9, `WS_*`, `GRILLE_*`, `HEADLIGHT_X/Y`, `BUMPER_*`, `DOOR_*`; `profile: VanBodyProfile`; `_add_quad` / `_add_tri` (with `inward`); headlight SpotLights unchanged (±1.75, 0.95, energy 3, range 26, 30°).
- `van_cab_shell.gd`: CabSkin (outer section at `profile.outer_x_at(y)`, about 2.54 at the sill, extruded -4.68..-8.2, sill points pulled down to `BASE_Y`), liner, back lip (closes S2), back wall, floor, face with windshield hole, reveal.
- `van_cab_face.gd`: split windshield, frame, A-pillars, grille, headlight housings, cab doors (z -4.95..-6.45) with windows. `van_cab_parts.gd`: dash, dash glow (omni 0.25), seats, driver, mirrors.
- `van_front_kit.gd`: bumper against the face, `_mount_z(y)` bolts the seeded rams to the bumper or face; cages welded to the windshield frame.
- `scripts/van/look/van_wheels.gd`: `WHEEL_X` 2.8, `FRONT_AXLE_Z` -7.25, radii 0.5 / 0.58, rear axles by count, `_build_arch`, `_build_exhaust()`.
- `scripts/van/look/van_hull.gd`: skin (`SKIN_OFFSET_M` 0.06), roof z -4.72..4.78, rear, sill boxes.

## Phase 5 · A real cab and what the windshield shows · done
- Cab-over rebuilt on `VanBodyProfile` with sides, back lip, framed split windshield, grille, headlight housings, cab doors and a dark cab behind the glass; rams and cages attached. Closes C1–C5 and S2; N2 kept. Commit b662a42.
- Verified: check, smoke clean, scene dump identical (the cab is built at runtime), lit front and quarter shots read by eye, `03-idle-outside` mean 0.0083 / p95 0.0227.
- Decisions D10–D13 answered by the owner (no `(auto)`).

## Next phase: 6 · Underside and wheels
- Start at: the audit's "Underside and wheels" section (`.claude/plans/research/van-exterior-2-01-audit.md`), then `scripts/van/look/van_wheels.gd` `_build_arch` and `FRONT_AXLE_Z`, and `van_cab_shell.gd` CabSkin; read `.claude/rules/art-style.md` and `.claude/rules/van-shell-and-hud.md`.
- Requirements: D6 arches cut into the sill and the cab skin with a lip, wheels tucked to the arch (the front wheels at x 2.8 now stand outside the cab side at about 2.54: U1), rear wheel arches (U2), frame rails, fuel tank, rear bumper with an underride bar, side steps (U4); find and fix the long sill pipe (U3), the diagonal rod (U6) and the cog-like tread (U5). Verify: check, smoke, scene dump, low lit side and rear shots.
- Open questions: none known; list the phase's own decisions at its start.
