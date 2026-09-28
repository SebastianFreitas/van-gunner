Status: partial
# Plan state: vanfix

## Plan
`vanfix`, `.claude/plans/vanfix.md`; branch `claude/plan-vanfix`, worktree
`.claude/worktrees/plan-vanfix`.

## Architecture now
- `tools/van_audit.py`: launcher (`--out`, `--strict`, `--timeout`), report-only (exit 0)
  until phase 5; report at `.godot/van_audit/report.txt`. FLICKER counts parallel faces within
  `PLANE_EPS` 0.01 m as coplanar (`van_audit_overlap.gd`), so edge-to-edge gaps are 2 cm (D12).
- `tools/van_audit/van_audit.tscn` + `van_audit.gd` runner; helpers `van_audit_mesh.gd`,
  `van_audit_states.gd`, `van_audit_overlap.gd` (FLICKER/CLIP/OPENING), `van_audit_gaps.gd`
  (EDGE, LEAK_IN, LEAK_OUT: LEAK_OUT is cast from OUTSIDE and flags layer-2-only meshes seen
  from the street).
- `tools/smoke/smoke_shots_closeups.gd`: close-ups `c01`..`c32`.
- Door leaf (`scripts/van/side_door_leaf.gd`): `DOOR_HALF_Z` 1.17, `JAMB_CLEAR` 0.13 (2 cm
  inside the jamb opening ±1.19 z, 0.13..2.94 y), `PANEL_HALF_Z` 1.07, trim strips 2 cm inside
  the panel frame's opening, `TRIM_LIFT` 0.01. Inner stack from the body face toward the
  cabin: RecessedPanel (single-sided) 1 cm, Perimeter/PanelFrame 1–5.5 cm, strips 2–6.5 cm;
  LatchPlate 1 cm proud of the outer skin.
- Windows (`scripts/van/side_windows.gd`): `TRIM_LIFT` 0.01, `FRAME_THICKNESS` =
  `CASING_BACK_REF` 0.04 − 0.01 = 0.03 (outer face 1 cm inboard of the hull casing's inner
  face); `FRAME_OUTER_POLY` a mitred 2 cm inset of `VanSideWall.WINDOW_CUT_POLY`. Hinge pivot
  at the liner (x 0 in hinge space); the audit shows no swing row, so D8's swing is clean as is.
- Iron cross (`scripts/van/iron_cross.gd`): vertical bar `TRIM_LIFT` inboard of the horizontal.
  Its placement `iron_inset = IRON_INSET 0.035 − glass_outward_bump 0.05` puts it 1.5 cm
  outboard of the liner, inside the frame's depth band (0..3 cm): the end pads overlap the
  frame (tiny FLICKER rows below).
- Window glass single-sided, `WINDOW_EDGE_SUBDIV` 10 everywhere; wall hole cut from the raw
  12 `WINDOW_CUT_POLY` vertices.

## Completed phase
Phase 1 (see git log). Phase 2 in progress, landed so far: 354b7ac (2-1 door leaf), a0e1c78
(2-2A window sampling), e8961dd (2-2B frame off the casing, iron bars apart), 7a4d3cb (2-3
door gaps 2 cm), 0f610ef (2-4 frame outline 2 cm inside the wall cut). Each CHECK/SMOKE CLEAN,
scene dump identical (no bless). Audit after all: gone are leaf vs jamb, frame vs casing/skin,
frame vs wall (closed), iron bar vs iron bar, PanelFrame vs strips/perimeter. Shots: c01 the
closed door now reads solid from inside with framed panels (picture 1 fixed); c10 the open
window's reveal still shows a ragged rust edge (likely the grime shader on the reveal; re-check
against picture 3 after the questions).

Remaining door/window rows (audit 2026-09-28, closed unless named):
- Door front edge: CLIP `SideDoors/<S>/CurvedBody` vs `Interior/FrontWall/Slab` (z −4.55,
  142 hits) and `VanLook/Hull/CornerPostF<S>` (z −4.65); FLICKER `SideDoors/Left/PanelFrame` vs
  `FrontWall/Slab` (0.109 m²). Leaf spans z −4.655..−2.315 (center −3.485); the wall's door
  opening reaches −4.785. D14.
- LatchPlate: CLIP vs `SideSkin<S>`, `SideDoorCasing<S>`, `InnerShell/CeilRib1_*` at y 3.05–3.07,
  FLICKER vs `SideDoorCasing<S>` 0.049 m². Internal: the plate sits above the leaf top (2.92);
  bring it inside the leaf (y ≤ leaf top − 2 cm). Spec after the questions.
- CLIP leaf vs `VanLook/MarkerLights/ClearanceL0|LensL0` (R too) at y 2.92, z −4.20: marker
  lights sit on the door; move them off the door in the look phase (carry forward).
- Half/open: FLICKER `SideWalls/<S>Wall` vs `PanelFrame|PerimeterFrame|BeltStrip|LowerCrease`
  (up to 0.41 m² open). D13.
- Half/open: FLICKER leaf parts vs `VanLook/Armour/ArmourPlates|ArmourGlass|ArmourRebar`,
  `VanLook/Wheels/SpareL`, `ToolBox`, `Hull/SideDoorCasing<S>`, `SideSkin<S>`,
  `SideWindowCasing<S>1`: hull dressing stays put while the door slides through it. Owned by the
  add-ons phase (D6: clear of every door); carry forward.
- IronCross end pads vs `CurvedFrame` (0.003–0.007 m², every pose). Spec after the questions:
  move the iron cross (bars and pads) 2 cm inboard of the frame's cabin face, or shorten the
  pads to stop 2 cm inside the frame opening; the second keeps the bars on the glass.
- LEAK_OUT: door `CurvedOuter` (1164/1095 rays), `LatchPlate` (70/57), `CurvedBody` (18/14),
  window `CurvedFrame` (50–65), `WindowGlass` (3–6), `IronCross/*` (1–31). D15.
- Noise (argue in research 01 at phase close): OPENING `open=win_*_front node=SideDoors/*`
  (slid-open door in the front window's swing box), door vs `VanLook/Cables/*` (cable router).

## Next phase
Phase 2 · Side doors and windows from inside (D7, D8, D10), continued (Blocker answered as D13-D15).
1. Door spec from D13 (recess 0.24 m) and D14 (shorten front 13 cm), one spec each, `side_doors.gd` /
   `side_door_leaf.gd` / `van_side_wall.gd` only as the answer needs.
2. LatchPlate inside the leaf; iron end pads 2 cm inside the frame opening (one spec each).
3. D15's layer change (layers 1 and 2).
4. Audit (600000 ms), grouped as in this session; shots c01, c02, c05, c10; scene dump; argue
   the noise in research 01; Handoff protocol.

## Blocker
none (answered 2026-09-28: Q1 → D13 recess 0.24 m, Q2 → D14 shorten front 13 cm, Q3 → D15
layers 1 and 2; all the recommended options).
