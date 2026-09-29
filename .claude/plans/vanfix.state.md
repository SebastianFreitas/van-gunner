Status: blocked
# Plan state: vanfix

## Plan
`vanfix`, `.claude/plans/vanfix.md`; branch `claude/plan-vanfix`, worktree
`.claude/worktrees/plan-vanfix`.

## Architecture now
- `tools/van_audit.py`: launcher (`--out`, `--strict`, `--timeout`), report-only (exit 0)
  until wired into smoke; report at `.godot/van_audit/report.txt` (~50 s since 158e9cb, D23).
  States `closed`, `half`/`open` (side doors + rear windows), `win_half`/`win_open` (front
  windows alone). FLICKER: parallel faces within `PLANE_EPS` 0.01 m (D12: gaps 2 cm, lifts 1 cm),
  in `van_audit_flicker.gd`. EDGE: per-mesh open edge, closed by a physics body within 1.5 cm or
  another mesh's edge within 1.5 cm of its ends and midpoint (`van_audit_gaps.gd`, 370 lines).
- Audit files `tools/van_audit/`: `van_audit.gd` (runner), `_mesh`, `_states`, `_overlap` (CLIP,
  OPENING), `_flicker`, `_gaps` (EDGE, LEAKs). Close-ups `smoke_shots_closeups.gd` `c01`..`c32`.
- Side door leaf (`scripts/van/side_door_leaf.gd`): opening half length 1.235 at z -3.42,
  recess 0.24 (D13), leaf `DOOR_HALF_Z` 1.105; outer parts on layers 1+2 (D15); port untouched.
- Side windows (`scripts/van/side_windows.gd`): `Hinge` pivot `HINGE_OUT_M` 0.32 outboard of
  the liner (D16), past the skin's outer face 0.22. Iron cross `scripts/van/iron_cross.gd`.
- Side walls: `VanSideWall._add_side` (`<S>Wall`, `<S>WallReveals`, D18); `van_side_wall_panel.gd`
  398 lines, `van_side_wall_shell.gd` 400 (cap); jambs `van_side_wall_jambs.gd`.
- Outer body (`scripts/van/look/van_hull.gd`, 334 lines): `SideSkin<S>` 0.16 → 0.22 off the
  liner, no inner face (D17); `RoofSkin`, `FrontSkin` at z -4.70, `RearSkin` ring at z 4.78, sills
  and `BellySkin` (D20); helpers `van_hull_patches.gd`, `van_hull_lines.gd` (lines at 0.22 + 0.01,
  breaking over the door slide, D19).
- Rear doors: `scripts/van/rear_doors.gd` (400, cap) + `scripts/van/rear_door_lighting.gd`
  (leaf parts on layers 1+2).
- Cab (real cab kept, D21): `scripts/van/look/van_cab_shell.gd` swept on
  `VanBodyProfile.section_points(steps, true)` from z -4.68 forward (`CabLiner`, `CabBackLip`,
  `CabFace`; back wall double-sided). Trim in `van_cab_face.gd` sits ≥ 2 cm off the face plane;
  front kit `van_front_kit.gd`. Front wheels `VanWheels.FRONT_WHEEL_OUT` 0.04 out, cab steps
  `SKIN_X + 0.17`, A-pillars 3 cm inside the outline (D22).

## Completed phase
Phase 4 · Sealed simple cab, done 815948b (see plan Progress). Phase 5 so far (session 6):
158e9cb audit speed-up, front-window poses, cross-mesh seams (D23); check clean. Audit now:
CLIP 70, EDGE 23, FLICKER 1699, HEIGHT 43, OPENING 83, REAR_ROOF 8, LEAK as before (44/1).

## Next phase
Phase 5 · Add-ons snapped and height-capped (D6), continued. First ask the Blocker questions and
record them as D24–D26. Then, one spec each: (1) roof add-ons (`van_roof.gd` rack/antennas/spot,
`van_roof_junk.gd`) under the chosen cap with a place-or-drop check, and the audit's HEIGHT /
REAR_ROOF using the same cap (today cap = roof crown `outer_roof_y_at(0)` 3.57, so the rack at
3.66–3.69 always reports); (2) wheels: Hub/Bolt 2 cm lift and `Flare*` self-FLICKER (40 pairs
each) in `van_wheels.gd`; (3) side add-ons (armour, rebar, spikes, signs, spares, rear dressing)
snapped to the skin and clear of doors/windows (CLIP/OPENING rows vs `VanLook/`); (4) interior
FLICKER named by the audit (Bulkhead 875 pairs, Props 301, InnerShell 163, Shell 49); (5) wire
`--strict` into smoke once every count is 0. Save specs after (1)–(2) if the session runs long.

## Requirements / gotchas
- The audit's `Interior/Props/FuseBox/Generator` fan/flywheel/blade rows change run to run
  (animated): freeze or skip animated parts before `--strict` goes into smoke. A PerimeterFrame vs
  SideSkin row in `half` flips 30/31 pairs on a MIN_AREA-borderline triangle.
- The remaining EDGE rows (CabLiner/BackLip/Face, 6 wheel wells, RearSkin, CornerPostF L/R,
  BellySkin, RearWall hinge CurvedBody, 4 ExteriorPane, SideSkin L/R, RearCorner L/R) are not
  seams shared edge to edge: each needs a look (by-design single-sided ones need an audit
  exemption list, not geometry).
- The cab's back edge meets `FrontSkin` at z -4.70 (cab outline 0.12 off the liner): keep the
  cab's outer outline on `VanBodyProfile.section_points(steps, true)` or FrontSkin's inner edge
  (sampled at 16 steps across the cab top) must move with it.
- A fresh worktree's first smoke fails on `VanLook` not found; run `py -3 tools/check.py` first.
- `rear_doors.gd`, `van_side_wall_shell.gd` are at 400 lines; split before adding.

## Blocker
Owner questions (D6 says "under a height cap above the roof" but gives no number; the plan's
Add-ons line). Audit cap today is the roof crown y 3.57; tops: rack 3.66–3.69, single tyres 3.92,
spotlight 4.14, crates/tyres 4.18–4.19, tarps/straps 4.22–4.24, a stacked tyre 4.44, antenna 5.76.
1. How high may roof add-ons stand above the roof crown?
   a) 0.7 m (y ~4.27) (recommended): rack, crates, tarps, straps, tyres and the spotlight stay;
      only stacked piles (the 4.44 tyre) drop. b) 0.35 m (y ~3.92): rack and flat tyres stay;
      crates, tarps, straps, spotlight drop. c) Rack height 0.12 m: all roof junk and the
      spotlight drop.
2. Antennas (thin whips 1.2–2.2 m tall)?
   a) Exempt from the cap, but never in the rear 1.5 m of the roof (recommended). b) Shortened
   to the cap. c) Dropped.
3. The rear 1.5 m of the roof (your "weird vertical walls above the back"; REAR_ROOF rows: an
   antenna, a crate, the rack's rear end and legs)?
   a) Nothing above rack height there; crates and antennas move forward or drop (recommended).
   b) Same cap as the rest of the roof. c) Nothing at all, the rack ends 1.5 m short.
