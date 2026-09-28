Status: partial
# Plan state: vanfix

## Plan
`vanfix`, `.claude/plans/vanfix.md`; branch `claude/plan-vanfix`, worktree
`.claude/worktrees/plan-vanfix`.

## Architecture now
- `tools/van_audit.py`: launcher (`--out`, `--strict`, `--timeout`), report-only (exit 0)
  until phase 5; report at `.godot/van_audit/report.txt` (~4 min, use `--timeout 600`).
  FLICKER counts parallel faces within `PLANE_EPS` 0.01 m as coplanar, so edge-to-edge gaps
  are 2 cm (D12), stacked lifts 1 cm (D7). CLIP `at=` is the mean of the intersection points
  (two symmetric corners average to the part's centre).
- `tools/van_audit/van_audit.tscn` + `van_audit.gd` runner; helpers `van_audit_mesh.gd`,
  `van_audit_states.gd` (poses every door and window at the same fraction),
  `van_audit_overlap.gd` (FLICKER/CLIP/OPENING), `van_audit_gaps.gd` (EDGE, LEAK_IN,
  LEAK_OUT cast from outside).
- `tools/smoke/smoke_shots_closeups.gd`: close-ups `c01`..`c32`; window close-ups aim at
  the hinge origin minus `HINGE_OUT_M`.
- Side door leaf (`scripts/van/side_door_leaf.gd`): opening `door_half_length` 1.235 at
  `door_center_z` -3.42, recess 0.24 (D13), leaf `DOOR_HALF_Z` 1.105, `PANEL_HALF_Z` 1.005,
  `JAMB_CLEAR` 0.13; inner stack RecessedPanel 1 cm, Perimeter/PanelFrame 1–5.5 cm, strips
  2–6.5 cm; LatchPlate 1 cm proud; Handle local z 0.81; CurvedOuter/LatchPlate/Handle on
  layers 1+2 (D15). Gun port untouched (D10).
- Side windows (`scripts/van/side_windows.gd`): frame `FRAME_THICKNESS` 0.03, outline a
  mitred 2 cm inset of `VanSideWall.WINDOW_CUT_POLY`; the `Hinge` pivot sits `HINGE_OUT_M`
  0.32 outboard of the liner at `y_hinge` 2.515 (children shifted back, closed pose
  unchanged; D16), past the hull skin (`SideSkin<S>` = side panel mesh 0.16 thick, 0.06 out,
  outer face 0.22) and casing (0.13). Frame/glass/iron on layers 1+2.
- Iron cross (`scripts/van/iron_cross.gd`): bars end `BAR_END_CLEAR` 0.04 inside the span,
  pads `PAD_END_CLEAR` 0.02; vertical bar `TRIM_LIFT` inboard of the horizontal.

- Side hull skin (`scripts/van/look/van_hull.gd` `_build_sides`): `walls.build_side_panel_mesh(wall_sign, walls.thickness, SIDE_SKIN_OUTER_M, false)`, i.e. the wall's grid and cuts from 0.16 to `SIDE_SKIN_OUTER_M` 0.22 off the liner with no inner face (D17). `VanSideWall.build_side_panel_mesh(wall_sign, x_from, x_to, inner_face)` passes through to `van_side_wall_panel.gd` `build_side_mesh` (398 lines, cap 400). Roof, rear, sills, patches, hull lines and armour still use `SKIN_OFFSET_M` 0.06.

- Side opening reveals (D18): `VanSideWall._add_side` builds `<Left|Right>Wall` from `van_side_wall_panel.gd` `build_side_mesh(..., Part.FACES)` (layer 2) and `<Left|Right>WallReveals` from `Part.RETURNS` (returns + window/door reveals, liner to 0.16, wall material, layers 1+2); the hull skin still calls `Part.ALL` for 0.16..0.22. `van_side_wall_panel.gd` and `van_side_wall_shell.gd` are at the 400-line cap. Door jambs are built by `scripts/van/van_side_wall_jambs.gd` (ring minus its outer return, layers 1+2). The side door casing (`van_hull_patches.gd`) and `van_hull_window_casings.gd` are deleted (buried duplicates).

## Completed phase
Phase 2 · Side doors and windows from inside, done (commits 354b7ac..cf9e65a, scene-dump bless
65b4809). Window pivot 0.32 m out (D16). Remaining window rows: front window vs its own open door
in the audit's all-open pose (forbidden in play by the interlocks; phase 5 poses them apart) and
the single-sided ExteriorPane EDGE rows.

## Next phase
Phase 3 · One sealed outer body (D4, D7), continued. Done: 1e0f3ab (D17); session 5: 99442cd, b6dfee2
(D18); session 6: 0927763 (roof, rear posts/header, rear corner strips and sills meet the 0.22 face;
rear corner's rear return deleted, RearSkin owns the rear face; new `BellySkin` at y -0.25 closes the
bottom between the sills; hull lines `_skin_x` = inner + 0.22 + `TRIM_LIFT` 0.01, so they are now
visible: at 0.06 they were buried in wall + skin), 08f3d43 (rear leaves' CurvedBody, WindowGlass,
WindowFrame, IronCross on layers 1+2 via new `scripts/van/rear_door_lighting.gd`, retarget_layers;
`rear_doors.gd` is at 400 lines). Check, smoke, scene dump clean (identical). Audit after 08f3d43:
CLIP 110, EDGE 27, FLICKER 1710, HEIGHT 43, LEAK_IN 1, LEAK_OUT 44 (was 75), OPENING 99, REAR_ROOF 8.
Shots v09, v14 read: rear doors now street-lit, body closed.
Session 7: ddb070e (D19: rub rail and belt line break from the bay's front to the open leaf's rear
edge, `van_hull_lines.gd` consts `DOOR_SLIDE_M` 2.45 and `DOOR_LEAF_HALF_Z` 1.105 mirror
side_doors.gd/side_door_leaf.gd), 6c93377 (`RearSkin` rebuilt as a ring at z 4.78 whose opening follows
the rear leaves' outline 2 cm out: bottom y 0.0, sides liner - 0.01, top vault - 0.005; the leaves
span z 4.63..4.79 at hinge z 4.71, the old posts/header lay 1 cm inside them), 7502ce1 (reveal from
the ring's inner edge back to the liner's end z 4.70 on sides and top). Check, smoke, scene dump
clean (identical). Audit: CLIP 102, EDGE 26, FLICKER 1703, HEIGHT 43, LEAK_IN 1, LEAK_OUT 44,
OPENING 99, REAR_ROOF 8; no RearSkin rows. Shots v09, v14 read after 6c93377: rear closed, leaves
framed by a thin rim.
Remaining, one spec each:
1. Leftover body EDGE rows: `SillL/R` open top edge at y 0.04 (length 9.52), `RearCornerL/R` bottom
   at z 4.70, `RoofSkin` front edge z -4.72; sills/belly end at z 4.80, 2 cm past the rear face.
   `RubRail<L|R>0` vs `CornerPostRL/RR` FLICKER (rail ends z 4.65 inside the post's z 4.58..4.70):
   end the rails 2 cm before the posts.
2. Optional: FLICKER `LeftWall`/`RightWall` vs `DoorJamb_L/R` 0.084 at (±2.495, 2.237, -4.644),
   `DoorJamb_R` vs `FrontWall/Slab` 0.023, `Floor/Deck` vs `BellySkin` 45.7 m² at y -0.25 (belly
   coplanar with the deck's underside: drop the belly 2 cm or delete it if the deck already closes).
Then verify: check, smoke, scene dump, audit, lit shots v08–v16 and close-ups c01, c02, c10.

