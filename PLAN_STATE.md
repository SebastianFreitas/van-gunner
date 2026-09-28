# Plan state: van-exterior-2

Plan: .claude/plans/van-exterior-2.md · Stage: running
Updated: 2026-09-28 · after phase 4 · commit d93335e

## Architecture now
- `scripts/debug/debug_van_commands.gd`: `cmd_torch` and `cmd_floodlight` (cull mask 3, toggled with `visible`).
- `tools/smoke/smoke_shots.gd` `van_views_lit()`: `--shots` saves v08..v16 `idle-van-lit-*` (side-front, side-rear, outside, quarter-driver, quarter-passenger, front, rear, window, roof).
- `scripts/van/look/van_cab.gd` + `van_cab_shell.gd` / `van_cab_face.gd` / `van_cab_parts.gd`: cab-over to `NOSE_Z` -8.2, headlight SpotLights kept (N2), dash glow 0.25; `van_front_kit.gd` bumper, rams, cages.
- `scripts/van/look/van_wheels.gd` + `van_chassis.gd`: wheels, flares, wells, steps, tank, exhaust, spares, rails, `RearBumper`.
- `scripts/van/look/van_hull.gd`: skin (+0.06), roof, RearSkin; calls `van_hull_lines.gd`, `van_hull_patches.gd`, `van_hull_window_casings.gd`; pushes its exterior material to group `side_doors` (`set_exterior_material`).
- `VanLook/MarkerLights`: clearance, tail and ID lamps on layer 1, tuned against the `*-outside` budget.
- Side windows: `side_window_exterior.gd` hangs `ExteriorPane` (layer 1, group `van_exterior_layer`, skipped by `VanLighting.mark_interior_geometry`) under each `WindowGlass`; `van_window_exterior.gdshader` discards from the cabin side.
- Exterior shader `scenes/van/van_exterior.gdshader` paints in model space (`sill_y_m`, `accent_band`, roughness uniforms).

## Phase 4 · Side windows from outside · done
- Exterior panes (D4, D17), casings round the openings (W3), side door leaf outer skin in hull paint (W1, D18), pillar rebar bent onto the skin with standoffs (W4, D19). Commit d93335e.
- Verified: check, smoke, scene dump identical, shot stats unchanged within noise, lit v15 read by eye. Reviewer skipped (main context at its line).
- No `(auto)` decisions. Loose ends are in the plan's Carry forward (Phase 4 line).

## Next phase: 7 · The night read (last phase)
- Start at: the audit's "Night read" section (`.claude/plans/research/van-exterior-2-01-audit.md`, N1–N5), then `VanLook/MarkerLights` and `van_exterior.gdshader` roughness; read `.claude/rules/art-style.md` (emission and `*-outside` budget) and `.claude/rules/van-shell-and-hud.md`.
- Requirements (D7): headlights light the road ahead (already true, N2: keep), tail and marker lamps glow, a faint wet sheen on the skin inside roughness 0.78..0.95, all inside the `*-outside` budget. Locate N5 (roof white disc). Also look at the Phase 4 carry-forward: milky lit side panes (dust layer in `van_window_exterior.gdshader`), casing reveal and sash clip, rebar visibility.
- Verify: check, smoke, scene dump, unlit `--shots` through `tools/shot_stats.py` against `art-style.md`, the owner's view by eye.
- Last phase: its handoff also closes the plan (Stage done, delete ACTIVE and PLAN_STATE.md, list `(auto)` decisions).
- Open questions: none known; list the phase's own decisions at its start.
