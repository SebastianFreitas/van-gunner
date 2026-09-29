Status: partial
# Plan state: vanfix

## Plan
`vanfix`, `.claude/plans/vanfix.md`; branch `claude/plan-vanfix`, worktree
`.claude/worktrees/plan-vanfix`.

## Architecture now
- Audit sections (phase 11): `van_audit_exempt.gd` `RULES` (glob pairs, reason, D) + `OPENING`; `FLICKER_MINOR` (visible `area` < `MIN_VISIBLE_AREA` 0.005, `area` sums pairs > 1 cm², `total` all pairs, D51), `FLICKER_EXEMPT`, `EDGE_EXEMPT` stay out of `AUDIT SUMMARY` (report header `COUNTS`/`MINOR`/`EXEMPT`, `AUDIT INFO` line). EDGE seam tests in `van_audit_seams.gd` (1.5 cm touch + collinear T-junction cover).
- `tools/van_audit.py`: launcher (`--out`, `--strict`, `--timeout`), report-only (exit 0)
  until wired into smoke; report at `.godot/van_audit/report.txt` (~50 s, D23). States `closed`,
  `half`/`open` (side doors + rear windows), `win_half`/`win_open` (front windows alone).
  FLICKER: parallel faces within `PLANE_EPS` 0.01 m (D12: gaps 2 cm, lifts 1 cm). EDGE: per-mesh
  open edge (`van_audit_gaps.gd`). Files `tools/van_audit/`; close-ups `smoke_shots_closeups.gd`.
- Side door: opening z -3.42 ± 1.235, leaf `DOOR_HALF_Z` 1.105, recess 0.30 (D38), slides
  `slide_distance` 2.45 (`side_doors.gd`): the open leaf's rear edge is at z ≈ 0.135; the open
  leaf spans x ≈ 2.70..2.96, so nothing low on the side fits under it.
- Cables (D40): `Router.hop_bays(pts, inset)` / `lift(p, inset)` in `van_cable_router.gd` lift any
  upper-wall run (y > 2.2) inside the door bay band (`VanInnerShell.DOOR_Z_*` ± 0.05) to x ±1.5,
  0.14 under the liner, with 0.3 m ramps; trunks (inset 0), feed and hopper (0.12) use it;
  `_trunk_at(pts, z)` gives anchors. Battery jumper rises at z -1.75 (window bay is -1.60..0.85).
- Audit `OPENING_EXEMPT` (`van_audit_overlap.gd`): PcRig in `door_left` (D39), wall/reveals/skin
  for the four windows (D41).
- Side windows y 1.775 ± 0.707 (bottom 1.07), centres z 2.835 / -0.375, hinge 0.32 out (D16).
- Outer body `van_hull.gd` (334): `SideSkin<S>` 0.22 off the liner (D17), real skin x at y 0 is
  `wall_x_at(0)` 2.42 + 0.22 = 2.64. Sills in `van_hull_patches.gd` (`_build_sill(walls, s,
  arch_spans)`, x 2.60..2.70, y -0.25..0.04, z -4.72..4.80, broken over
  `VanWheels.rear_arch_spans(look)`, `SILL_MIN_SEGMENT`), lines `van_hull_lines.gd` (D19).
- Chassis `scripts/van/look/van_chassis.gd` (RefCounted under `VanWheels`): flares/wells as D29;
  `SILL_OUT_X` 2.70 (the real sill face; was a stale 2.62); exhaust pipe and hangers off it.
  D30 slot: `SLOT_Z0` 0.16 .. `rear_axles[0] - (REAR_RADIUS + FLARE_GAP + FLARE_T) - 0.02`
  (4-wheel 2.30, 6-wheel 1.60), packed with `ADDON_GAP` 0.02: exhaust side toolbox
  (`TOOLBOX_LEN` 0.92) then spare (`SPARE_LEN` 0.84), other side tank (`TANK_LEN` 1.2) then spare;
  a misfit is not built. Builders take a centre z.
- Side armour (`van_armour.gd`, `van_armour_pieces.gd`, D32/D33): slots pillar, top, tail only;
  `_skin_x` = `wall_x_at(y) + SIDE_SKIN_OUTER_M`; `_plate_x(y0, y1)` leans plates on the skin chord;
  `_clear_of_openings` (door path, windows +0.03, `BELT_BAND_Y`, `DRIP_BAND_Y`, roof cap) drops
  misfits; no signs or car door. `van_chassis.gd` `SKIN_X` 2.56 stays (D34: embedded, no rows).
- Roof (spec-5-2): slats at `RACK_Y + 0.03` on the rails, legs to `RACK_LEG_TOP_Y`, antenna bases on
  the rail top, whips 8 segments × 1 ring; junk at `van_roof_junk.gd` `BASE_Y` (`RACK_Y + 0.035`).
- Cab (D21, D22): `van_cab_shell.gd` on `VanBodyProfile.section_points(steps, true)`.
- Caps: `rear_doors.gd`, `van_side_wall_shell.gd`, `side_windows.gd` at 400 lines; `van_audit_gaps.gd` 399;
  split before adding.
- Side window stop ring (D53): `side_windows.gd` `WindowStop` on each window root, `STOP_OUTER_POLY`
  (cut +4 cm) / `STOP_INNER_POLY` (cut -5 cm), `STOP_LIFT` 0.015, `STOP_THICKNESS` 0.008, built with
  `build_curved_frame_ring_mesh`; audit `OPENING` window prefixes include `/WindowStop`.

## Completed phase
11 (done). Commits 721fd76 (floor, exemptions, header), a92d1cb (EDGE collinear seams). Audit, two runs
identical: EDGE 10, FLICKER 9, LEAK_IN 1, LEAK_OUT 45; MINOR 417; EXEMPT EDGE 12, FLICKER 31. Check clean;
no smoke (tools/van_audit only), no shots (nothing visible).
12 (partial, sessions 5-7; session 6: probe tool 7d0de6e). Commit 5ffaddc: every LEAK_IN/LEAK_OUT row now ends with
`from=(...) dir=(...) trace=<node>:<F|B>@(x,y,z) > ...` (first ray of the row, up to 8 hits;
`van_audit_gaps.gd` `trace_ray`, file now 399 lines: split before adding more). Counts unchanged
(EDGE 10, FLICKER 9, LEAK_IN 1, LEAK_OUT 45). Triage from the traces (no fixes landed yet):
- **Rear door centre seam** (≈25 LEAK_OUT rows, 1-4 rays each: Bulkhead KickPlate/MeshFwd/MeshBack/
  BottomRail/TopRail, CabDoor Mesh/Bar1/Glass/TopRail, FrontWall/Slab, Ceiling/Vault, CeilRib2_3/3_4,
  Hopper WarnLamp, Cables@355): rays from `(0, 0.8|2.0, 5.052)` heading -z pass the closed rear doors at
  x ≈ 0..0.12 with no hit. Needs the leaves' inner-edge x in the closed pose and an overlap strip
  (astragal) on one leaf; `rear_doors.gd` is at the 400 cap: split first. Visible change: shots.
- **Side door gaps**: `RightWallReveals` (150) at the opening's front end z -4.616 and `DoorJamb_R` (86)
  at the rear end z -2.275, `Right/CurvedBody` (20) hit on its rear edge at z -2.315 then the ray crosses
  the van to the left door: the closed leaf (`DOOR_HALF_Z` 1.105) leaves ~13 cm uncovered at each end of
  the opening (z -3.42 ± 1.235). `Left/CurvedBody` (34) at y 0.16: rays pass under the leaf into the cabin
  (PcRig crate). Check the leaf's frames/outer pieces vs the opening before lengthening (D12 wants 2 cm).
- **Session 6 (commit 7d0de6e, D52):** `py -3 tools/van_audit.py --probe x,y,z:dx,dy,dz` lists every
  triangle a rig-local ray crosses (brute force, not the proxies) plus 8 rays offset 1/2 cm. Findings:
  - LEAK_IN (22) is NOT a B-pillar hole: probe of `0,1,-3.5:0.787,0.046,0.616` crosses zero triangles,
    while every offset ray hits `RightWall`/`RightWallReveals` (t ≈ 3.20) or `SideWindows/RightFront/
    Hinge/CurvedFrame` (t ≈ 3.24). A seam between the window's closed frame and the wall cut at the cut's
    front-bottom corner (≈ (2.52, 1.15, -1.53)). Probe points along the cut's rim to see whether the frame
    ring's outline (`build_curved_frame_ring_mesh`, `van_side_wall_shell.gd`:160) matches
    `WINDOW_CUT_POLY` there (rounded corner vs frame corner), then close it (frame overlaps cut ≥ 2 cm).
  - Side door: opening `van_side_wall.gd`:43-46 (`door_half_length` 1.235, `door_center_z` -3.42,
    y 0.02..3.05, `door_jamb_inset` 0.11); the leaf (`side_door_leaf.gd`:13 `DOOR_HALF_Z` 1.105,
    `JAMB_CLEAR` 0.13 on all four sides, x on `wall_x_at(mid_y)`) sits 2 cm inside the jamb lip (D12).
    Probe of `7,0.8,-1.948:-0.977,0.201,-0.073` (the `DoorJamb_R` row): jamb lip F at x 2.600, its back
    at x 2.458, then the LEFT door's PanelFrame/CurvedBody (the proxy trace missed those). So the jamb
    rows see the door frame's lip through the opening: by design (D18 put the reveals in street light).
    Exempt `DoorJamb_*` and `*WallReveals` first hits on LEAK_OUT (rule + reason + D); then probe the
    `Left/CurvedBody` y 0.16 row (`-6.062,0.8,1.552:0.577,-0.106,-0.810`), which continues into the
    PcRig: a real see-through slot under the leaf needs a seal (a strip on the leaf's bottom/end
    edges overlapping the jamb lip, 2 cm off it). `VanInnerShell.DOOR_Z_MIN/MAX` (-4.655/-2.185,
    `van_inner_shell.gd`:18) duplicate the opening; `DOOR_LEAF_HALF_Z` 1.105 is copied in `van_armour.gd`,
    `van_hull_lines.gd`, `van_marker_lights.gd`: keep in step if either changes.
  - Upper-left rows (`DoorJamb_L` 96, `LeftWall` 13, CeilRibs) enter the left opening's rear-top corner
    through the same slot: same exemption/seal question, probe one before deciding.
- **Session 7 (commit 9f1eb2a, D53):** the side window LEAK_IN was the 2 cm slot between the frame's outer
  edge and the cut (ray slid along the bottom edge under the frame's outer vertex (-1.129, -0.62)): sealed
  by the cabin-side `WindowStop` ring. Audit now: EDGE 10, FLICKER 9, LEAK_IN 1, LEAK_OUT 43; MINOR 425
  (8 new tiny BeltRail vs WindowStop pairs, under the floor); EXEMPT unchanged. Check, smoke clean; shots
  c18/c19 show the ring as window trim, the open sash clears it.
  The remaining LEAK_IN (14 rays, `from=(0,1,-1.5) dir=(0.299,0.171,0.939)`) is a new face of the rear
  doors: probe shows the ray grazing `RearWall/RightHinge/WindowGlass`'s edge at (1.975, 2.13, 4.702) with
  the offset ray u-1 hitting nothing and u-2 hitting `WindowFrame`: a crack between the rear door's glass
  edge and its frame's inner return. Fix it with the rear door work (step 3): glass larger than the
  frame's hole by 2 cm and seated in the frame's depth, or the frame's inner return closed.
- **Window reveals by design?** `LeftWallReveals` (144) at (-2.609, 1.575, 1.613) and `RightWall` (11)
  at (2.478, 2.288, -1.586): rays enter a window cut's edge and hit the reveal/wall; D41 says the
  frames surround the cut, so reveal faces seen inside a window opening can take a LEAK_OUT exemption
  (needs `rule_for("LEAK_OUT", ...)` plus a hit-inside-window-cut test) once the B-pillar hole is fixed.
- **Test geometry**: `Floor/Deck` (3), `RearEntryRamp` (3) come from ring origin (1.812, 2.0, 4.814),
  0.2 m behind the rear doors, grazing the deck's end face under the doors: decide exempt (rear sill,
  by design) or push ring origins out to half-extent + 2 m (changes every ray: re-baseline counts).

## Blocker
none

## Next phase
Phase 12 continues (partial). Step (1) is done (D53). Order now: (2) LEAK_OUT exemption for jamb lips and
reveals seen through openings (`rule_for("LEAK_OUT", ...)`; `van_audit_gaps.gd` is at 399: split first) +
side door leaf seal where the probe shows see-through (`Left/CurvedBody` y 0.16 row), (3) rear door centre
seam strip plus the rear window glass-to-frame crack (the LEAK_IN above; split `rear_doors.gd` first),
(4) LEAK_OUT exemptions for window reveals and the rear sill, (5) EDGE rows below. Each fix: check, smoke,
audit; shots for (2) and (3). Its EDGE input, after phase 11: `Cab/CabLiner` (78, bottom
edge y -0.222 z -4.72, 5 m), `Cab/CabBackLip` (31), `Hull/RearSkin` (2), `Hull/CornerPostFL/FR` (12 each),
`Hull/BellySkin` (2), `RearWall/Left|RightHinge/CurvedBody` (100 each), `Hull/RearCornerL/R` (1 each): fix
holes, or add a rule with reason and D to `van_audit_exempt.gd`. The 9 FLICKER leftovers (CasingLeft/Right vs
CasingHead, Vault vs PatchCeil0_Ring, Cables @366/@386, FrameRailL/R vs RearBumper, CatchBin Scrap2/Scrap8,
VentDuct vs VentGrille, Bulkhead TopRail_9 vs MeshBack_322) are code fixes for phase 12 or 13. No phase
question stops.

## Requirements / gotchas
- Animated machine parts are frozen at rest in the audit (D48). Row presence uses `total`, not per-pair cuts (D51).
- Remaining EDGE rows (CabLiner/BackLip/Face, 6 Wells (single plates, by design: exemption),
  RearSkin, CornerPostF L/R, BellySkin, RearWall hinge CurvedBody, 4 ExteriorPane, SideSkin L/R,
  RearCorner L/R) each need a look; by-design single-sided ones go on an audit exemption list.
- The audit's `at=` is a padded-AABB cell corner, not the faces' position: find the faces from the
  meshes' own numbers (the hanger rows were "at z -2.6" for a hanger at z -0.6).
- Front flares use `WHEEL_X` without `FRONT_WHEEL_OUT`: only 2 cm beyond the front tyre.
- The cab's back edge meets `FrontSkin` at z -4.70: keep the cab outline on
  `VanBodyProfile.section_points(steps, true)`.
- A fresh worktree's first smoke fails on `VanLook` not found; run `py -3 tools/check.py` first.
