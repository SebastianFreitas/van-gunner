# vanfix

Stage: running
Started: 2026-09-28
Procedure: `.claude/skills/plan/SKILL.md` (the interview, then "go"; state in `.claude/plans/vanfix.state.md` while running).
Interview: done under the old procedure (no parts A/B/C); missed: audit tool layout and method (D11 auto); gap size where 1 cm meets the audit's 1 cm coplanar tolerance (D12 auto); side door slide clearance through the wall (D13); door front edge vs cab wall (D14); street lighting on door and window parts (D15); window hinge pivot position (D16 auto); side skin layering against the wall (D17 auto); who owns the opening reveals and whether the buried casings go (D18 auto); side door slide path vs the belt line and rub rail (D19); whether the front audit calls for replacing the cab (D21 auto); front wheels moved out to clear the cab skin (D22 auto); audit speed-up, front windows posed apart from their doors and cross-mesh EDGE seams (D23 auto)

## Rebase note (2026-09-28, landed on main)

This plan was written in a worktree cut from main at 1554975, before
van-exterior-2 phases 2 to 7 landed (c4711c6 .. c970044). Main now has the
audit (`research/van-exterior-2-01-audit.md`), the seam patches
(`van_hull_patches.gd`), the side-window exterior panes and casings, the
real cab-over cab (`van_cab*.gd`), the chassis kit (`van_chassis.gd`) and
the night read. So:

- **Current state** and **First look** below describe the old van: phase 1
  re-surveys the code on main and re-takes the shots before trusting them.
- **D1** is overtaken: van-exterior-2 finished (Stage: done), nothing is
  parked from it.
- **D5 is reopened**: phase 4 seals the existing real cab (gaps, joins to
  the body) instead of replacing it with a simple block; ask the owner at
  phase 4's start if the audit says otherwise.
- The owner's pictures 1 to 3 (side door from inside, window sawtooth)
  were taken of main's van and still stand.

## Brief (owner's words, verbatim)

> we need to fix the van once again dude
> from the outside 90% of the assets are not properlly connected
> the side doors, form the inside have some asset flcikering on top of eahc other probably
> also theres still artifacts coming out of the van, specially on the backpart, form the ouside you see weird vertical walls going above the van.
>
> for this place i wanan focus on these things specifically, right now, it doesnt matter if the textures are amazing, or whaetver, it looks horrible because of these 2 main issues, the assets arent connected you can see inside from literally every angle, and theres asset cliping, i have specially noticed on the window, the corners, very noticable after you open the window, and the side door on the inside. make a plan to review everything about the van for this specific problems and solve them
> if you want, before you start making the plan and ask me questions, i could send you tons of pictures

## Scope

- In: the van's geometry only: `scenes/van/van_shell.tscn` and its builders in `scripts/van/` (side walls, side doors and `side_door_leaf.gd`, side windows, rear doors, front wall, ceiling, pillars, rails), `scripts/van/look/` (hull, hull lines, cab, front kit, armour, markings, marker lights, wheels, roof, roof junk, rear dressing), a new geometry audit under `tools/`, new close-up views in `tools/smoke/smoke_shots.gd`, `.claude/rules/van-shell-and-hud.md`.
- Out (stays exactly as is): textures and shader looks (the brief: "it doesnt matter if the textures are amazing"); DoorSpill, RearCone, ExteriorLight and the `*-outside` budget; door and window gameplay (breach, smash HP, weld, gun ports), breach points and walk space; interior machines and cables unless the audit names one; the detailed real cab (D5).

## Current state (explored 2026-09-28; anchors drift, grep the names)

- `van_shell.tscn` `Shell`: SideWalls (`VanSideWall`), Ceiling (vault), Floor, SideWindows (4: hinge + frame + glass + iron + breakable), SideDoors (CSG-style Panel parts Body/OuterSkin/Inset/BeltLine/LowerCrease), SidePillars (6 hard-coded 0.18 × 3.05 × 0.5 m posts), Rails (4 bowed edges).
- `VanBodyProfile`: `inner_x_at`, `outer_x_at` (+0.12 wall), `roof_y_at`, `outer_roof_y_at` (+0.14 roof); the one outline.
- `van_hull.gd`: skin pushed out 0.06 (`SKIN_OFFSET_M`) from the liner, i.e. halfway through the 0.12 wall, built as separate sides, roof (0.05 lip), rear, sills (y -0.25): separate pieces, not one closed body.
- `van_hull_lines.gd`: rails, belt, drip, corner posts at `inner_x_at + 0.06`, the same plane as the skin.
- `side_door_leaf.gd` `fit_door_leaf`: body 0.14 thick, outer skin 0.035, frame rings and panel trims at 0.035–0.045 offsets on the same curve: coplanar candidates for the inside flicker.
- `side_windows.gd` `_fit_window_root`: glass, iron cross and breakable glass ride the hinge within 1–6 cm of the fixed frame (0.05 thick at offset 0); the 10-step frame ring and the cross bars meet at the corners the swing passes.
- `rear_doors.gd`: two leaves 0.16 thick, 12 mm centre gap, window hole; `van_rear_dressing.gd` adds lock bar, welded bars, chains, cage corners.
- `van_cab.gd`: hood, windshield, header, headlights; from the quarter view the front is an open box you can see into.
- Add-ons: `van_armour.gd` (plates at a fixed `FACE_X` 2.6, rebar, spikes, road signs), `van_roof.gd` (rack at y 3.66, antennas 1.2–2.2 m, dish), `van_roof_junk.gd` (can exceed the rack), `van_wheels.gd` (spares, arches, flaps).
- Tooling: `smoke_shots.gd` whole-van views v01–v03, interior v04–v07, lit v08–v16; debug `ghost`, `torch`, `floodlight`.
- Owner pictures (2026-09-28, `images/1-3.png` in that session's scratchpad): (1) side cargo door from inside is a see-through hole: the leaf's inner face is missing, the street shows through and only trim strips float in it; (2) same with the gun port open; (3) the opened side window: the frame ring and wall reveal have sawtooth, stepped edges along the opening. The rear "vertical walls above the van" had no picture: the audit finds them.
- First look (2026-09-28 shots): side door leaf reads as a glossy black slab from outside; the front is an open wooden box; rear doors and hull meet the side skin with visible steps.

## Option map (planning only; struck lines are settled by a D)

### Relation to van-exterior-2
- ~~Replace it, park cab/underside/night read~~ → D1
- ~~Pause and resume after~~ / ~~Fold into it~~

### Finding problems
- ~~Headless measuring audit + close-up shots, kept in smoke~~ · precedent: mesh-lint passes in asset pipelines (open-edge / coplanar checks) → D3
- ~~Shots only~~ / ~~Owner pictures only~~

### Holes
- ~~One closed outer body from the outline, reveals at openings~~ · precedent: watertight/manifold hulls (racing-game car shells) → D4
- ~~Patch each gap~~ / ~~Double-sided liner~~

### Front
- ~~Sealed simple cab block~~ → D5 / ~~Full real cab now~~ / ~~Leave out~~

### Add-ons
- ~~Snap to body, height cap, else drop~~ → D6 / ~~Strip all~~ / ~~Only pictured ones~~

### Flicker
- ~~One owner per surface, fixed lift gap for trim~~ · precedent: decal offset / polygon offset practice → D7 / ~~Nudge apart~~

### Window swing
- ~~Same swing, clearance checked at closed, half, open~~ → D8 / ~~Slide into pocket~~ / ~~Outer shutter~~

## Open items

- none (round 2 answered 2026-09-28).

## Decisions (owner answers; `(auto)` = taken while running, review at the end)

- **D1 · Old plan.** Vanfix replaces van-exterior-2: it takes over the audit, holes/seams and window phases; the cab, underside and night-read phases are parked as notes for after vanfix.
- **D2 · Pictures.** Yes: the owner sends pictures before round 2.
- **D3 · Audit.** Tool + close-up shots: a headless audit tool lists every pair of surfaces lying on top of each other and every gap between outside pieces, with node names; fixed close-up shots of every seam, door and window, closed and opened; it stays in the smoke test so a new gap or overlap fails.
- **D4 · Holes.** One closed outer body: the outside skin rebuilt as one sealed shell from the body outline (sides, roof, rear, front, bottom meeting), every door and window opening lined by a reveal; add-ons sit on top.
- **D5 · Front.** (Reopened, see Rebase note: seal the existing real cab.) Seal it as a simple cab: a plain sealed cab block on the body outline (windshield, doors outlined, no gaps); the detailed real cab stays parked.
- **D6 · Add-ons.** Snap to the body, else drop: every add-on placed against the sealed body's surface and checked (touches the body, clear of every door, window and opening, under a height cap above the roof); a failing one is not built.
- **D7 · Flicker.** One owner per surface: duplicates deleted; trim, frames and plates that sit on top lifted by a fixed gap (about 1 cm); the audit checks the gap.
- **D9 · Order.** Inside first: audit tool and shots → side door and window from inside → sealed outer body → sealed simple cab → add-ons snapped and height-capped.
- **D10 · Gun port.** Leave the port as is: the door leaf is sealed and solid from inside around the port's existing opening; hatch, hole and open/close stay as they are and the audit skips them. The port gets a full rework later (owner: "its gonna have to be fully reworked").
- **D8 · Window.** Same swing, clean clearance: frame, glass, bars and wall opening cut so nothing passes through anything anywhere in the swing, checked at closed, half and fully open.
- **D11 · Audit layout (auto).** `tools/van_audit.py` + `tools/van_audit/` runner that boots the van at IDLE like the probe, collects every visible triangle in rig space, and reports FLICKER / CLIP / OPENING (triangle tests, doors and windows posed closed, half, open without tweens), HEIGHT / REAR_ROOF, EDGE and LEAK_IN / LEAK_OUT (Jolt ray and sphere queries on temporary layer-20 proxies); close-ups are a `c`-prefixed view set so `v01`.. never renumber. Reason: physics queries make leaks cheap in GDScript, and a separate tool keeps smoke untouched until phase 5 wires it in.
- **D12 · Gap vs audit tolerance (auto).** Where two parallel faces sit edge to edge (leaf vs jamb, frame rim vs wall cut, trim ends vs frame openings) the gap is 2 cm, because the audit counts faces within `PLANE_EPS` 1 cm as coplanar; stacked depth lifts stay `TRIM_LIFT` 1 cm (D7). Reason: 1 cm exactly still flagged, and 1 cm more is invisible in play.
- **D13 · Door slide recess.** The side door recesses 0.24 m outward (was 0.17) before sliding, so its cabin-side trim clears the 0.16 m side wall; the open door stands 7 cm further off the van side and keeps its framed-panel relief inside.
- **D14 · Door front edge.** Shorten the side door 13 cm at its front edge (2.34 → 2.21 m wide, rear edge unchanged); the wall opening, jamb and track follow, so nothing is buried in the cab back wall or the front corner posts.
- **D15 · Street-lit door and window parts.** Door `CurvedOuter`, `LatchPlate`, `Handle` and window `CurvedFrame`, `WindowGlass`, `IronCross` go on render layers 1 and 2, so street lights, the torch and cabin lights all reach them.
- **D16 · Window hinge pivot (auto).** The side window's hinge pivot moves from the liner to 0.32 m outboard of it at the same height (past the hull skin's outer face at 0.22 and the casing at 0.13; 0.14 still clipped the skin's rounded top corners), so no sash part rises into the wall while it swings (D8). Reason: with the pivot at the liner the frame's outer top corner lifts into the wall above the cut; any pivot outboard of every sash part and all wall material fixes it with no visible change when closed.
- **D17 · Side skin layer (auto).** The side hull skin owns only the outer layer: the wall's own grid and cuts from the wall's outer face (0.16) to `VanHull.SIDE_SKIN_OUTER_M` 0.22 off the liner, no inner face, so its returns continue the wall's edge to edge. Reason: the old skin was the whole wall panel shifted 0.06 out, overlapping the wall and z-fighting its returns (4 m² FLICKER); 0.22 keeps the outer face, casings and `HINGE_OUT_M` where they are.
- **D18 · Reveal owners (auto).** Each side opening's cut is lined by two bands with one owner each: the wall's own reveal from the liner to 0.16 (split into `<Left|Right>WallReveals`, wall material, layers 1+2) and the skin's returns from 0.16 to 0.22; the door jamb keeps only its lip (its outer return is stripped), and the side door and window casings, fully buried inside wall and skin with holes equal to the cuts, are deleted as duplicates (D7). Reason: no visible change from inside, street light now reaches the reveal from outside, and every duplicate face pair is gone.
- **D19 · Hull lines over the door's slide path.** The belt line and the rub rail break over the side door's slide path, from the door bay's rear edge to the fully open door's rear edge, the way the drip rail breaks around openings; the door itself carries no rail. The recess stays D13's 0.24 m and the rails keep their profile.
- **D21 · Cab sealing scope (auto).** The phase 4 audit shows no LEAK, CLIP or OPENING row at the front and the shots show a closed cab, so D5's reopened course stands: phase 4 keeps the real cab and only removes its coplanar trim (FLICKER) and closes the back wall from both sides. Reason: nothing in the audit says otherwise.
- **D22 · Front wheels off the cab skin (auto).** The front wheels sit `VanWheels.FRONT_WHEEL_OUT` 0.04 m further out than the rear, the cab steps 3 cm out (inner face 2 cm off `CabSkin`) and the A-pillars 3 cm inside the outline (2 cm inside the bumper ends), because the tyre caps, treads and steps lay on the cab's bowed side plane and the pillars 1 cm off the bumper ends (FLICKER). Reason: a few cm, invisible in play; review at the end.
- **D23 · Audit poses and seams (auto).** The audit visits each flicker pair once (padded-AABB min-corner cell, normal and moving-root rejects first; ~50 s whole run), poses the side doors with the rear windows (`half`, `open`) and the door-adjacent front windows alone (`win_half`, `win_open`) as the interlock allows in play, and closes an open edge whose ends and midpoint each lie within 1.5 cm of another mesh's edge. Reason: `--strict` in smoke needs a fast run with no rows play can never show; test tooling only.

## Constraints (every phase)

- Geometry only: no texture or shader-look work; exterior materials keep their recipe (`art-style.md`: procedural grime, metallic ≤ 0.3, roughness 0.78–0.95, always night).
- `VanBodyProfile` is the one outline for anything meeting the wall, vault or skin (rules file); no piece gets its own width constants.
- Light pairing: set `layers` / `light_cull_mask` before `add_child`; retarget only through `VanLighting.retarget_layers`.
- Door/window gameplay, breach points, collision shapes and walk space unchanged unless a phase says so.
- `DEFAULT_VAN_SEED` 1337; the scene dump and smoke fingerprint are blessed only by a phase that says the tree changes, and the report says so.
- Worktree mode: commit by path on the branch, never push.

## Progress

| # | Phase | Kind | Rests on | Status |
|---|---|---|---|---|
| 1 | Geometry audit tool and close-up shots | code, research | D3, D9, D11 | done 60e1a32 |
| 2 | Side doors and windows from inside | code | D7, D8, D10, audit | done cf9e65a |
| 3 | One sealed outer body | code | D4, D7, audit | done a809f31 |
| 4 | Sealed simple cab | code | D5, D4, audit | done 815948b |
| 5 | Add-ons snapped and height-capped | code | D6, audit | todo |

## Phases

### 1 · Geometry audit tool and close-up shots (D3, D9)
Research: how to list coplanar overlaps and open gaps from Godot meshes headless (triangle/AABB tests on the built `van.tscn`), then go past it.
Deliverables: a headless audit under `tools/` (run from `tools/smoke/` or its own `.py`) that instances the van at seed 1337 and reports, with node paths: surface pairs within 1 cm of each other and facing the same way (flicker), outside edges that don't meet a neighbour (see-through gaps), anything above a roof height cap, anything passing through a door or window opening; side doors and windows checked closed, half and fully open; the gun port skipped (D10). Close-up `--shots` views of every seam, both side doors from inside and outside, every side window closed and open, the rear roof line. `.claude/plans/research/vanfix-01-audit.md`: every finding (node, builder, picture, severity), the owner's three pictures matched to findings. The audit's pass/fail wiring into smoke comes in the phase that clears its last finding; until then it reports.
Verification: check, smoke, the audit names the side-door hole, the window sawtooth and something above the rear roof line.
Notes: done 60e1a32. `tools/van_audit.py` + `tools/van_audit/` (mesh, states, overlap, gaps) and close-ups c01–c32; findings in `research/vanfix-01-audit.md` (side-door LEAK_OUT on CurvedOuter, window CurvedFrame FLICKER vs hull casing, REAR_ROOF rack/crate/antenna). Audit takes ~4 min.

### 2 · Side doors and windows from inside (D7, D8, D10)
Deliverables: side door leaves solid from both sides (inner face built, trim lifted by the D7 gap, duplicates removed), port untouched; the window frame, reveal, glass and iron cut clean along the opening with no stepped edges and no part crossing another at closed, half or open.
Verification: check, smoke, scene dump (bless if the tree changes, say so), audit clear for doors and windows, close-up shots re-read against pictures 1–3.

### 3 · One sealed outer body (D4, D7)
Deliverables: the exterior skin rebuilt as one closed shell from `VanBodyProfile` (sides, roof, rear, bottom, meeting the front), reveals at every door and window, hull lines on the D7 gap, the rear doors seated in it; the liner faces only in.
Verification: check, smoke, scene dump, audit clear for gaps on the body, lit shots v08–v16 and the new close-ups.
Notes: done a809f31 (sessions 4–9: 1e0f3ab..a809f31). Side skin 0.16–0.22 (D17), reveal owners (D18), roof/rear/sills/belly/front skin at the 0.22 face, RearSkin ring around the leaves, hull lines breaking over the door slide (D19), FrontSkin closing the cab step. Audit: CLIP 102, EDGE 24, FLICKER 1727, LEAK_IN 1, LEAK_OUT 44; the body's EDGE rows left are per-mesh seams and the single-sided side skin, no holes.

### 4 · Sealed simple cab (D5, D4)
Deliverables: `van_cab.gd` front closed into a plain sealed block on the body outline, windshield and door outlines, joined to the body without gaps; front kit refit onto it. The detailed cab stays parked.
Verification: check, smoke, scene dump, audit clear at the front, front and quarter shots.
Notes: done 815948b (session 11: fda7fad, 23f70b1, 815948b). Real cab kept (D21): windshield frame, post, grille surround, headlight bezel/lens buried off the cab face's plane, back wall double-sided; ram joints, cage tabs, lamp cages refit; cab steps, front wheels and A-pillars off the cab side and bumper (D22). Audit: `VanLook/Cab/` FLICKER 41 → 0, total FLICKER 1727 → 1683; the 3 cab EDGE rows left are tube ends (CabLiner, CabBackLip) and a CabFace seam at the windshield corner, no holes.

### 5 · Add-ons snapped and height-capped (D6)
Deliverables: armour, rebar, spikes, signs, roof rack, roof junk, antennas, spares and rear dressing placed against the sealed body's surface; a placement check (touches the body, clear of openings, under the roof cap) drops any failure; the audit becomes a smoke failure.
Verification: check, smoke (fingerprint/bless as the phase states), scene dump, audit fully clear across several `van` seeds, rear and roof shots.

## Carry forward

- (Phase 1) The audit takes ~4 min, nearly all in three FLICKER passes; phase 5 must speed it up (normal bucketing, or moving-roots-only flicker at half/open) before `--strict` goes into smoke.
- (Phase 1) The side door leaf `CurvedBody` clips the jamb, casing and forward into the cab back wall (z to -4.74); fix the leaf length before triaging the door OPENING rows (props in the PcRig/CabRelay area).
- (Phase 1) Rear doors show the same missing inner face as the side doors (LEAK_OUT on `RearWall/*Hinge/CurvedBody`): phase 3 seats the rear doors.
- (Overtaken, see Rebase note: van-exterior-2 finished all seven phases.) Parked from van-exterior-2 (D1): the real cab with a dark interior and dash glow (its D3, D9), the underside and wheels (D6), the night read (D7). Its phase 1 tooling (torch, floodlight, lit shots v08–v16) stays and is used here.
- A fresh worktree's first smoke run fails on `VanLook` not found (stale class cache); `py -3 tools/check.py` first fixes it.
- (Phase 2) The audit poses every door and window at the same fraction, so the front window and its side door are audited open together, which the interlock forbids in play (except a breach smash); phase 5 should pose door-adjacent windows and their door in separate states.
- (Phase 2) `side_windows.gd` `HINGE_OUT_M` 0.32 is sized to today's hull skin (panel mesh 0.16 thick, 0.06 out: outer face 0.22 off the liner). Phase 3 rebuilds the skin: re-derive it (pivot outboard of all wall material around the opening, open pane below the cut's rounded top corners) and re-audit the window swing.
- (Phase 2) Left for later phases: front window vs its own slid-open door rows (the audit's all-open pose; play's interlock forbids it except a breach smash, phase 5 poses them apart); door vs `VanLook` Hull/Armour/Wheels/Cables/MarkerLights rows (D6, phases 3 and 5); `CurvedBody` LEAK_OUT past the jamb gap (phase 3); ExteriorPane EDGE rows (single-sided pane, by design); the rust band on the window reveal in c10 is the grime shader, not geometry.
- (Phase 3) Every exterior piece but the side skin sits at `SKIN_OFFSET_M` 0.06 off the liner (roof edge, rear posts, sills, patches, hull lines, armour face), while the side skin's outer face is at 0.22 (D17): the sealed body needs one outer surface; the roof crown must stay under the rack (y 3.66). `VanBodyProfile.outer_x_at` is liner + 0.12 but the wall is 0.16 thick.
- (Phase 3, session 5) `HINGE_OUT_M` 0.32's reasoning named the window casing (0.13), now deleted; the skin's outer face 0.22 still sets it. `van_side_wall_panel.gd` and `van_side_wall_shell.gd` are at the 400-line cap: any further panel or ring change needs a helper split first.
- (Phase 3) The audit's EDGE check is per mesh (open = one triangle, no physics body within 1.5 cm), so edge-to-edge seams between hull pieces (FrontSkin/RoofSkin, RearSkin/Sill/BellySkin/RearCorner at the rear bottom corner, CornerPostF caps at z -4.58) and SideSkin's by-design missing inner face (D17) still report; phase 5 should match edges across meshes before `--strict`. LEAK_IN 1 at (2.703, 1.086, -0.202) is unexplained. Optional FLICKER: `Left/RightWall` vs `DoorJamb_L/R` at (±2.495, 2.237, -4.644), `DoorJamb_R` vs `FrontWall/Slab`.
- (Phase 4) Every wheel's `Hub` and its `Bolt%d` boxes share planes (FLICKER on `VanLook/Wheels/Wheel*/Hub`, 30 rows); `van_wheels.gd` `_build_wheel`. Clear them with the add-ons in phase 5 (a 2 cm lift of the bolts off the hub face).
