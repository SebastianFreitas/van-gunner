# Spec 5-2 · Side-step hangers, roof rack and antenna FLICKER

Worktree: C:/Users/Traff/Documents/van-gunner/.claude/worktrees/plan-vanfix. Do not commit.

## Goal
Clear the audit's FLICKER rows (parallel faces within 0.01 m) between the side steps and their
hangers, the hangers and the side skin, the roof rack's rails, slats, legs and antenna bases, and
each antenna whip against itself. Rule for every fix (D12): parallel faces either ≥ 0.02 m apart, or
one part clearly embedded in the other with no face within 0.01 m of the other's face planes.
Changes are a few cm, invisible in play.

## Target files
1. `scripts/van/look/van_chassis.gd` `_build_steps` (side step only; leave CabStep alone, no rows).
2. `scripts/van/look/van_roof.gd` `_build_rack`, `_build_antennas`.

## Facts
- Sill (read only, `van_hull_patches.gd`): x 2.60..2.70 (outer face 2.70 = `SILL_OUT_X`), y -0.25..0.04,
  chamfer top (2.62, 0.04) → (2.70, -0.02). The side skin's bottom edge is at y ≈ 0.02.
- `SideStep<S>` box 0.30 × 0.05 × 2.2 at x SKIN_X+0.15 (x 2.56..2.86, y -0.085..-0.035);
  `SideStepHanger<S><i>` 0.18 × 0.12 × 0.06 at x SKIN_X+0.09 (2.56..2.74, y -0.10..0.02). Rows:
  step vs hanger (both inner faces at 2.56), SideSkin vs hanger (hanger top 0.02 on the skin's bottom).
  Suggested: step x 2.62..2.86 (inner end inside the sill), hanger x 2.58..2.74, y -0.11..0.00.
- Rack: rails `RackRailL/R` (0.06 bars at ±RACK_HALF_X, RACK_Y), slats 0.045 bars at the same RACK_Y
  between the rails, legs 0.06 bars at x = ±RACK_HALF_X up to RACK_Y. Rows: rail vs slat (5 each
  side), rail vs leg (6), slat vs leg (2), `RackRailL` vs `AntennaBase0` (16 pairs, the 0.08 base box
  centred on the rail at RACK_Y). Suggested: slats end 0.02 inside each rail's inner face... no: slats
  sit on top of the rails (y RACK_Y + 0.06 * 0.5 + 0.045 * 0.5 + 0.0 so their bottoms rest on
  the rail top, or lift 0.02 above it and overlap in x) — pick one where no faces are within 0.01;
  legs stop at the rail's bottom face (RACK_Y - 0.03) and are 0.04 thick so their side faces stay
  0.01+ inside the rail's; the antenna base sits on top of the rail (base centre y RACK_Y + 0.03 + 0.04)
  and the whip starts on the base top. Antenna 2 (x +RACK_HALF_X, z 1.2) likewise.
- `Antenna0` vs itself, 321 pairs: a CylinderMesh whip 0.008..0.018 radius. Find out why one mesh
  flickers with itself (e.g. the cap discs at top_radius 0.008: many tiny triangles; or the audit's
  MIN_AREA) — if the cylinder's own caps are coplanar degenerate triangles, set `cap_top = false` /
  `cap_bottom = false` where the end is buried (the bottom sits inside the base) or use `radial_segments`
  8 and `rings` 1. Report what it was.
- `van_roof.gd` has `fits(top_y, z_max, antenna)` and `_drop_misfits()`: keep every group's top under
  the same cap (moving bases up by 0.07 must still pass `fits`; if `fits` reads fixed numbers, check them).

## Rules
GDScript: tabs, typed everything, `##` docs on new consts, two blank lines between funcs, ~100
columns. Keep node names. Do not touch other files.

## Verification
1. `py -3 tools/check.py 2>&1 | tail -5` → CHECK CLEAN.
2. `py -3 tools/van_audit.py 2>&1 | tail -3`; `grep -E "Rack|Antenna|SideStep" .godot/van_audit/report.txt | cut -c1-200`:
   report what is left and the SUMMARY line.
3. `py -3 tools/smoke.py 2>&1 | tail -5` smoke clean (report a fingerprint diff, do NOT bless).
