# Plan state: van-exterior-2

Plan: .claude/plans/van-exterior-2.md · Stage: running
Updated: 2026-09-28 · after phase 3 · commit f8d8339

## Architecture now
- `scripts/debug/debug_van_commands.gd`: `cmd_torch` and `cmd_floodlight` (cull mask 3, toggled with `visible`).
- `tools/smoke/smoke_shots.gd` `van_views_lit()`: `--shots` saves v08..v16 `idle-van-lit-*` (side-front, side-rear, outside, quarter-driver, quarter-passenger, front, rear, window, roof).
- `scripts/van/look/van_cab.gd` + `van_cab_shell.gd` / `van_cab_face.gd` / `van_cab_parts.gd`: cab-over from -4.72 to `NOSE_Z` -8.2; `van_front_kit.gd` bumper, rams, cages.
- `scripts/van/look/van_wheels.gd` + `van_chassis.gd`: wheels, flares, wells, steps, tank, exhaust, spares, frame rails, `RearBumper` (z 4.92).
- `scripts/van/look/van_hull.gd`: side skin (`SKIN_OFFSET_M` 0.06, z -4.7..4.7, y 0..3.08), roof z -4.72..4.78 with a 0.10 lip, RearSkin at z 4.78; calls `van_hull_lines.gd` and `van_hull_patches.gd`.
- `scripts/van/look/van_hull_patches.gd`: `RearCornerL/R`, chamfered `SillL/R`, `SideDoorCasingL/R` (ring 0.07 wide round the side door opening, liner +0.04..+0.19, built with `walls.build_curved_shell_mesh` and a rectangular hole).
- Side door: `side_door_leaf.gd` `fit_door_leaf()` builds `CurvedBody` (0.14 thick from the liner) + `CurvedOuter` (0.035) with `door_body_material()` (glossy black, W1). The leaf recesses inward then slides +z inside the van (`side_doors.gd`).
- Side windows: `side_windows.gd`, interior `RearWindowGlassMaterial` seen from both sides; openings z [2.835, -0.375], y centre 1.775, half 1.222 × 0.707.

## Phase 3 · Holes and seams · done
- S1 rear corner returns, S3 sealed sill, S4 roof lip, S6 door casing; S5 was the road under the rear, closed by phase 6's bumper. Commit f8d8339.
- Verified: check, smoke, scene dump identical, lit v09/v14/v15 read by eye. Reviewer skipped (main context at its line).
- No `(auto)` decisions.

## Next phase: 4 · Side windows from outside
- Start at: the audit's "Windows and door leaf" section (`.claude/plans/research/van-exterior-2-01-audit.md`, W1–W5), then `scripts/van/side_windows.gd` and `side_door_leaf.gd` `door_body_material()`; read `.claude/rules/art-style.md` and `.claude/rules/van-shell-and-hud.md`.
- Requirements: D4 per side window an outer frame ring and a dark-tinted exterior pane on layer 1, a reveal with depth, exterior glass with strong fresnel and no interior rim recipe; interior pane, iron cross and breakable glass unchanged. W1: give the door leaf's outside an exterior (non-glossy) look; it sits in the new casing. W4: locate the floating bars beside the side window (candidates `van_armour_pieces.gd` `add_bar()`). W5 (rear door windows) is the reference. Verify: check, smoke, scene dump, lit and unlit window close-ups, interior views unchanged by eye, `*-outside` budget.
- Open questions: none known; list the phase's own decisions at its start.
